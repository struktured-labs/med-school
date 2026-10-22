import sys; sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from vs import Rom, ROM, LAB, Copro
r=Rom(ROM,LAB); r.start_game(12,2,0x55,0xAA,mode=3,level2=12,speed2=2); cop=Copro(r,0)
lag=play=0; last=r.r("ticks")
for f in range(30000):
    r.step(0); cop.poll(None); t=r.r("ticks")
    if r.r("mstate")==0 and r.r("mode")==2:
        play+=1; lag+= (t==last)
    last=t
print("play frames",play,"lag frames",lag)
