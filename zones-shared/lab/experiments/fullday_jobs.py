"""
Full-day lab (2026-11-20, Thomas): the cast table and the dog to the END OF THE GAME DAY, on the dog lines of a finished
dog-watch run (beach-lineup2: menus 0-6 game frames late). Two jobs, both replaying a line's representative route from
its stored beach state, exactly as zigzag_jobs.zz_line_job / zz_cast_job do:

  fd_line_job   no cast. The natural path from READY to the end of the day with the stay-awake push (stick south-east,
                4 polls) every 2000 VIs: the dog's visible runs for the whole day (the cards BEFORE a cast), the cast
                hash every 2 VIs (which casts are distinct states), the clock at READY, when and how the day ends.
  fd_cast_job   for each cast frame k (VIs after READY): B from k, held to the end of the day on one unbroken run
                (no reloads on that run): every bite, the dog's visible runs the whole time (the cards AFTER the cast),
                a savestate at each bite; then from each bite's state B is let go 4 polls after the bite (bites 1-2
                also 12, as the dog-watch run): Nut / fish size / miss ("d" = the day ended before the catch), and the dog for
                `tail` VIs after the bite on that released path (after a release the random numbers go another way than while holding).

Times are VI labels after the line's READY (the harness restores VI labels exactly across savestate loads); a bite's
time is the first VI its window shows, as in the dog-watch run's tables.

`until` (2026-11-20 16:21, Thomas: "most attempts reset after a minute or so ... just get the same 90 seconds again"):
both jobs stop at that VI label instead of the end of the day; a cast keeps going past it until its second bite has
shown, exactly as the dog-watch run did (bites 1-2 always, later bites while they show by the limit). End = "limit".

THE BEACH CHECK (Thomas: "a check that you are still on the beach ... on the dock with the dog in line2 position"):
at READY the job records where Jack and the dog are and refuses a line whose dog is not at the expected spot; then on
every VI the map must still be the beach, and every 30 VIs Jack must be where he stood at READY (at the dock end) and the
dog's record must say "beach". The first failure ends that run and is written down with its time; nothing after it is
recorded. The end of the day itself (06:00: the game takes the controls, player action 254, then loads the house) is
reported as "day".
The dog walking is NOT a failure: found with the first sandbox run of this lab, on some lines the dog leaves its tile
later in the day (first seen 137 s after READY) - that is the game, and the cards have to show it. So the dog's position
is recorded whenever it has moved 4 units or more (`p`: [k, x, z] at the 30-VI checks) and so is every change of
"the dog's tile is on the visibility grid" (`g`: [k, 0 | 1]; off the grid it does not animate and cannot be seen).

Game facts used [DECOMP]: time.c handleTimeUpdates runs once per game update from mainGameLoopCallback and updateClock
adds 10 game seconds, so a game hour = 360 updates = 720 VIs = 12.03 s; at gHour == 6 it calls setPlayerAction(254) and
handleExitLevel(END_OF_DAY). player.c handleFishingAction: waiting rolls range(0, 400) every update while B is held and
has no time-of-day term. [EMU 2026-11-20, sandbox, dog-beach save with the dog moved to the lineup2 tile] READY at
06:50, day end 16,684 VIs after READY, 26 bites on one all-day hold, stamina unchanged, dog on its tile all day.
"""
from __future__ import annotations

import os

from _base import ROOT, A  # noqa: F401
from hm64.fishing import FISHING, FISH, NUT_BITS, WAKE_POLLS, _B, _SE, _in_window, _resolver, _classify
from hm64.zigzag import ZigZagInput, drive, MAP_CTRL, MAP_BEACH, ENT_DOG, ENT_PLAYER, cast_hash, map_is
from zigzag_jobs import STORE, READY_X_MIN, _bkey, _meta, _tmpdir, _cleanup, dog_visible

WAKE_EVERY = 2000        # stay-awake push every 2000 VIs after READY (campaign "awake": keeps the 40 s idle nap away)
NO_PUSH_BEFORE = 2360     # casts before this label need no push (the nap comes 2400 VIs after Jack stops): none is
                         # made, exactly as in the dog-watch run, whose casts end at 2398
WAKE_GUARD = 30          # a runner never pushes right before casting (campaign_jobs: w + 30 <= cast)
CHECK_EVERY = 30
JACK_TOL = 2.0
DOG_TOL = 96.0           # at READY the dog must be within this of the save's dog spot. Was 24 (its tile) until the first
                         # Mac run (2026-11-20): on 1 of 120 lineup2 lines the dog has already walked 25 units by READY
                         # (-223.3, 220.7); that is the game, so the line is kept and its READY position recorded.
