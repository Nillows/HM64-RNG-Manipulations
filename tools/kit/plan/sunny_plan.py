"""The sunny pier-spot campaign's plan for one sunny save (2026-11-26): every job spelled out, so the Macs only run.

  python3 -I sunny_plan.py --label LABEL --zz zz_lines.json --zone-plan zone_plan_LABEL.json.gz --fd1 FD1_lines.jsonl
          --out gap_plan_LABEL.json.gz

Same job format and label rule as the rainy gap campaign's part A (v3223/gap_plan.py; a cast tau VIs after a member's
READY is line label tau + k_off). No sunny cast was ever made away from the representative's spot, so EVERY line is a
"part A" line:
  gate  (the fast check) per line and zone (middle = Jack's z 176.4, south = 194.4): the heaviest member standing
        there, NO cast, to label 10198 (170 s after READY = the end of the cast data). Compared with the recorded
        no-cast line: the dog change for change, to the end. Plus control casts at the representative's own spot
        (the recorded bites must come out: this is fatal; a line that differs is a finding, not a failure).
  A     the zone plan's casts (recorded casts whose dog comes within 48 units of a tile the zone's camera grid
        treats differently, + every 100th other cast as a check), each held exactly as long as its recording
        (labels 5398 / 6598 / 8398 / 10198), so every recorded bite is compared and nothing stays "not proven".
"""
import argparse, collections, gzip, json
ap = argparse.ArgumentParser()
for a in ("label", "zz", "zone-plan", "fd1", "out"):
    ap.add_argument("--" + a, required=True)
A = ap.parse_args()
zz = json.load(open(A.zz)); ZP = json.load(gzip.open(getattr(A, "zone_plan"), "rt"))
ZONES = {"middle": 176.4, "south": 194.4}
END, CHUNK, SPAN = 10198, 24, 400
zone_of = lambda z: "north" if z < 161 else "middle" if z < 191 else "south"


def chunks(lst):
    lst = sorted(lst); i = 0
    while i < len(lst):
        j = i + 1
        while j < len(lst) and j - i < CHUNK and lst[j][0] - lst[i][0] <= SPAN:
            j += 1
        yield lst[i:j]; i = j


def job(part, zn, key, b, D, B, rrr, casts, until, z, extra=None):
    j = {"key": key, "b": b, "D": D, "B": B, "rep_ready_rel": rrr, "casts": casts, "until": until, "tail": 0, "dog_at": ZP["dog_at"],
         "spot": zn, "z": z, "part": part, "tag": f"{part}:{zn}:{key}:{B}:{until}:{casts[0][0]}"}
    if extra:
        j.update(extra)
    return j


def runs_to(d, lim):
    out, k = [], 0
    for i in range(0, len(d), 2):
        k = d[i] if i == 0 else k + d[i]
        if k > lim:
            break
        out.append([k, d[i + 1]])
    return out


fd1 = {}
for ln in open(A.fd1):
    r = json.loads(ln)
    if r.get("ok"):
        fd1[r["key"]] = r
jobs = {"A": [], "B1": [], "B2": [], "C": []}; gate = []; count = collections.Counter(); a_lines = []; nomember = collections.Counter()
for key in ZP["order"]:
    L = zz[key]; r = fd1[key]
    assert r["end"][0] >= END and r["end"][1] == "limit", (key, r["end"])
    for zn, want in ZONES.items():
        mem = [m for m in L["members"] if "spot" in m and "k_off" in m and zone_of(m["spot"][1]) == zn]
        cl = ZP["lines"][key].get("zcasts", {}).get(zn, [])
        if not mem:
            nomember[zn] += 1; count[f"casts of lines that never stand in the {zn} zone (not planned)"] += len(cl)
            continue
        near = [m for m in mem if abs(m["spot"][1] - want) <= 1.5] or mem
        m = max(near, key=lambda m: (m["w"], -m["B"], m["b"]))
        rrr = m["ready_rel"] - m["k_off"]
        if key not in a_lines:
            a_lines.append(key)
        byu = collections.defaultdict(list)
        for c in cl:
            byu[c[1]].append([c[0], None])
        for until, lst in sorted(byu.items()):
            for ch in chunks(lst):
                jobs["A"].append(job("A", zn, key, m["b"], m["D"], m["B"], rrr, ch, until, round(m["spot"][1], 3)))
                count["A casts"] += len(ch); count[f"A casts {zn}"] += len(ch)
        gate.append({"kind": "line", "key": key, "b": m["b"], "D": m["D"], "B": m["B"], "rep_ready_rel": rrr, "until": END, "step": 2,
                     "dog_at": ZP["dog_at"], "spot": zn, "z": round(m["spot"][1], 3), "k_off": m["k_off"], "tag": f"gate:{zn}:{key}",
                     "want": {"h0": r["h0"], "step": r["step"], "hs": r["hs"][:(1200 - r["h0"]) // r["step"] + 1], "runs": runs_to(r["d"], END)}})
for key in a_lines:                            # control at the recorded spot
    rep = zz[key]["rep"]; cl = ZP["lines"][key]["zcasts"].get("middle") or ZP["lines"][key]["zcasts"].get("south") or []
    pick = [cl[int(i * len(cl) / 6)] for i in range(6)] if len(cl) >= 6 else cl
    byu = collections.defaultdict(list)
    for c in pick:
        byu[c[1]].append(c)
    for until, lst in sorted(byu.items()):
        for ch in chunks([[c[0], None] for c in lst]):
            want = {str(c[0]): c[3] for c in lst if [c[0], None] in ch}
            gate.append(dict(job("gate", "rep", key, rep["b"], rep["D"], rep["B"], rep["ready_rel"], ch, until, round(rep["spot"][1], 3)), kind="cast", want=want))
            count["gate control casts"] += len(ch)
count["gate line jobs"] = sum(1 for g in gate if g["kind"] == "line"); count["A jobs"] = len(jobs["A"])
tags = [j["tag"] for j in jobs["A"]] + [g["tag"] for g in gate]; assert len(tags) == len(set(tags)), "duplicate tags"
plan = {"code": "gap-plan-1", "label": A.label, "dog_at": ZP["dog_at"], "zones": ZONES, "end": END, "reps": {k: {a: zz[k]["rep"][a] for a in ("b", "D", "B", "ready_rel")} for k in ZP["order"]}, "a_lines": len(a_lines),
        "gate": gate, "jobs": jobs, "counts": dict(count), "gate_lines_fatal": False, "lines_without_member": dict(nomember)}
json.dump(plan, gzip.open(A.out, "wt"), separators=(",", ":"))
print(A.label, "lines", len(ZP["order"]), "with a member outside north", len(a_lines), "no member:", dict(nomember)); [print("  ", k, v) for k, v in sorted(count.items())]
