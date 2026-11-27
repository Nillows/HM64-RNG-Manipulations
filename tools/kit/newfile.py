"""HM64 lab pool: make the cast campaign of a NEW GAME FILE from its save(s) and put it in the queue (kit 2026-11-27).

  bash hm64_pool.sh newfile NAME [--sunny SAVE] [--rainy SAVE] [--no-push]
  (= python3 -I kit/newfile.py --pool .../hm64_pool.sh --hm64 ~/Documents/hm64 NAME ...)      main Mac only

NAME: short, lower case, letters / digits / '-': e.g. baby-walk-horse. It becomes the campaign casts-NAME, the labels
NAME-lineup2-<sunny|rainy>-<sha8>, the cast folders NAME-<sunny|rainy>-<window>, the lab-data folders NAME-sunny /
NAME-rainy and, when the casts are done, the refinement campaign zones-NAME (made by next/plan/auto_plan.py).

What it does: reads each save (weather, horse, married, wife, baby and its age, year / season / day, dog, rod),
refuses a save that is not usable (wrong weather for its slot, dog not on the lineup2 tile of the beach, no rod in
hand, bad checksum, a name or save already used), copies the saves to sourcefiles/NAME/ (they never go to GitHub),
builds the campaign folder from kit/casts-template, pushes it (campaign-push) and adds it to the queue (queue-add).
Every machine running "hm64_pool.sh work" then picks it up.
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile, time
ap = argparse.ArgumentParser()
ap.add_argument("name"); ap.add_argument("--sunny"); ap.add_argument("--rainy")
ap.add_argument("--pool", required=True); ap.add_argument("--hm64", required=True)
ap.add_argument("--lab"); ap.add_argument("--no-push", action="store_true"); ap.add_argument("--out")
a = ap.parse_args()
KIT = os.path.dirname(os.path.abspath(__file__))
HM = os.path.abspath(a.hm64); LAB = a.lab or os.path.join(HM, "runs", "dogspots", "hm64-lab")
def die(m):
    print("\nSTOP (newfile): " + m); sys.exit(1)
if not re.fullmatch(r"[a-z][a-z0-9-]{2,30}", a.name) or a.name.endswith("-") or "--" in a.name:
    die("the name must be 3-31 characters: lower-case letters, digits and single '-' (e.g. baby-walk-horse)")
if not (a.sunny or a.rainy): die("give at least one save: --sunny SAVE and / or --rainy SAVE")
if not os.path.isdir(os.path.join(LAB, "m64h")): die(f"no lab folder with the harness at {LAB}")
sys.path.insert(0, LAB)
from m64h import sram as S                                                     # noqa: E402
WIVES = {0: "maria", 1: "popuri", 2: "elli", 3: "ann", 4: "karen"}
SEASON = {1: "spring", 2: "summer", 3: "autumn", 4: "winter"}
def read(path):
    raw = open(path, "rb").read()
    kind, be = S.detect(raw)
    s = be[:0x1000]
    ev = [int.from_bytes(s[0xF00 + 4 * i:0xF04 + 4 * i], "big") for i in range(16)]
    bit = lambda n: bool(ev[n // 32] >> (n % 32) & 1)
    return {"sha256": hashlib.sha256(raw).hexdigest(), "kind": kind, "year": s[0x10], "season": SEASON.get(s[0x11], str(s[0x11])),
            "day": s[0x13], "weather": s[0x24], "married": bit(0), "baby": bit(1), "horse": bit(5), "wife": s[0xE6],
            "baby_age": s[0xE7], "fever_seen": bit(216), "wife_left": bit(217)}
saves = {}
for slot, path, wcode in (("sunny", a.sunny, 1), ("rainy", a.rainy, 2)):
    if not path: continue
    path = os.path.expanduser(path)
    if not os.path.isfile(path): die(f"no file {path}")
    i = read(path)
    if i["weather"] != wcode: die(f"{os.path.basename(path)} was given as the {slot} save but its weather byte is {i['weather']} (1 = sunny, 2 = rain)")
    exp = [f"weather={'sunny' if wcode == 1 else 'rain'}", f"horse={'yes' if i['horse'] else 'no'}", f"married={'yes' if i['married'] else 'no'}"]
    if i["married"] and i["wife"] in WIVES: exp.append("wife=" + WIVES[i["wife"]])
    exp += [f"baby={'yes' if i['baby'] else 'no'}", "dog=beach", "tile=18:23", "rod=yes", f"season={i['season']}", f"day={i['day']}"]
    i["expect"] = ",".join(exp); i["path"] = path; i["file"] = os.path.basename(path)
    saves[slot] = i
# the save check of the lab (the kit's copy: it knows every key), on a private copy of the tool next to the harness
tmp = tempfile.mkdtemp(prefix="hm64newfile.")
os.makedirs(os.path.join(tmp, "tools")); shutil.copy(os.path.join(KIT, "casts-template", "save_check.py"), os.path.join(tmp, "tools"))
os.symlink(os.path.join(LAB, "m64h"), os.path.join(tmp, "m64h"))
for slot, i in saves.items():
    print(f"\n== the {slot} save: {i['file']}")
    r = subprocess.run([sys.executable, "-I", os.path.join(tmp, "tools", "save_check.py"), i["path"], "--expect", i["expect"]])
    if r.returncode != 0: shutil.rmtree(tmp, ignore_errors=True); die(f"the {slot} save is not usable for a lineup2 run (FAIL above). Nothing was made.")
    notes = []
    if i["wife_left"]: notes.append("the wife has LEFT (life event 217): the game places neither wife nor baby")
    if i["baby"]:
        st = "lying (under 30 days)" if i["baby_age"] < 30 else "crawling (30-119 days)" if i["baby_age"] < 120 else "walking (120 days +)"
        notes.append(f"baby age {i['baby_age']} days = {st}")
        if 30 <= i["baby_age"] < 120 and not i["fever_seen"]: notes.append("WARNING: the baby-fever cutscene has not happened yet (life event 216): each night has a 1-in-11 roll for it")
    if i["year"] == 1 and i["season"] == "spring" and i["day"] >= 3 and not i["horse"] and i["weather"] == 1: notes.append("ranch CLOSED (spring of year 1, no horse: the horse offer is armed)")
    elif not i["horse"] and i["weather"] == 1: notes.append("ranch OPEN (no horse outside spring of year 1)")
    if i["season"] == "winter": notes.append("WARNING: winter (no ranch animals, no sparrows): not one of the file kinds planned so far")
    i["notes"] = notes
    for n in notes: print("    note: " + n)
shutil.rmtree(tmp, ignore_errors=True)
name = a.name; tag = name; prefix = name
labels = {slot: f"{prefix}-lineup2-{slot}-{i['sha256'][:8]}" for slot, i in saves.items()}
camp = "casts-" + name
pc = os.path.join(HM, "pool", "campaigns")
if os.path.isdir(pc):
    if os.path.isdir(os.path.join(pc, camp)) and not a.no_push: die(f"a campaign {camp} is already on GitHub: choose another name")
    for d in sorted(os.listdir(pc)):
        fj = os.path.join(pc, d, "file.json")
        if os.path.isfile(fj):
            for s2 in json.load(open(fj)).get("saves", {}).values():
                for slot, i in saves.items():
                    if s2.get("sha256") == i["sha256"]: die(f"the {slot} save is already the save of campaign {d}")
out = a.out or os.path.join(HM, "pool", "newfile", camp)
if os.path.exists(out): shutil.rmtree(out)
shutil.copytree(os.path.join(KIT, "casts-template"), out)
shutil.copytree(os.path.join(KIT, "zones-template"), os.path.join(out, "next", "zones-template"))
shutil.copytree(os.path.join(KIT, "plan"), os.path.join(out, "next", "plan"))
rp = os.path.join(out, "run_hm64_file.sh"); t = open(rp).read()
sub = {"NAME": name, "TAG": tag, "PREFIX": prefix, "ONLY": "both" if len(saves) == 2 else next(iter(saves)),
       "SUNNY_SHA": saves.get("sunny", {}).get("sha256", ""), "RAINY_SHA": saves.get("rainy", {}).get("sha256", ""),
       "EXP_SUNNY": saves.get("sunny", {}).get("expect", ""), "EXP_RAINY": saves.get("rainy", {}).get("expect", "")}
for k, v in sub.items(): t = t.replace("@" + k + "@", v)
assert not re.search(r"@[A-Z_]+@", t), re.findall(r"@[A-Z_]+@", t)
open(rp, "w").write(t)
WINDOWS = "d90:90:40:0-1 d140c90:140:90:2-5 d170c120:170:120:4-5"
fj = {"name": name, "tag": tag, "prefix": prefix, "made": time.strftime("%Y-%m-%d %H:%M"), "windows": WINDOWS,
      "saves": {slot: {"sha256": i["sha256"], "file": i["file"], "label": labels[slot], "expect": i["expect"], "year": i["year"],
                       "season": i["season"], "day": i["day"], "horse": i["horse"], "married": i["married"],
                       "wife": WIVES.get(i["wife"], i["wife"]) if i["married"] else None, "baby": i["baby"],
                       "baby_age": i["baby_age"] if i["baby"] else None, "notes": i["notes"]} for slot, i in saves.items()}}
json.dump(fj, open(os.path.join(out, "file.json"), "w"), indent=1)
needs = [x for l in labels.values() for x in (f"results/dogwatch/{l}", f"states/dogwatch/{l}/b")]
cj = {"name": camp, "version": time.strftime("%Y-%m-%d") + "a",
      "title": f"Game file {name} ({' + '.join(saves)}): dog-watch on the main Mac, casts to 120 s shared; then zones-{name} is made by itself",
      "image": json.load(open(os.path.join(KIT, "image.json"))), "rom_sha256": "15c570120bfaa97b4580762f5ee5939a56ba054e696925ea81ccfa55a022d2a6",
      "base_sha256": "", "saves": [], "needs": needs,
      "needs_when": {x: f"results/dogwatch/{l}/.done_phase3" for l in labels.values() for x in (f"results/dogwatch/{l}", f"states/dogwatch/{l}/b")},
      "shared": "the cast blocks of each window, 50 parts per block, claims on branch lab-coord", "runner": "run_hm64_file.sh",
      "presets": {"preset": "dogwatch", "windows": WINDOWS, "kit": "fullday-2", "blocks_per_list": 50}}
json.dump(cj, open(os.path.join(out, "campaign.json"), "w"), indent=1)
m = []
for slot, l in labels.items():
    f = f"{name}-{slot}"
    m.append(f"{f}|hm64-dogwatch-{l}.zip|0|each")
    for w in WINDOWS.split(): m.append(f"{f}|hm64-fullday-{tag}-{slot}-{w.split(':')[0]}@*.zip|0|each")
    m.append(f"{f}|hm64-gaps-{l}@*.zip|0|each")
m.append(f"{name}-{next(iter(saves))}|run-{tag}120-*.log|0|each")
open(os.path.join(out, "labdata_map.txt"), "w").write("\n".join(m) + "\n")
sf = os.path.join(HM, "sourcefiles", name); os.makedirs(sf, exist_ok=True)
for i in saves.values():
    d = os.path.join(sf, i["file"])
    if os.path.abspath(d) != os.path.abspath(i["path"]): shutil.copy(i["path"], d)
print(f"\n  campaign folder: {out}\n  saves copied to: {sf}   (they stay on the LAN)")
for slot, l in labels.items(): print(f"  label {slot}: {l}")
if a.no_push:
    print("  --no-push: not put on GitHub"); sys.exit(0)
for cmd in (["campaign-push", out], ["queue-add", camp]):
    r = subprocess.run(["bash", a.pool] + cmd, stdin=subprocess.DEVNULL)
    if r.returncode != 0: die(f"hm64_pool.sh {cmd[0]} failed (see above). The campaign folder is {out}.")
print(f"\nNEW GAME FILE {name}: campaign {camp} is on GitHub and in the queue. Machines running 'hm64_pool.sh work' pick it up"
      f" within 20 minutes; the main Mac (work topdown) makes its dog-watch.")
