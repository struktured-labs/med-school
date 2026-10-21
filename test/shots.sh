#!/bin/bash
# Headless screenshots: fceux under a PRIVATE Xvfb, Wayland disabled.
set -e
cd "$(dirname "$0")/.."
L=build/medschool.labels
hexof(){ printf "%d" 0x$(grep " \.$1\$" $L | awk '{print $2}'); }
mkdir -p shots
.venv/bin/python test/record.py ${1:-1} ${2:-1} /tmp/ms_shots.lua
sed -i "1i local GFLO=$(hexof gframe) local MODE=$(hexof mode) local STATE=$(hexof state)" /tmp/ms_shots.lua
export SHOTDIR=$PWD/shots
unset WAYLAND_DISPLAY
timeout 300 xvfb-run -a -s "-screen 0 1024x768x24" env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=xcb \
  HOME=/tmp/ms_fceux_home fceux --loadlua /tmp/ms_shots.lua build/medschool.nes >/tmp/ms_fceux.log 2>&1 || true
ls -la shots