POS_STEP = 4.0
DAY_MAX = 17400          # safety: the day ends ~16,700 VIs after READY
END_OF_DAY_ACTION = 254
IDLE_NAP = 9                 # player.c startAction(IDLE_NAP): 1200 idle updates (40 s)
KIND = {37: "s", 38: "m", 39: "l"}


class DayController:
    """Poll callback. q = VI label (after READY) of the poll = q0 + polls since arming. Stay-awake pushes at every
    multiple of WAKE_EVERY (not within WAKE_GUARD before a cast), B from `cast` until `release` (None = keep holding)."""

    def __init__(self, q0, n0=0, cast=None, release=None, push=True):
        self.q0, self.n0, self.cast, self.release, self.push = q0, n0, cast, release, push

    def __call__(self, n):
        q = self.q0 + n - self.n0
        if self.cast is not None and q >= self.cast:
            return _B if (self.release is None or q < self.release) else 0
        if self.push and q >= WAKE_EVERY:
            r = q % WAKE_EVERY
            if r < WAKE_POLLS and (self.cast is None or q - r + WAKE_GUARD <= self.cast):
                return _SE
        return 0


def in_push(k, lo=-2, hi=40):
    """Is label k inside (or just after) a stay-awake push of the no-cast schedule? Hashes there are not compared."""
    return k >= WAKE_EVERY and lo <= (k % WAKE_EVERY) <= hi


def _clock(e):
    return [e.u8(A.HOUR), e.u8(A.MINUTES), e.u8(A.SECONDS)]


def _spot(e):
    return {"jx": e.f32(ENT_PLAYER + 0x28), "jz": e.f32(ENT_PLAYER + 0x30),
            "dx": e.f32(ENT_DOG + 0x28), "dz": e.f32(ENT_DOG + 0x30), "dloc": e.u8(A.DOG + 0x16)}


def beach_fail(e, ref):
    """None when Jack is still at his READY spot at the dock end, on the beach, with the dog still at its spot."""
    m = e.u16(MAP_CTRL)
    if not map_is(m, MAP_BEACH):
        return f"map {m}"
    jx, jz = e.f32(ENT_PLAYER + 0x28), e.f32(ENT_PLAYER + 0x30)
    if abs(jx - ref["jx"]) > JACK_TOL or abs(jz - ref["jz"]) > JACK_TOL:
        return f"jack moved to {jx:.1f},{jz:.1f}"
    if not map_is(e.u8(A.DOG + 0x16), MAP_BEACH):
        return f"dog record map {e.u8(A.DOG + 0x16)}"
    return None


def _to_ready(emu, j):
    """Replay the representative from its beach state to READY. Returns (R, ref, error)."""
    real, Wt = _bkey(j["b"])
    bp = STORE / "b" / f"{real}.st"
    if not bp.exists():
        return None, None, f"no beach state {bp.name} in {STORE}"
    m = _meta(bp)
    inp = ZigZagInput(D=int(j["D"]), B=int(j["B"]), start_stage=5, stage_start_vi=m["stage_start"], W=Wt)
    rec = drive(emu, inp, ready=True, beach_vi0=m["entry_vi"], max_vi=900, load=bp)
    emu.set_poll_callback(None)
    r = rec["ready"]
    if not r or not r["pier"]:
        return None, None, "no READY on replay"
    ref = _spot(emu)
    if ref["jx"] < READY_X_MIN:
        return None, None, f"READY short of the dock end (x {ref['jx']:.1f})"
    if not map_is(emu.u16(MAP_CTRL), MAP_BEACH) or not map_is(ref["dloc"], MAP_BEACH):
        return None, None, f"not on the beach at READY (map {emu.u16(MAP_CTRL)}, dog record map {ref['dloc']})"
    want = j.get("dog_at")
    if want and (abs(ref["dx"] - want[0]) > DOG_TOL or abs(ref["dz"] - want[1]) > DOG_TOL):
        return None, None, f"the dog is at {ref['dx']:.1f},{ref['dz']:.1f}, not at the expected spot {want[0]},{want[1]}"
    return r["abs_vi"], ref, None


