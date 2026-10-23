"""Shots for the personality pass: pose sheet, menu (style + difficulty rows), CPU-vs-CPU."""
import sys; sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from emu import Rom
from PIL import Image, ImageDraw
ROM, LAB = "build/medschool.nes", "build/medschool.labels"
NM = ["GRAD", "MONITR", "PILL", "BANDGE", "PETRI"]

def menu(mode, chars, diffs, out):
    r = Rom(ROM, LAB); r.step(0, 30); r.press(0x10); r.step(0, 10)
    r.w(0x305, mode); r.w(0x30E, chars[0]); r.w(0x30F, chars[1]); r.w(0x3E0, diffs[0]); r.w(0x3E1, diffs[1])
    r.press(0x04); r.press(0x04); r.press(0x04); r.press(0x04); r.step(0, 6)
    Image.fromarray(r.frame).save(out)

menu(3, (2, 4), (0, 2), "shots/40_menu_cpu_vs_cpu_style_diff.png")
menu(1, (1, 3), (1, 1), "shots/41_menu_vs_cpu_p2_style_only.png")
menu(2, (0, 4), (1, 1), "shots/42_menu_2p_no_cpu_rows.png")

# pose sheet: in-game render of idle / win (2 phases) / lose per avatar
r = Rom(ROM, LAB); r.start_game(11, 1, 0x12, 0x34, mode=3, level2=11, speed2=1, boards=0, nocopro=True)
r.step(0, 80)
cells = []
for a in range(5):
    row = []
    r.w(r.L["P1::avatar"], a); r.w(r.L["P2::avatar"], a)
    r.w(r.L["mstate"], 0); r.step(0, 3); row.append(Image.fromarray(r.frame).crop((72, 42, 104, 78)))
    for ph in (4, 20):
        r.w(r.L["mstate"], 1); r.w(r.L["round_winner"], 0); r.w(r.L["nmi_count"], ph - 2)
        r.step(0, 2); r.w(r.L["mstate"], 1); r.w(r.L["round_winner"], 0); f = Image.fromarray(r.frame)
        row.append(f.crop((72, 42, 104, 78)))
        if ph == 4: lose = f.crop((200, 42, 232, 78))
    row.append(lose)
    r.w(r.L["mstate"], 0)
    cells.append(row)
S = 4; W, H = 32 * S, 36 * S
sheet = Image.new("RGB", (110 + 4 * (W + 10), 30 + 5 * (H + 10)), (16, 16, 24))
d = ImageDraw.Draw(sheet)
for j, t in enumerate(("IDLE", "WIN (bounce)", "WIN (flip)", "LOSE")):
    d.text((110 + j * (W + 10) + 10, 8), t, fill=(255, 255, 255))
for a, row in enumerate(cells):
    d.text((8, 30 + a * (H + 10) + H // 2), NM[a], fill=(255, 255, 255))
    for j, c in enumerate(row):
        sheet.paste(c.resize((W, H), Image.NEAREST), (110 + j * (W + 10), 30 + a * (H + 10)))
sheet.save("shots/43_pose_sheet.png")

# CPU vs CPU match (built-in CPU, PILL/GREEDY HARD vs PETRI/AGGRESSIVE EASY), mid-game + round end
r = Rom(ROM, LAB); r.start_game(11, 1, 0x56, 0x78, mode=3, level2=11, speed2=1, boards=0, nocopro=True, chars=(2, 4), diff=(2, 0))
r.step(0, 2400); Image.fromarray(r.frame).save("shots/44_cpu_vs_cpu_midgame.png")
for _ in range(40000):
    r.step(0, 1)
    if r.r("mstate"): break
r.step(0, 40); Image.fromarray(r.frame).save("shots/45_cpu_vs_cpu_round_end_poses.png")
print("ok")
