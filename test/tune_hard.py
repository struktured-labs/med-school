"""Tune HARD knob sets: P1 = GRAD MEDIUM reference, P2 = avatar at HARD with knobs poked after setup."""
import sys, json, random
from multiprocessing import Pool
sys.path.insert(0, "test")
from emu import Rom
CANDS = json.loads(sys.argv[1])      # {name: [avatar, [13 knobs]]}
N = int(sys.argv[2]); LVS = [int(x) for x in sys.argv[3].split(",")]
def run(a):
    name, av, kn, lv, k = a
    rng = random.Random(k * 7 + 1 + lv); s0, s1 = rng.randrange(256), rng.randrange(1, 256)
    r = Rom("build/medschool.nes", "build/medschool.labels")
    r.start_game(lv, 1, s0, s1, mode=3, level2=lv, speed2=1, boards=0, nocopro=True, chars=(0, av), diff=(1, 2))
    if kn:
        base = r.L["P2::k_wr"]
        for i, v in enumerate(kn): r.w(base + i, v)
    f = 0
    while r.r("mode") == 2 and r.r("mstate") != 2 and f < 60000:
        r.step(0x10 if r.r("mstate") and f % 8 == 0 else 0, 1); f += 1
    return name, r.r("P2::wins") > r.r("P1::wins")
jobs = [(n, c[0], c[1], lv, k) for n, c in CANDS.items() for lv in LVS for k in range(N)]
with Pool(22) as p: res = p.map(run, jobs, chunksize=1)
for n in CANDS: w = [x for m, x in res if m == n]; print(n, "%d/%d" % (sum(w), len(w)), round(sum(w) / len(w), 3))
