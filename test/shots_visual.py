import sys; sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from vs import Rom, ROM, LAB, Copro, Bot
import medsim as M, random
from PIL import Image
S=lambda r,n: Image.fromarray(r.frame).save("shots/"+n+".png")
r=Rom(ROM,LAB); r.step(0,60); S(r,"30_title"); r.step(0,40); S(r,"30b_title_parade")
r.press(0x10); r.step(0,10); S(r,"31_menu")
# 1P mid-game + throw
r=Rom(ROM,LAB); r.start_game(11,1,0x12,0x34); m=M.MedGame(11,1,0x12,0x34); bot=Bot(random.Random(3),"greedy")
shot={8:"32_1p_throw",900:"33_1p_play"}
for f in range(1000):
    i=bot.greedy_inp(m); r.step(i); m.frame(i)
    if f in shot: S(r,shot[f])
# close-up of pills: crop the playfield, 3x
img=Image.open("shots/33_1p_play.png"); img.crop((96,80,160,208)).resize((192,384),Image.NEAREST).save("shots/34_pill_closeup.png")
# VS CPU vs CPU and a round end
r=Rom(ROM,LAB); r.start_game(2,1,0x12,0x34,mode=3,level2=2,speed2=1); cop=Copro(r,0)
for f in range(4000):
    r.step(0); cop.poll(None)
    if f==700: S(r,"35_vs_play")
    if r.r("mstate")!=0:
        r.step(0,20); S(r,"36_vs_round_end"); break
# 1P clear & fail
r=Rom(ROM,LAB); r.start_game(0,2,0x12,0x34); m=M.MedGame(0,2,0x12,0x34); bot=Bot(random.Random(5),"greedy")
for f in range(9000):
    i=bot.greedy_inp(m); r.step(i); m.frame(i)
    if r.r("P1::state") in (5,6): r.step(0,30); S(r,"37_1p_end_state%d"%r.r("P1::state")); break
