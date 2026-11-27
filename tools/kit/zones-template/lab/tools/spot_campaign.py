"""
Pier-spot lab (2026-11-25): is the cast data recorded at the early-cut spot usable from the other spots of the dock
end? Jobs: experiments/spot_jobs.py. Nothing of the dog-watch or full-day runs is changed.

  python3 tools/spot_campaign.py --src results/dogwatch/<label> --plan spot_plan_<label>.json.gz --out results/spots/<label> lines
  python3 tools/spot_campaign.py --src ... --plan ... --out ... casts
  python3 tools/spot_campaign.py --src ... --plan ... --out ... report

--src   the finished dog-watch run of the save (zz_lines.json: every line's representative and members); its state
        store in HM64_ZZ_STORE (the beach savestates).
--plan  made by Claude from the recorded data (tools/spot_plan.py): per line the representative, its no-cast cast
        hashes to 170 s, and the casts to repeat with the bites the recorded run got.

lines   every line from every pier spot its own second cuts reach (same beach state, same first cut, one second cut
        per spot), no cast, to 170 s: SP1_lines.jsonl. GATE: at the representative's own spot the cast hashes must be
        the recorded ones, every one; otherwise this lab is not on the recorded lines and the run stops.
casts   the plan's casts from the spots nearest to --cast-z (default one game frame late, the middle, the south end)
        and a control sample at the representative's own spot: SP2_casts.jsonl.
report  SPOTS.md + the same on the screen.
Resumable: finished jobs are skipped. Ctrl-C any time.
"""
from __future__ import annotations

import argparse
import gzip
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "experiments"))
from common import default_rom, default_sram   # noqa: E402
from m64h.pool import run_jobs                 # noqa: E402

CHUNK = 24
VI_S = 59.826


def load_jsonl(p):
    out = []
    p = Path(p)
    if p.exists():
        with p.open() as f:
            for line in f:
                try:
                    out.append(json.loads(line))
                except ValueError:
                    pass
    return out


def good(p):
    return [r for r in load_jsonl(p) if "_error" not in r and "error" not in r]


def run_stage(name, fn, jobs, out_path, workers, rom, sram, key):
    done = {key(r["_job"]) for r in good(out_path) if r.get("ok", True) is not False}
    todo = [j for j in jobs if key(j) not in done]
    print(f"[{name}] {len(jobs)} jobs, {len(done)} already done, {len(todo)} to run", flush=True)
    if os.environ.get("HM64_COORD_DIR"):
        return run_stage_shared(name, fn, jobs, out_path, workers, rom, sram, key)
    if not todo:
        return 0
    if os.environ.get("HM64_COORD_DIR"):
        return run_stage_shared(name, fn, jobs, out_path, workers, rom, sram, key)
    t0, n, bad = time.time(), 0, 0
    with Path(out_path).open("a") as f:
        for res in run_jobs(fn, todo, rom=rom, sram=sram, workers=workers):
            if "_error" in res or "error" in res:
                bad += 1
                print(f"[{name}] job error: {str(res.get('_error') or res.get('error'))[-400:]}", flush=True)
            f.write(json.dumps(res, separators=(",", ":")) + "\n")
            f.flush()
            n += 1
            if n % 10 == 0 or n == len(todo):
                el = time.time() - t0
                left = el / n * (len(todo) - n)
                print(f"[{name}] {n}/{len(todo)}  {n / el * 60:.1f} jobs/min  eta "
                      + (f"{left / 3600:.1f} h" if left > 5400 else f"{left / 60:.0f} min"), flush=True)
    return bad


