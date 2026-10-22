import sys; sys.path.insert(0,"/tmp/py65"); sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from cycles import *
from collections import Counter
import bisect
names = sorted((v,k) for k,v in lab.items() if 0x8000<=v<0x10000 and '@' not in k)
addrs=[v for v,k in names]
prof=Counter()
def run_prof(ram, extra, addr):
    m = MPU(); mem = m.memory
    for i in range(0x800): mem[i] = ram[i]
    for a, v in extra.items(): mem[a] = v
    for i in range(32768): mem[0x8000+i] = prg[i]
    mem[0x7000]=0x20; mem[0x7001]=addr&0xFF; mem[0x7002]=addr>>8; mem[0x7003]=0xEA
    m.pc=0x7000; m.sp=0xF0
    while m.pc != 0x7003:
        pc=m.pc; c=m.processorCycles; m.step()
        if pc>=0x8000: prof[names[bisect.bisect_right(addrs,pc)-1][1]] += m.processorCycles-c
r=Rom(ROM,LAB); r.start_game(12,2,0x55,0xAA,mode=3,level2=12,speed2=2); cop=Copro(r,0)
n=0
for f in range(3000):
    r.step(0); cop.poll(None)
    if r.r("mstate")==0 and r.r("P1::state")==1 and r.r("P1::ai_have")==0 and cop.answers[0]:
        a=cop.answers[0]; ram=[r.nes[i] for i in range(0x800)]
        run_prof(ram,{0x5084:1,0x5085:a["done_col"],0x5086:a["done_o4"],0x5087:a["tuck_col"],0x5088:a["tuck_row"]},lab["P1::drive"]); n+=1
for k,v in prof.most_common(12): print(k, v//n)
