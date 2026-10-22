"""Title -> menu with START on P1 while P2's line floats high (reads $FF), and vice versa."""
import sys; sys.path[:0]=["test"]
from emu import Rom
for who in (1, 2):
    r = Rom(sys.argv[1], sys.argv[2])
    r.step(0, 30)
    for f in range(6):
        b1, b2 = (0x10 if f < 2 else 0, 0xFF) if who == 1 else (0xFF, 0x10 if f < 2 else 0)
        r.step(b1, btn2=b2)
    r.step(0xFF if who == 2 else 0, 10, btn2=0xFF if who == 1 else 0)
    print("START on P%d with other port floating -> mode %d (1 = menu)" % (who, r.r("mode")))