def run_stage_shared(name, fn, jobs, out_path, workers, rom, sram, key):
    """The same stage shared with other machines (tools/coord.py): blocks of the job list, top down or bottom up.
    Returns the number of job errors; 0 with a note when the other machine holds what is left."""
    from coord import Coord
    C = Coord(os.environ["HM64_COORD_DIR"], os.environ.get("HM64_COORD_CAMPAIGN") or Path(out_path).parent.name + "." + Path(out_path).stem,
              os.environ.get("HM64_COORD_MACHINE", ""), os.environ.get("HM64_COORD_ORDER", "up"),
              int(os.environ.get("HM64_COORD_BLOCKS", "50") or 50))
    blocks = C.set_jobs([key(j) for j in jobs])
    print(f"[{name}] shared run: machine {C.me}, order {C.order}, {len(jobs)} jobs in {len(blocks)} blocks; "
          f"other machines: {', '.join(sorted(C.others())) or 'none seen yet'}", flush=True)
    bad, t0, ran, last_hb = 0, time.time(), 0, 0.0
    while True:
        have = {key(r["_job"]) for r in good(out_path) if r.get("ok", True) is not False}
        local_done = {b for b, ix in enumerate(blocks) if all(key(jobs[i]) in have for i in ix)}
        for b in sorted(local_done):
            if C._parse(C.mine)["b"].get(b, ("", 0))[0] != "done":
                C.mark_done(b, old=True)
        what, b = C.next_block(local_done)
        if what == "end":
            print(f"[{name}] every block is done ({ran} jobs run here this time)", flush=True)
            return 4 if bad else 0
        if what == "wait":
            print(f"[{name}] {b} blocks left, all held by other machines: waiting (taken over if a machine goes silent "
                  f"for {C.stale / 60:.0f} min)", flush=True)
            C.heartbeat()
            time.sleep(float(os.environ.get("HM64_COORD_POLL_S", "60") or 60))
            continue
        todo = [jobs[i] for i in blocks[b] if key(jobs[i]) not in have]
        print(f"[{name}] block {b + 1}/{len(blocks)} ({ {'up': 'top down', 'down': 'bottom up', 'middle': 'middle out'}[C.order] }): {len(todo)} jobs", flush=True)
        berr = 0
        with Path(out_path).open("a") as f:
            for res in run_jobs(fn, todo, rom=rom, sram=sram, workers=workers):
                if "_error" in res or "error" in res:
                    berr += 1
                    print(f"[{name}] job error: {str(res.get('_error') or res.get('error'))[-400:]}", flush=True)
                f.write(json.dumps(res, separators=(",", ":")) + "\n")
                f.flush()
                ran += 1
                if time.time() - last_hb > 240:
                    C.heartbeat()
                    last_hb = time.time()
        bad += berr
        if berr:
            print(f"[{name}] block {b + 1}: {berr} job errors - the block stays open; stopping (the same command runs it again)", flush=True)
            return 4
        C.mark_done(b)
        el = time.time() - t0
        print(f"[{name}] block {b + 1} done; {ran} jobs here in {el / 60:.0f} min ({ran / max(el, 1) * 60:.1f} jobs/min)", flush=True)
        P = C.pool()
        if P["eta_s"] is not None:
            e = P["eta_s"]
            print(f"[{name}] pool: {len(P['machines'])} Mac(s), {P['rate']:.1f} jobs/min ("
                  + ", ".join(f"{m} {r:.1f}" for m, r in sorted(P["machines"].items())) + f") - {P['left']} jobs left in this list: "
                  + (f"{e / 3600:.1f} h" if e > 5400 else f"{e / 60:.0f} min") + " for the pool", flush=True)
            pre = os.environ.get("HM64_COORD_CAMPAIGN") or ""
            if pre and P["rate"] > 0:
                A = C.campaign(pre, int(os.environ.get("HM64_COORD_LISTS", "0") or 0))
                h = lambda j: (lambda x: f"{x / 60:.1f} h" if x > 90 else f"{x:.0f} min")(j / P["rate"])
                print(f"[{name}] campaign so far: {A['opened']}" + (f" of {A['expected']}" if A["expected"] else "") + f" lists opened, {A['left']} jobs left in them = {h(A['left'])}"
                      + (f"; {A['unopened']} lists not opened yet (about {h(A['unopened'] * A['avg_jobs'])} more if they are like the opened ones)" if A["unopened"] else "")
                      + " at the pool's present speed (rough: jobs differ in length between lists)", flush=True)


def read_plan(p):
    op = gzip.open if str(p).endswith(".gz") else open
    with op(p, "rt") as f:
        return json.load(f)


def spots_of(line, rep):
    """One second cut B per pier spot among the line's own members on the representative's beach state and first
    cut: [(z, x, B, ready_rel)] north to south; the representative's own spot first."""
    seen = {}
    for m in line["members"]:
        if m["b"] != rep["b"] or m["D"] != rep["D"] or "spot" not in m:
            continue
        s = (round(m["spot"][0], 3), round(m["spot"][1], 3))
        if s not in seen or m["B"] < seen[s][0]:
            seen[s] = (m["B"], m["ready_rel"])
    rs = (round(rep["spot"][0], 3), round(rep["spot"][1], 3))
    seen[rs] = (rep["B"], rep["ready_rel"])
    out = [(s[1], s[0], b, rr) for s, (b, rr) in seen.items()]
    out.sort(key=lambda t: (t[2] != rep["B"], t[2]))
    return out


