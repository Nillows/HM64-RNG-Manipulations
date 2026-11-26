"""
Gap campaign, part C (2026-11-26, Thomas: "until we know they are reliable, unreliable, and why"): one cast with a
per-frame trace, to compare the same cast made from the representative's spot (north zone) and from another camera
zone of the dock end.

  gap_trace_job   j: key, b, D, B, rep_ready_rel, k (cast label of the representative), until (label), dog_at, tag.
                  The cast is made exactly as spot_jobs.sp_cast_job makes it (same rung, same controller) and B is
                  held to `until`. Every 2 VIs from label k - 2:
                    s   the generator's value (libkmc sRandNext, u32)
                    g   [label, 0 | 1, ...] changes of "the dog's tile is on the camera's visibility grid"
                    p   [label, x, z, ...] the dog's position when it has moved 1 unit or more
                    a   [[label, dogInfo action, dogInfo direction, screen facing, animation], ...] when one of them changes
                    b   [label, ...] the first VI of every bite window (Jack's fishing phase 3-5)
[DECOMP entity.c / animals.c] a dog whose tile is off the visibility grid does not animate, so updateDog never sees an
animation end and draws no random number; the trace shows the frame the two spots first disagree about the grid and
the frame the generator's values first differ.
"""
from __future__ import annotations

import os

from _base import A  # noqa: F401
from fullday_jobs import _Watch, _clock, DayController, NO_PUSH_BEFORE, IDLE_NAP, END_OF_DAY_ACTION, DAY_MAX
from hm64.fishing import FISHING
from hm64.zigzag import ENT_DOG
from zigzag_jobs import _tmpdir, _cleanup, dog_visible
from spot_jobs import _ready

GAP_CODE = "gaps-1 (2026-11-26: per-frame trace of one cast)"
STEP = 2


def gap_trace_job(emu, j):
    k, until = int(j["k"]), int(j["until"])
    base = {"key": j["key"], "B": j["B"], "tag": j.get("tag"), "k": k}
    tmp = _tmpdir()
    try:
        R, Rr, ref, err = _ready(emu, j)
        if err:
            return dict(base, error=err)
        k_r = emu.vi - Rr
        base["shift"] = R - Rr
        base["jack"] = [round(ref["jx"], 3), round(ref["jz"], 3)]
        k0 = k - 2
        if k0 < k_r:
            return dict(base, skipped=True)                   # Jack is not at the dock end yet at this spot
        w0 = _Watch(Rr, ref)
        push = k >= NO_PUSH_BEFORE
        emu.set_poll_callback(DayController(k_r, emu.polls(), push=push))
        h0 = emu.add_listener(w0)
        try:
            emu.advance(Rr + k0 - emu.vi)
        finally:
            emu.remove_listener(h0)
        if w0.fail:
            return dict(base, error=f"beach check before the cast: {w0.fail}")
        if emu.u16(A.PLAYER + 0x64) in (IDLE_NAP, END_OF_DAY_ACTION, FISHING):
            return dict(base, error=f"player action {emu.u16(A.PLAYER + 0x64)} at label {k0}")
        rung = os.path.join(tmp, "rung.st")
        emu.save_state(rung)
        w = _Watch(Rr, ref)
        S, G, P, AC, BT = [], [], [], [], []
        st = {"on": None, "px": None, "pz": None, "code": None, "inw": False, "end": None, "started": None}

        def watch(e):
            w(e)
            kk = e.vi - Rr
            if kk < k0 or (kk - k0) % STEP:
                return
            S.append(e.u32(A.RAND_SEED))
            on = 1 if dog_visible(e) else 0
            if on != st["on"]:
                G.extend((kk, on)); st["on"] = on
            x, z = e.f32(ENT_DOG + 0x28), e.f32(ENT_DOG + 0x30)
            if st["px"] is None or abs(x - st["px"]) >= 1.0 or abs(z - st["pz"]) >= 1.0:
                P.extend((kk, round(x, 1), round(z, 1))); st["px"], st["pz"] = x, z
            code = [e.u8(A.DOG + 0x17), e.u8(A.DOG + 0x18), e.u8(ENT_DOG + 0x67), e.u16(ENT_DOG + 0x54)]
            if code != st["code"]:
                AC.append([kk] + code); st["code"] = code

        def stop(e):
            kk = e.vi - Rr
            if w.fail:
                st["end"] = [w.fail[0], "beach check: " + w.fail[1]]
                return True
            a = e.u16(A.PLAYER + 0x64)
            if a == FISHING:
                if st["started"] is None:
                    st["started"] = kk
                inw = 3 <= e.u8(A.PLAYER + 0x6A) <= 5
                if inw and not st["inw"]:
                    BT.append(kk)
                st["inw"] = inw
                if kk >= until:
                    st["end"] = [kk, "limit", _clock(e)]
                    return True
                return False
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
            hit = emu.advance_until(stop, DAY_MAX - (emu.vi - Rr) + 2)
        finally:
            emu.remove_listener(hd)
        if not hit:
            st["end"] = [emu.vi - Rr, "no end in the time limit"]
        return dict(base, k0=k0, step=STEP, s=S, g=G, p=P, a=AC, b=BT, e=st["end"], started=st["started"])
    finally:
        emu.set_poll_callback(None)
        _cleanup(tmp)
