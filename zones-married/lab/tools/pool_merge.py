"""Merge the result parts several Macs made of ONE job list (2026-11-25).

  python3 -I pool_merge.py --out MERGED.jsonl PART.jsonl[.gz] [PART ...] [--key tag] [--expect N]

Rows are keyed by their job tag (row["_job"][key]); error rows and refused rows (ok false) are dropped. A job several
Macs ran must give the same row (timing fields aside): a difference is reported and stops the merge with exit 3,
because the lab is deterministic and two Macs must agree. The output is ordered by first appearance."""
import argparse, gzip, json, sys
ap = argparse.ArgumentParser()
ap.add_argument("parts", nargs="+"); ap.add_argument("--out", required=True)
ap.add_argument("--key", default="tag"); ap.add_argument("--expect", type=int, default=0)
a = ap.parse_args()
SKIP = {"_job", "_t", "_wall", "_worker", "_tries", "t", "wall"}
def rows(p):
    f = gzip.open(p, "rt") if p.endswith(".gz") else open(p)
    with f:
        for ln in f:
            try:
                yield json.loads(ln)
            except ValueError:
                continue                                  # a line still being written when the part was copied
def body(r):
    return json.dumps({k: v for k, v in r.items() if k not in SKIP}, sort_keys=True)
seen, order, stats, clash = {}, [], [], []
for p in a.parts:
    n = new = dup = bad = 0
    for r in rows(p):
        n += 1
        if "_error" in r or "error" in r or r.get("ok", True) is False or a.key not in r.get("_job", {}):
            bad += 1; continue
        k = r["_job"][a.key]
        if k in seen:
            dup += 1
            if body(seen[k]) != body(r): clash.append((k, p))
        else:
            seen[k] = r; order.append(k); new += 1
    stats.append((p, n, new, dup, bad))
for p, n, new, dup, bad in stats:
    print(f"  {p}: {n} rows, {new} new, {dup} also made by another part, {bad} error / refused rows left out")
print(f"merged: {len(order)} jobs" + (f" of {a.expect} expected" if a.expect else ""))
if clash:
    print(f"STOP: {len(clash)} jobs came out DIFFERENT on two Macs (first: {clash[:3]}). Nothing written.")
    sys.exit(3)
with open(a.out, "w") as f:
    for k in order: f.write(json.dumps(seen[k], separators=(",", ":")) + "\n")
if a.expect and len(order) != a.expect:
    print(f"NOT COMPLETE: {a.expect - len(order)} jobs missing"); sys.exit(2)
