import sys; sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from vs import Rom, ROM, LAB, Copro
from collections import Counter
r=Rom(ROM,LAB); r.start_game(12,2,0x55,0xAA,mode=3,level2=12,speed2=2); cop=Copro(r,0)
c=Counter(); last=r.r("ticks"); h=(0,0); st=(0,0)
for f in range(12000):
    r.step(0); cop.poll(None); t=r.r("ticks")
    nh=(r.r("P1::ai_have"),r.r("P2::ai_have")); ns=(r.r("P1::state"),r.r("P2::state"))
    if r.r("mstate")==0 and r.r("mode")==2 and t==last:
        c[("planned" if (nh[0]>h[0] or nh[1]>h[1]) else "noplan", st)]+=1
    h=nh; st=ns; last=t
print(c.most_common(12))
