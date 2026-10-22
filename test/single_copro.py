"""DRDANGER/winner core has only the $5200 copro: copro_ok=2 -> P1 built-in, P2 copro brain."""
import sys; sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from vs import Rom, ROM, LAB, Copro
for gid,(lv,s0,s1) in enumerate([(5,0x12,0x34),(8,0x55,0xAA),(2,0x9E,0x21)]):
    r=Rom(ROM,LAB); r.start_game(lv,1,s0,s1,mode=3,level2=lv,speed2=1,boards=0,nocopro=2); cop=Copro(r,0)
    assert r.r("copro_ok")==2
    f=0
    while r.r("mode")==2 and f<20000 and r.r("mstate")==0:
        r.step(0); cop.poll(None); f+=1
    print(dict(lv=lv,frames=f,P1_virus=r.r("P1::vcount"),P2_virus=r.r("P2::vcount"),st=(r.r("P1::state"),r.r("P2::state")),searches=cop.searches))
