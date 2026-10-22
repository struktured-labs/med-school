"""Cycle cost of P1::drive on real frames (py65 on RAM snapshots from cynes)."""
import sys; sys.path.insert(0,"/tmp/py65"); sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from vs import Rom, ROM, LAB, Copro
from emu import labels
from py65.devices.mpu6502 import MPU
lab = labels(LAB)
prg = open(ROM,"rb").read()[16:16+32768]
def run_sub(ram, extra, addr):
    m = MPU(); mem = m.memory
    for i in range(0x800): mem[i] = ram[i]
    for a, v in extra.items(): mem[a] = v
    for i in range(32768): mem[0x8000+i] = prg[i]
    mem[0x7000] = 0x20; mem[0x7001] = addr & 0xFF; mem[0x7002] = addr >> 8; mem[0x7003] = 0xEA
    m.pc = 0x7000; m.sp = 0xF0; c0 = m.processorCycles
    while m.pc != 0x7003: m.step()
    return m.processorCycles - c0
if __name__ == "__main__":
    r=Rom(ROM,LAB); r.start_game(12,2,0x55,0xAA,mode=3,level2=12,speed2=2); cop=Copro(r,0)
    plan=[]; other=[]
    for f in range(int(sys.argv[1]) if len(sys.argv)>1 else 4000):
        r.step(0); cop.poll(None)
        if r.r("mstate")==0 and r.r("P1::state")==1:
            ram=[r.nes[i] for i in range(0x800)]
            a=cop.answers[0]; extra={}
            if a: extra={0x5084:1,0x5085:a["done_col"],0x5086:a["done_o4"],0x5087:a["tuck_col"],0x5088:a["tuck_row"]}
            c=run_sub(ram, extra, lab["P1::drive"])
            (plan if ram[lab["P1::ai_have"]]==0 else other).append(c)
    print("plan frames n=%d max=%d avg=%d"%(len(plan),max(plan),sum(plan)//len(plan)))
    print("other frames n=%d max=%d avg=%d"%(len(other),max(other),sum(other)//len(other)))
