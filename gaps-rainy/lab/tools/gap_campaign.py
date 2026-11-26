"""
Gap campaign on the rainy files (2026-11-26; plan made by Claude: plans/gap_plan_<label>.json.gz, every job spelled
out). Jobs: experiments/spot_jobs.py (casts, no-cast lines) and experiments/gap_jobs.py (per-frame trace).

  python3 tools/gap_campaign.py --src results/dogwatch/<label> --plan gap_plan_<label>.json.gz --out results/gaps/<label> STAGE

  gate  (never shared: every Mac proves itself)  for the dog lines of part A: the chosen member of the line in each
        zone, no cast, 20 s -> the dog it shows must be the recorded line's dog, change for change, for the first
        8 s; and casts at the representative's own spot must give the recorded bites. GA_gate_*.jsonl, GA_gate.json.
        Exit 3 when it fails: part A does not count then (the runner skips it and says so).
  A     the lines never cast away from the north zone, from a member that stands in each zone   GA_casts.jsonl
  B1    recorded Nuts not proven in a zone, held to the Nut's bite + margin                      GB1_casts.jsonl
  B2    every cast a zone measured with other bites, held to 170 s after READY                   GB2_casts.jsonl
  C     per-frame trace of a sample of differing casts, from the north spot and from the zone    GC_trace.jsonl
Shared stages (A, B1, B2, C) use tools/coord.py when HM64_COORD_DIR is set: one list per stage and save, named
gaps-<label>.<stage>. Resumable: finished jobs are skipped.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "experiments"))
import spot_campaign as SC                      # noqa: E402
from common import default_rom, default_sram   # noqa: E402

GATE_S = 480            # labels (8 s) the member's dog must match the recorded line's
FILES = {"A": "GA_casts.jsonl", "B1": "GB1_casts.jsonl", "B2": "GB2_casts.jsonl", "C": "GC_trace.jsonl"}


def setup(args):
    src = Path(args.src)
    if not (src / args.zz).exists():
        sys.exit(f"STOP: {src / args.zz} is missing - --src must be the results folder of the finished dog-watch run")
    plan = SC.read_plan(args.plan)
    if plan.get("code") != "gap-plan-1":
        sys.exit(f"STOP: {args.plan} is not a gap plan")
    zz = json.load(open(src / args.zz))
    miss = [k for k in plan["reps"] if k not in zz]
    if miss:
        sys.exit(f"STOP: {len(miss)} of the plan's {len(plan['reps'])} lines are not in {src / args.zz} (first {miss[:3]}): "
                 "this is not the dog-watch run the plan was made from")
    bad = [k for k, a in plan["reps"].items() if (a["b"], a["D"], a["B"], a["ready_rel"]) != tuple(zz[k]["rep"][x] for x in ("b", "D", "B", "ready_rel"))]
    if bad:
        sys.exit(f"STOP: {len(bad)} lines have another representative here than in the plan (first {bad[:3]}): "
                 "this is not the dog-watch run the plan was made from")
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    return plan, out


def undelta(d):
    out, k = [], 0
    for i in range(0, len(d), 2):
        k = d[i] if i == 0 else k + d[i]
        out.append((k, d[i + 1]))
    return out


def code_at(runs, k):
    c = None
    for kk, code in runs:
        if kk > k:
            break
        c = code
    return c


def stage_gate(args):
    plan, out = setup(args)
    import spot_jobs as SJ
    rom, sram = default_rom(), default_sram()
    coord = os.environ.pop("HM64_COORD_DIR", None)          # the gate is every Mac's own proof: not shared
    try:
        lj = [g for g in plan["gate"] if g["kind"] == "line"]
        cj = [g for g in plan["gate"] if g["kind"] == "cast"]
        if not lj and not cj:
            print("[gate] no part-A lines on this save: nothing to prove", flush=True)
            json.dump({"ok": True, "lines": {}, "casts": {}}, open(out / "GA_gate.json", "w"))
            return 0
        bad = SC.run_stage("GA gate, lines", SJ.sp_line_job, lj, out / "GA_gate_lines.jsonl", args.workers, rom, sram, lambda j: j["tag"])
        bad += SC.run_stage("GA gate, casts", SJ.sp_cast_job, cj, out / "GA_gate_casts.jsonl", args.workers, rom, sram, lambda j: j["tag"])
    finally:
        if coord is not None:
            os.environ["HM64_COORD_DIR"] = coord
    res = {"ok": True, "lines": {}, "casts": {}, "job_errors": bad}
    rows = {r["_job"]["tag"]: r for r in SC.good(out / "GA_gate_lines.jsonl")}
    for g in lj:
        r = rows.get(g["tag"])
        if not r or not r.get("ok"):
            res["lines"][g["tag"]] = {"ok": False, "why": (r or {}).get("why", "no row")}
            res["ok"] = False
            continue
        mine, want = undelta(r["d"]), [tuple(x) for x in g["want"]["runs"]]
        lo = max(r["k0"], want[0][0] if want else 0, mine[0][0] if mine else 0) + 2
        first = next((k for k in range(lo, 1200, 2) if code_at(mine, k) != code_at(want, k)), None)
        wh = {g["want"]["h0"] + i * g["want"]["step"]: h for i, h in enumerate(g["want"]["hs"])}
        cmp = [(r["h0"] + i * r["step"], h) for i, h in enumerate(r["hs"]) if r["h0"] + i * r["step"] in wh and r["h0"] + i * r["step"] < GATE_S]
        eq = sum(1 for k, h in cmp if wh[k] == h)
        ok = first is None or first >= GATE_S
        res["lines"][g["tag"]] = {"ok": ok, "member": [g["b"], g["D"], g["B"]], "k_off": g.get("k_off"), "shift": r.get("shift"), "jack": r.get("jack"),
                                  "dog_same_until_label": first, "hashes_equal_first_8s": [eq, len(cmp)], "grid_changes": r.get("g2")}
        res["ok"] = res["ok"] and ok
        print(f"[gate] {g['tag']}  member D {g['D']} B {g['B']} (k_off {g.get('k_off')}), Jack at {r.get('jack')}: the recorded dog "
              + ("to the end of the 20 s" if first is None else f"until label {first} ({first / SC.VI_S:.1f} s)")
              + f"; cast hashes equal in the first 8 s: {eq} of {len(cmp)}  ->  {'ok' if ok else 'NOT the recorded line'}", flush=True)
    rows = {r["_job"]["tag"]: r for r in SC.good(out / "GA_gate_casts.jsonl")}
    n_ok = n_bad = 0
    for g in cj:
        r = rows.get(g["tag"])
        for c in (r or {}).get("casts", []):
            want = [tuple(x) for x in g["want"].get(str(c["k"]), [])]
            got = [(b[0], b[1]) for b in c["b"]]
            n = min(len(want), len(got))
            if n and want[:n] == got[:n] and abs(len(want) - len(got)) <= 1:
                n_ok += 1
            else:
                n_bad += 1
                res["casts"][f"{g['key']}:{c['k']}"] = {"want": want[:6], "got": got[:6]}
        if not r:
            n_bad += len(g["casts"])
    res["control"] = [n_ok, n_bad]
    res["ok"] = res["ok"] and n_bad == 0 and not bad
    print(f"[gate] control casts at the recorded spot: {n_ok} as recorded, {n_bad} not", flush=True)
    json.dump(res, open(out / "GA_gate.json", "w"), indent=1)
    print("[gate] " + ("PASSED" if res["ok"] else "FAILED: part A does not count on this Mac (see GA_gate.json); the other parts do not depend on it"), flush=True)
    return 0 if res["ok"] else 3


def stage_part(args, part):
    plan, out = setup(args)
    import spot_jobs as SJ
    import gap_jobs as GJ
    rom, sram = default_rom(), default_sram()
    jobs = plan["jobs"][part]
    if args.max_jobs:
        stp = max(1, len(jobs) // args.max_jobs)
        jobs = jobs[::stp][:args.max_jobs]
    if not jobs:
        print(f"[{part}] no jobs on this save", flush=True)
        return 0
    os.environ["HM64_COORD_CAMPAIGN"] = f"gaps-{plan['label']}.{part}"
    # blocks per list from its length (about 90 jobs each, 2 to 30): a claim costs about a minute of waiting for the
    # other Macs, so a short list must not be cut into 50. The same on every Mac (it follows from the plan).
    os.environ["HM64_COORD_BLOCKS"] = os.environ.get("HM64_GAP_BLOCKS") or str(max(2, min(30, round(len(jobs) / 90))))
    fn = GJ.gap_trace_job if part == "C" else SJ.sp_cast_job
    ncast = len(jobs) if part == "C" else sum(len(j["casts"]) for j in jobs)
    print(f"{GJ.GAP_CODE if part == 'C' else SJ.SP_CODE}  part {part}: {ncast} casts in {len(jobs)} jobs", flush=True)
    bad = SC.run_stage(f"G{part}", fn, jobs, out / FILES[part], args.workers, rom, sram, lambda j: j["tag"])
    return 4 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--plan", required=True)
    ap.add_argument("--zz", default="zz_lines.json")
    ap.add_argument("--out", required=True)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--max-jobs", type=int, default=int(os.environ.get("HM64_GAP_MAX_JOBS", "0") or 0), help="test: at most this many jobs per part")
    ap.add_argument("stage", choices=["gate", "A", "B1", "B2", "C"])
    args = ap.parse_args()
    return stage_gate(args) if args.stage == "gate" else stage_part(args, args.stage)


if __name__ == "__main__":
    sys.exit(main())
