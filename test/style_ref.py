"""Copro style vs style-0 reference (ISO: both carts run GRAD knobs; only the copro style register differs).
Each style s (and a style-0 control) plays N matches vs a style-0 opponent, sides alternating, same seeds per style.
Usage: COPRO=50 ISO=1 style_ref.py N LV[,LV..] [workers]"""
import sys, os, json, random, time
sys.path.insert(0, "test")
os.environ["ISO"] = "1"; os.environ.setdefault("COPRO", "50")
import personality as P
from multiprocessing import Pool
LAB = ["METHODICAL", "DEFENSIVE", "GREEDY", "CHAOTIC", "AGGRESSIVE", "STYLE0-CONTROL"]
if __name__ == "__main__":
    n = int(sys.argv[1]); lvs = [int(x) for x in sys.argv[2].split(",")]; w = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    jobs = []; gid = 0
    for lv in lvs:
        for s in range(6):
            for k in range(n):
                rng = random.Random(k * 7 + 3 + lv); s0, s1 = rng.randrange(256), rng.randrange(1, 256)
                jobs.append((gid, lv, 1, (s, 5) if k % 2 == 0 else (5, s), (1, 1), s0, s1)); gid += 1
    t = time.time()
    with Pool(w) as p: rows = p.map(P.run, jobs, chunksize=1)
    side = lambda r: [((r["lv"], r["chars"][0] if r["chars"][0] != 5 or r["chars"][1] == 5 and r["gid"] % 2 == 0 else r["chars"][1]), 0 if (r["chars"][0] != 5 or (r["chars"][1] == 5 and r["gid"] % 2 == 0)) else 1)]
    res = {"L%d %s" % (lv, LAB[s]): v for (lv, s), v in sorted(P.agg(rows, side).items())}
    out = dict(kind="style_ref", engine="copro lat=" + os.environ["COPRO"] + " ISO", levels=lvs, n=n, seconds=round(time.time() - t, 1),
               unfinished=sum(r["winner"] is None for r in rows), per_style_vs_style0=res)
    json.dump(dict(out, rows=rows), open("test/results/style_ref_%s.json" % "-".join(map(str, lvs)), "w"), indent=1)
    print(json.dumps(out, indent=1))
