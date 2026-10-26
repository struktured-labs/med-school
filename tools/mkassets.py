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

def put_glyph(t, rows, col=1, shadow=2):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '#':
                tiles[t][y][x + 1] = col
    if shadow:                       # 1px drop shadow (colour 2) down-right
        for y in range(6, -1, -1):
            for x in range(6, -1, -1):
                if tiles[t][y][x] == col and tiles[t][y + 1][x + 1] == 0:
                    tiles[t][y + 1][x + 1] = shadow

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
 1: [" 111111 ","1111111 ","11 1111 ","1 11111 ","1111111 ","1111111 ","1111111 "," 111111 "],  # left half: seam column 7, rounded join corners
 2: [" 111111 ","11111111","111 1111","11 11111","11111111","11111111","11111111"," 111111 "],  # right half
 3: [" 111111 ","11111111","11 11111","1 111111","11111111","11111111","11111111","        "],  # top half: seam row 7
 4: [" 111111 ","11111111","111 1111","11 11111","11111111","11111111","11111111"," 111111 "],  # bottom half
 5: ["1  11  1"," 111111 "," 1 11 1 ","11111111"," 11  11 "," 111111 "," 1 11 1 ","1      1"],  # germ
 6: ["1  1  1 "," 1 1 1  ","  1 1 1 ","11  1 11"," 1 1 1  ","  1 1 1 "," 1  1  1","1   1   "],  # pop
}
for shape, rows in SHAPES.items():
    for color in (1, 2, 3):
        t = 0x80 + shape * 4 + color
        art(t, [r.replace('1', str(color)) for r in rows])

# virus wiggle frames 1 and 2 (frame 0 = SHAPES[5]); tiles $60+c / $64+c
VFR = [
 [" 1 11 1 ","1 1111 1"," 1 11 1 ","11111111"," 11  11 "," 111111 ","  1  1  "," 1    1 "],
 ["  1  1  ","1 1111 1","1 1  1 1"," 111111 ","11 11 11"," 111111 "," 1 11 1 ","1      1"],
]
for f, rows in enumerate(VFR):
    for color in (1, 2, 3):
        art(0x60 + f * 4 + color, [r.replace('1', str(color)) for r in rows])
# wallpaper (palette 2, colour 1): sparse medical crosses on a diagonal lattice
art(0x68, ["1       ","        ","  1     ","        ","    1   ","        ","      1 ","        "])   # dotted lattice
art(0x69, ["        ","      1 ","        ","    1   ","        ","  1     ","        ","1       "])
art(0x5E, ["   1    ","  121   ","   1    ","        ","        ","        ","        ","        "])   # lattice node: small cross
# panel frame (colour 3 outer line, colour 2 inner line)
art(0x6A, ["        ","        ","  333333","  322222","  32    ","  32    ","  32    ","  32    "])
art(0x6B, ["        ","        ","33333333","22222222","        ","        ","        ","        "])
art(0x6C, ["        ","        ","333333  ","222223  ","    23  ","    23  ","    23  ","    23  "])
art(0x6D, ["  32    "]*8)
art(0x6E, ["    23  "]*8)
art(0x6F, ["  32    ","  32    ","  32    ","  32    ","  322222","  333333","        ","        "])
art(0x70, ["        ","        ","        ","        ","22222222","33333333","        ","        "])
art(0x71, ["    23  ","    23  ","    23  ","    23  ","222223  ","333333  ","        ","        "])

