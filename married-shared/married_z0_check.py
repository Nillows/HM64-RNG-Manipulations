#!/usr/bin/env python3
"""Married-table run, pre-flight (2026-11-25). The zigzag reference route (mash 10/s START>A, U276 V52 C80 D86 B134)
from power-on on one save, twice in fresh emulators (zigzag_jobs.zz_record_job = the dog-spot lab's Z0 record).

  HM64_SRAM=<save> python3 tools/married_z0_check.py --weather 1      (1 sunny, 2 rain)

Always: the two cold boots must give the same record; the game must load the weather asked for with the rod in Jack's
hand; the house load must come at VI 1036, draw 499 and the farm load at VI 1448, draw 704 (every save of the lab so
far); the dog must be on the beach at the beach load; Jack must reach READY.
When Claude's sandbox has played the same save (EXPECT, by the save's sha256): the record must equal the sandbox's.

What the sandbox found on Thomas's married no-horse saves (x86 mupen64plus 2.6.0 bundle, 2026-11-25):
- Married to Karen: from 6:00 to 7:59 she stands idle in the house at x -128 z -64 [DECOMP npc.c, KAREN married
  schedule]; the reference route is the same as on an unmarried copy of the same save, to the draw.
- The sunny married save is spring 8, the Planting Festival [DECOMP game.c setFestivalDailyBits]: festival mornings draw 8
  fewer random numbers on the farm (beach load at draw 1065 against 1073; spring 1 the same; spring 3-6 / 9 / 12, any
  weekday: 1073). The run uses the save moved to spring 9 (tools/save_redate.py): beach 1073, wake 1180, READY 1259 =
  the unmarried sunny lineup2 save (spring 4) to the draw.
- The rainy married save (spring 9) = the rainy no-horse save (spring 5) to the draw: beach 7429, wake 9382, READY 10593."""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "experiments"))
from m64h.pool import run_jobs                  # noqa: E402
from tools.common import default_rom, default_sram  # noqa: E402

# zz_record_job "got", sandbox x86 mupen64plus 2.6.0 bundle (two cold boots equal), by the save's sha256
EXPECT = {
    # Harvest Moon 64 (USA).beach-lineup2-nohorse-married-sunny.SaveRAM (01999fee..., spring 8) moved to spring 9 (Tuesday)
    # by tools/save_redate.py --day 9 --weekday 2: sunny, married to Karen, no horse, dog x -197.272 z 222.243, tile 18:23
    "237e3d1dfe5d220e28015cc865409fdcf467ed8423d258f6bde302e03fa2ab09":
        {"house": [1036, 499], "farm": [1448, 704], "beach": [2264, 1073], "wake": [213, 1180],
         "ready": [339, -92.0, 194.0, 1259]},
    # Harvest Moon 64 (USA).beach-lineup2-nohorse-married-rainy.SaveRAM: spring 9, rain, married to Karen, no horse,
    # dog x -197.272 z 222.243, tile 18:23 - the same record as the rainy no-horse save (8e972d75), to the draw
    "629912496c6211d0da630c895176336c45c57ffccf4f1451d83d932e9f34b03c":
        {"house": [1036, 499], "farm": [1448, 704], "beach": [2264, 7429], "wake": [213, 9382],
         "ready": [339, -92.0, 194.0, 10593]},
}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--weather", type=int, required=True, help="gWeather the save must load (weather.h: 1 sunny, 2 rain)")
    a = ap.parse_args()
    sram = default_sram()
    if not sram or not Path(sram).is_file():
        print(f"STOP: no save (HM64_SRAM={os.environ.get('HM64_SRAM')})", flush=True)
        return 2
    sha = hashlib.sha256(Path(sram).read_bytes()).hexdigest()
    import zigzag_jobs as ZJ
    res = list(run_jobs(ZJ.zz_record_job, [{"run": 1}, {"run": 2}], rom=default_rom(), sram=sram, workers=2, fresh=True))
    bad = [r for r in res if "_error" in r]
    if bad:
        print("STOP: the record run failed: " + bad[0]["_error"][-600:], flush=True)
        return 2
    res.sort(key=lambda r: r["_job"]["run"])
    x, y = ({k: v for k, v in r.items() if k != "_job"} for r in res)
    got = x["got"]
    sv = x["info"].get("save", {})
    d5 = x["info"]["stages"].get("5", {}).get("dog", {})
    print(f"  save {sha[:12]}: {sv.get('season_name')} {sv.get('day')} year {sv.get('year')}, weather {sv.get('weather')}, "
          f"rod in hand {sv.get('rod_in_hand')}; dog at the beach load: {d5.get('map')} x {d5.get('x')} z {d5.get('z')}", flush=True)
    print(f"  reference route: {json.dumps(got)}", flush=True)
    stops = []
    if x != y:
        stops.append("two cold boots of this save gave different records (not repeatable)")
    if sv.get("weather") != a.weather:
        stops.append(f"the game loads weather {sv.get('weather')}, not {a.weather}")
    if not sv.get("rod_in_hand"):
        stops.append("the rod is not in Jack's hand at the house load")
    if got.get("house") != [1036, 499] or got.get("farm") != [1448, 704]:
        stops.append(f"house / farm loads {got.get('house')} / {got.get('farm')}, not [1036, 499] / [1448, 704] as on every lab save")
    if d5.get("map") != "beach":
        stops.append(f"the dog is not on the beach at the beach load ({d5.get('map')})")
    if not got.get("ready"):
        stops.append("Jack did not reach READY on the reference route")
    want = EXPECT.get(sha)
    if want is not None and got != want:
        stops.append(f"the reference route does not give Claude's sandbox numbers {json.dumps(want)} - this emulator build "
                     "differs from the sandbox on this save")
    if stops:
        for s in stops:
            print("STOP: " + s, flush=True)
        print("Nothing was run. Send this log to Claude.", flush=True)
        return 3
    if want is not None:
        print("  equal to Claude's sandbox record of this save (x86 build): OK", flush=True)
    else:
        print("  no sandbox record of this save yet: the structural checks passed (repeatable, weather, rod, house / farm "
              "loads, dog on the beach, READY) - send this line to Claude with the results", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
