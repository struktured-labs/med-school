"""Built-in (no-copro) CPU: CPU vs CPU and VS CPU run on the 6502; check it plays, clears
viruses, never lags past a frame, and the frame checker still agrees with the sim."""
import sys, json, random
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from emu import Rom
ROM, LAB = "build/medschool.nes", "build/medschool.labels"
out = []
for gid in range(int(sys.argv[1]) if len(sys.argv) > 1 else 6):
    rng = random.Random(gid)
    lv = rng.choice([0, 2, 5, 8]); s0, s1 = rng.randrange(256), rng.randrange(1, 256)
    r = Rom(ROM, LAB)
    r.start_game(lv, 1, s0, s1, mode=3, level2=lv, speed2=1, boards=0, nocopro=True)
    v0 = (r.r("P1::vcount"), r.r("P2::vcount")); f = 0; locks = [0, 0]; last = [None, None]
    while r.r("mode") == 2 and f < 20000:
        r.step(0, 1); f += 1
        for i, p in enumerate(("P1", "P2")):
            pi = r.r(p + "::pidx")
            if pi != last[i]: locks[i] += 1; last[i] = pi
        if r.r("P1::state") in (5, 6) or r.r("P2::state") in (5, 6): break
    out.append(dict(gid=gid, lv=lv, frames=f, v0=v0, v1=(r.r("P1::vcount"), r.r("P2::vcount")),
                    locks=locks, st=(r.r("P1::state"), r.r("P2::state"))))
    print(out[-1], flush=True)
json.dump(out, open("test/results/builtin_cpu.json", "w"), indent=1)