# --------------------------------------------------------------- avatars (16x16, original)
# 0 = transparent, 1 red, 2 yellow, 3 blue (sprite palette 0).  Tiles $E0 + 4*n: TL TR BL BR.
AVATARS = [
 ("GRADCAP", [   # grad-cap virus mascot
  "      3333      ", "   3333333333   ", "333333333333333 ", "   3333333333 2 ",
  "    11111111  2 ", "   1111111111 22", "  111221122111  ", "  111221122111  ",
  " 11111111111111 ", " 11111111111111 ", "  111122221111  ", "  111112211111  ",
  "   1111111111   ", "  1 11111111 1  ", " 1   1    1   1 ", "                "]),
 ("MONITOR", [   # heart-monitor robot with headphones
  "    11111111    ", "   1        1   ", "  11 333333 11  ", " 111333333331111",
  " 111322333331111", " 113323233331 1 ", "  13333233233   ", "  13333332333   ",
  "   3333333333   ", "    22222222    ", "    2 2222 2    ", "   22 2222 22   ",
  "      2222      ", "     22  22     ", "    222  222    ", "                "]),
 ("CAPSULE", [   # capsule with a stethoscope
  "     111222     ", "    1111222 3   ", "   11111222233  ", "   11331223 3   ",
  "   11331223 3   ", "   11111222 3   ", "   11111222 3   ", "   111112223    ",
  "   11111222     ", "   11311232     ", "   11131322     ", "    1113222     ",
  "     33333      ", "    3     3     ", "    3     33    ", "     33333 33   "]),
 ("BANDAGE", [   # walking bandage (new design)
  "                ", "   2222222222   ", "  222222222222  ", "  22 2 22 2 22  ",
  "  222222222222  ", "  2213222213 2  ", "  221322221322  ", "  222222222222  ",
  "  222211112222  ", "  22 2 22 2 22  ", "  222222222222  ", "   2222222222   ",
  "    22    22    ", "    22    22    ", "   222    222   ", "                "]),
 ("PETRI", [     # petri-dish slime (new design)
  "                ", "      1111      ", "    11111111    ", "   1122112211   ",
  "   1122112211   ", "   1111111111   ", "  111111111111  ", "  111133331111  ",
  " 11111111111111 ", "3333333333333333", "3              3", "3  2   2   2   3",
  " 33333333333333 ", "                ", "                ", "                "]),
]
for n, (name, rows) in enumerate(AVATARS):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), name
    for q, (oy, ox) in enumerate(((0, 0), (0, 8), (8, 0), (8, 8))):
        art(0xE0 + n * 4 + q, [rows[oy + y][ox:ox + 8] for y in range(8)])

