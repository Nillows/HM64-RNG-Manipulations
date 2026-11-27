"""HM64 lab pool: after a game file's cast run, make its pier-zone (refinement) campaign by itself (kit 2026-11-27).

  python3 -I auto_plan.py --campaign CASTS_CAMPAIGN_DIR --lab LAB --hm64 ~/Documents/hm64 --names "sunny rainy"
  (called by run_hm64_file.sh on the main Mac when its own casts are finished; safe to run again by hand)

For each save of the campaign (file.json):
  1. the expected number of jobs of each cast block: the "list" line of the claims files in LAB/results/fullday/coord
  2. every machine's cast rows: this Mac's LAB/results/fullday/<tag>/FD_casts_bNN.jsonl and the other machines'
     hm64-fullday-<tag>@<machine>.zip in the lab-data clone (~/Documents/hm64/lab-data/<name>-<save>/), which the
     lab-data script (tools/hm64_labdata.sh) fetches. Merged with pool_merge.py: a job two machines ran must give the
     same row, and every job must be there (--expect). Not complete yet: wait 10 min, fetch again (default 12 h).
  3. zone_plan.py + sunny_plan.py (the scripts every pier-zone plan was made with) -> plans/gap_plan_<label>.json.gz
Then the campaign zones-<name> is built from next/zones-template, pushed (campaign-push) and queued (queue-add).
Nothing is done for a save whose plan is already in a zones-<name> campaign on GitHub. Exit 0 = queued (or already
there); 1 = not made (the message says why). Status file: ~/Documents/hm64/pool/autoplan/<name>.status
"""
import argparse, glob, gzip, json, os, re, shutil, subprocess, sys, time, zipfile
ap = argparse.ArgumentParser()
ap.add_argument("--campaign", required=True); ap.add_argument("--lab", required=True); ap.add_argument("--hm64", required=True)
ap.add_argument("--names", default="sunny rainy"); ap.add_argument("--wait-hours", type=float, default=12.0)
ap.add_argument("--every-min", type=float, default=10.0); ap.add_argument("--no-push", action="store_true")
ap.add_argument("--pool"); ap.add_argument("--labdata-dir"); ap.add_argument("--no-fetch", action="store_true")
a = ap.parse_args()
HERE = os.path.dirname(os.path.abspath(__file__)); C = os.path.abspath(a.campaign); LAB = os.path.abspath(a.lab); HM = os.path.abspath(a.hm64)
fj = json.load(open(os.path.join(C, "file.json")))
NAME, TAG = fj["name"], fj["tag"]
POOL = a.pool or os.path.join(HM, "hm64-pool", "hm64_pool.sh")
LD = a.labdata_dir or os.path.join(HM, "lab-data")
WORK = os.path.join(HM, "pool", "autoplan", NAME); os.makedirs(WORK, exist_ok=True)
STATUS = os.path.join(HM, "pool", "autoplan", NAME + ".status")
def note(m): print(f"  [plan {time.strftime('%H:%M:%S')}] {m}", flush=True)
def status(m):
    open(STATUS, "w").write(time.strftime("%Y-%m-%d %H:%M ") + m + "\n")
def stop(m):
    status("NOT MADE: " + m); print("\nSTOP (auto plan): " + m, flush=True); sys.exit(1)
ZC = "zones-" + NAME
if os.path.isdir(os.path.join(HM, "pool", "campaigns", ZC)) and not a.no_push:
    note(f"{ZC} is already on GitHub: nothing to do"); status("already on GitHub"); sys.exit(0)
names = [n for n in a.names.split() if n in fj["saves"]]
if not names: stop("none of the saves named is in file.json")
windows = []                                          # (window name, [block numbers])
for w in fj["windows"].split():
    p = w.split(":"); lo, hi = p[3].split("-"); windows.append((p[0], list(range(int(lo), int(hi) + 1))))
def expected(label, tag, b):
    d = os.path.join(LAB, "results", "fullday", "coord", f"{label}.{tag}.FD_casts_b{b:02d}")
    got = set()
    for f in glob.glob(os.path.join(d, "*.claims")):
        for ln in open(f):
            p = ln.split()
            if len(p) >= 4 and p[0] == "list": got.add((p[1], int(p[2])))
    if not got: return None
    if len(got) > 1: stop(f"the machines do not agree on the job list of {os.path.basename(d)}: {sorted(got)}")
    return next(iter(got))[1]
