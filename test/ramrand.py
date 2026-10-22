"""Power-up with random/$FF RAM (MiSTer randomises RAM): poke RAM, soft reset, then START on P1 / P2."""
import sys, random; sys.path[:0]=["test"]
from emu import Rom
rom, lab = sys.argv[1], sys.argv[2]
bad = 0
for trial in range(40):
    for who in (1, 2):
        r = Rom(rom, lab)
        rnd = random.Random(trial)
        for a in range(0x800): r.nes[a] = 0xFF if trial == 0 else rnd.randrange(256)
        r.nes.reset()
        r.step(0, rnd.randrange(20, 90))
        t = 0x10
        r.step(t if who == 1 else 0, 2, btn2=t if who == 2 else 0); r.step(0, 8)
        if r.r("mode") != 1: bad += 1; print("FAIL trial", trial, "P%d" % who, "mode", r.r("mode"))
print("fails", bad, "/ 80")
