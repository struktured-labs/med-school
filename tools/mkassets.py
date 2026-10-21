#!/usr/bin/env python3
"""Generate Med School CHR + nametables. All art is original, drawn here as ASCII."""
import sys, os
OUT = sys.argv[1] if len(sys.argv) > 1 else "build"
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- 5x7 font (original)
FONT = {
' ': ["     "]*7,
'0': [" ### ","#   #","#  ##","# # #","##  #","#   #"," ### "],
'1': ["  #  "," ##  ","  #  ","  #  ","  #  ","  #  "," ### "],
'2': [" ### ","#   #","    #","  ## "," #   ","#    ","#####"],
'3': ["#### ","    #","    #"," ### ","    #","    #","#### "],
'4': ["   # ","  ## "," # # ","#  # ","#####","   # ","   # "],
'5': ["#####","#    ","#### ","    #","    #","#   #"," ### "],
'6': [" ### ","#    ","#    ","#### ","#   #","#   #"," ### "],
'7': ["#####","    #","   # ","  #  "," #   "," #   "," #   "],
'8': [" ### ","#   #","#   #"," ### ","#   #","#   #"," ### "],
'9': [" ### ","#   #","#   #"," ####","    #","    #"," ### "],
'A': [" ### ","#   #","#   #","#####","#   #","#   #","#   #"],
'B': ["#### ","#   #","#   #","#### ","#   #","#   #","#### "],
'C': [" ### ","#   #","#    ","#    ","#    ","#   #"," ### "],
'D': ["#### ","#   #","#   #","#   #","#   #","#   #","#### "],
'E': ["#####","#    ","#    ","#### ","#    ","#    ","#####"],
'F': ["#####","#    ","#    ","#### ","#    ","#    ","#    "],
'G': [" ### ","#   #","#    ","# ###","#   #","#   #"," ####"],
'H': ["#   #","#   #","#   #","#####","#   #","#   #","#   #"],
'I': [" ### ","  #  ","  #  ","  #  ","  #  ","  #  "," ### "],
'J': ["  ###","   # ","   # ","   # ","   # ","#  # "," ##  "],
'K': ["#   #","#  # ","# #  ","##   ","# #  ","#  # ","#   #"],
'L': ["#    ","#    ","#    ","#    ","#    ","#    ","#####"],
'M': ["#   #","## ##","# # #","# # #","#   #","#   #","#   #"],
'N': ["#   #","##  #","# # #","#  ##","#   #","#   #","#   #"],
'O': [" ### ","#   #","#   #","#   #","#   #","#   #"," ### "],
'P': ["#### ","#   #","#   #","#### ","#    ","#    ","#    "],
'Q': [" ### ","#   #","#   #","#   #","# # #","#  # "," ## #"],
'R': ["#### ","#   #","#   #","#### ","# #  ","#  # ","#   #"],
'S': [" ####","#    ","#    "," ### ","    #","    #","#### "],
'T': ["#####","  #  ","  #  ","  #  ","  #  ","  #  ","  #  "],
'U': ["#   #","#   #","#   #","#   #","#   #","#   #"," ### "],
'V': ["#   #","#   #","#   #","#   #","#   #"," # # ","  #  "],
'W': ["#   #","#   #","#   #","# # #","# # #","## ##","#   #"],
'X': ["#   #","#   #"," # # ","  #  "," # # ","#   #","#   #"],
'Y': ["#   #","#   #"," # # ","  #  ","  #  ","  #  ","  #  "],
'Z': ["#####","    #","   # ","  #  "," #   ","#    ","#####"],
'!': ["  #  ","  #  ","  #  ","  #  ","  #  ","     ","  #  "],
'-': ["     ","     ","     ","#####","     ","     ","     "],
'.': ["     ","     ","     ","     ","     ","     ","  #  "],
':': ["     ","  #  ","     ","     ","     ","  #  ","     "],
'>': [" #   ","  #  ","   # ","    #","   # ","  #  "," #   "],
'/': ["    #","    #","   # ","  #  "," #   ","#    ","#    "],
'(': ["   # ","  #  "," #   "," #   "," #   ","  #  ","   # "],
')': [" #   ","  #  ","   # ","   # ","   # ","  #  "," #   "],
}

tiles = [[[0]*8 for _ in range(8)] for _ in range(256)]

def put_glyph(t, rows, col=1):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '#':
                tiles[t][y][x + 1] = col

