"""Attract with no copro (copro_ok forced 0): the scripted demo must reproduce the recorded round."""
import sys; sys.path[:0] = ["test", "ref"]
from emu import Rom
r = Rom("build/medschool.nes", "build/medschool.labels")
r.step(0, 5); r.w(r.L["copro_ok"], 0)
for f in range(1300):
    r.step(0)
    if r.r("demo"): break
print("demo started at frame", f, "game_mode", r.r("game_mode"))
for f in range(20000):
    r.step(0)
    if r.r("mstate") != 0: break
final = (r.ram(0x400, 128), r.ram(0x500, 128))
print("round over after", f, "frames; boards match recording:", repr(final) == open("build/demo_final.txt").read())
for f in range(400):
    r.step(0)
print("back at title:", r.r("mode") == 0)
