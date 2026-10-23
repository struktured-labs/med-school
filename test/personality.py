"""CPU personality / difficulty metrics (emulator only, CPU vs CPU).

  h2h   : the 5 personalities at MEDIUM, round robin (sides alternate)
  diff  : every avatar x EASY/MEDIUM/HARD vs a fixed reference (GRAD/METHODICAL MEDIUM)
Engine: built-in 6502 CPU (nocopro) by default; COPRO=lat runs both sides on the C-port
copro with that DONE latency (frames) instead.  Usage: personality.py h2h|diff N LV[,LV..] [workers]
"""
import sys, os, json, random, time
from multiprocessing import Pool
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from emu import Rom
ROM, LAB = "build/medschool.nes", "build/medschool.labels"
COPRO = os.environ.get("COPRO")
NAMES = ["GRAD/METHODICAL", "MONITR/DEFENSIVE", "PILL/GREEDY", "BANDGE/CHAOTIC", "PETRI/AGGRESSIVE"]
DIFF = ["EASY", "MEDIUM", "HARD"]
MAXF = 60000

def run(args):
    gid, lv, sp, chars, diffs, s0, s1 = args
    r = Rom(ROM, LAB)
    if COPRO:
        from vs import Copro
        r.start_game(lv, sp, s0, s1, mode=3, level2=lv, speed2=sp, boards=0, chars=chars, diff=diffs)
        cop = Copro(r, int(COPRO))
    else:
        r.start_game(lv, sp, s0, s1, mode=3, level2=lv, speed2=sp, boards=0, nocopro=True, chars=chars, diff=diffs)
        cop = None
    st = [dict(pills=0, react=0, react_n=0, vir=0, play=0, h=0, hn=0, chains=0, gsent=0, tucks=0,
               rounds=0, topouts=0, lost=0) for _ in (0, 1)]
    P = ("P1::", "P2::"); B = (0x400, 0x500)
    prevst = [None, None]; prevb = [r.ram(0x400, 128), r.ram(0x500, 128)]
    vc = [r.r("P1::vcount"), r.r("P2::vcount")]; gq = [r.nes[0x390], r.nes[0x391]]
    rx = [None, None]; mx = [0, 0]; f = 0; lastms = 0
    while r.r("mode") == 2 and f < MAXF:
        ms = r.r("mstate")
        r.step(0x10 if ms and f % 8 == 0 else 0, 1); f += 1
        if cop: cop.poll(None)
        ms = r.r("mstate")
        if ms and not lastms:
            w = r.r("round_winner")
            if w in (0, 1):
                st[w]["rounds"] += 1
                l = 1 - w; st[l]["lost"] += 1
                if r.r(P[w] + "state") != 5: st[l]["topouts"] += 1
        lastms = ms
        if ms == 2: break                      # match decided (CHAMPION); no rematch
        if ms: 
            prevst = [None, None]; continue
        for i in (0, 1):
            s = r.r(P[i] + "state"); b = r.ram(B[i], 128)
            st[i]["play"] += 1
            v = r.r(P[i] + "vcount")
            if v < vc[i]: st[i]["vir"] += vc[i] - v
            vc[i] = v
            g = r.nes[0x390 + i]
            if g > gq[i]: st[1 - i]["gsent"] += 1
            gq[i] = g
            if f % 30 == 0:
                top = next((k // 8 for k in range(128) if b[k] & 3), 16)
                st[i]["h"] += 16 - top; st[i]["hn"] += 1
            if s == 1:
                if prevst[i] != 1: rx[i] = 0; mx[i] = 0
                if r.r(P[i] + "throw_t") == 0 and rx[i] is not None:
                    if r.r(P[i] + "btn"): st[i]["react"] += rx[i]; st[i]["react_n"] += 1; rx[i] = None
                    else: rx[i] += 1
            mx[i] = max(mx[i], r.r(P[i] + "chain_v"))
            if prevst[i] == 1 and s == 2:
                st[i]["pills"] += 1
                new = [k for k in range(128) if b[k] & 3 and not prevb[i][k] & 3]
                old = prevb[i]
                if any(any(old[rr * 8 + k % 8] & 3 for rr in range(k // 8)) for k in new):
                    st[i]["tucks"] += 1
            if prevst[i] in (2, 3, 4) and s in (0, 1):
                if mx[i] >= 2: st[i]["chains"] += 1
                mx[i] = 0
            prevst[i] = s; prevb[i] = b
    for i in (0, 1):
        st[i]["mist"] = r.r(P[i] + "mist_n") | (r.r(P[i] + "mist_n", 1) << 8)
    wins = [r.r("P1::wins"), r.r("P2::wins")]
    return dict(gid=gid, lv=lv, chars=chars, diffs=diffs, frames=f, wins=wins, st=st,
                winner=(0 if wins[0] > wins[1] else 1 if wins[1] > wins[0] else None))

def agg(rows, side_of):
    """side_of(row) -> list of (key, side index) to accumulate"""
    A = {}
    for row in rows:
        for key, i in side_of(row):
            a = A.setdefault(key, dict(matches=0, mwins=0, rounds=0, rwins=0, topouts=0, pills=0, mist=0,
                                       react=0, react_n=0, vir=0, play=0, h=0, hn=0, chains=0, gsent=0, tucks=0))
            s = row["st"][i]; a["matches"] += 1; a["mwins"] += row["winner"] == i
            a["rounds"] += s["rounds"] + s["lost"]; a["rwins"] += s["rounds"]; a["topouts"] += s["topouts"]
            for k in ("pills", "mist", "react", "react_n", "vir", "play", "h", "hn", "chains", "gsent", "tucks"):
                a[k] += s[k]
    out = {}
    for k, a in A.items():
        p = max(a["pills"], 1)
        out[k] = dict(matches=a["matches"], match_win=round(a["mwins"] / a["matches"], 3),
                      round_win=round(a["rwins"] / max(a["rounds"], 1), 3),
                      topout_rate=round(a["topouts"] / max(a["rounds"], 1), 3),
                      vir_per_min=round(a["vir"] / max(a["play"], 1) * 3600, 2),
                      avg_stack=round(a["h"] / max(a["hn"], 1), 2),
                      chain_per100=round(100 * a["chains"] / p, 2), garbage_per100=round(100 * a["gsent"] / p, 2),
                      tuck_rate=round(a["tucks"] / p, 4), mistake_rate=round(a["mist"] / p, 4),
                      react_frames=round(a["react"] / max(a["react_n"], 1), 2), pills=a["pills"])
    return out

if __name__ == "__main__":
    kind, n = sys.argv[1], int(sys.argv[2])
    lvs = [int(x) for x in sys.argv[3].split(",")]
    workers = int(sys.argv[4]) if len(sys.argv) > 4 else 20
    jobs = []; gid = 0
    for lv in lvs:
        if kind == "h2h":
            for a in range(5):
                for b in range(a + 1, 5):
                    for k in range(n):
                        rng = random.Random(gid * 7 + 1); s0, s1 = rng.randrange(256), rng.randrange(1, 256)
                        c = (a, b) if k % 2 == 0 else (b, a)
                        jobs.append((gid, lv, 1, c, (1, 1), s0, s1)); gid += 1
        else:
            for a in range(5):
                for d in range(3):
                    for k in range(n):
                        rng = random.Random(k * 7 + 1 + lv); s0, s1 = rng.randrange(256), rng.randrange(1, 256)
                        jobs.append((gid, lv, 1, (0, a), (1, d), s0, s1)); gid += 1
    t = time.time()
    with Pool(workers) as pool: rows = pool.map(run, jobs, chunksize=1)
    res = dict(kind=kind, engine=("copro lat=" + COPRO) if COPRO else "built-in 6502", levels=lvs, n=n,
               seconds=round(time.time() - t, 1), unfinished=sum(r["winner"] is None for r in rows))
    if kind == "h2h":
        res["per_style"] = {"L%d %s" % (lv, NAMES[a]): v for (lv, a), v in sorted(agg(rows, lambda r: [((r["lv"], r["chars"][0]), 0), ((r["lv"], r["chars"][1]), 1)]).items())}
        pw = {}
        for row in rows:
            for i in (0, 1):
                key = "L%d %s vs %s" % (row["lv"], NAMES[row["chars"][i]].split("/")[1], NAMES[row["chars"][1 - i]].split("/")[1])
                w = pw.setdefault(key, [0, 0]); w[1] += 1; w[0] += row["winner"] == i
        res["pairwise_match_wins"] = {k: "%d/%d" % tuple(v) for k, v in sorted(pw.items()) if k.split()[1] < k.split()[3]}
    else:
        res["per_avatar_diff"] = {"L%d %s %s" % (lv, NAMES[a], DIFF[d]): v for (lv, a, d), v in sorted(agg(rows, lambda r: [((r["lv"], r["chars"][1], r["diffs"][1]), 1)]).items())}
        res["reference"] = {"L%d ref GRAD MEDIUM" % k[0]: v for k, v in agg(rows, lambda r: [((r["lv"],), 0)]).items()}
    tag = "%s_%s_%s" % (kind, "copro" if COPRO else "bi", "-".join(map(str, lvs)))
    os.makedirs("test/results", exist_ok=True)
    json.dump(dict(res, rows=rows), open("test/results/personality_%s.json" % tag, "w"), indent=1)
    print(json.dumps(res, indent=1))
