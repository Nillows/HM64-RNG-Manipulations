#!/usr/bin/env python3
"""Copy a Harvest Moon 64 save with another date in diary slot 0 (2026-11-25, married tables).

  python3 -I tools/save_redate.py IN OUT --day 9 --weekday 2 [--expect-in SHA256] [--expect-out SHA256]

Only two bytes of slot 0 change, dayOfWeek (0x12, time.h: 0 Sunday ... 6 Saturday) and dayOfMonth (0x13), and the slot's
checksum (u16 at 0xFFE = byte sum of 0x000..0xFFD, calculateSaveChecksum). The file keeps its format (BizHawk SaveRAM,
mupen .sra or big-endian cart SRAM; m64h.sram). The same input always gives the same output bytes.

Why (decomp src/game/game.c setFestivalDailyBits): spring 1 (New Year's) and spring 8 (Planting Festival) are festival
days; on those mornings the beach-lineup2 reference route draws 8 fewer random numbers on the farm than on an ordinary
day (sandbox 2026-11-25: spring 1 / 8 -> beach load at draw 1065, spring 3-6 / 9 / 12 and any weekday -> 1073). The lab
tables are for ordinary mornings, so a save made on a festival day is moved to an ordinary day before a run.
--expect-in / --expect-out: the sha256 the input must have / the output must come out as (exit 2 if not)."""
import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from m64h import sram as S      # noqa: E402


def redate(data: bytes, day: int, weekday: int) -> bytes:
    kind, be = S.detect(data)
    be = bytearray(be)
    if be[0:16] != S.SIG:
        raise SystemExit("diary slot 0 has no signature")
    be[0x12] = weekday
    be[0x13] = day
    c = sum(be[0:0xFFE]) & 0xFFFF
    be[0xFFE], be[0xFFF] = c >> 8, c & 0xFF
    out = bytearray(data)
    if kind == "bizhawk-saveram":
        out[S.BIZHAWK_SRAM_OFFSET:S.BIZHAWK_SRAM_OFFSET + S.SRAM_SIZE] = S.wordswap(bytes(be))
    elif kind == "bizhawk-saveram(be)":
        out[S.BIZHAWK_SRAM_OFFSET:S.BIZHAWK_SRAM_OFFSET + S.SRAM_SIZE] = bytes(be)
    elif kind == "cart-sram-bigendian":
        out = bytearray(be)
    elif kind == "mupen-sra":
        out = bytearray(S.wordswap(bytes(be)))
    else:
        raise SystemExit(f"unknown save format {kind}")
    if S.detect(bytes(out))[1] != bytes(be):
        raise SystemExit("the copy does not read back as written")
    return bytes(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--day", type=int, required=True, help="day of the month, 1-30")
    ap.add_argument("--weekday", type=int, required=True, help="0 Sunday ... 6 Saturday")
    ap.add_argument("--expect-in")
    ap.add_argument("--expect-out")
    a = ap.parse_args()
    if not (1 <= a.day <= 30 and 0 <= a.weekday <= 6):
        raise SystemExit("day must be 1-30 and weekday 0-6")
    data = Path(a.src).read_bytes()
    sin = hashlib.sha256(data).hexdigest()
    if a.expect_in and sin != a.expect_in:
        print(f"STOP: {a.src} has sha256 {sin}, not {a.expect_in}")
        return 2
    out = redate(data, a.day, a.weekday)
    sout = hashlib.sha256(out).hexdigest()
    if a.expect_out and sout != a.expect_out:
        print(f"STOP: the copy came out as sha256 {sout}, not {a.expect_out}")
        return 2
    Path(a.dst).write_bytes(out)
    print(f"{Path(a.dst).name}: {Path(a.src).name} ({sin[:12]}) with day {a.day}, weekday {a.weekday} -> sha256 {sout}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