for ch, g in FONT.items():
    put_glyph(ord(ch), g)

def art(t, rows):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            tiles[t][y][x] = 0 if ch in ' .' else int(ch)

# --------------------------------------------------------------- pill + germ shapes
# '1' = body colour (swapped per colour), '3' never used here; highlights use 0 holes.
SHAPES = {
 0: ["  1111  "," 111111 ","11 11111","11111111","11111111","11111111"," 111111 ","  1111  "],  # single
 1: ["  111111"," 1111111","11 11111","11111111","11111111","11111111"," 1111111","  111111"],  # left half
 2: ["111111  ","1111111 ","11111111","11111111","11111111","11111111","1111111 ","111111  "],  # right half
 3: ["  1111  "," 111111 ","11 11111","11111111","11111111","11111111","11111111","11111111"],  # top half
 4: ["11111111","11111111","11111111","11111111","11111111","11111111"," 111111 ","  1111  "],  # bottom half
 5: ["1  11  1"," 111111 "," 1 11 1 ","11111111"," 11  11 "," 111111 "," 1 11 1 ","1      1"],  # germ
 6: ["1  1  1 "," 1 1 1  ","  1 1 1 ","11  1 11"," 1 1 1  ","  1 1 1 "," 1  1  1","1   1   "],  # pop
}
for shape, rows in SHAPES.items():
    for color in (1, 2, 3):
        t = 0x80 + shape * 4 + color
        art(t, [r.replace('1', str(color)) for r in rows])

# bottle tiles (colour 3)
art(0xA0, ["   33   "]*8)                                   # left/right wall (vertical bar)
art(0xA1, ["        ","        ","        ","33333333","33333333","        ","        ","        "])  # horiz
art(0xA2, ["        ","        ","        ","   33333","   33333","   33   ","   33   ","   33   "])  # top-left corner
art(0xA3, ["        ","        ","        ","33333   ","33333   ","   33   ","   33   ","   33   "])  # top-right
art(0xA4, ["   33   ","   33   ","   33   ","   33333","   33333","        ","        ","        "])  # bottom-left
art(0xA5, ["   33   ","   33   ","   33   ","33333   ","33333   ","        ","        ","        "])  # bottom-right
art(0xA6, ["   3 3 3","  3 3 3 ","   3 3 3","  3 3 3 ","   3 3 3","  3 3 3 ","   3 3 3","  3 3 3 "])  # unused deco

# big 2x title letters with red drop-shadow, colour 2 face
BIG = "MEDSCHOL"
for i, ch in enumerate(BIG):
    g = FONT[ch]
    canvas = [[0]*16 for _ in range(16)]
    for y in range(7):
        for x in range(5):
            if g[y][x] == '#':
                for dy in range(2):
                    for dx in range(2):
                        yy, xx = 1 + y*2 + dy, 2 + x*2 + dx
                        if yy+1 < 16 and xx+1 < 16 and canvas[yy+1][xx+1] == 0:
                            canvas[yy+1][xx+1] = 1
                        canvas[yy][xx] = 2
    base = 0xC0 + i * 4
    for q, (oy, ox) in enumerate(((0, 0), (0, 8), (8, 0), (8, 8))):
        for y in range(8):
            for x in range(8):
                tiles[base + q][y][x] = canvas[oy + y][ox + x]

def chr_bytes():
    out = bytearray()
    for t in tiles:
        lo = bytes(sum(((t[y][x] & 1) << (7 - x)) for x in range(8)) for y in range(8))
        hi = bytes(sum((((t[y][x] >> 1) & 1) << (7 - x)) for x in range(8)) for y in range(8))
        out += lo + hi
    out += bytes(4096)  # second pattern table unused
    return out

open(f"{OUT}/chr.bin", "wb").write(chr_bytes())

