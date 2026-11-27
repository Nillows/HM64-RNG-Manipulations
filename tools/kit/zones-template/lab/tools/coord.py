"""Two (or more) machines on one job list, coordinated through small text files (2026-11-25).

The campaign cuts its full, ordered job list into numbered blocks. A machine works the blocks from the top down
(order "up": block 0, 1, 2 ...), from the bottom up (order "down": last block first) or from the middle outwards,
alternating sides (order "middle"), and stops when every block is done by somebody. Any number of machines. Each machine writes ONLY its own file in the shared folder:

    <dir>/<campaign>/<machine>.claims      lines:  list <sha1> <jobs> <blocks> | claim <b> <t> | done <b> <t> |
                                                   drop <b> <t> | hb <t>

A host-side script (tools/hm64_coord_sync.sh) copies these files to and from a git branch and writes <dir>/.sync_ok
(the time of its last successful round). Without that script the folder is simply local: one machine, same results.
Two machines that claim the same block at the same moment: the smaller machine name keeps it, the other drops it.
A claim whose machine has shown no sign of life for HM64_COORD_STALE_MIN minutes (default 90) may be taken over.
Running a block twice is harmless (the lab is deterministic; results are keyed by job tag).
"""
import hashlib
import os
import time
from pathlib import Path


class Coord:
    def __init__(self, folder, campaign, machine, order="up", nblocks=50, now=time.time, sleep=time.sleep):
        if order not in ("up", "down", "middle"):
            raise SystemExit(f"STOP: order must be up, down or middle (got {order})")
        if not machine or any(c in machine for c in " /\\\n"):
            raise SystemExit(f"STOP: bad machine name {machine!r}")
        self.root = Path(folder)
        self.dir = self.root / campaign
        self.dir.mkdir(parents=True, exist_ok=True)
        self.me, self.order, self.nb_want = machine, order, max(1, int(nblocks))
        self.mine = self.dir / f"{machine}.claims"
        self.now, self.sleep = now, sleep
        self.stale = 60 * float(os.environ.get("HM64_COORD_STALE_MIN", "90") or 90)
        self.wait_sync = float(os.environ.get("HM64_COORD_SYNC_WAIT_S", "180") or 180)
        self.sig = None
        self.blocks = []

    # ---- files
    def _write(self, line):
        with self.mine.open("a") as f:
            f.write(line + "\n")
            f.flush()
            os.fsync(f.fileno())

    @staticmethod
    def _parse(path):
        st = {"list": None, "b": {}, "seen": 0.0, "old": set(), "first": None}
        try:
            lines = path.read_text().splitlines()
        except OSError:
            return st
        for ln in lines:
            p = ln.split()
            try:
                if p[0] == "list":
                    st["list"] = (p[1], int(p[2]), int(p[3]))
                elif p[0] in ("claim", "done", "drop"):
                    st["b"][int(p[1])] = (p[0], float(p[2]))
                    st["seen"] = max(st["seen"], float(p[2]))
                    if len(p) > 3 and p[3] == "old":
                        st["old"].add(int(p[1]))
                    elif st["first"] is None:
                        st["first"] = float(p[2])
                elif p[0] == "hb":
                    st["seen"] = max(st["seen"], float(p[1]))
            except (IndexError, ValueError):
                continue
        return st

    def others(self):
        out = {}
        for p in sorted(self.dir.glob("*.claims")):
            if p.name != self.mine.name:
                out[p.name[:-7]] = self._parse(p)
        return out

    def synced_at(self):
        try:
            return float((self.root / ".sync_ok").read_text().split()[0])
        except (OSError, ValueError, IndexError):
            return None

    # ---- the job list
    def set_jobs(self, keys):
        """keys: the tags of the FULL job list, in order. Returns the blocks (lists of indexes)."""
        n = len(keys)
        nb = min(self.nb_want, max(1, n))
        size = -(-n // nb) if n else 1
        self.blocks = [list(range(i, min(n, i + size))) for i in range(0, n, size)] or [[]]
        self.sig = (hashlib.sha1("\n".join(keys).encode()).hexdigest(), n, len(self.blocks))
        for m, st in self.others().items():
            if st["list"] and st["list"] != self.sig:
                raise SystemExit(f"STOP: {m} works on another job list ({st['list'][1]} jobs in {st['list'][2]} blocks, "
                                 f"this machine {n} in {len(self.blocks)}): not the same campaign, plan or lab code. "
                                 "Nothing was run.")
        if self._parse(self.mine)["list"] != self.sig:
            self._write(f"list {self.sig[0]} {self.sig[1]} {self.sig[2]}")
        return self.blocks

    def heartbeat(self):
        self._write(f"hb {self.now():.0f}")

    def mark_done(self, b, old=False):
        """old=True: work done before this start (announced only; not counted in the pool's speed)."""
        self._write(f"done {b} {self.now():.0f}" + (" old" if old else ""))

    def pool(self, window=1800.0):
        """Speed of every machine on this list over the last `window` s and the time left for the whole list:
        {"machines": {name: jobs/min}, "rate": jobs/min, "left": jobs nobody has finished, "eta_s": seconds or None}."""
        t = self.now()
        allm = dict(self.others())
        allm[self.me] = self._parse(self.mine)
        done, per = set(), {}
        for m, st in allm.items():
            jobs = 0
            for b, (what, tc) in st["b"].items():
                if what != "done" or b >= len(self.blocks):
                    continue
                done.add(b)
                if b not in st["old"] and t - tc <= window:
                    jobs += len(self.blocks[b])
            if st["first"] is None or t - st["seen"] > self.stale:
                continue
            span = max(120.0, min(window, t - st["first"]))
            per[m] = jobs / span * 60.0
        left = sum(len(ix) for b, ix in enumerate(self.blocks) if b not in done)
        rate = sum(per.values())
        return {"machines": per, "rate": rate, "left": left, "eta_s": (left / rate * 60.0) if rate > 0 else None}

    def campaign(self, prefix, expect_lists=0):
        """All lists of this campaign any machine has opened (folders named <prefix>...): jobs left in them, and how
        many lists are not opened yet. {"opened", "expected", "left", "avg_jobs", "unopened"}"""
        opened = left = total = 0
        for d in sorted(p for p in self.root.iterdir() if p.is_dir() and p.name.startswith(prefix)):
            sig, done = None, set()
            for f in d.glob("*.claims"):
                st = self._parse(f)
                sig = sig or st["list"]
                done |= {b for b, (what, _) in st["b"].items() if what == "done"}
            if not sig:
                continue
            _, jobs, nb = sig
            size = -(-jobs // nb) if nb else jobs
            got = sum(min(size, max(0, jobs - b * size)) for b in done if b < nb)
            opened += 1; total += jobs; left += max(0, jobs - got)
        avg = total / opened if opened else 0
        return {"opened": opened, "expected": expect_lists, "left": left, "avg_jobs": avg,
                "unopened": max(0, expect_lists - opened) if expect_lists else 0}

    def _state(self):
        t = self.now()
        done, held = set(), {}
        for m, st in self.others().items():
            if st["list"] and st["list"] != self.sig:
                raise SystemExit(f"STOP: {m} now works on another job list. Stopping here.")
            alive = t - st["seen"] <= self.stale
            for b, (what, tc) in st["b"].items():
                if what == "done":
                    done.add(b)
                elif what == "claim" and alive:
                    held[b] = (m, tc)
        return done, held

    def next_block(self, local_done):
        """The next block for this machine: ('run', b) | ('wait', n) other machines still hold n blocks | ('end', 0)."""
        while True:
            done, held = self._state()
            left = [b for b in range(len(self.blocks)) if b not in done and b not in local_done]
            free = [b for b in left if b not in held]
            if not left:
                return "end", 0
            if not free:
                return "wait", len(left)
            if self.order == "middle":                    # nearest to the middle of the list, alternating sides
                mid = (len(self.blocks) - 1) / 2
                b = min(free, key=lambda x: (abs(x - mid), x))
            else:
                b = min(free) if self.order == "up" else max(free)
            t0 = self.now()
            self._write(f"claim {b} {t0:.0f}")
            if self.synced_at() is not None:              # a sync script is running: let the claim travel first
                lim = t0 + self.wait_sync
                while (self.synced_at() or 0) < t0 + 1 and self.now() < lim:
                    self.sleep(5)
                # one more round so the other machine's claim of the same moment has arrived too
                t1 = self.now()
                while (self.synced_at() or 0) < t1 + 1 and self.now() < lim:
                    self.sleep(5)
            done, held = self._state()
            if b in done or (b in held and held[b][0] < self.me):
                self._write(f"drop {b} {self.now():.0f}")
                continue
            return "run", b
