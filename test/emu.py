"""cynes-based headless driver for Med School."""
import re, numpy as np
from cynes.emulator import NES
from cynes import *  # noqa

def labels(path):
    """name -> address; per-player zero-page names map to P1 (lower) and 'P2::name' (higher)."""
    multi = {}
    for line in open(path):
        m = re.match(r"al ([0-9A-Fa-f]+) \.(\S+)", line)
        if m:
            multi.setdefault(m.group(2), set()).add(int(m.group(1), 16))
    out = {}
    for k, v in multi.items():
        v = sorted(v)
        out[k] = v[0]
        if len(v) == 2:
            out["P1::" + k] = v[0]
            out["P2::" + k] = v[1]
    return out

# our byte layout (A=$80 ... Right=$01) -> cynes controller bits
def to_cynes(b):
    m = 0
    if b & 0x80: m |= NES_INPUT_A
    if b & 0x40: m |= NES_INPUT_B
    if b & 0x20: m |= NES_INPUT_SELECT
    if b & 0x10: m |= NES_INPUT_START
    if b & 0x08: m |= NES_INPUT_UP
    if b & 0x04: m |= NES_INPUT_DOWN
    if b & 0x02: m |= NES_INPUT_LEFT
    if b & 0x01: m |= NES_INPUT_RIGHT
    return m

class Rom:
    def __init__(self, rom, lab):
        self.nes = NES(rom)
        self.L = labels(lab)
        self.frame = None
    def step(self, btn=0, n=1, btn2=0):
        self.nes.controller = to_cynes(btn) | (to_cynes(btn2) << 8)
        self.frame = self.nes.step(frames=n)
        return self.frame
    def r(self, name, off=0):
        return self.nes[self.L[name] + off]
    def ram(self, addr, n=1):
        return [self.nes[addr + i] for i in range(n)]
    def w(self, addr, v):
        self.nes[addr] = v
    def press(self, btn, hold=2, gap=4):
        self.step(btn, hold); self.step(0, gap)
    def start_game(self, level, speed, s0, s1, mode=0, level2=0, speed2=1, boards=1, rng=0, nocopro=False):
        self.step(0, 30)
        self.press(0x10)            # title -> menu
        self.step(0, 10)
        self.w(0x300, level); self.w(0x301, speed)
        self.w(0x305, mode); self.w(0x308, boards); self.w(0x306, level2); self.w(0x307, speed2)
        self.w(0x302, s0); self.w(0x303, s1); self.w(0x304, 0xA5); self.w(0x3A2, rng)
        if nocopro is not False: self.w(self.L['copro_ok'], 0 if nocopro is True else nocopro)
        self.step(0x10, 1)          # START pressed -> game setup
        self.step(0, 1)
        for _ in range(400):
            if self.r("mode") == 2:
                break
            self.step(0, 1)
