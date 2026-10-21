local OUT = os.getenv("SHOTDIR") or "shots"
local function pad(b)
  return {A=b>=128, B=(b%128)>=64, select=(b%64)>=32, start=(b%32)>=16,
          up=(b%16)>=8, down=(b%8)>=4, left=(b%4)>=2, right=(b%2)>=1}
end
local function adv(n, b) for i=1,n do joypad.set(1, pad(b or 0)); emu.frameadvance() end end
local function shot(name) gui.savescreenshotas(OUT.."/"..name..".png") end
emu.speedmode("maximum")
adv(90) shot("01_title")
adv(2,16) adv(20)
memory.writebyte(0x300,L) memory.writebyte(0x301,S) adv(10) shot("02_level_select")
memory.writebyte(0x302,S0) memory.writebyte(0x303,S1) memory.writebyte(0x304,0xA5)
adv(1,16) adv(1)
local GF = 0
for k,v in pairs(marks) do end
local done = {}
local function rd() return memory.readbyte(GFLO) + 256*memory.readbyte(GFLO+1) end
while memory.readbyte(MODE) ~= 2 do adv(1) end
shot("03_game_start")
for i=1,40000 do
  local g = rd()
  if marks[g] and not done[g] then done[g]=true; shot("04_"..marks[g]) end
  if g > 0 and (memory.readbyte(STATE) >= 5) and not done.endshot then
    adv(40); shot("05_end"); done.endshot=true; break
  end
  joypad.set(1, pad(inp[g+1] or 0))
  emu.frameadvance()
end
emu.exit()
