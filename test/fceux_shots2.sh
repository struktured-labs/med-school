#!/bin/bash
# fceux (no copro: real open bus), scripted joypad only: level select, pause, demo attract shots.
cd "$(dirname "$0")/.."
L=build/medschool.labels
a(){ printf "%d" 0x$(grep -E " \.$1\$" $L | head -1 | awk '{print $2}'); }
mkdir -p shots
cat > /tmp/ms_s2.lua <<LUA
local MODE=$(a mode) local DEMO=$(a demo) local COP=$(a copro_ok)
local D="$PWD/shots/"
local out=io.open("/tmp/ms_s2.txt","w")
local function adv(n,b1,b2) for i=1,n do joypad.set(1,b1 or {}); joypad.set(2,b2 or {}); emu.frameadvance() end end
local function tap(p,btn) local t={} t[btn]=true if p==1 then adv(2,t,{}) else adv(2,{},t) end adv(6) end
local function shot(n) gui.savescreenshotas(D..n..".png") adv(2) end
adv(60) out:write("copro_ok="..memory.readbyte(COP).."\n")
tap(1,"start") adv(10) shot("10_level_select_default")
tap(1,"right") out:write("mode after RIGHT (no copro) = "..memory.readbyte(0x305).."\n")
for i=1,6 do tap(1,"down") end tap(1,"right")   -- SEED -> FIXED
tap(1,"down") tap(1,"A") tap(1,"right") tap(1,"A") tap(1,"A") tap(1,"right") tap(2,"B")
adv(4) shot("11_level_select_2p_seed")
tap(1,"start") adv(150) tap(2,"start") adv(6) shot("12_pause_2p")
out:write("paused mode="..memory.readbyte(MODE).."\n")
tap(1,"start") adv(30)
emu.poweron() adv(1200) out:write("demo="..memory.readbyte(DEMO).."\n") adv(600) shot("13_attract_demo_no_copro")
out:close() emu.exit()
LUA
unset WAYLAND_DISPLAY
timeout 200 xvfb-run -a -s "-screen 0 640x480x24" env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb HOME=/tmp/ms_fceux_home \
  fceux --loadlua /tmp/ms_s2.lua build/medschool.nes >/tmp/ms_fceux_s2.log 2>&1
cat /tmp/ms_s2.txt; ls shots | grep -E "^1[0-3]_"
