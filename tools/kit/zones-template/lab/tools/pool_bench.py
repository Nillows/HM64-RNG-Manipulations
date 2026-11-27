"""Which worker count is fastest on this Mac (2026-11-25)? Runs the lab's own reference route from power-on
(zz_check_job: a fixed, self-contained job) N times at each worker count and compares jobs per minute.

  python3 tools/pool_bench.py --workers-list 4,9,10 [--jobs 0] [--out bench.json]

--jobs 0 = 8 jobs per worker, at least 60 (each job is a few seconds). The fewest workers within 3% of the best rate win (less heat, same speed)."""
import argparse, json, os, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "experiments"))
from common import default_rom, default_sram   # noqa: E402
from m64h.pool import run_jobs                 # noqa: E402
import zigzag_jobs as ZJ                        # noqa: E402
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers-list", required=True); ap.add_argument("--jobs", type=int, default=0); ap.add_argument("--out")
    a = ap.parse_args()
    cands = sorted({max(1, int(x)) for x in a.workers_list.split(",") if x.strip()})
    rom, sram = default_rom(), default_sram()
    res = []
    for w in cands:
        n = a.jobs or max(60, 8 * w)
        t0 = time.time(); bad = 0
        for r in run_jobs(ZJ.zz_check_job, [{"check": i} for i in range(n)], rom=rom, sram=sram, workers=w, fresh=True):
            bad += ("_error" in r or "error" in r)
        el = time.time() - t0
        res.append({"workers": w, "jobs": n, "seconds": round(el, 1), "per_min": round(n / el * 60, 2), "errors": bad})
        print(f"[bench] {w:2d} workers: {n} jobs in {el:5.0f} s = {n / el * 60:6.1f} jobs/min" + (f"  ({bad} errors)" if bad else ""), flush=True)
    ok = [r for r in res if not r["errors"]]
    if not ok:
        print("[bench] every run had job errors: no result", flush=True)
        sys.exit(1)
    top = max(r["per_min"] for r in ok)
    best = min(r["workers"] for r in ok if r["per_min"] >= 0.97 * top)
    print(f"[bench] best: {best} workers", flush=True)
    if a.out:
        json.dump({"best": best, "runs": res, "cpus": os.cpu_count()}, open(a.out, "w"), indent=1)


if __name__ == "__main__":
    main()
