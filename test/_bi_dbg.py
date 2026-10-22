import sys; sys.path.insert(0,"test")
from emu import Rom
r = Rom("build/medschool.nes","build/medschool.labels")
r.start_game(8,1,0x31,0x77,mode=3,level2=8,speed2=1,boards=0,nocopro=True)
b=r.L["P1::board"] if "P1::board" in r.L else None
print(b, [k for k in r.L if "board" in k.lower()][:8])
last=None
for f in range(4000):
    r.step(0,1)
    pi=r.r("P1::pidx")
    if pi!=last:
        last=pi
        if pi in (3,6,12,20):
            bb=0x0400
            for y in range(16): print("".join(".rybRYB?"[ (c&3)+(4 if c&4 else 0) if c else 0] if True else "" for c in r.ram(bb+y*8,8)))
            print("fin",r.r("P1::ai_fin"),"o",r.r("P1::ai_o"),"best",r.nes[0x3AC+1],"bc",r.nes[0x3AC+2],"ok",r.r("P1::ai_ok"))
    if r.r("P1::state") in (5,6): break
