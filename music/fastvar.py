#!/usr/bin/env python3
"""Post-export step: append "danger" variants that reuse an existing song's channel data
but play it 20% faster. Header byte +2 = 1 makes the stock engine's tempo lookup return 2
("NTSC song on PAL"), so every 5th frame runs a double song frame: 96-frame bars become 80.
No extra song data is stored. Usage: python3 fastvar.py export/med_school_music.s"""
import re,sys
FAST=[('Pulse Rx',2),('Vitals Rx',7)]   # (name, source song id) -> ids 8, 9
p=sys.argv[1]; s=open(p).read()
m=re.search(r'music_data_med_school:\n\t\.byte (\d+)\n',s); n=int(m.group(1))
assert n==8,n
s=s[:m.start(1)]+str(n+len(FAST))+s[m.end(1):]
add=''
for k,(nm,src) in enumerate(FAST):
    add+=f'; {n+k:02x} : {nm} (song {src} data, fast)\n'
    add+=''.join(f'\t.word @song{src}ch{c}\n' for c in range(5))
    add+='\t.byte .lobyte(@tempo_env_1_mid), .hibyte(@tempo_env_1_mid), 1, 0\n'
i=s.index('\n.export music_data_med_school')
s=s[:i]+'\n'+add.rstrip('\n')+s[i:]
open(p,'w').write(s)
print('added',len(FAST),'fast variants')
