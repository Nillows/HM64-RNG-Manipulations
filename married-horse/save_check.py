"""Check a Harvest Moon 64 save before a lab run: what game-file circumstance is it? (2026-11-23, rainy tables)

  python3 -I tools/save_check.py SAVE [SAVE ...] [--expect weather=rain,horse=yes,dog=beach,tile=18:23,rod=yes]
                                                 [--json out.json] [--diff OTHER_SAVE]

Every field is read from diary slot 0 by the offsets of the decomp's src/buffers/sramBuffer.h (gameFile.c loads them
the same way: gWeather = weather, gForecast = forecast, toolSlots[0..8] with byte 0x418 = the tool in hand, life
event bits u32[16] big-endian at 0xF00):
  signature, checksum (byte sum of 0x000..0xFFD = u16 at 0xFFE, calculateSaveChecksum), year / season / day,
  weather (weather.h: 1 sunny, 2 rain, 3 snow, 5 typhoon) and forecast, the tool in hand (24 = FISHING_POLE),
  dog (location, x, z, its 32-unit view tile: col int((x + 800) / 32), row int((z + 544) / 32)), horse (block at
  0x580 + life event bit 5 HAVE_HORSE + bit 14 RANCH_GET_HORSE_CUTSCENE), married (bit 0), baby (bit 1).
--expect names what the lab run assumes; any mismatch is printed as FAIL and the exit code is 1. The dog tile of
beach-lineup2 (x -198.5, z 223.5) is 18:23.

  python3 -I tools/save_check.py --find weather=rain,horse=no,dog=beach,tile=18:23,rod=yes DIR [DIR ...]
finds the save by what it is, not by its name: every save file under the folders (3 levels, .SaveRAM / .sra / .srm /
.sav) whose slot 0 passes the expectations. Prints "MATCH <sha256> <path>" per file; exit 0 when exactly one save
(one sha256, maybe in several copies) matches, 3 when none does, 4 when different saves do.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from m64h.sram import detect, SLOT_SIZE, SIG   # noqa: E402

WEATHER = {0: "none", 1: "sunny", 2: "rain", 3: "snow", 4: "rain(unused 4)", 5: "typhoon"}
SEASON = {1: "spring", 2: "summer", 3: "autumn", 4: "winter"}
MAPS = {0: "ranch", 9: "beach", 82: "farm", 87: "house"}
FISHING_POLE = 24
EVENTS = {0: "MARRIED", 1: "HAVE_BABY", 5: "HAVE_HORSE", 14: "RANCH_GET_HORSE_CUTSCENE", 15: "ENGAGED"}


def tile(x, z):
    return int((x + 800) / 32), int((z + 544) / 32)


def slot0(path):
    data = Path(path).read_bytes()
    kind, be = detect(data)
    s = be[0:SLOT_SIZE]
    if s[:16] != SIG:
        raise SystemExit(f"{path}: diary slot 0 has no signature")
    f32 = lambda o: struct.unpack(">f", s[o:o + 4])[0]
    u16 = lambda o: struct.unpack(">H", s[o:o + 2])[0]
    u32 = lambda o: struct.unpack(">I", s[o:o + 4])[0]
    ev = [u32(0xF00 + 4 * i) for i in range(16)]
    bit = lambda n: bool(ev[n // 32] >> (n % 32) & 1)
    dog = {"location": s[0x507], "where": MAPS.get(s[0x507], str(s[0x507])), "x": round(f32(0x508), 3),
           "z": round(f32(0x50C), 3), "name": s[0x500:0x506].hex(), "affection": s[0x506]}
    dog["tile"] = "%d:%d" % tile(dog["x"], dog["z"])
    horse = {"have": bit(5), "ranch_cutscene_seen": bit(14), "location": s[0x587], "where": MAPS.get(s[0x587], str(s[0x587])),
             "x": round(f32(0x588), 3), "z": round(f32(0x58C), 3), "grown": s[0x590], "age": s[0x591],
             "affection": s[0x586], "flags": "0x%04X" % u16(0x594), "name": s[0x580:0x586].hex()}
    out = {
        "file": Path(path).name, "sha256": hashlib.sha256(data).hexdigest(), "kind": kind,
        "checksum_ok": sum(s[0:0xFFE]) & 0xFFFF == u16(0xFFE),
        "year": s[0x10], "season": SEASON.get(s[0x11], s[0x11]), "day_of_week": s[0x12], "day": s[0x13],
        "weather": WEATHER.get(s[0x24], s[0x24]), "forecast": WEATHER.get(s[0x25], s[0x25]),
        "gold": u32(0x20), "stamina": [s[0x39], s[0x38]],
        "tools": list(s[0x410:0x419]), "in_hand": s[0x418], "rod_in_hand": s[0x418] == FISHING_POLE,
        "dog": dog, "horse": horse, "married": bit(0), "baby": bit(1), "wife": s[0xE6],
        "events": [EVENTS.get(n, n) for n in range(512) if bit(n)],
    }
    return out, s


def check(info, expect):
    res = []
    for k, v in expect.items():
        if k == "weather":
            got = info["weather"]
        elif k == "horse":
            got = "yes" if info["horse"]["have"] else "no"
        elif k == "dog":
            got = info["dog"]["where"]
        elif k == "tile":
            got = info["dog"]["tile"]
        elif k == "rod":
            got = "yes" if info["rod_in_hand"] else "no"
        elif k == "married":
            got = "yes" if info["married"] else "no"
        elif k == "baby":
            got = "yes" if info["baby"] else "no"
        elif k == "wife":
            got = WIVES.get(info["wife"], str(info["wife"]))
        elif k == "season":
            got = info["season"]
        elif k == "day":
            got = info["day"]
        else:
            raise SystemExit(f"unknown --expect key {k}")
        res.append((k, v, got, str(got) == v))
    res.append(("checksum", "valid", "valid" if info["checksum_ok"] else "BAD", info["checksum_ok"]))
    return res


# wife byte 0xE6 (npc.h: MARIA 0, POPURI 1, ELLI 2, ANN 3, KAREN 4; 255 = none)
WIVES = {0: "maria", 1: "popuri", 2: "elli", 3: "ann", 4: "karen", 255: "none"}

EXTS = (".saveram", ".sra", ".srm", ".sav")


def find(expect_s, dirs):
    exp = dict(kv.split("=", 1) for kv in expect_s.split(","))
    seen, match = 0, []
    files = []
    for d in dirs:
        if not os.path.isdir(d):
            continue
        base = len(Path(d).parts)
        for cur, sub, names in os.walk(d):
            depth = len(Path(cur).parts) - base
            sub[:] = sorted(x for x in sub if depth < 3 and x not in ("__MACOSX", "runs", "node_modules") and not x.startswith("."))
            files += [Path(cur) / n for n in sorted(names) if Path(n).suffix.lower() in EXTS and not n.startswith("._")]
    for f in files:
        if True:
            seen += 1
            try:
                info, _ = slot0(f)
            except (SystemExit, Exception):        # not a save this tool reads: not a candidate
                continue
            res = check(info, exp)
            if all(ok for *_, ok in res):
                match.append((info["sha256"], str(f), info))
    shas = sorted({m[0] for m in match})
    print(f"looked at {seen} save files in {len(dirs)} folders for {expect_s}: {len(match)} match ({len(shas)} different saves)")
    for sha, f, info in match:
        print(f"MATCH {sha} {f}")
    return 0 if len(shas) == 1 else 3 if not shas else 4


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--find":
        sys.exit(find(sys.argv[2], sys.argv[3:]))
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("saves", nargs="+")
    ap.add_argument("--expect", action="append", default=[], help="per save, in order: weather=rain,horse=yes,dog=beach,tile=18:23,rod=yes")
    ap.add_argument("--diff", help="list the slot-0 bytes that differ from this save")
    ap.add_argument("--json")
    a = ap.parse_args()
    allok, infos = True, []
    for i, p in enumerate(a.saves):
        info, s = slot0(p)
        infos.append(info)
        d, h = info["dog"], info["horse"]
        print(f"{info['file']}  sha256 {info['sha256'][:12]}  ({info['kind']}, checksum {'valid' if info['checksum_ok'] else 'BAD'})")
        print(f"  day      year {info['year']} {info['season']} {info['day']} (day of week {info['day_of_week']}), weather {info['weather']}, forecast {info['forecast']}")
        print(f"  Jack     gold {info['gold']}, stamina {info['stamina'][0]}/{info['stamina'][1]}, tools {info['tools']}, in hand {info['in_hand']}"
              f" ({'fishing rod' if info['rod_in_hand'] else 'NOT the rod'})")
        print(f"  dog      {d['where']} (map {d['location']}) x {d['x']} z {d['z']}  tile {d['tile']}")
        print(f"  horse    {'YES' if h['have'] else 'no'} (HAVE_HORSE {h['have']}, ranch cutscene seen {h['ranch_cutscene_seen']}); block: {h['where']} (map {h['location']})"
              f" x {h['x']} z {h['z']}, grown {h['grown']}, age {h['age']}, flags {h['flags']}")
        print(f"  family   married {info['married']}, baby {info['baby']}, wife {info['wife']}; life events {info['events']}")
        if i < len(a.expect):
            exp = dict(kv.split("=", 1) for kv in a.expect[i].split(","))
            for k, v, got, ok in check(info, exp):
                print(f"  [{'PASS' if ok else 'FAIL'}] {k:8s} want {v:8s} got {got}")
                allok &= ok
        if a.diff:
            _, o = slot0(a.diff)
            diffs = [j for j in range(SLOT_SIZE) if s[j] != o[j]]
            print(f"  vs {Path(a.diff).name}: {len(diffs)} bytes differ in slot 0: " + " ".join("0x%03X" % j for j in diffs[:80]))
    if a.json:
        Path(a.json).write_text(json.dumps(infos, indent=1) + "\n")
    sys.exit(0 if allok else 1)


if __name__ == "__main__":
    main()
