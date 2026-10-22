#!/bin/bash
# Real controller path check: fceux joypad.set on ports 1 and 2 (no RAM pokes), private Xvfb.
cd "$(dirname "$0")/.."
L=build/medschool.labels
a(){ printf "%d" 0x$(grep -E " \.$1\$" $L | head -${2:-1} | tail -1 | awk '{print $2}'); }
# duplicate scoped names: lower address = P1
P1PX=$(grep -E " \.px$" $L | awk '{print $2}' | sort | head -1); P2PX=$(grep -E " \.px$" $L | awk '{print $2}' | sort | tail -1)
cat > /tmp/ms_pads.lua <<LUA
local MODE=$(a mode) local ROW=$(a menu_row) local GM=$(a game_mode) local P1PX=0x$P1PX local P2PX=0x$P2PX local ST=$(a mstate)
local out=io.open("/tmp/ms_pads.txt","w")
local function adv(n,b1,b2) for i=1,n do joypad.set(1,b1 or {}); joypad.set(2,b2 or {}); emu.frameadvance() end end
local function tap(p,btn) local t={} t[btn]=true if p==1 then adv(2,t,{}) else adv(2,{},t) end adv(6) end
adv(60)
out:write("title mode="..memory.readbyte(MODE).."\n")
tap(2,"start") out:write("P2 START at title -> mode="..memory.readbyte(MODE).."\n")
tap(1,"down") out:write("P1 DOWN in menu -> row="..memory.readbyte(ROW).."\n")
tap(2,"down") out:write("P2 DOWN in menu -> row="..memory.readbyte(ROW).."\n")
tap(1,"up") tap(2,"up")
tap(1,"right") tap(2,"right") out:write("mode setting after P1+P2 RIGHT -> cfg_mode="..memory.readbyte(0x305).."\n")
tap(1,"start") adv(30) out:write("P1 START -> mode="..memory.readbyte(MODE).." game_mode="..memory.readbyte(GM).."\n")
adv(20)
local x1,x2=memory.readbyte(P1PX),memory.readbyte(P2PX)
tap(1,"left") tap(2,"right")
out:write(string.format("in game: P1 px %d->%d (LEFT), P2 px %d->%d (RIGHT)\n",x1,memory.readbyte(P1PX),x2,memory.readbyte(P2PX)))
out:close() emu.exit()
LUA
unset WAYLAND_DISPLAY
timeout 120 xvfb-run -a -s "-screen 0 640x480x24" env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb HOME=/tmp/ms_fceux_home \
  fceux --loadlua /tmp/ms_pads.lua ${1:-build/medschool.nes} >/tmp/ms_fceux_pads.log 2>&1
cat /tmp/ms_pads.txt
