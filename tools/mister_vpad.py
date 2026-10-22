#!/usr/bin/env python3
"""Virtual clone of the 0810:e501 USB pad via /dev/uinput on the MiSTer (same VID/PID, so
MiSTer applies the same NES_input_0810_e501_v3.map). Usage: mister_vpad.py "<step> ..."
steps: k<code>:<ms> hold key code (hex) ms; a<axis>=<val>:<ms>; s = screenshot; w<ms> wait"""
import os, sys, time, struct, fcntl
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT, UI_DEV_CREATE, UI_DEV_DESTROY = 0x40045564, 0x40045565, 0x40045567, 0x5501, 0x5502
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
for ev in (EV_KEY, EV_ABS): fcntl.ioctl(fd, UI_SET_EVBIT, ev)
for k in range(0x120, 0x12A): fcntl.ioctl(fd, UI_SET_KEYBIT, k)
for a in (0, 1): fcntl.ioctl(fd, UI_SET_ABSBIT, a)
absmax = [0] * 64; absmin = [0] * 64; absmax[0] = absmax[1] = 255
dev = struct.pack("80sHHHHI", b"usb gamepad           ", 3, 0x0810, 0xE501, 0x0110, 0)
dev += struct.pack("64i", *absmax) + struct.pack("64i", *absmin) + struct.pack("64i", *([0] * 64)) + struct.pack("64i", *([0] * 64))
os.write(fd, dev); fcntl.ioctl(fd, UI_DEV_CREATE)
def ev(t, c, v):
    os.write(fd, struct.pack("llHHi", 0, 0, t, c, v)); os.write(fd, struct.pack("llHHi", 0, 0, EV_SYN, 0, 0))
time.sleep(2.5)
ev(EV_ABS, 0, 127); ev(EV_ABS, 1, 127)
for st in sys.argv[1].split():
    if st == "s":
        open("/dev/MiSTer_cmd", "w").write("screenshot\n"); time.sleep(1.2)
    elif st[0] == "w":
        time.sleep(int(st[1:]) / 1000)
    elif st[0] == "k":
        c, ms = st[1:].split(":"); ev(EV_KEY, int(c, 16), 1); time.sleep(int(ms) / 1000)
        if ms != "0": pass
    elif st[0] == "u":
        ev(EV_KEY, int(st[1:], 16), 0)
    elif st[0] == "a":
        ax, rest = st[1:].split("="); v, ms = rest.split(":"); ev(EV_ABS, int(ax), int(v)); time.sleep(int(ms) / 1000)
time.sleep(0.3); fcntl.ioctl(fd, UI_DEV_DESTROY); os.close(fd)