def fetch():
    if a.no_fetch: return
    t = os.path.join(HM, "tools", "hm64_labdata.sh")
    if os.path.isfile(t):
        r = subprocess.run(["bash", t], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        tail = [l for l in r.stdout.splitlines() if l.strip()][-1:] or [""]
        note(f"lab-data fetched / uploaded ({tail[0].strip()[:110]})")
def gather(save):
    """-> (merged dir per window, problems)"""
    label = fj["saves"][save]["label"]; out = {}; problems = []
    for wn, blocks in windows:
        tag = f"{TAG}-{save}-{wn}"; local = os.path.join(LAB, "results", "fullday", tag)
        md = os.path.join(WORK, "fd", tag)
        if os.path.isdir(md): shutil.rmtree(md)
        os.makedirs(md)
        for f in (".limits", "FD1_lines.jsonl"):
            if not os.path.isfile(os.path.join(local, f)): problems.append(f"{tag}: {f} is not on this Mac (its casts are not finished here)"); break
            shutil.copy(os.path.join(local, f), md)
        else:
            zdir = os.path.join(WORK, "zips", tag)
            if os.path.isdir(zdir): shutil.rmtree(zdir)
            os.makedirs(zdir)
            zs = sorted(glob.glob(os.path.join(LD, f"{NAME}-{save}", f"hm64-fullday-{tag}@*.zip")))
            for z in zs:
                m = re.search(r"@(.+)\.zip$", os.path.basename(z)).group(1)
                try:
                    with zipfile.ZipFile(z) as zf:
                        for n in zf.namelist():
                            if re.fullmatch(re.escape(tag) + r"/FD_casts_b\d\d\.jsonl", n):
                                with zf.open(n) as src, open(os.path.join(zdir, f"{m}__{os.path.basename(n)}"), "wb") as dst: shutil.copyfileobj(src, dst)
                except zipfile.BadZipFile:
                    problems.append(f"{os.path.basename(z)} is not a complete zip yet")
            for b in blocks:
                exp = expected(label, tag, b)
                if exp is None: problems.append(f"{tag} block {b}: no job list on this Mac yet"); continue
                parts = [p for p in [os.path.join(local, f"FD_casts_b{b:02d}.jsonl")] + sorted(glob.glob(os.path.join(zdir, f"*__FD_casts_b{b:02d}.jsonl"))) if os.path.isfile(p) and os.path.getsize(p)]
                if not parts: problems.append(f"{tag} block {b}: no rows anywhere yet (0 of {exp} jobs)"); continue
                r = subprocess.run([sys.executable, "-I", os.path.join(C, "lab", "tools", "pool_merge.py"), "--out", os.path.join(md, f"FD_casts_b{b:02d}.jsonl"), "--expect", str(exp)] + parts,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                if r.returncode == 3: stop(f"{tag} block {b}: two machines gave DIFFERENT rows for the same job. This must not happen (the lab is deterministic): nothing is planned.\n" + r.stdout[-1500:])
                if r.returncode != 0:
                    last = [l for l in r.stdout.splitlines() if l.strip()][-1:] or ["?"]
                    problems.append(f"{tag} block {b}: not all {exp} jobs are here yet ({last[0].strip()[:120]}; parts: {len(parts)})")
        out[wn] = md
    return out, problems
t0 = time.time(); plans = {}; counts = {}
os.makedirs(os.path.join(WORK, "nospots"), exist_ok=True); open(os.path.join(WORK, "nospots", "SP2_casts.jsonl"), "w").close()
os.makedirs(os.path.join(WORK, "plans"), exist_ok=True)
for save in names:
    label = fj["saves"][save]["label"]; dw = os.path.join(LAB, "results", "dogwatch", label)
    if not os.path.isfile(os.path.join(dw, ".done_phase3")): stop(f"the dog-watch of {label} is not finished on this Mac")
    while True:
        fetch()
        md, problems = gather(save)
        if not problems: break
        left = a.wait_hours * 3600 - (time.time() - t0)
        note(f"{label}: the casts are not complete yet ({len(problems)} open): " + "; ".join(problems[:3]) + (" ..." if len(problems) > 3 else ""))
        if left <= 0: stop(f"{label}: after {a.wait_hours:g} h the casts are still not complete: " + "; ".join(problems[:6]))
        status(f"waiting for the casts of {label}: {len(problems)} blocks open")
        time.sleep(max(5, min(a.every_min * 60, left)))
    fds = [md[w] for w, _ in windows]
    zp = os.path.join(WORK, "plans", f"zone_plan_{label}.json.gz"); gp = os.path.join(WORK, "plans", f"gap_plan_{label}.json.gz")
    for cmd in ([os.path.join(HERE, "zone_plan.py"), label, os.path.join(HERE, "masks.json"), dw, os.path.join(WORK, "nospots")] + fds + ["--out", zp],
                [os.path.join(HERE, "sunny_plan.py"), "--label", label, "--zz", os.path.join(dw, "zz_lines.json"), "--zone-plan", zp, "--fd1", os.path.join(fds[-1], "FD1_lines.jsonl"), "--out", gp]):
        r = subprocess.run([sys.executable, "-I"] + cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        print("\n".join("    " + l for l in r.stdout.splitlines()[-12:]), flush=True)
        if r.returncode != 0: stop(f"{os.path.basename(cmd[0])} failed for {label} (see above)")
    g = json.load(gzip.open(gp, "rt"))
    counts[save] = {k: (len(v) if isinstance(v, (list, dict)) else v) for k, v in g.items() if k in ("A", "gate_lines", "gate_casts", "jobs")}
    plans[save] = gp
    note(f"{label}: plan made ({os.path.getsize(gp) // 1024} KB)")
out = os.path.join(WORK, ZC)
if os.path.exists(out): shutil.rmtree(out)
shutil.copytree(os.path.join(C, "next", "zones-template"), out)
os.makedirs(os.path.join(out, "plans"))
for save, gp in plans.items(): shutil.copy(gp, os.path.join(out, "plans"))
zv = "".join(f"SHA_{s}={fj['saves'][s]['sha256']}\n" for s in names) + "".join(f"LABEL_{s}={fj['saves'][s]['label']}\n" for s in names)
for s in ("sunny", "rainy"):
    if s not in names: zv += f"SHA_{s}=\nLABEL_{s}=\n"
rp = os.path.join(out, "run_hm64_zones.sh"); t = open(rp).read()
for k, v in {"NAME": NAME, "ZONE_VARS": zv.rstrip("\n"), "ONLY": "both" if len(names) == 2 else names[0]}.items(): t = t.replace("@" + k + "@", v)
assert not re.search(r"@[A-Z_]+@", t)
open(rp, "w").write(t)
labels = [fj["saves"][s]["label"] for s in names]
cc = json.load(open(os.path.join(C, "campaign.json")))
needs = [x for l in labels for x in (f"results/dogwatch/{l}", f"states/dogwatch/{l}/b")]
zj = {"name": ZC, "version": time.strftime("%Y-%m-%d") + "a",
      "title": f"Game file {NAME} ({' + '.join(names)}): pier zones - the gate, then the casts that can differ (plan made by auto_plan.py)",
      "image": cc["image"], "rom_sha256": cc["rom_sha256"], "base_sha256": "", "saves": [], "needs": needs,
      "needs_when": {x: f"results/dogwatch/{l}/.done_phase3" for l in labels for x in (f"results/dogwatch/{l}", f"states/dogwatch/{l}/b")},
      "shared": "one list per save (gaps-<label>.A), 50 parts, claims on branch lab-coord; the gate is run by every machine for itself",
      "runner": "run_hm64_zones.sh", "plan_counts": counts,
      "presets": {"preset": "dogwatch", "zones": {"middle": 176.4, "south": 194.4}, "plans": "plans/gap_plan_<label>.json.gz", "parts": ["A"], "blocks_per_list": 50}}
json.dump(zj, open(os.path.join(out, "campaign.json"), "w"), indent=1)
shutil.copy(os.path.join(C, "file.json"), out); shutil.copy(os.path.join(C, "labdata_map.txt"), out)
note(f"campaign folder {out}")
if a.no_push:
    status("made, not pushed (--no-push)"); sys.exit(0)
for cmd in (["campaign-push", out], ["queue-add", ZC]):
    r = subprocess.run(["bash", POOL] + cmd, stdin=subprocess.DEVNULL)
    if r.returncode != 0: stop(f"hm64_pool.sh {cmd[0]} failed: the campaign folder is {out}; push it by hand with  bash {POOL} campaign-push {out}  and  bash {POOL} queue-add {ZC}")
status(f"{ZC} is on GitHub and in the queue")
note(f"{ZC} is on GitHub and in the queue")
