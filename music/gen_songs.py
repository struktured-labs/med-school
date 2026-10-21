#!/usr/bin/env python3
"""Generates med_school.txt and med_school_sfx.txt (FamiStudio text format).
All melodies are original compositions for "Med School"."""
NAMES=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
FL={'Db':'C#','Eb':'D#','Gb':'F#','Ab':'G#','Bb':'A#'}
def midi(n):
    p=n[:-1]; o=int(n[-1]); p=FL.get(p,p); return NAMES.index(p)+12*(o+1)
def name(m): return NAMES[m%12]+str(m//12-1)
def tr(n,s): return name(midi(n)+s)
Q={'maj':[0,4,7],'min':[0,3,7],'7':[0,4,7,10],'m7':[0,3,7,10],'M7':[0,4,7,11],
   'm7b5':[0,3,6,10],'m6':[0,3,7,9],'m9':[0,3,7,10,14]}
STAB={'maj':'StabMaj','min':'StabMin','7':'StabDom7','m7':'StabMin7','M7':'StabMaj7','m7b5':'StabHalfDim','m6':'StabMin','m9':'StabMin7'}
def env(t,vals,loop=None,rel=None,extra=''):
    s=f'\t\tEnvelope Type="{t}" Length="{len(vals)}"'
    if loop is not None: s+=f' Loop="{loop}"'
    if rel is not None: s+=f' Release="{rel}"'
    return s+extra+f' Values="{",".join(map(str,vals))}"'
def inst(n,*envs): return [f'\tInstrument Name="{n}"']+list(envs)
INSTR=[]
INSTR+=inst('LeadStac',env('Volume',[13,11,9,7,5,3,2,1,0]),env('DutyCycle',[2]))
INSTR+=inst('LeadHold',env('Volume',[13,11,10,9,9,8,8,7,7,6,6,5,5,4,4,3]),env('DutyCycle',[2]))
for nm,arp in [('StabMaj',[0,4,7]),('StabMin',[0,3,7]),('StabDom7',[0,4,7,10]),('StabMin7',[0,3,7,10]),('StabMaj7',[0,4,7,11]),('StabHalfDim',[0,3,6,10])]:
    INSTR+=inst(nm,env('Volume',[8,7,5,3,1,0]),env('DutyCycle',[1]),env('Arpeggio',arp,loop=0))
INSTR+=inst('Bass',env('Volume',[15]))
INSTR+=inst('Hat',env('Volume',[5,3,1,0]))
INSTR+=inst('HatOpen',env('Volume',[6,5,4,3,2,1,0]))
INSTR+=inst('Snare',env('Volume',[13,10,8,6,4,3,2,1,0]),env('Arpeggio',[2,0,0],))
INSTR+=inst('Kick',env('Volume',[12,8,4,0]),env('Arpeggio',[0,-3,-6,-6]))
INSTR+=inst('NightLead',env('Volume',[9,11,10,10,9,9,9,8,8,8,7],loop=10)+'\n'+env('Volume',[0]).replace('Volume','X')[:0],
            env('DutyCycle',[0,0,0,0,1,1,1,1,2,2,2,2,1,1,1,1],loop=4),
            env('Pitch',[0]*12+[0,1,1,1,0,-1,-1,-1],loop=12,extra=' Relative="False"'))
INSTR+=inst('NightArp',env('Volume',[5,4,3,2,1,1,0]),env('DutyCycle',[2]))
INSTR+=inst('Brush',env('Volume',[3,3,2,2,2,1,1,1,0]))
INSTR+=inst('BrushAcc',env('Volume',[5,4,4,3,3,2,2,1,1,0]))
INSTR+=inst('FastArp',env('Volume',[6,4,3,1,0]),env('DutyCycle',[0]))
INSTR+=inst('Fanfare',env('Volume',[14,12,11,10,10,9,9,9,8,8,8,7,7,7,6,6,6,5,5,4,4,3,3,2,2,1]),env('DutyCycle',[2]))
INSTR+=inst('Harm',env('Volume',[9,8,7,7,6,6,5,5,4,4,3,3,2,2,1]),env('DutyCycle',[1]))
# fix NightLead (strip helper)
INSTR=[l for l in INSTR if l.strip()]
INSTR=[l.split('\n')[0] for l in INSTR]
HATN,HATON,SNN,KICKN,BRN='C#5','C5','F#3','A#2','D5'  # noise "notes" (pitch index = note&15)

def parse(bar):
    toks=bar.split(); assert len(toks)==16,(bar,len(toks))
    out=[];cur=None
    for i,t in enumerate(toks):
        if t=='-': cur[2]+=1
        else:
            if cur: out.append(cur); cur=None
            if t!='.': cur=[i,t,1]
    if cur: out.append(cur)
    return out
class Song:
    def __init__(s,name,nl,groove=None,loop=0):
        s.name=name;s.nl=nl;s.groove=groove;s.loop=loop;s.ch={c:[] for c in ['Square1','Square2','Triangle','Noise','DPCM']}
    def bar(s,c,notes):  # notes: (row,val,durRows,instr[,vol])
        s.ch[c].append(notes)
    def t(s,r):
        base=int(round(r*s.nl))
        if not s.groove: return base
        sw={'7-7-5-5':(0,2,3,1),'6-6-4-4':(0,1,2,1)}[s.groove]
        return base+sw[int(r)%4]
    def nbars(s): return max(len(v) for v in s.ch.values())
    def text(s,pre):
        n=s.nbars(); g=f' Groove="{s.nl}" GroovePaddingMode="Middle"'
        L=[f'\tSong Name="{s.name}" Length="{n}" LoopPoint="{s.loop}" PatternLength="16" BeatLength="4" NoteLength="{s.nl}"{g}']
        for c,bars in s.ch.items():
            L.append(f'\t\tChannel Type="{c}"')
            pats={}
            for i,b in enumerate(bars):
                if not b: continue
                key=repr(b)
                if key not in pats:
                    pn=f'{pre}{c[0]}{c[-1]}{len(pats):02d}'; pats[key]=pn
                    L.append(f'\t\t\tPattern Name="{pn}"')
                    for nt in b:
                        r,v,d,ins=nt[:4]
                        dd=max(1,int(round(d*s.nl)))
                        extra=f' Volume="{nt[4]}"' if len(nt)>4 else ''
                        L.append(f'\t\t\t\tNote Time="{s.t(r)}" Value="{v}" Duration="{dd}" Instrument="{ins}"{extra}')
            for i,b in enumerate(bars):
                if b: L.append(f'\t\t\tPatternInstance Time="{i}" Pattern="{pats[repr(b)]}"')
        return L
def lead(bars,ins,sh=0,hold_ins=None):
    res=[]
    for b in bars:
        res.append([(r,tr(v,sh),d,(hold_ins if (hold_ins and d>=2) else ins)) for r,v,d in parse(b)])
    return res
def chord(sym):
    r,q=sym.split(':'); return r,q
# ---------------- ROUNDS ----------------
R_MEL=[
"C5 . F5 . A5 . F5 . G5 - A5 . . . . .",
". . D6 . C6 . A5 . . . F5 . D5 . . .",
"A#4 . D5 . F5 . D5 . E5 - F5 . . . . .",
". . C6 . A#5 . G5 . E5 . C5 . . . . .",
"C5 . F5 . A5 . F5 . G5 - A5 . . . . .",
". . E6 . C#6 . A5 . . . G5 . E5 . . .",
"D5 . F5 . A5 . D6 . C6 - A5 . F5 . . .",
"G5 . . E5 . . C5 . D5 - E5 . . . . .",
"D5 . F5 . A#5 . F5 . C6 - D6 . . . . .",
". . C#6 . C6 . A#5 . . . F5 . C#5 . . .",
"C5 . F5 . A5 . C6 . F6 - . . E6 . D6 .",
"C6 . A5 . F#5 . D5 . . . F#5 . A5 . C6 .",
"A#5 - - . A5 . G5 . F5 . . D5 . . F5 .",
"E5 - - . G5 . A#5 . C6 . . . A#5 . G5 .",
"A5 . . . F5 . . . C5 . F5 . A5 . C6 .",
"A#5 . G5 . E5 . C5 . D5 . E5 . G5 . . .",
# bridge (D minor)
"D5 - - - . . F5 . E5 - D5 . C5 . A4 .",
"A#4 - - - . . D5 . C5 - A#4 . A4 . G4 .",
"A4 - C#5 . E5 - G5 . . . F5 . E5 . C#5 .",
"D5 - - - - - . . A5 . . . D6 . . .",
"D6 - C6 . A#5 - A5 . A#5 . F5 . D5 . F5 .",
"G5 - F5 . E5 - D5 . E5 . A#4 . G4 . A#4 .",
"C5 . E5 . G5 . A#5 . C6 . A#5 . G5 . E5 .",
"G5 . . . . . . . C5 . D5 . E5 . G5 .",
]
R_CH=['F:maj','D:min','G:m7','C:7','F:maj','A:7','D:min','C:7','A#:maj','A#:min','F:maj','D:7','G:m7','C:7','F:maj','C:7',
      'D:min','G:min','A:7','D:min','A#:maj','G:m6','C:7','C:7']
def root_midi(r,lo=40):  # bass root in E2..D#3 range
    m=NAMES.index(r)+12*3
    while m<lo: m+=12
    while m>=lo+12: m-=12
    return m
def walk(chs,sh=0,dur=3):
    bars=[]
    for i,c in enumerate(chs):
        r,q=chord(c); nr,_=chord(chs[(i+1)%len(chs)])
        m=root_midi(r)+sh; iv=Q[q]; nxt=root_midi(nr)+sh
        approach = nxt-1 if (nxt-1)!=m+iv[2] else nxt+1
        seq=[m,m+iv[1],m+iv[2],approach] if i%2==0 else [m,m+iv[2],m+12,approach]
        bars.append([(k*4,name(x),dur,'Bass') for k,x in enumerate(seq)])
    return bars
def stabs(chs,sh=0):
    out=[]
    for c in chs:
        r,q=chord(c); m=root_midi(r,52)+sh  # E3..
        out.append([(row,name(m),2,STAB[q]) for row in (2,6,10,14)])
    return out
def drums_rounds(i,fill=False):
    b=[]
    for row in range(0,16,2):
        if row in (4,12): b.append((row,SNN,2,'Snare'))
        elif row in (0,10): b.append((row,KICKN,2,'Kick'))
        else: b.append((row,HATN if row!=14 else HATON,2,'Hat' if row!=14 else 'HatOpen'))
    if fill: b=b[:6]+[(12,SNN,1,'Snare'),(13,SNN,1,'Snare'),(14,SNN,1,'Snare'),(15,SNN,1,'Snare')]
    return b
rounds=Song('Rounds',6,'7-7-5-5')
for b in lead(R_MEL,'LeadStac',hold_ins='LeadHold'): rounds.bar('Square1',b)
for b in stabs(R_CH): rounds.bar('Square2',b)
for b in walk(R_CH): rounds.bar('Triangle',b)
for i in range(24): rounds.bar('Noise',drums_rounds(i,fill=i in (15,23)))
# ---------------- CODE BLUE (Rounds +2 semitones, same 24-bar layout) ----------------
cb=Song('Code Blue',5,'6-6-4-4')
for b in lead(R_MEL,'LeadStac',sh=2,hold_ins='LeadHold'): cb.bar('Square1',b)
for c in R_CH:
    r,q=chord(c); m=root_midi(r,57)+2; iv=Q[q]
    pat=(iv+[12])[:4] if len(iv)>=4 else iv+[12]
    seq=[pat[k%len(pat)] for k in range(16)] if True else None
    cb.bar('Square2',[(k,name(m+seq[k]),1,'FastArp') for k in range(16)])
for c in R_CH:
    r,q=chord(c); m=root_midi(r)+2
    cb.bar('Triangle',[(k*2,name(m+(12 if k%2 else 0)),1,'Bass') for k in range(8)])
for i in range(24):
    b=[(k,HATN,1,'Hat') for k in range(16) if k not in (0,4,8,12)]
    b+= [(0,KICKN,1,'Kick'),(8,KICKN,1,'Kick'),(4,SNN,2,'Snare'),(12,SNN,2,'Snare')]
    cb.bar('Noise',sorted(b))
# ---------------- NIGHT SHIFT ----------------
N_CH=['D:m9','G:m7','E:m7b5','A:7','D:m7','A#:M7','E:m7b5','A:7','F:M7','A#:M7','E:m7b5','A:7',
      'D:m7','G:m7','C:7','F:M7','A#:M7','G:m7','E:m7b5','A:7','D:m7','G:m7','A:7','A:7']
N_MEL=[
"A4 - - - - - D5 - E5 - F5 - - - E5 -","D5 - - - - - - - A#4 - C5 - D5 - F5 -","G5 - - - F5 - E5 - D5 - - - A#4 - - -","C#5 - - - - - - - E5 - - - A4 - - -",
"A4 - - - - - D5 - F5 - A5 - - - G5 -","F5 - - - - - D5 - A5 - - - - - - -","G5 - - - A#5 - - - A5 - G5 - E5 - - -","F5 - - - E5 - - - C#5 - - - - - - -",
"C5 - - - F5 - - - A5 - - - G5 - E5 -","F5 - - - D5 - - - - - - - C5 - D5 -","E5 - - - G5 - A#5 - D6 - - - C6 - A#5 -","A5 - - - - - - - G5 - F5 - E5 - - -",
"F5 - - - E5 - D5 - - - - - A4 - - -","A#4 - - - D5 - F5 - A5 - - - G5 - - -","E5 - - - G5 - - - A#5 - - - A5 - G5 -","A5 - - - - - - - - - - - . . . .",
"D5 - F5 - A5 - - - C6 - - - A5 - - -","A#5 - - - A5 - G5 - F5 - - - D5 - - -","E5 - G5 - A#5 - - - D6 - C6 - A#5 - G5 -","A5 - - - - - - - C#6 - - - E6 - - -",
"D6 - - - - - - - C6 - A5 - F5 - - -","G5 - - - A#5 - - - A5 - G5 - F5 - - -","E5 - - - G5 - - - F5 - E5 - C#5 - - -","E5 - - - - - - - - - - - . . . .",
]
ns=Song('Night Shift',8)
for b in lead(N_MEL,'NightLead'): ns.bar('Square1',[(r,v,d-0.5 if d>1 else d,i) for r,v,d,i in b])
for i,c in enumerate(N_CH):
    r,q=chord(c); m=root_midi(r,50); iv=Q[q]
    order=[0,1,2,3,2,1,2,3] if len(iv)>=4 else [0,1,2,1]
    if i%2: order=[3,2,1,0,1,2,3,2] if len(iv)>=4 else order
    ivs=(iv*2)
    ns.bar('Square2',[(k*2,name(m+ivs[order[k%len(order)]]+(12 if k>=4 and i%4==3 else 0)),2,'NightArp') for k in range(8)])
for i,c in enumerate(N_CH):
    r,q=chord(c); m=root_midi(r,38); iv=Q[q]
    if i%4==3: ns.bar('Triangle',[(0,name(m),6,'Bass'),(6,name(m+iv[2]),2,'Bass'),(8,name(m+12),6,'Bass'),(14,name(m+iv[2]),2,'Bass')])
    else: ns.bar('Triangle',[(0,name(m),7,'Bass'),(8,name(m+iv[2]),5,'Bass'),(14,name(m+iv[1]),2,'Bass')])
for i in range(24):
    b=[(k,BRN,1,'BrushAcc' if k in (4,12) else 'Brush') for k in range(0,16,2)]+[(k,BRN,1,'Brush') for k in (7,15)]
    ns.bar('Noise',sorted(b))
# ---------------- JINGLES ----------------
title=Song('Title Fanfare',6,'7-7-5-5',loop=4)
tm=R_MEL[:3]+["F6 - - - - - - - - - - - - - - -"]
for b in lead(tm,'Fanfare'): title.bar('Square1',b)
th=["A4 . C5 . F5 . C5 . E5 - F5 . . . . .",". . A5 . A5 . F5 . . . D5 . A4 . . .","G4 . A#4 . D5 . A#4 . C5 - D5 . . . . .","C6 - - - - - - - - - - - - - - -"]
for b in lead(th,'Harm'): title.bar('Square2',b)
for b in walk(['F:maj','D:min','G:m7','C:7']) [:3]: title.bar('Triangle',b)
title.bar('Triangle',[(0,'F2',12,'Bass')])
for i in range(3): title.bar('Noise',drums_rounds(i,fill=i==2))
title.bar('Noise',[(0,KICKN,2,'Kick'),(0,HATON,8,'HatOpen')])
for c in ['Square1','Square2','Triangle','Noise']: title.bar(c,[])
clear=Song('Stage Clear',5,loop=2)
clear.bar('Square1',[(k,v,1 if k<12 else 16-k,'Fanfare') for k,v in zip(range(0,16,2),['F4','A4','C5','F5','A5','C6','F6','F6'])][:7])
clear.bar('Square1',[(0,'F6',2,'LeadStac'),(4,'G6',2,'LeadStac'),(8,'A6',8,'Fanfare')])
clear.bar('Square2',[(k+1,v,1,'Harm') for k,v in zip(range(0,14,2),['C4','F4','A4','C5','F5','A5','C6'])])
clear.bar('Square2',[(0,'C6',2,'Harm'),(4,'E6',2,'Harm'),(8,'F6',8,'Harm')])
clear.bar('Triangle',[(0,'F2',4,'Bass'),(4,'A2',4,'Bass'),(8,'C3',4,'Bass'),(12,'E3',4,'Bass')])
clear.bar('Triangle',[(0,'F3',2,'Bass'),(4,'C3',2,'Bass'),(8,'F2',8,'Bass')])
clear.bar('Noise',[(k,HATN,1,'Hat') for k in range(0,16,2)]); clear.bar('Noise',[(0,SNN,2,'Snare'),(4,SNN,2,'Snare'),(8,KICKN,2,'Kick'),(8,HATON,8,'HatOpen')][::1][:4])
clear.ch['Noise'][-1]=[(0,SNN,2,'Snare'),(4,SNN,2,'Snare'),(8,HATON,8,'HatOpen')]
for c in ['Square1','Square2','Triangle','Noise']: clear.bar(c,[])
over=Song('Game Over',9,loop=2)
over.bar('Square1',[(0,'A5',3,'LeadHold'),(4,'F5',3,'LeadHold'),(8,'D5',3,'LeadHold'),(12,'A4',3,'LeadHold')])
over.bar('Square1',[(0,'A#4',3,'LeadHold'),(4,'G4',3,'LeadHold'),(8,'E4',2,'LeadHold'),(10,'C#4',2,'LeadHold'),(12,'D4',4,'Fanfare')])
over.bar('Square2',[(0,'F5',3,'Harm'),(4,'D5',3,'Harm'),(8,'A4',3,'Harm'),(12,'F4',3,'Harm')])
over.bar('Square2',[(0,'G4',3,'Harm'),(4,'E4',3,'Harm'),(8,'C#4',2,'Harm'),(10,'A3',2,'Harm'),(12,'F3',4,'Harm')])
over.bar('Triangle',[(0,'D3',7,'Bass'),(8,'A#2',7,'Bass')])
over.bar('Triangle',[(0,'G2',4,'Bass'),(4,'A2',6,'Bass'),(12,'D2',4,'Bass')])
over.bar('Noise',[(0,BRN,1,'BrushAcc'),(8,BRN,1,'BrushAcc')]); over.bar('Noise',[(12,SNN,2,'Snare')])
for c in ['Square1','Square2','Triangle','Noise']: over.bar(c,[])
LS_CH=['A#:maj','F:maj','G:m7','C:7']
ls=Song('Level Select',6,'7-7-5-5')
ls_mel=["F5 . . D5 . . A#4 . C5 . D5 . F5 . . .","A5 . . F5 . . C5 . D5 . C5 . A4 . . .","A#4 . D5 . G5 . F5 . D5 - C5 . A#4 . . .","G4 . A4 . A#4 . C5 . E5 . G5 . A#5 . . ."]
for b in lead(ls_mel,'LeadStac'): ls.bar('Square1',b)
for b in stabs(LS_CH): ls.bar('Square2',b)
for b in walk(LS_CH): ls.bar('Triangle',b)
for i in range(4): ls.bar('Noise',[(r,n,d,ins) for r,n,d,ins in drums_rounds(i) if ins!='Kick' or r==0])
# ---------------- write music project ----------------
SONGS=[rounds,cb,ns,title,clear,over,ls]
def project(name,songs,instr):
    L=[f'Project Version="4.5.3" TempoMode="FamiStudio" Name="{name}" Author="Carmelo Piccione" Copyright="2026 Carmelo Piccione"']+instr
    for k,s in enumerate(songs): L+=s.text(f'S{k}')
    return '\n'.join(L)+'\n'
open('med_school.txt','w').write(project('Med School',SONGS,INSTR))
# ---------------- SFX ----------------
SI=[]
SI+=inst('SfxRotate',env('Volume',[10,8,5,2,0]),env('DutyCycle',[2]),env('Pitch',[0,-8,-16,-24],extra=' Relative="True"'))
SI+=inst('SfxLand',env('Volume',[12,8,5,2,0]),env('Arpeggio',[0,-2,-4]))
SI+=inst('SfxLandT',env('Volume',[15]),env('Pitch',[0,6,12,18],extra=' Relative="True"'))
SI+=inst('SfxClear',env('Volume',[12,11,10,9,8,7,6,5,4,3,2,1,0]),env('DutyCycle',[1]),env('Arpeggio',[0,4,7,12],loop=0))
SI+=inst('SfxVirus',env('Volume',[13,12,11,10,9,8,7,6,5,4,3,2,1,0]),env('DutyCycle',[2,2,1,1,0,0],loop=0),env('Pitch',[-6]*1,loop=0,extra=' Relative="True"'))
SI+=inst('SfxNoise',env('Volume',[8,6,4,2,1,0]))
def sfx(nm,chs):
    s=Song(nm,1)
    for c in ['Square1','Square2','Triangle','Noise']: s.bar(c,chs.get(c,[]))
    return s
SFX=[sfx('Rotate',{'Square1':[(0,'E5',4,'SfxRotate')]}),
     sfx('Land',{'Noise':[(0,'A#2',5,'SfxLand')],'Triangle':[(0,'A2',4,'SfxLandT')]}),
     sfx('Clear',{'Square1':[(0,'C5',4,'SfxClear'),(4,'E5',4,'SfxClear'),(8,'G5',8,'SfxClear')],'Noise':[(0,'D5',6,'SfxNoise')]}),
     sfx('Virus Clear',{'Square1':[(0,'G5',3,'SfxVirus'),(3,'C6',3,'SfxVirus'),(6,'E6',3,'SfxVirus'),(9,'G6',7,'SfxVirus')],'Noise':[(0,'C5',8,'SfxNoise'),(9,'C#5',6,'SfxNoise')]})]
for s in SFX: s.nl=3
open('med_school_sfx.txt','w').write(project('Med School SFX',SFX,SI))
print('ok')