def setup(args):
    src = Path(args.src)
    if not (src / args.zz).exists():
        sys.exit(f"STOP: {src / args.zz} is missing - --src must be the results folder of the finished dog-watch run")
    plan = read_plan(args.plan)
    zz = json.load(open(src / args.zz))
    keys = [k for k in plan["order"] if k in plan["lines"]]
    miss = [k for k in keys if k not in zz]
    if miss:
        sys.exit(f"STOP: {len(miss)} of the plan's {len(keys)} lines are not in {src / 'zz_lines.json'} (first {miss[:3]}): "
                 "this is not the dog-watch run the plan was made from")
    bad = []
    for k in keys:
        a, b = plan["lines"][k]["rep"], zz[k]["rep"]
        if (a["b"], a["D"], a["B"], a["ready_rel"]) != (b["b"], b["D"], b["B"], b["ready_rel"]):
            bad.append(k)
    if bad:
        sys.exit(f"STOP: {len(bad)} lines have another representative here than in the plan (first {bad[:3]}): "
                 "this is not the dog-watch run the plan was made from")
    if args.max_lines:
        keys = keys[:args.max_lines]
    return src, plan, zz, keys


def stage_lines(args):
    src, plan, zz, keys = setup(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    rom, sram = default_rom(), default_sram()
    import spot_jobs as SJ
    until = int(plan["until"])
    jobs = []
    for k in keys:
        rep = zz[k]["rep"]
        for z, x, B, rr in spots_of(zz[k], rep):
            jobs.append({"key": k, "b": rep["b"], "D": rep["D"], "B": B, "rep_ready_rel": rep["ready_rel"], "until": until,
                         "dog_at": plan["dog_at"], "z": z, "x": x})
    print(f"{SJ.SP_CODE}  lines of {src}  save {sram}  workers {args.workers}  {len(keys)} lines, {len(jobs)} line x spot runs "
          f"to {until} VIs after READY", flush=True)
    bad = run_stage("SP1 lines", SJ.sp_line_job, jobs, out / "SP1_lines.jsonl", args.workers, rom, sram, lambda j: (j["key"], j["B"]))
    rows = good(out / "SP1_lines.jsonl")
    same = diff = norow = 0
    worst = []
    by = {(r["key"], r["B"]): r for r in rows if r.get("ok")}
    for k in keys:
        rep = zz[k]["rep"]
        r = by.get((k, rep["B"]))
        if not r:
            norow += 1
            continue
        P = plan["lines"][k]
        d = first_diff(P, r)
        n = common(P, r)
        if d is None:
            same += n
        else:
            diff += 1
            worst.append((k[:8], d))
    refused = [r for r in rows if r.get("ok") is False]
    print(f"[SP1] the representative's own spot against the recorded run: {len(keys) - norow - diff} of {len(keys)} lines equal on every "
          f"cast hash ({same} hashes), {diff} lines differ, {norow} without a row; {len(refused)} line x spot runs refused", flush=True)
    for r in refused[:6]:
        print(f"  refused: line {r['key'][:8]} B {r.get('B')}: {r.get('why')}", flush=True)
    json.dump({"lines": len(keys), "rep_equal": len(keys) - norow - diff, "rep_differ": worst[:20], "rep_no_row": norow,
               "refused": len(refused), "job_errors": bad}, open(out / "sp_lines_summary.json", "w"), indent=1)
    if diff or norow or bad:
        print("STOP: " + (f"{diff} lines do not give the recorded cast hashes at the representative's own spot (first: {worst[:3]}). " if diff else "")
              + (f"{norow} representatives have no row. " if norow else "") + (f"{bad} job errors. " if bad else "")
              + "Nothing was cast. Send the log to Claude.", flush=True)
        return 3
    return 0


def common(P, r):
    """number of labels both the plan's hashes and the row's hashes have"""
    lo = max(P["h0"], r["h0"])
    hi = min(P["h0"] + P["step"] * (len(P["hs"]) - 1), r["h0"] + r["step"] * (len(r["hs"]) - 1))
    return max(0, (hi - lo) // 2 + 1)


def first_diff(P, r):
    """first label where the row's cast hash is not the recorded one (None = equal on every common label)"""
    lo = max(P["h0"], r["h0"])
    hi = min(P["h0"] + P["step"] * (len(P["hs"]) - 1), r["h0"] + r["step"] * (len(r["hs"]) - 1))
    for k in range(lo, hi + 1, 2):
        if P["hs"][(k - P["h0"]) // P["step"]] != r["hs"][(k - r["h0"]) // r["step"]]:
            return k
    return None


def cast_targets(zz_line, rep, zs):
    """[(tag, z, B)]: the representative's own spot ('rep') and the member spot nearest to each wanted z (within 1.5)"""
    sp = spots_of(zz_line, rep)
    out = [("rep", sp[0][0], sp[0][2])]
    used = {sp[0][2]}
    for want in zs:
        best = min(sp[1:], key=lambda t: abs(t[0] - want), default=None)
        if best and abs(best[0] - want) <= 1.5 and best[2] not in used:
            used.add(best[2])
            out.append((f"z{want:g}", best[0], best[2]))
    return out


def stage_casts(args):
    src, plan, zz, keys = setup(args)
    out = Path(args.out)
    rom, sram = default_rom(), default_sram()
    import spot_jobs as SJ
    if not (out / "sp_lines_summary.json").exists():
        sys.exit("STOP: run the stage `lines` first")
    s = json.load(open(out / "sp_lines_summary.json"))
    if s["rep_differ"] or s["rep_no_row"] or s["job_errors"]:
        sys.exit("STOP: the lines stage did not pass its gate; nothing is cast")
    zs = [float(v) for v in str(args.cast_z).split(",") if v.strip()]
    jobs = []
    ncast = 0
    for k in keys:
        rep = zz[k]["rep"]
        P = plan["lines"][k]
        for tag, z, B in cast_targets(zz[k], rep, zs):
            cl = P["casts"] if tag != "rep" else P["casts"][::max(1, int(args.control_every))]
            if args.max_casts and len(cl) > args.max_casts:
                stp = len(cl) / args.max_casts
                cl = [cl[int(i * stp)] for i in range(args.max_casts)]
            byu = {}
            for c in cl:
                byu.setdefault(c[1], []).append([c[0], c[2] if tag == "rep" else None])
            for until, lst in sorted(byu.items()):
                lst.sort()
                i = 0
                while i < len(lst):
                    j = i + 1
                    while j < len(lst) and j - i < CHUNK and lst[j][0] - lst[i][0] <= 400:
                        j += 1
                    ch = lst[i:j]
                    jobs.append({"key": k, "b": rep["b"], "D": rep["D"], "B": B, "rep_ready_rel": rep["ready_rel"], "casts": ch,
                                 "until": until, "tail": 0, "dog_at": plan["dog_at"], "spot": tag, "z": z,
                                 "tag": f"{k}:{B}:{until}:{ch[0][0]}"})
                    ncast += len(ch)
                    i = j
    print(f"{SJ.SP_CODE}  casts: {ncast} casts in {len(jobs)} jobs on {len(keys)} lines, spots rep (control, every "
          f"{args.control_every}th cast) + z {zs}", flush=True)
    bad = run_stage("SP2 casts", SJ.sp_cast_job, jobs, out / "SP2_casts.jsonl", args.workers, rom, sram, lambda j: j["tag"])
    return 4 if bad else 0


def zone_member(zz_line, rep, want):
    sp = spots_of(zz_line, rep)
    best = min(sp[1:], key=lambda t: abs(t[0] - want), default=None)
    return best if best and abs(best[0] - want) <= 1.5 else None


def stage_zones(args):
    """The plan's per-zone casts (plan['zones']: name -> Jack's z; per line 'zcasts': name -> [[k, until, kind, bites]],
    kind 0 = the dog comes near a tile the zone's grid treats differently, 1 = check sample of the casts that are copied)."""
    src, plan, zz, keys = setup(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    rom, sram = default_rom(), default_sram()
    import spot_jobs as SJ
    jobs = []
    ncast = 0
    for k in keys:
        rep = zz[k]["rep"]
        P = plan["lines"][k]
        for zn, want in sorted(plan["zones"].items()):
            m = zone_member(zz[k], rep, float(want))
            cl = P.get("zcasts", {}).get(zn, [])
            if not m or not cl:
                continue
            if args.max_casts and len(cl) > args.max_casts:
                stp = len(cl) / args.max_casts
                cl = [cl[int(i * stp)] for i in range(args.max_casts)]
            byu = {}
            for c in cl:
                byu.setdefault(c[1], []).append([c[0], None])
            for until, lst in sorted(byu.items()):
                lst.sort()
                i = 0
                while i < len(lst):
                    j = i + 1
                    while j < len(lst) and j - i < CHUNK and lst[j][0] - lst[i][0] <= 400:
                        j += 1
                    ch = lst[i:j]
                    jobs.append({"key": k, "b": rep["b"], "D": rep["D"], "B": m[2], "rep_ready_rel": rep["ready_rel"], "casts": ch,
                                 "until": until, "tail": 0, "dog_at": plan["dog_at"], "spot": zn, "z": m[0],
                                 "tag": f"{zn}:{k}:{m[2]}:{until}:{ch[0][0]}"})
                    ncast += len(ch)
                    i = j
    print(f"{SJ.SP_CODE}  zone casts: {ncast} casts in {len(jobs)} jobs on {len(keys)} lines, zones {plan['zones']}", flush=True)
    bad = run_stage("SP3 zone casts", SJ.sp_cast_job, jobs, out / "SP3_zones.jsonl", args.workers, rom, sram, lambda j: j["tag"])
    return 4 if bad else 0


def zone_report(plan, keys, out, L):
    rows = good(out / "SP3_zones.jsonl")
    if not rows:
        return
    ref = {}
    for k in keys:
        for zn, cl in plan["lines"][k].get("zcasts", {}).items():
            for c in cl:
                ref[(zn, k, c[0])] = c
    st = {}
    for r in rows:
        zn = r["_job"]["spot"]
        S = st.setdefault(zn, {0: [0, 0, 0, 0, 0, 0], 1: [0, 0, 0, 0, 0, 0], "skipped": 0})
        S["skipped"] += len(r.get("skipped", []))
        for c in r.get("casts", []):
            p = ref.get((zn, r["key"], c["k"]))
            if not p:
                continue
            want = [tuple(b) for b in p[3]]
            got = [(b[0], b[1]) for b in c["b"]]
            a = S[p[2]]
            a[0] += 1
            a[1] += got == want
            a[2] += bool(got and want and got[-1] == want[-1] and len(got) == len(want))
            wn = any(o == "N" for _, o in want)
            gn = any(o == "N" for _, o in got)
            a[3] += wn and gn and got != want
            a[4] += wn and not gn
            a[5] += gn and not wn
    L.append("## Zone casts: the recorded casts whose dog comes near a tile the zone's grid treats differently\n")
    L.append("| zone | set | casts | as recorded, every bite | same last bite (moment + catch) | Nut kept but other bites | Nut lost | new Nut | not possible there |")
    L.append("|---|---|---|---|---|---|---|---|---|")
    for zn in sorted(st):
        for kind, nm in ((0, "near a differing tile"), (1, "check sample of the copied casts")):
            a = st[zn][kind]
            pc = lambda x: "-" if not a[0] else f"{x} ({x / a[0]:.1%})"
            L.append(f"| {zn} | {nm} | {a[0]} | {pc(a[1])} | {pc(a[2])} | {a[3]} | {a[4]} | {a[5]} | {st[zn]['skipped'] if kind == 0 else ''} |")
    L.append("\n(the check sample should be as recorded on nearly every cast: it measures how safe copying the other casts is)\n")


def stage_report(args):
    src, plan, zz, keys = setup(args)
    out = Path(args.out)
    L = []
    w = {k: plan["lines"][k]["w"] for k in keys}
    tot = sum(w.values()) or 1.0
    L.append(f"# Pier spots: {plan['label']}\n")
    L.append("Times are seconds after the representative's READY. A row 'split' = the first cast hash that is not the recorded one.\n")
    rows = [r for r in good(out / "SP1_lines.jsonl") if r.get("ok")]
    byz = {}
    for r in rows:
        if r["key"] not in w:
            continue
        P = plan["lines"][r["key"]]
        d = first_diff(P, r)
        z = round(r["jack"][1], 1)
        byz.setdefault(z, []).append((r["key"], d, r))
    L.append("## No cast: the line from each pier spot against the recorded line\n")
    L.append("| Jack's z at the dock end | lines | weight of those lines | same to 170 s | split by 20 s | 40 s | 60 s | 90 s | 120 s | 170 s | earliest split |")
    L.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for z in sorted(byz):
        v = byz[z]
        ww = sum(w[k] for k, _, _ in v)
        def sh(lim):
            return sum(w[k] for k, d, _ in v if d is not None and d <= lim * VI_S) / (ww or 1)
        first = min((d for _, d, _ in v if d is not None), default=None)
        L.append(f"| {z:.1f} | {len(v)} | {ww / tot:.1%} | {sum(w[k] for k, d, _ in v if d is None) / (ww or 1):.1%} | "
                 + " | ".join(f"{sh(t):.1%}" for t in (20, 40, 60, 90, 120, 170)) + f" | {'-' if first is None else f'{first / VI_S:.1f} s'} |")
    L.append("\n(shares are of the route weight of the lines that reach that spot)\n")
    crow = good(out / "SP2_casts.jsonl")
    if crow:
        ref = {}
        for k in keys:
            for c in plan["lines"][k]["casts"]:
                ref[(k, c[0])] = c
        st = {}
        for r in crow:
            tag = r["_job"]["spot"]
            S = st.setdefault(tag, {"z": set(), "n": 0, "same": 0, "nut": 0, "nut_kept": 0, "non": 0, "non_nut_now": 0, "skipped": 0,
                                    "hash_ok": 0, "hash_bad": 0})
            S["z"].add(round(r["_job"]["z"], 1))
            S["skipped"] += len(r.get("skipped", []))
            for c in r.get("casts", []):
                p = ref.get((r["key"], c["k"]))
                if not p:
                    continue
                want = [tuple(b) for b in p[3]]
                got = [(b[0], b[1]) for b in c["b"]]
                S["n"] += 1
                S["same"] += got == want
                wn = next(((lab, i) for i, (lab, o) in enumerate(want) if o == "N"), None)
                gn = next(((lab, i) for i, (lab, o) in enumerate(got) if o == "N"), None)
                if wn:
                    S["nut"] += 1
                    S["nut_kept"] += gn == wn
                else:
                    S["non"] += 1
                    S["non_nut_now"] += gn is not None
                if c.get("ok") is True:
                    S["hash_ok"] += 1
                elif c.get("ok") is False:
                    S["hash_bad"] += 1
        L.append("## Casts: the recorded casts repeated from other spots\n")
        L.append("| spot | Jack's z | casts | every bite and catch as recorded | recorded Nut casts | Nut on the same bite at the same moment | recorded no-Nut casts | of those, a Nut now | not possible (before READY at that spot) |")
        L.append("|---|---|---|---|---|---|---|---|---|")
        for tag in sorted(st, key=lambda t: (t != "rep", t)):
            S = st[tag]
            pc = lambda a, b: "-" if not b else f"{a} ({a / b:.1%})"
            L.append(f"| {tag} | {', '.join(f'{z:.1f}' for z in sorted(S['z']))} | {S['n']} | {pc(S['same'], S['n'])} | {S['nut']} | "
                     f"{pc(S['nut_kept'], S['nut'])} | {S['non']} | {pc(S['non_nut_now'], S['non'])} | {S['skipped']} |")
        c = st.get("rep")
        if c:
            L.append(f"\nControl (the representative's own spot): {c['same']} of {c['n']} casts as recorded; cast-state hash "
                     f"{c['hash_ok']} equal / {c['hash_bad']} different. Anything but all equal means this lab does not reproduce the recorded run.\n")
    zone_report(plan, keys, out, L)
    txt = "\n".join(L) + "\n"
    (out / ("ZONES.md" if plan.get("zones") else "SPOTS.md")).write_text(txt)
    print(txt, flush=True)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True)
    ap.add_argument("--plan", required=True)
    ap.add_argument("--zz", default="zz_lines.json", help="the lines file inside --src (zz_lines.prefold.json after fold_copies.py --write)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--max-lines", type=int, default=int(os.environ.get("HM64_SP_MAX_LINES", "0") or 0))
    ap.add_argument("--max-casts", type=int, default=int(os.environ.get("HM64_SP_MAX_CASTS", "0") or 0),
                    help="test knob: at most this many casts per line and spot")
    ap.add_argument("--cast-z", default=os.environ.get("HM64_SP_CAST_Z", "164.4,176.4,194.4"),
                    help="Jack's z at the dock end of the spots to cast from (nearest spot of each line within 1.5 units)")
    ap.add_argument("--control-every", type=int, default=int(os.environ.get("HM64_SP_CONTROL_EVERY", "25") or 25))
    ap.add_argument("stage", choices=["lines", "casts", "zones", "report"])
    args = ap.parse_args()
    return {"lines": stage_lines, "casts": stage_casts, "zones": stage_zones, "report": stage_report}[args.stage](args)


if __name__ == "__main__":
    sys.exit(main())
