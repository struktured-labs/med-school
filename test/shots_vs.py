# headless versus screenshots from the cynes framebuffer, copro served by the C port
import sys, random
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from vs import Rom, ROM, LAB, Copro, Bot
import medsim as M
from PIL import Image
def run(mode, name, frames, lv=6, seed=(0x12, 0x34)):
    r = Rom(ROM, LAB); r.start_game(lv, 1, *seed, mode=mode, level2=lv, speed2=1)
    m = M.MedMatch(lv, 1, lv, 1, *seed)  # used only for the greedy human bot view
    cop = Copro(r, 0); bot = Bot(random.Random(1), "greedy"); bot2 = Bot(random.Random(2), "greedy")
    cpu = [mode == 3, mode in (1, 3)]
    for f in range(max(frames) + 1):
        i1 = 0 if cpu[0] else bot.greedy_inp(m.p[0]); i2 = 0 if cpu[1] else bot2.greedy_inp(m.p[1])
        r.step(i1, btn2=i2); cop.poll(None); m.frame(i1, i2)
        if f in frames:
            Image.fromarray(r.frame).save(f"shots/{name}_{f:05d}.png")
for mode, name in ((1, "vs_cpu"), (2, "2p"), (3, "cpu_vs_cpu")):
    run(mode, name, [600, 1800, 3600])