# win / lose pose frames per avatar (original art, sprite palette 0)
POSES = [  # (win, lose) per avatar, 16x16, 0/space transparent, 1 red 2 yellow 3 blue
 ("GRADCAP", [
  "     3333    2  ", "  3333333333 2  ", "     3333  22   ", "                ",
  "1   11111111   1", " 1 1111111111 1 ", "  111221122111  ", "  112221122211  ",
  " 11111111111111 ", " 11113333331111 ", "  111133331111  ", "  111111111111  ",
  "   1111111111   ", "    11111111    ", "   11  11  11   ", "                "], [
  "                ", "                ", "      3333      ", "   3333333333   ",
  "  333333333333 2", "   1333333331  2", "  111111111111 2", "  111111111111  ",
  " 11111111111111 ", " 11111222211111 ", " 11112111121111 ", "  111111111111  ",
  "   1111111111   ", "  1 11111111 1  ", " 1   1    1   1 ", "                "]),
 ("MONITOR", [
  "2              2", " 2  11111111  2 ", "  21        12  ", "  1 33333333 1  ",
  " 11331133113311 ", " 11311111111311 ", " 11331111113311 ", "  13331111333 1 ",
  "   3333113333   ", "   3333333333   ", "    22222222    ", "   2222222222   ",
  "     222222     ", "     22  22     ", "    222  222    ", "                "], [
  "                ", "                ", "    11111111    ", "   1        1   ",
  "  11 333333 11  ", " 111323323231111", " 111332333231111", " 113323233231 1 ",
  "  13333333333   ", "  12222222222   ", "   3333333333   ", "    22222222    ",
  "   222 22 222   ", "  22   22   22  ", "      2222      ", "                "]),
 ("CAPSULE", [
  " 2   111222   2 ", "    1111222     ", "2  111112222   2", "   11331223     ",
  "   11331223     ", "   11111222     ", "   11111222     ", " 3 111112223  3 ",
  "  3111112223 3  ", "   31311232 3   ", "    3131322 3   ", "    31113222    ",
  "     3     3    ", "                ", "   2        2   ", "                "], [
  "                ", "                ", "                ", "                ",
  "         222    ", "  111    2222   ", " 11111  223322  ", " 11331   2332 2 ",
  " 11331  222222  ", " 111111  2222   ", "  11111    2    ", "   111  3333    ",
  "    3333     3  ", "   3          3 ", "  33         33 ", " 33333333333333 "]),
 ("BANDAGE", [
  "2              2", " 22          22 ", "  22222222222   ", "  222222222222  ",
  "  22 2 22 2 22  ", "  2232222232 2  ", "  223332233322  ", "  2232222232 2  ",
  "  222222222222  ", "  222111111222  ", "  22 211112 22  ", "  222222222222  ",
  "   2222222222   ", "    22    22    ", "   222    222   ", "                "], [
  "                ", "                ", "                ", "                ",
  "                ", "                ", "    2222222     ", "   222222222    ",
  "   2312221322   ", "   2222112222   ", "    2222222   22", "  2 2 22 2 2222 ",
  " 2222222222222  ", "22  2 22 2 22  2", "2222222222222222", "                "]),
 ("PETRI", [
  "   1   11   1   ", "   11 1111 11   ", "   1111111111   ", "   1122112211   ",
  "   1222112221   ", "   1111111111   ", "  111111111111  ", "  111333333111  ",
  " 11111333311111 ", "3333333333333333", "3              3", "3  2   2   2   3",
  " 33333333333333 ", "                ", "                ", "                "], [
  "                ", "                ", "                ", "                ",
  "                ", "                ", "                ", "      1111      ",
  "    11111111    ", "  111211121111  ", "3111111111111113", "3111111111111113",
  "3  2   2   2   3", " 33333333333333 ", "                ", "                "]),
]
POSE_TILES = [0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18, 0x1C, 0xA8, 0xAC]  # win0, lose0, win1, ...
for n, (name, win, lose) in enumerate(POSES):
    for k, rows in enumerate((win, lose)):
        assert len(rows) == 16 and all(len(r) == 16 for r in rows), name
        base = POSE_TILES[n * 2 + k]
        for q, (oy, ox) in enumerate(((0, 0), (0, 8), (8, 0), (8, 8))):
            art(base + q, [rows[oy + y][ox:ox + 8] for y in range(8)])

# bottle: glass tube (palette 1: 1 white highlight, 2 grey, 3 light-blue rim)
V = "  3112  "
art(0xA0, [V]*8)
art(0xA1, ["        ","        ","33333333","11111111","11111111","22222222","        ","        "])
art(0xA2, ["        ","        ","  333333","  311111","  311111","  312222",V,V])
art(0xA3, ["        ","        ","333333  ","111111  ","111111  ","222222  ",V,V])
art(0xA4, [V,V,"  333333","  311111","  311111","  322222","        ","        "])
art(0xA5, [V,V,"333333  ","111111  ","111111  ","222222  ","        ","        "])

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

def box(nt, x0, y0, x1, y1, pal=1):
    nt.tile(x0, y0, 0x6A, pal); nt.tile(x1, y0, 0x6C, pal)
    nt.tile(x0, y1, 0x6F, pal); nt.tile(x1, y1, 0x71, pal)
    for x in range(x0 + 1, x1):
        nt.tile(x, y0, 0x6B, pal); nt.tile(x, y1, 0x70, pal)
    for y in range(y0 + 1, y1):
        nt.tile(x0, y, 0x6D, pal); nt.tile(x1, y, 0x6E, pal)