class _Watch:
    """Per-VI recorder (runs on the emulator thread): the dog's visible runs [k, base * 8 + screen facing] when they
    change, the beach check, how often the dog's tile is off the visibility grid, the dog's largest drift."""

    def __init__(self, R, ref, runs=None):
        self.R, self.ref = R, ref
        self.runs = [] if runs is None else runs
        self.last = None
        self.fail = None
        self.checks = 0
        self.pos = []                                     # [k, x, z] when the dog has moved >= POS_STEP since the last entry
        self.px, self.pz = ref["dx"], ref["dz"]
        self.grid = []                                    # [k, 0 | 1] changes of "tile on the visibility grid"
        self.on = None

    def __call__(self, e):
        k = e.vi - self.R
        code = e.u16(ENT_DOG + 0x54) * 8 + e.u8(ENT_DOG + 0x67)
        if code != self.last:
            self.runs.append(k)
            self.runs.append(code)
            self.last = code
        if self.fail is None:
            if not map_is(e.u16(MAP_CTRL), MAP_BEACH):
                self.fail = [k, f"map {e.u16(MAP_CTRL)}"]
            elif k % CHECK_EVERY == 0:
                self.checks += 1
                why = beach_fail(e, self.ref)
                if why:
                    self.fail = [k, why]
                else:
                    x, z = e.f32(ENT_DOG + 0x28), e.f32(ENT_DOG + 0x30)
                    if abs(x - self.px) >= POS_STEP or abs(z - self.pz) >= POS_STEP:
                        self.pos += [k, round(x, 1), round(z, 1)]
                        self.px, self.pz = x, z
                    on = 1 if dog_visible(e) else 0
                    if on != self.on:
                        if self.on is not None or not on:
                            self.grid += [k, on]
                        self.on = on


def _delta(runs):
    """[k, code, k, code, ...] -> [k0, code, dk, code, ...]"""
    out, prev = [], None
    for i in range(0, len(runs), 2):
        out.append(runs[i] if prev is None else runs[i] - prev)
        out.append(runs[i + 1])
        prev = runs[i]
    return out


# ------------------------------------------------------------------------------------------------ the day without a cast
def fd_line_job(emu, j):
    """j: key, b, D, B, dog_at [x, z] (optional), step (hash every `step` VIs, default 2)."""
    R, ref, err = _to_ready(emu, j)
    if err:
        return {"key": j["key"], "ok": False, "why": err}
    step = int(j.get("step", 2))
    until = j.get("until")                                # VI label to stop at (None = the end of the day)
    k_r = emu.vi - R
    out = {"key": j["key"], "ok": True, "k0": k_r, "clock": _clock(emu),
           "jack": [round(ref["jx"], 1), round(ref["jz"], 1)], "dog_at": [round(ref["dx"], 1), round(ref["dz"], 1)]}
    w = _Watch(R, ref)
    hs = []
    st = {"end": None}

    def watch(e):
        w(e)
        k = e.vi - R
        if k >= 4 and k % step == 0:
            hs.append(cast_hash(e))

    def stop(e):
        if w.fail:
            st["end"] = [w.fail[0], "beach check: " + w.fail[1]]
            return True
        a = e.u16(A.PLAYER + 0x64)
        acts.add(a)
        if a == END_OF_DAY_ACTION:
            st["end"] = [e.vi - R, "day", _clock(e)]
            return True
        if a == IDLE_NAP:                                 # the stay-awake pushes did not work
            st["end"] = [e.vi - R, "nap", _clock(e)]
            return True
        if until is not None and e.vi - R >= until:
            st["end"] = [e.vi - R, "limit", _clock(e)]
            return True
        return False
    acts = set()
    w(emu)
    emu.set_poll_callback(DayController(k_r, emu.polls()))
    h = emu.add_listener(watch)
    try:
        hit = emu.advance_until(stop, DAY_MAX)
    finally:
        emu.remove_listener(h)
        emu.set_poll_callback(None)
    out["end"] = st["end"] if hit else [emu.vi - R, "no end in the time limit"]
    first = max(4, k_r + 1)
    out["h0"] = first + (-first) % step                   # label of hs[0]; hs[i] is label h0 + i * step
    out["actions"] = sorted(acts)
    out["step"] = step
    out["hs"] = hs
    out["d"] = _delta(w.runs)
    out["p"], out["g"], out["chk"] = w.pos, w.grid, w.checks
    return out


# ------------------------------------------------------------------------------------------------ casts held all day
def fd_cast_job(emu, j):
    """j: key, b, D, B, casts [[k, hash or None], ...] (k = VI labels after READY), tail (VIs of dog after each bite on
    the released path, default 240), dog_at, tag."""
    casts = sorted((int(k), h) for k, h in j["casts"])
    tail = int(j.get("tail", 240))
    tmp = _tmpdir()
    out = []
    try:
        R, ref, err = _to_ready(emu, j)
        if err:
            return {"key": j["key"], "tag": j.get("tag"), "error": err}
        k_r = emu.vi - R
        k0 = casts[0][0] - 2
        if k_r > k0:
            return {"key": j["key"], "tag": j.get("tag"), "error": f"cast before READY+{k_r}"}
        w0 = _Watch(R, ref)
        push = casts[-1][0] >= NO_PUSH_BEFORE
        emu.set_poll_callback(DayController(k_r, emu.polls(), push=push))
        h0 = emu.add_listener(w0)
        try:
            emu.advance(R + k0 - emu.vi)
        finally:
            emu.remove_listener(h0)
        if w0.fail:
            return {"key": j["key"], "tag": j.get("tag"), "error": f"beach check before the casts: {w0.fail}"}
        if emu.u16(A.PLAYER + 0x64) in (IDLE_NAP, END_OF_DAY_ACTION, FISHING):
            return {"key": j["key"], "tag": j.get("tag"), "error": f"player action {emu.u16(A.PLAYER + 0x64)} at READY+{k0}"}
        rung = os.path.join(tmp, "rung.st")
        emu.save_state(rung)                              # label k0 (the push schedule stays armed through this VI)
        for k, hsh in casts:
            out.append(_one_cast(emu, rung, k0, k, hsh, R, ref, tail, tmp, j.get("until"), push))
    finally:
        emu.set_poll_callback(None)
        _cleanup(tmp)
    return {"key": j["key"], "tag": j.get("tag"), "casts": out}