# ---------------------------------------------------------------- nametables
class NT:
    def __init__(self):
        self.t = [0x20] * 960
        self.pal = [[1] * 32 for _ in range(30)]
    def text(self, x, y, s):
        for i, ch in enumerate(s):
            self.t[y*32 + x + i] = ord(ch)
    def tile(self, x, y, v, pal=None):
        self.t[y*32 + x] = v
        if pal is not None:
            self.pal[y][x] = pal
    def region(self, x0, y0, x1, y1, pal):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.pal[y][x] = pal
    def big(self, x, y, s):
        for i, ch in enumerate(s):
            if ch == ' ':
                continue
            b = 0xC0 + BIG.index(ch) * 4
            self.tile(x + 2*i, y, b, 0); self.tile(x + 2*i + 1, y, b + 1, 0)
            self.tile(x + 2*i, y + 1, b + 2, 0); self.tile(x + 2*i + 1, y + 1, b + 3, 0)
    def bytes(self):
        attr = bytearray(64)
        for by in range(15):
            for bx in range(16):
                p = self.pal[by*2][bx*2] & 3
                a = (by // 2) * 8 + (bx // 2)
                shift = ((by & 1) << 2) | ((bx & 1) << 1)
                attr[a] |= p << shift
        return bytes(self.t) + bytes(attr)

def bottle(nt, x0, y0):
    # x0,y0 = top-left playfield cell (8 wide, 16 tall)
    nt.tile(x0 - 1, y0 - 1, 0xA2); nt.tile(x0 + 8, y0 - 1, 0xA3)
    for c in range(8):
        nt.tile(x0 + c, y0 - 1, 0xA1 if c not in (3, 4) else 0x20)
    nt.tile(x0 + 2, y0 - 1, 0xA5); nt.tile(x0 + 5, y0 - 1, 0xA4)
    nt.tile(x0 + 2, y0 - 2, 0xA0); nt.tile(x0 + 5, y0 - 2, 0xA0)
    for r in range(16):
        nt.tile(x0 - 1, y0 + r, 0xA0); nt.tile(x0 + 8, y0 + r, 0xA0)
        for c in range(8):
            nt.tile(x0 + c, y0 + r, 0x80)
    nt.tile(x0 - 1, y0 + 16, 0xA4); nt.tile(x0 + 8, y0 + 16, 0xA5)
    for c in range(8):
        nt.tile(x0 + c, y0 + 16, 0xA1)

title = NT()
title.big(6, 7, "MED SCHOOL")
for i, x in enumerate(range(8, 24, 2)):
    title.tile(x, 13, 0x80 + 5*4 + (i % 3) + 1, 0)
    title.tile(x + 1, 13, 0x80 + [1,3,2][i % 3]*4 + ((i+1) % 3) + 1 if False else 0x20, 0)
for i, x in enumerate(range(9, 23, 4)):
    title.tile(x, 15, 0x84 + (i % 3) + 1, 0); title.tile(x + 1, 15, 0x88 + ((i+1) % 3) + 1, 0)
title.region(6, 6, 25, 16, 0)
title.text(10, 19, "PRESS START")
title.text(5, 25, "2026 STRUKTURED LABS")
open(f"{OUT}/nt_title.bin", "wb").write(title.bytes())

menu = NT()
menu.text(11, 3, "MED SCHOOL")
menu.text(10, 5, "PRESCRIPTION")
menu.text(7, 8, "MODE")
menu.text(7, 11, "1P LEVEL")
menu.text(7, 13, "1P SPEED")
menu.text(7, 16, "2P LEVEL")
menu.text(7, 18, "2P SPEED")
menu.text(5, 22, "UP/DOWN    SELECT")
menu.text(5, 24, "LEFT/RIGHT CHANGE")
menu.text(5, 26, "START      BEGIN")
open(f"{OUT}/nt_menu.bin", "wb").write(menu.bytes())

vs = NT()
bottle(vs, 4, 10); bottle(vs, 20, 10)
vs.region(2, 8, 13, 27, 0); vs.region(18, 8, 29, 27, 0)
vs.text(4, 2, "1P"); vs.text(20, 2, "2P")
vs.text(4, 3, "VIRUS"); vs.text(20, 3, "VIRUS")
vs.text(4, 4, "WINS"); vs.text(20, 4, "WINS")
vs.text(14, 9, "NEXT")
vs.text(14, 10, " 1P"); vs.text(14, 16, " 2P")
vs.text(11, 28, "MED SCHOOL")
open(f"{OUT}/nt_vs.bin", "wb").write(vs.bytes())

game = NT()
bottle(game, 12, 10)
game.region(10, 8, 21, 27, 0)
game.text(2, 4, "LEVEL"); game.text(2, 7, "SPEED"); game.text(2, 10, "VIRUS")
game.text(2, 13, "SCORE"); game.text(23, 4, "NEXT")
game.text(23, 26, "MED")
game.text(23, 27, "SCHOOL")
open(f"{OUT}/nt_game.bin", "wb").write(game.bytes())
print("assets ok")