def wallpaper(nt):
    """every blank tile in a palette-2 area becomes the lattice wallpaper"""
    for y in range(30):
        for x in range(32):
            if nt.t[y * 32 + x] == 0x20 and nt.pal[(y // 2) * 2][(x // 2) * 2] == 2:
                nt.t[y * 32 + x] = 0x5E if (x % 4 == 0 and y % 4 == 0) else (0x68 if (x + y) % 2 == 0 else 0x69)

def screen():
    nt = NT()
    nt.pal = [[2] * 32 for _ in range(30)]
    return nt

def bottle_regions(nt, x0):
    nt.region(x0 - 2, 8, x0 + 9, 27, 1)          # glass + neck (palette 1)
    nt.region(x0, 10, x0 + 7, 25, 0)             # playfield (palette 0)

title = screen()
title.region(4, 4, 27, 17, 3); box(title, 4, 4, 27, 17, 3)
title.big(6, 7, "MED SCHOOL")
for i, x in enumerate(range(9, 23, 4)):
    title.tile(x, 13, 0x84 + (i % 3) + 1, 0); title.tile(x + 1, 13, 0x88 + ((i+1) % 3) + 1, 0)
for i, x in enumerate(range(7, 25, 3)):
    title.tile(x, 15, 0x94 + (i % 3) + 1, 0)
title.region(6, 6, 25, 15, 0)
title.region(2, 18, 29, 29, 1)
title.text(10, 19, "PRESS START")
title.text(5, 25, "2026 STRUKTURED LABS")
wallpaper(title)
open(f"{OUT}/nt_title.bin", "wb").write(title.bytes())

menu = screen()
menu.region(2, 2, 29, 27, 1); box(menu, 2, 2, 29, 27)
menu.text(11, 3, "MED SCHOOL")
menu.text(10, 5, "PRESCRIPTION")
menu.text(7, 7, "MODE")
menu.text(7, 9, "1P LEVEL")
menu.text(7, 10, "1P SPEED")
menu.text(7, 11, "1P CHAR")
menu.text(7, 14, "2P LEVEL")
menu.text(7, 15, "2P SPEED")
menu.text(7, 16, "2P CHAR")
menu.text(7, 19, "BOARDS")
menu.text(7, 20, "RNG")
menu.text(7, 21, "SEED")
menu.text(7, 22, "MUSIC")
menu.text(7, 23, "CODE")
menu.text(5, 24, "UP/DOWN SELECT  L/R SET")
menu.text(5, 25, "A/B     CODE DIGIT")
menu.text(5, 26, "START   BEGIN")
wallpaper(menu)
open(f"{OUT}/nt_menu.bin", "wb").write(menu.bytes())

vs = screen()
for x0, lab in ((4, "1P"), (20, "2P")):
    vs.region(x0 - 2, 0, x0 + 9, 7, 1); box(vs, x0 - 2, 0, x0 + 9, 6)
    vs.text(x0, 2, lab); vs.text(x0, 3, "VIRUS"); vs.text(x0, 4, "WINS")
    bottle_regions(vs, x0)
    bottle(vs, x0, 10)
vs.region(10, 28, 21, 29, 1)
vs.text(11, 28, "MED SCHOOL")
wallpaper(vs)
open(f"{OUT}/nt_vs.bin", "wb").write(vs.bytes())

game = screen()
game.region(0, 2, 10, 23, 1); box(game, 0, 2, 10, 23)
game.region(22, 2, 29, 9, 1); box(game, 22, 2, 29, 9)
game.region(22, 24, 29, 29, 1); box(game, 22, 24, 29, 29)
bottle_regions(game, 12)
bottle(game, 12, 10)
game.text(2, 4, "LEVEL"); game.text(2, 7, "SPEED"); game.text(2, 10, "VIRUS")
game.text(2, 13, "SCORE"); game.text(23, 4, "NEXT")
game.text(23, 26, "MED")
game.text(23, 27, "SCHOOL")
wallpaper(game)
open(f"{OUT}/nt_game.bin", "wb").write(game.bytes())
print("assets ok")
