import sys; sys.path.insert(0, "test")
from emu import Rom
from PIL import Image
r = Rom("build/medschool.nes", "build/medschool.labels")
r.step(0, 60); Image.fromarray(r.frame).save("shots/smoke_title.png")
r.start_game(5, 1, 0x12, 0x34)
print("mode", r.r("mode"), "state", r.r("state"), "gframe", r.r("gframe"), "vcount", r.r("vcount"))
for i in range(120): r.step(0x04 if i>40 else 0)
Image.fromarray(r.frame).save("shots/smoke_game.png")
b = r.ram(0x400, 128)
for row in range(16): print("".join("%02x" % v for v in b[row*8:row*8+8]))
print("state", r.r("state"), "py", r.r("py"), "gframe", r.r("gframe"), "score", r.r("score"))