def _one_cast(emu, rung, k0, k, hsh, R, ref, tail, tmp, until=None, push=True):
    row = {"k": k}
    w = _Watch(R, ref)
    st = {"inw": False, "end": None, "hash": None, "started": None}
    bites = []                                            # [label, state file]

    def watch(e):
        w(e)
        if e.vi - R == k:
            st["hash"] = cast_hash(e)

    def stop(e):
        kk = e.vi - R
        if w.fail:
            st["end"] = [w.fail[0], "beach check: " + w.fail[1]]
            return True
        a = e.u16(A.PLAYER + 0x64)
        if a == FISHING:
            if st["started"] is None:
                st["started"] = kk
            if until is not None and kk > until and len(bites) >= 2:
                st["end"] = [kk, "limit", _clock(e)]      # as the dog-watch run: bites 1-2 always, later ones only
                return True                               # while they show by `until`
            inw = 3 <= e.u8(A.PLAYER + 0x6A) <= 5
            new = inw and not st["inw"]
            st["inw"] = inw
            return new
        st["inw"] = False
        if a == END_OF_DAY_ACTION:
            st["end"] = [kk, "day", _clock(e)]
            return True
        if st["started"] is not None:
            st["end"] = [kk, f"action {a}", _clock(e)]
            return True
        if kk > k + 60:
            st["end"] = [kk, f"cast did not start (action {a})"]
            return True
        return False

    emu.set_poll_callback(DayController(k0, 0, cast=k, push=push))
    emu.load_state(rung)
    hd = emu.add_listener(watch)
    try:
        while True:
            hit = emu.advance_until(stop, DAY_MAX - (emu.vi - R) + 2)
            if not hit:
                st["end"] = [emu.vi - R, "no end in the time limit"]
                break
            if st["end"]:
                break
            lab = emu.vi - R                              # a bite shows: its state, B still held through this VI
            ck = os.path.join(tmp, f"b{len(bites)}.st")
            hb = cast_hash(emu)
            emu.save_state(ck)
            bites.append([lab, ck, hb])
    finally:
        emu.remove_listener(hd)
    row["ok"] = None if hsh is None else (st["hash"] == hsh)
    row["e"] = st["end"]
    row["d"] = _delta(w.runs)
    if w.pos:
        row["p"] = w.pos
    if w.grid:
        row["g"] = w.grid
    # the releases: from each bite's state, B up 4 polls after the bite (bites 1-2: also 12)
    B, T = [], []
    for i, (lab, ck, hb) in enumerate(bites):
        res = []
        for off in ((4, 12) if i < 2 else (4,)):
            wt = _Watch(R, ref)
            emu.set_poll_callback(lambda n, off=off: _B if n < off else 0)
            emu.load_state(ck)
            ht = emu.add_listener(wt) if off == 4 else None
            try:
                emu.advance_until(_resolver(), 600)
                o = _classify(emu)
                if o == "fish":
                    o = KIND.get(emu.u8(A.PLAYER + 0x2C), "f")
                elif o == "nut":
                    o = "N"
                elif emu.u16(A.PLAYER + 0x64) == END_OF_DAY_ACTION or not map_is(emu.u16(MAP_CTRL), MAP_BEACH):
                    o = "d"                               # the day ended before the catch (a bite in its last second)
                else:
                    o = {"miss": "x", "held_through": "h"}.get(o, "o")
                res.append(o)
                if ht is not None and tail > 0:
                    left = lab + tail - (emu.vi - R)
                    if left > 0:
                        emu.advance_until(lambda e: wt.fail is not None, left)
            finally:
                if ht is not None:
                    emu.remove_listener(ht)
            if off == 4:
                T.append(_delta(wt.runs) + ([-1, wt.fail[0]] if wt.fail else []))
        B.append([lab, res[0] if len(set(res)) == 1 else "/".join(res), hb])
        for q in (ck, ck + ".json"):
            if os.path.exists(q):
                os.remove(q)
    emu.set_poll_callback(None)
    row["b"] = B
    row["t"] = T
    return row
