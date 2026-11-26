"""
Pier-spot lab (2026-11-25, Thomas: "do one prescribed spot (early cut) and see if the data we collect there is usable
for the other spots").

Why: a dog whose tile is off the camera's visibility grid does not animate and draws no random numbers; the camera
follows Jack, so the spot where Jack stands at the dock end decides when the dog drops off the grid. Every line's
casts were recorded from its representative (the earliest second cut of its class, z about 158: the north end of the
dock end). These jobs replay the SAME beach state with a LATER second cut B (the same dog line, Jack 6 units further
south per game frame of later cut) and record exactly what fullday_jobs records, with every time given as the
representative's VI label (VIs after the representative's READY), so rows compare label for label:

  sp_line_job   no cast: cast hash every 2 VIs, the dog's visible runs, position and grid changes, to `until`
  sp_cast_job   the given casts (labels of the representative), each held as in the full-day run: every bite, the
                catch of a release at every bite, the dog's grid changes

Same beach state + same first cut D => same absolute time line; the label shift is exact:
  representative's READY (absolute VI) = the beach state's entry VI + the representative's ready_rel.
The stay-awake pushes come at the representative's labels (every 2000), as in the recorded data.
"""
from __future__ import annotations

import os

from _base import A  # noqa: F401
import fullday_jobs as FJ
from fullday_jobs import _Watch, _delta, _clock, _one_cast, DayController, NO_PUSH_BEFORE, IDLE_NAP, END_OF_DAY_ACTION, DAY_MAX
from hm64.fishing import FISHING
from hm64.zigzag import cast_hash
from zigzag_jobs import STORE, _bkey, _meta, _tmpdir, _cleanup, dog_visible

SP_CODE = "spots-1 (2026-11-25: one dog line from other pier spots, labels of the representative)"


def _ready(emu, j):
    """READY of this job's route (b, D, B). Returns (R, Rrep, ref, error): R = this route's READY, Rrep = the
    representative's READY on the same beach state, both absolute VIs."""
    R, ref, err = FJ._to_ready(emu, j)
    if err:
        return None, None, None, err
    real, _ = _bkey(j["b"])
    m = _meta(STORE / "b" / f"{real}.st")
    return R, int(m["entry_vi"]) + int(j["rep_ready_rel"]), ref, None


def sp_line_job(emu, j):
    """j: key, b, D, B, rep_ready_rel, until (label), dog_at, step."""
    R, Rr, ref, err = _ready(emu, j)
    if err:
        return {"key": j["key"], "B": j["B"], "ok": False, "why": err}
    step = int(j.get("step", 2))
    until = int(j["until"])
    k_r = emu.vi - Rr
    out = {"key": j["key"], "B": j["B"], "ok": True, "k0": k_r, "shift": R - Rr, "clock": _clock(emu),
           "jack": [round(ref["jx"], 3), round(ref["jz"], 3)], "dog_at": [round(ref["dx"], 1), round(ref["dz"], 1)]}
    w = _Watch(Rr, ref)
    hs, g2 = [], []
    st = {"end": None, "on": None}

    def watch(e):
        w(e)
        k = e.vi - Rr
        if k >= 4 and k % step == 0:
            hs.append(cast_hash(e))
            on = 1 if dog_visible(e) else 0
            if on != st["on"]:
                g2.append(k)
                g2.append(on)
                st["on"] = on

    def stop(e):
        if w.fail:
            st["end"] = [w.fail[0], "beach check: " + w.fail[1]]
            return True
        a = e.u16(A.PLAYER + 0x64)
        if a == END_OF_DAY_ACTION:
            st["end"] = [e.vi - Rr, "day", _clock(e)]
            return True
        if a == IDLE_NAP:
            st["end"] = [e.vi - Rr, "nap", _clock(e)]
            return True
        if e.vi - Rr >= until:
            st["end"] = [e.vi - Rr, "limit", _clock(e)]
            return True
        return False
    w(emu)
    emu.set_poll_callback(DayController(k_r, emu.polls()))
    h = emu.add_listener(watch)
    try:
        hit = emu.advance_until(stop, DAY_MAX)
    finally:
        emu.remove_listener(h)
        emu.set_poll_callback(None)
    out["end"] = st["end"] if hit else [emu.vi - Rr, "no end in the time limit"]
    first = max(4, k_r + 1)
    out["h0"] = first + (-first) % step
    out["step"] = step
    out["hs"] = hs
    out["d"] = _delta(w.runs)
    out["p"], out["g"], out["g2"], out["chk"] = w.pos, w.grid, g2, w.checks
    return out


def sp_cast_job(emu, j):
    """j: key, b, D, B, rep_ready_rel, casts [[k, hash or None], ...] (the representative's labels), until (label),
    tail, dog_at, tag."""
    casts = sorted((int(c[0]), c[1]) for c in j["casts"])
    tail = int(j.get("tail", 0))
    tmp = _tmpdir()
    out, skipped = [], []
    base = {"key": j["key"], "B": j["B"], "tag": j.get("tag")}
    try:
        R, Rr, ref, err = _ready(emu, j)
        if err:
            return dict(base, error=err)
        k_r = emu.vi - Rr
        base["shift"] = R - Rr
        base["jack"] = [round(ref["jx"], 3), round(ref["jz"], 3)]
        skipped = [k for k, _ in casts if k - 2 < k_r]        # Jack is not at the dock end yet at this spot
        casts = [c for c in casts if c[0] - 2 >= k_r]
        if not casts:
            return dict(base, casts=[], skipped=skipped)
        k0 = casts[0][0] - 2
        w0 = _Watch(Rr, ref)
        push = casts[-1][0] >= NO_PUSH_BEFORE
        emu.set_poll_callback(DayController(k_r, emu.polls(), push=push))
        h0 = emu.add_listener(w0)
        try:
            emu.advance(Rr + k0 - emu.vi)
        finally:
            emu.remove_listener(h0)
        if w0.fail:
            return dict(base, error=f"beach check before the casts: {w0.fail}")
        if emu.u16(A.PLAYER + 0x64) in (IDLE_NAP, END_OF_DAY_ACTION, FISHING):
            return dict(base, error=f"player action {emu.u16(A.PLAYER + 0x64)} at label {k0}")
        rung = os.path.join(tmp, "rung.st")
        emu.save_state(rung)
        for k, hsh in casts:
            out.append(_one_cast(emu, rung, k0, k, hsh, Rr, ref, tail, tmp, j.get("until"), push))
    finally:
        emu.set_poll_callback(None)
        _cleanup(tmp)
    return dict(base, casts=out, skipped=skipped)
