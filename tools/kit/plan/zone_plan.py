"""Plan of the camera-zone cast run (sandbox side, 2026-11-25).

The dock end has three camera zones (visibility grids): north (Jack's z 154.8-158.4, the recorded one), middle
(164-188.4), south (194-196.1). A recorded cast can only come out differently in another zone if the dog's recorded
path comes near a tile that the two grids treat differently. This plan lists, per zone, the recorded casts whose dog
comes within MARGIN units of such a tile before the cast's last recorded bite + EXT VIs (measured on the spot run:
99.3% of the real differences, every new Nut), minus the casts the spot run already made in that zone, plus every
SAMPLE-th other cast as a check of the casts that are copied.

  python3 -I zone_plan.py LABEL masks.json DOGWATCH_DIR SPOTS_DIR FD_DIR [FD_DIR ...] --out zone_plan_<label>.json.gz
"""
import argparse, glob, gzip, json
ap = argparse.ArgumentParser()
ap.add_argument("label"); ap.add_argument("masks"); ap.add_argument("dogwatch"); ap.add_argument("spots"); ap.add_argument("fd", nargs="+")
ap.add_argument("--out", required=True); ap.add_argument("--margin", type=float, default=48); ap.add_argument("--ext", type=int, default=600)
ap.add_argument("--sample", type=int, default=100)
a = ap.parse_args()
M = json.load(open(a.masks)); zone = {}
for r in M:
    if r.get("ready"):
        g = bytes.fromhex(r["snaps"][0]["grid"]); zone.setdefault(sum(1 for b in g if b), g)
N, MID, S = (zone[k] for k in sorted(zone, reverse=True))
ZONES = {"middle": (176.4, MID, "z176.4"), "south": (194.4, S, "z194.4")}
zz = json.load(open(a.dogwatch + "/zz_lines.json"))
rec = json.load(open(a.dogwatch + "/Z0_record.json")); d = (rec["record"] if "record" in rec else rec)["info"]["stages"]["5"]["dog"]
dog_at = [d["x"], d["z"]]
fd1 = {}
for ln in open(a.fd[-1] + "/FD1_lines.jsonl"):
    r = json.loads(ln)
    if r.get("ok"): fd1[r["key"]] = r
rows = {}
for fdir in a.fd:
    until = int(float(open(fdir + "/.limits").read().split()[0]) * 60) - 2
    for fn in sorted(glob.glob(fdir + "/FD_casts_b*.jsonl")):
        for ln in open(fn):
            row = json.loads(ln)
            for c in row.get("casts", []):
                if "b" not in c or c.get("ok") is False: continue
                old = rows.get((row["key"], c["k"]))
                if old is None or until > old[0]: rows[(row["key"], c["k"])] = (until, c)
done = {t: set() for t in ("z176.4", "z194.4")}
for ln in open(a.spots + "/SP2_casts.jsonl"):
    r = json.loads(ln)
    t = r["_job"]["spot"]
    if t in done:
        for c in r.get("casts", []): done[t].add((r["key"], c["k"]))
def path(pts):
    for (k0, x0, z0), (k1, x1, z1) in zip(pts, pts[1:]):
        n = max(1, int(max(abs(x1 - x0), abs(z1 - z0)) // 4))
        for i in range(n + 1): yield x0 + (x1 - x0) * i / n, z0 + (z1 - z0) * i / n
def near(dt, pts, m):
    for x, z in path(pts):
        fx = (x + 16 + 784.0) / 32; fz = (z + 16 + 528.0) / 32
        for tx, tz in dt:
            if tx - m <= fx < tx + 1 + m and tz - m <= fz < tz + 1 + m: return True
    return False
lines = {}; order = []; cnt = {t: [0, 0, 0] for t in ZONES}
for key in sorted(fd1, key=lambda k: (-zz[k]["w"], k)):
    f = fd1[key]; rep = zz[key]["rep"]; p = f.get("p") or []
    nat = [(p[i], p[i + 1], p[i + 2]) for i in range(0, len(p), 3)]
    zc = {t: [] for t in ZONES}; n_other = {t: 0 for t in ZONES}
    for (kk, k) in sorted(x for x in rows if x[0] == key):
        until, c = rows[(kk, k)]
        q = c.get("p") or []
        pts = [(0, dog_at[0], dog_at[1])] + [x for x in nat if x[0] <= k] + [(q[i], q[i + 1], q[i + 2]) for i in range(0, len(q), 3)]
        end = (c["b"][-1][0] if c["b"] else k) + a.ext
        # the dog keeps to its no-cast path only until the cast; after the row's own positions end, hold the last one
        pts.append((end, pts[-1][1], pts[-1][2]))
        bites = [[b[0], b[1]] for b in c["b"]]
        for t, (zt, g, sptag) in ZONES.items():
            dt = [(i % 42, i // 42) for i, (x, y) in enumerate(zip(N, g)) if x != y]
            if (key, k) in done[sptag]: cnt[t][2] += 1; continue
            if near(dt, pts, a.margin / 32):
                zc[t].append([k, until, 0, bites]); cnt[t][0] += 1
            else:
                n_other[t] += 1
                if n_other[t] % a.sample == 0: zc[t].append([k, until, 1, bites]); cnt[t][1] += 1
    lines[key] = {"w": zz[key]["w"], "rep": {"b": rep["b"], "D": rep["D"], "B": rep["B"], "ready_rel": rep["ready_rel"], "spot": rep["spot"]},
                  "h0": f["h0"], "step": f["step"], "hs": f["hs"][:60], "casts": [], "zcasts": zc}
    order.append(key)
plan = {"code": "zone-plan-1", "label": a.label, "dog_at": dog_at, "until": 10198, "order": order, "lines": lines,
        "zones": {t: ZONES[t][0] for t in ZONES}, "margin": a.margin, "ext": a.ext, "sample": a.sample,
        "counts": {t: {"near a tile the grids treat differently": cnt[t][0], "check sample of the rest": cnt[t][1], "already made by the spot run": cnt[t][2]} for t in ZONES},
        "recorded_casts": len(rows)}
with gzip.open(a.out, "wt", compresslevel=9) as f: json.dump(plan, f, separators=(",", ":"))
print(a.label, plan["recorded_casts"], plan["counts"])
