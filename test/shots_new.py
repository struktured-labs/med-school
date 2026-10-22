import sys; sys.path.insert(0,"test"); sys.path.insert(0,"ref")
from vs import Rom, ROM, LAB, Copro
from PIL import Image
r=Rom(ROM,LAB); r.step(0,30); r.press(0x10); r.step(0,10)
r.w(0x30E,1); r.w(0x30F,4); r.w(0x3A2,1); r.step(0,4)
Image.fromarray(r.frame).save("shots/20_menu_chars_rng.png")
r=Rom(ROM,LAB); r.step(0,30); r.press(0x10); r.step(0,10); r.w(0x30E,2); r.w(0x30F,3)
r.w(0x305,3); r.w(0x306,6); r.w(0x300,6); r.w(0x302,0x12); r.w(0x303,0x34); r.w(0x304,0xA5); r.w(0x3A2,1)
r.w(r.L["copro_ok"],2)
r.step(0x10,1); r.step(0,1); cop=Copro(r,0)
for f in range(1500): r.step(0); cop.poll(None)
Image.fromarray(r.frame).save("shots/21_cvc_single_copro_avatars.png")
r=Rom(ROM,LAB); r.start_game(11,1,0x12,0x34); r.step(0,200); r.press(0x10); r.step(0,5)
Image.fromarray(r.frame).save("shots/22_pause_1p.png")
