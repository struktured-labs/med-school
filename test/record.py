"""Find a winning greedy game, record per-gframe inputs + interesting frames, emit fceux Lua."""
import sys, random
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from emu import Rom
import medsim as M
from compare import Bot
level, speed = int(sys.argv[1]), int(sys.argv[2])
for seed in range(0x1234, 0x1234 + 60):
    s0, s1 = seed >> 8, seed & 255
    r = Rom("build/medschool.nes", "build/medschool.labels")
    r.start_game(level, speed, s0, s1)
    g = M.MedGame(level, speed, s0, s1)
    bot = Bot(random.Random(seed), "greedy")
    inputs, marks, last = [], {}, -1
    while len(inputs) < 20000:
        inp = bot.greedy_inp(g)
        r.step(inp)
        gf = r.r("gframe") | r.r("gframe", 1) << 8
        if gf == last: continue
        last = gf
        inputs.append(r.r("dbg_inp")); g.frame(inputs[-1])
        if g.state == M.CLEARWAIT and "clear" not in marks and g.timer == 10 and g.vcount < g.b.virus_count() + 99 and len(inputs) > 300:
            marks["clear"] = gf
        if len(inputs) == 700: marks["play"] = gf
        if g.state in (M.WIN, M.LOSE): break
    if g.state == M.WIN:
        marks["win"] = last + 30
        break
print("seed", hex(seed), "frames", len(inputs), "marks", marks, file=sys.stderr)
out = sys.argv[3]
with open(out, "w") as f:
    f.write("local L=%d local S=%d local S0=%d local S1=%d\n" % (level, speed, s0, s1))
    f.write("local inp={%s}\n" % ",".join(map(str, inputs)))
    f.write("local marks={%s}\n" % ",".join('[%d]="%s"' % (v, k) for k, v in marks.items()))
    f.write(open("test/shots_tmpl.lua").read())
