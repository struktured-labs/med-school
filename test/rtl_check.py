"""Fidelity: Med School's copro uploads vs the REAL DRDANGER firmware (70dad713) on the copro RTL
(Verilator vsim_pub2), against the C port the harness uses.  Also reports real DONE latency."""
import sys, os, json, random, subprocess
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
import vs
VSIM = "/home/struktured/projects/dr-mario-lateflip-wt/tmp/pubtrace/obj_pub2/vsim_pub2"
caps = []
class Rec(vs.Copro):
    def poll(self, expect):
        r = self.r
        for w in (0, 1):
            g = r.nes[0x57F0 + w]
            if g != self.go[w] and w == 1:
                base = 0x5200
                caps.append(bytes(r.nes[base + i] for i in range(132)))
        super().poll(expect)
vs.Copro = Rec
N = int(sys.argv[1]) if len(sys.argv) > 1 else 36
for gid in range(3):
    if len(caps) >= N: break
    vs.run_match((gid, 1, 11, 1, 11, 1, 0x30 + gid, 0x77, 0, 6000))
caps = caps[:N]
import ctypes
lib = vs.Copro.__mro__[1].__init__.__globals__.get("LIB") if False else None
r0 = vs.Rom(vs.ROM, vs.LAB); cp = vs.Copro.__mro__[1](r0, 0)
def cport(inb):
    buf = (ctypes.c_ubyte * 132).from_buffer_copy(inb); out = (ctypes.c_ubyte * 8)()
    cp.lib.ms_search(buf, out); return list(out[:6])
def rtl(inb):
    line = "%d %d %d %d " % tuple(inb[0x80:0x84]) + " ".join("%02x" % v for v in inb[:128])
    p = subprocess.run(["nice", "-n", "5", VSIM, "64"], cwd="/tmp/dd", input=line + "\n", capture_output=True, text=True)
    return p.stdout.split()
with ThreadPoolExecutor(12) as ex:
    outs = list(ex.map(rtl, caps))
agree = 0; lat = []; rows = []
for inb, t in zip(caps, outs):
    j = t.index("DONE"); dclk = int(t[j + 1]); col, o = int(t[j + 2]), int(t[j + 3])
    tk = t.index("TUCK"); tc, tr = int(t[tk + 1]), int(t[tk + 2])
    c = cport(inb)
    ok = (col, o, tc) == (c[2], c[3], c[4]) or (col, o) == (c[2], c[3])
    agree += ok; lat.append(dclk / 85.909e6 * 60.0988)
    rows.append(dict(rtl=(col, o, tc, tr), cport=c, ok=ok, frames=round(lat[-1], 1)))
lat.sort()
print(json.dumps(dict(n=len(caps), agree=agree, lat_med=lat[len(lat)//2], lat_p90=lat[int(len(lat)*.9)], lat_max=lat[-1]), indent=1))
for r in rows:
    if not r["ok"]: print(r)
json.dump(rows, open("test/results/rtl_check.json", "w"), indent=1)
