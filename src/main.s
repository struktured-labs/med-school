; =====================================================================
;  MED SCHOOL  -  clean-room NES falling-capsule puzzle (Phase 2)
;  100% original code. Behaviour follows the written rule specs listed
;  in CLEANROOM.md; nothing here is derived from any commercial ROM image.
;  NROM-256.  Modes: 1P, 1P vs CPU, 2P, CPU vs CPU (CPU = copro mailbox).
; =====================================================================
.ifndef PASTEL
PASTEL = 0
.endif

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
JOY1      = $4016
JOY2      = $4017

BTN_A = $80
BTN_B = $40
BTN_START = $10
BTN_SELECT = $20
BTN_UP = $08
BTN_DOWN = $04
BTN_LEFT = $02
BTN_RIGHT = $01

ST_SPAWN = 0
ST_FALL  = 1
ST_CHECK = 2
ST_CLEARWAIT = 3
ST_GRAV  = 4
ST_WIN   = 5
ST_LOSE  = 6

CLEAR_FRAMES = 16
GRAV_FRAMES  = 16           ; loose pieces / garbage fall one row per 16 frames (owner's measured settle gravity)
GARB_DELAY   = 24           ; frames from garbage delivery to its first row of fall (owner spec W(h) = 264 - 16h)
BOARD_X  = 12          ; 1P layout
BOARD_XA = 4           ; versus layout, left bottle
BOARD_XB = 20          ; versus layout, right bottle
BOARD_Y  = 10

; harness-visible config block
cfg_level = $0300
cfg_speed = $0301
seed_s0   = $0302
seed_s1   = $0303
seed_lock = $0304
cfg_mode  = $0305
cfg_level2 = $0306
cfg_speed2 = $0307
cfg_boards = $0308       ; 0 SAME (default) 1 RANDOM
cfg_seedm = $0309        ; 0 RANDOM 1 FIXED
cfg_sd    = $030A        ; [4] seed hex digits (s0 hi, s0 lo, s1 hi, s1 lo)
cfg_char1 = $030E        ; avatar per player (0 = grad-cap virus)
cfg_char2 = $030F
cfg_diff1 = $03E0        ; CPU difficulty per player: 0 EASY 1 MEDIUM 2 HARD
cfg_diff2 = $03E1
cfg_music = $03E2        ; in-game music: 0 ROUNDS 1 NIGHT SHIFT 2 OFF (persists until power-off/reset)
cfg_rng   = $03A2        ; 0 CLASSIC (faithful 128-pill loop) 1 FAIR (9-combo bag)
NCHARS    = 5
THROW_F   = 24           ; capsule throw (frames from spawn until it enters play)
MR_DIG    = 13           ; first seed-digit menu cursor index
pills   = $0310
gq_n    = $0390        ; [2]   pending garbage count per receiver
gq_col  = $0392        ; [8]
gq_clr  = $039A        ; [8]
oam     = $0200
board1  = $0400
mask1   = $0480
board2  = $0500
mask2   = $0580
hudbuf  = $06B0
PL_EM   = $0100        ; [16] CPU planner scratch (bottom of the stack page)
PL_LH   = $0110        ; [16]
PL_LV   = $0120        ; [16]
PL_RCH  = $0130        ; [64] reach sets, row*4+o
tile1   = $0700
tile2   = $0780

.segment "HEADER"
  .byte "NES", $1A, 2, 1, $01, $00
  .res 8, 0

.segment "ZEROPAGE"
tmp0: .res 1
tmp1: .res 1
tmp2: .res 1
tmp3: .res 1
tmp4: .res 1
tmp5: .res 1
ptr:  .res 2
ctp:  .res 2           ; cell -> tile table for this frame (germ animation phase)
nmi_count: .res 1
nmi_ready: .res 1
layout: .res 1          ; 0 = 1P screen, 1 = versus screen
pad1: .res 1
pad2: .res 1
padprev: .res 1
padprev2: .res 1
raw1: .res 1
raw2: .res 1
padnew: .res 1          ; rising edges of pad1|pad2
mode: .res 1            ; 0 title 1 menu 2 game
game_mode: .res 1       ; 0 1P 1 VSCPU 2 2P 3 CPUCPU
vs_mode: .res 1
attract: .res 1
mstate: .res 1          ; 0 playing 1 round over 2 match over
mtimer: .res 2
round_no: .res 1
round_winner: .res 1
ticks: .res 1           ; logic frames (harness sync)
gframe: .res 2
s0: .res 1
s1: .res 1
lx: .res 1
ly: .res 1
lo_: .res 1
grav_g: .res 1
menu_row: .res 1
menu_ph: .res 1
any: .res 1
moved: .res 1
count: .res 1
placed: .res 1
vtop: .res 1
vrange: .res 1
attempts: .res 2
max_att: .res 2
thresh: .res 2
vcolor: .res 1
cellidx: .res 1
digits: .res 8
title_idle: .res 2
copro_ok: .res 1
rng_mode: .res 1         ; 0 CLASSIC 1 FAIR (latched from cfg_rng at match start)
boards: .res 1
paused: .res 1
pause_last: .res 1
demo: .res 1
dptr: .res 2
dcnt: .res 1
demo_b1: .res 1
demo_b2: .res 1
pl_sa: .res 4
pl_sb: .res 4
pl_sc: .res 4
pl_y: .res 1
pl_yy: .res 1
pl_k: .res 1
pl_chg: .res 1
pl_want: .res 1
pl_cur: .res 1
pl_row: .res 1
pl_ry: .res 1

.segment "CODE"
; ------------------------------------------------------------- players
.scope P1
  PNUM = 0
  board = board1
  mask = mask1
  tilebuf = tile1
  WIN = $5000
  OAMOFF = 0
  .include "player.inc"
.endscope
.scope P2
  PNUM = 1
  board = board2
  mask = mask2
  tilebuf = tile2
  WIN = $5200
  OAMOFF = 8
  .include "player.inc"
.endscope

.segment "CODE"
reset:
  sei
  cld
  ; MMC1 (mapper-100 copro build): control = $0E (vertical mirroring, PRG mode 3 = 16K
  ; at $8000 + last 16K fixed = the NROM layout, 8K CHR).  Harmless writes on NROM.
  lda #$80
  sta $8000
  lda #$0E
  sta $8000
  lsr a
  sta $8000
  lsr a
  sta $8000
  lsr a
  sta $8000
  lsr a
  sta $8000
  lda #0
  sta $E000
  sta $E000
  sta $E000
  sta $E000
  sta $E000
  sta $A000
  sta $A000
  sta $A000
  sta $A000
  sta $A000
  sei
  cld
  ldx #$40
  stx $4017
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx $4010
  bit PPUSTATUS
@v1: bit PPUSTATUS
  bpl @v1
  lda #0
  tax
@clr:
  sta $00,x
  sta $0100,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clr
  jsr hide_sprites
@v2: bit PPUSTATUS
  bpl @v2
  jsr load_palette
  lda #1
  sta cfg_speed
  sta cfg_speed2
  sta cfg_diff1            ; CPU difficulty MEDIUM
  sta cfg_diff2
  lda #11
  sta cfg_level
  sta cfg_level2
  ; copro present?  An empty $5000 window reads back open bus = the address high byte.
  ; bit0 = P1 window $5000, bit1 = P2 window $5200 (the DRDANGER/winner core has only
  ; the $5200 copro; a player without its own window uses the built-in 6502 CPU)
  ldx #0
  lda $5085
  cmp #$50
  beq @c2
  inx
@c2:
  lda $5285
  cmp #$52
  beq @cp
  inx
  inx
@cp:
  stx copro_ok
  jsr audio_init
  jsr enter_title
main_loop:
  lda nmi_count
@w: cmp nmi_count
  beq @w
  jsr read_pads
  jsr soft_reset_chk
  lda mode
  beq @title
  cmp #1
  beq @menu
  jsr game_tick
  jmp main_loop
@title:
  jsr title_tick
  jmp main_loop
@menu:
  jsr menu_tick
  jmp main_loop

; soft reset: P1 holds Down+Start+Select+A+B (port 1; in 1P / VS CPU either port,
; matching the P1 drive mapping).  Silence the APU, blank the screen, wait for every
; button on both ports to be released (so the held Start can't fall through to the
; title), then restart through the cold-boot path (RAM clear, audio_init, title).
SR_COMBO = BTN_DOWN|BTN_START|BTN_SELECT|BTN_A|BTN_B
soft_reset_chk:
  lda pad1
  ldx game_mode
  cpx #2
  bcs @p
  ora pad2
@p:
  and #SR_COMBO
  cmp #SR_COMBO
  beq soft_reset
  rts
soft_reset:
  sei
  lda #0
  sta PPUCTRL              ; no NMI: the audio engine is not entered again
  sta PPUMASK
  sta $4015                ; all APU channels off
  lda #$30
  sta $4000
  sta $4004
  sta $400C
  lda #$80
  sta $4008
@rel:
  bit PPUSTATUS
@vb: bit PPUSTATUS
  bpl @vb
  ldx #0
  jsr read_stable
  sta tmp3
  ldx #1
  jsr read_stable
  ora tmp3
  bne @rel
  lda #$0F
  sta $4015
  jmp reset

pad_sane:
  pha
  and #(BTN_LEFT|BTN_RIGHT)
  cmp #(BTN_LEFT|BTN_RIGHT)
  beq @bad
  pla
  pha
  and #(BTN_UP|BTN_DOWN)
  cmp #(BTN_UP|BTN_DOWN)
  beq @bad
  pla
  rts
@bad:
  pla
  lda #0
  rts

; one port (X = 0 for $4016, 1 for $4017) -> A; strobe held high a few cycles,
; full 8-bit read of that port alone
read_port:
  lda #1
  sta JOY1
  nop
  nop
  nop
  nop
  lda #0
  sta JOY1
  sta tmp0
  ldy #8
@l:
  lda JOY1,x
  and #3                   ; bit 0 = standard pad, bit 1 = Famicom expansion pad
  cmp #1
  rol tmp0
  dey
  bne @l
  lda tmp0
  rts

; read a port until two consecutive reads agree (DMC-DMA safe), max 4 tries
read_stable:
  jsr read_port
  sta tmp1
  lda #3
  sta tmp2
@r:
  jsr read_port
  cmp tmp1
  beq @ok
  sta tmp1
  dec tmp2
  bne @r
@ok:
  rts

read_pads:
  lda pad1
  sta padprev
  lda pad2
  sta padprev2
  ldx #0
  jsr read_stable
  sta raw1
  jsr pad_sane
  sta pad1
  ldx #1
  jsr read_stable
  sta raw2
  jsr pad_sane
  sta pad2
  ; rising edges per port, then merged (a held button on one pad can't mask the other)
  lda padprev
  eor #$FF
  and pad1
  sta padnew
  lda padprev2
  eor #$FF
  and pad2
  ora padnew
  sta padnew
  rts

screen_off:
  lda #0
  sta PPUCTRL
  sta nmi_ready
  bit PPUSTATUS
@w: bit PPUSTATUS
  bpl @w
  lda #0
  sta PPUMASK
  rts

screen_on:
  bit PPUSTATUS
@w: bit PPUSTATUS
  bpl @w
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  lda #%10000000
  sta PPUCTRL
  lda #%00011110
  sta PPUMASK
  rts

load_palette:
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #0
@l:
  lda palette,x
  sta PPUDATA
  inx
  cpx #32
  bne @l
  rts

draw_nt:
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldy #0
  ldx #4
@l:
  lda (ptr),y
  sta PPUDATA
  iny
  bne @l
  inc ptr+1
  dex
  bne @l
  rts

hide_sprites:
  lda #$FF
  ldx #0
@l: sta oam,x
  inx
  bne @l
  rts

two_digits:
  ldx #'0'
@l: cmp #10
  bcc @d
  sbc #10
  inx
  bne @l
@d: ora #'0'
  rts

; 16-bit LFSR: feedback = bit1(s0) xor bit1(s1); both bytes shift right,
; s0 bit0 -> s1 bit7.  Returns A = s0.
rng_step:
  lda s0
  eor s1
  and #2
  cmp #1
  ror s0
  ror s1
  lda s0
  rts

mod_a:
@l: cmp tmp5
  bcc @d
  sbc tmp5
  jmp @l
@d: rts

gen_pills:
  lda rng_mode
  beq @classic
  jmp gen_fair
@classic:
  lda #0
  sta tmp0
  ldy #127
@l:
  jsr rng_step
  and #$0F
  clc
  adc tmp0
@m9:
  cmp #9
  bcc @ok
  sbc #9
  jmp @m9
@ok:
  sta tmp0
  sta pills,y
  dey
  bpl @l
  rts

; FAIR: 9-combo bag.  Refill = ids 0..8, Fisher-Yates i = 8..1 with j = (rng_step) mod (i+1);
; dealt in bag order into pills[127] down to pills[0] (same fill direction as CLASSIC).
FBAG = $03A3               ; [9]
gen_fair:
  lda #9
  sta tmp0                 ; bag position (9 = empty)
  ldy #127
@l:
  lda tmp0
  cmp #9
  bcc @deal
  ldx #8
@f: txa
  sta FBAG,x
  dex
  bpl @f
  ldx #8
@sh:
  stx tmp1
  inc tmp1                 ; i+1
  jsr rng_step
@mod:
  cmp tmp1
  bcc @md
  sbc tmp1
  jmp @mod
@md:
  sty tmp2
  tay                      ; j
  lda FBAG,x
  pha
  lda FBAG,y
  sta FBAG,x
  pla
  sta FBAG,y
  ldy tmp2
  dex
  bne @sh
  lda #0
  sta tmp0
@deal:
  ldx tmp0
  lda FBAG,x
  sta pills,y
  inc tmp0
  dey
  bpl @l
  rts

; ------------------------------------------------------------- title / attract
enter_title:
  jsr screen_off
  lda #<nt_title
  sta ptr
  lda #>nt_title
  sta ptr+1
  jsr draw_nt
  jsr hide_sprites
  lda #0
  sta mode
  sta attract
  sta demo
  sta paused
  sta title_idle
  sta title_idle+1
  lda #3
  jsr audio_song
  jmp screen_on

title_tick:
  lda #8                   ; live controller bytes (diagnostic): "1P xx 2P yy" row 27
  sta hudbuf
  lda #>($2000+27*32+10)
  sta hudbuf+1
  lda #<($2000+27*32+10)
  sta hudbuf+2
  lda #'1'
  sta hudbuf+3
  lda #'P'
  sta hudbuf+4
  lda raw1
  ldx #5
  jsr hud_hex2
  lda #'2'
  sta hudbuf+7
  lda #'P'
  sta hudbuf+8
  lda raw2
  ldx #9
  jsr hud_hex2
  lda #0
  sta hudbuf+11
  jsr title_parade
  lda #2
  sta nmi_ready
  lda padnew
  and #BTN_START
  beq @idle
  jmp enter_menu
@idle:
  inc title_idle
  bne @r
  inc title_idle+1
  lda title_idle+1
  cmp #4                 ; ~17 s idle -> CPU vs CPU attract
  bcc @r
  lda copro_ok
  bne @live
  jmp start_demo           ; no copro: scripted CPU-vs-CPU demo (recorded inputs)
@live:
  lda #1
  sta attract
  sta boards               ; attract: independent boards
  lda #3
  sta game_mode
  lda nmi_count
  sta s0
  eor #$A7
  sta s1
  lda #4
  sta P1::level
  sta P2::level
  lda #1
  sta P1::speed
  sta P2::speed
  jmp start_match
@r: rts

; recorded demo: both players are "human" and their pads come from demo_data
start_demo:
  lda #1
  sta attract
  sta demo
  lda #DEMO_BOARDS
  sta boards
  lda #2
  sta game_mode
  lda #DEMO_S0
  sta s0
  sta seed_s0
  lda #DEMO_S1
  sta s1
  sta seed_s1
  lda #DEMO_LV
  sta P1::level
  sta P2::level
  lda #DEMO_SP
  sta P1::speed
  sta P2::speed
  lda #<demo_data
  sta dptr
  lda #>demo_data
  sta dptr+1
  lda #0
  sta dcnt
  jmp start_match

; next recorded input pair -> demo_b1/demo_b2; C=1 at the end of the stream
demo_next:
  lda dcnt
  bne @have
  ldy #2
  lda (dptr),y
  bne @load
  sec
  rts
@load:
  sta dcnt
  ldy #0
  lda (dptr),y
  sta demo_b1
  iny
  lda (dptr),y
  sta demo_b2
  lda dptr
  clc
  adc #3
  sta dptr
  bcc @have
  inc dptr+1
@have:
  dec dcnt
  clc
  rts

; ------------------------------------------------------------- menu
enter_menu:
  jsr screen_off
  lda #<nt_menu
  sta ptr
  lda #>nt_menu
  sta ptr+1
  jsr draw_nt
  jsr hide_sprites
  lda #1
  sta mode
  lda #0
  sta menu_row
  lda #6
  jsr audio_song
  jmp screen_on

menu_tick:
  lda padnew
  and #BTN_DOWN
  beq @nu
  lda menu_row
  cmp #MR_DIG
  bcc @d1
  lda #0
  sta menu_row
  jmp @nu
@d1:
  inc menu_row
  jsr menu_skip
  bcc @nu
  inc menu_row
@nu:
  lda padnew
  and #BTN_UP
  beq @nd
  lda menu_row
  beq @u0
  cmp #MR_DIG
  bcc @u1
  lda #MR_DIG-1
  sta menu_row
  jmp @nd
@u0:
  lda #MR_DIG
  sta menu_row
  jmp @nd
@u1:
  dec menu_row
  jsr menu_skip
  bcc @nd
  dec menu_row
@nd:
  lda menu_row
  cmp #MR_DIG
  bcc @val
  ; seed digit row: LEFT/RIGHT pick a digit, A/B change it
  lda padnew
  and #BTN_RIGHT
  beq @dl
  lda menu_row
  cmp #MR_DIG+3
  bcs @dl
  inc menu_row
@dl:
  lda padnew
  and #BTN_LEFT
  beq @da
  lda menu_row
  cmp #MR_DIG+1
  bcc @da
  dec menu_row
@da:
  ldx menu_row
  lda padnew
  and #BTN_A
  beq @db
  lda cfg_sd-MR_DIG,x
  clc
  adc #1
  and #15
  sta cfg_sd-MR_DIG,x
  lda #1
  sta cfg_seedm            ; editing the code implies FIXED
@db:
  lda padnew
  and #BTN_B
  beq @nol
  lda cfg_sd-MR_DIG,x
  sec
  sbc #1
  and #15
  sta cfg_sd-MR_DIG,x
  lda #1
  sta cfg_seedm
  jmp @nol
@val:
  ldx menu_row
  ldy menu_addr,x
  lda padnew
  and #BTN_RIGHT
  beq @nor
  lda $0300,y
  cmp menu_max,x
  bcs @nor
  clc
  adc #1
  sta $0300,y
  jmp @nol
@nor:
  lda padnew
  and #BTN_LEFT
  beq @nol
  lda $0300,y
  beq @nol
  sec
  sbc #1
  sta $0300,y
@nol:
  ; cursor sprite (slot 63)
  ldx menu_row
  lda cur_row_tab,x
  sta oam+252
  lda #'>'
  sta oam+253
  lda #0
  sta oam+254
  lda cur_col_tab,x
  sta oam+255
  ; avatar previews (P1 beside the 1P rows, P2 beside the 2P rows)
  lda cfg_char1
  ldx #9*8-1
  ldy #0
  jsr avatar_at_208
  lda cfg_char2
  ldx #14*8-1
  ldy #16
  jsr avatar_at_208
  ; ---- values -> hudbuf (len, hi, lo, bytes...); a third of the rows per frame
  ldx #0
  inc menu_ph
  lda menu_ph
  cmp #3
  bcc @ph
  lda #0
  sta menu_ph
@ph:
  cmp #1
  bne @p0
  jmp @half_b
@p0:
  bcc @half_a
  jmp @half_c
@half_a:
  lda #10
  ldy #0
  jsr hud_hdr              ; mode name
  lda cfg_mode
  asl a
  sta tmp0
  asl a
  asl a
  adc tmp0
  tay
  lda #10
  sta tmp1
@mn:
  lda mode_names,y
  sta hudbuf,x
  iny
  inx
  dec tmp1
  bne @mn
  lda #2
  ldy #1
  jsr hud_hdr
  lda cfg_level
  jsr hud_2d
  lda #3
  ldy #2
  jsr hud_hdr
  lda cfg_speed
  jsr hud_speed
  lda #6
  ldy #3
  jsr hud_hdr
  lda cfg_char1
  ldy #<(char_names-word6)
  jsr hud_wordn
  jmp @sde
@half_b:
  ldy #4
  lda #0
  jsr hud_cpu
  lda #2
  ldy #5
  jsr hud_hdr
  lda cfg_level2
  jsr hud_2d
  lda #3
  ldy #6
  jsr hud_hdr
  lda cfg_speed2
  jsr hud_speed
  lda #6
  ldy #7
  jsr hud_hdr
  lda cfg_char2
  ldy #<(char_names-word6)
  jsr hud_wordn
  ldy #8
  lda #1
  jsr hud_cpu
  jmp @sde
@half_c:
  lda #6
  ldy #9
  jsr hud_hdr
  lda cfg_boards
  ldy #<(boards_names-word6)
  jsr hud_wordn
  lda #6
  ldy #10
  jsr hud_hdr
  lda cfg_rng
  ldy #<(rng_names-word6)
  jsr hud_wordn
  lda #6
  ldy #11
  jsr hud_hdr
  lda cfg_seedm
  ldy #<(seedm_names-word6)
  jsr hud_wordn
  lda #6
  ldy #12
  jsr hud_hdr
  lda cfg_music
  ldy #<(music_names-word6)
  jsr hud_wordn
  lda #7
  ldy #13
  jsr hud_hdr
  ldy #0
@sdl:
  lda cfg_sd,y
  jsr hexch
  sta hudbuf,x
  inx
  cpy #3
  beq @sde
  lda #' '
  sta hudbuf,x
  inx
  iny
  jmp @sdl
@sde:
  lda #0
  sta hudbuf,x
  lda #2
  sta nmi_ready
  lda padnew
  and #BTN_START
  bne @go
  rts
@go:
  lda seed_lock
  cmp #$A5
  beq @keep                ; harness-supplied seed
  lda cfg_seedm
  bne @fixed
  lda nmi_count
  eor title_idle
  sta seed_s0
  eor #$5A
  adc gframe
  sta seed_s1
  jmp @keep
@fixed:
  lda cfg_sd
  asl a
  asl a
  asl a
  asl a
  ora cfg_sd+1
  sta seed_s0
  lda cfg_sd+2
  asl a
  asl a
  asl a
  asl a
  ora cfg_sd+3
  sta seed_s1
@keep:
  lda seed_s0              ; show the seed in use next time
  lsr a
  lsr a
  lsr a
  lsr a
  sta cfg_sd
  lda seed_s0
  and #15
  sta cfg_sd+1
  lda seed_s1
  lsr a
  lsr a
  lsr a
  lsr a
  sta cfg_sd+2
  lda seed_s1
  and #15
  sta cfg_sd+3
  lda seed_s0
  sta s0
  lda seed_s1
  sta s1
  lda cfg_boards
  sta boards
  lda cfg_rng
  sta rng_mode
  lda cfg_char1
  sta P1::avatar
  lda cfg_char2
  sta P2::avatar
  lda cfg_mode
  sta game_mode
  lda cfg_level
  sta P1::level
  lda cfg_speed
  sta P1::speed
  lda cfg_level2
  sta P2::level
  lda cfg_speed2
  sta P2::speed
  lda #0
  sta attract
  sta demo
  sta paused
  lda #$FF
  sta oam+252
  jmp start_match

; is player A (0/1) CPU-controlled in the selected mode?  Z=0 yes
menu_is_cpu:
  tay
  lda cfg_mode
  cpy #0
  bne @p2
  cmp #3
  beq @y
  lda #0
  rts
@p2:
  and #1
  rts
@y:
  lda #1
  rts
; C=1 if the cursor sits on a CPU row whose player is human (skip it)
menu_skip:
  lda menu_row
  cmp #4
  beq @a
  cmp #8
  beq @b
  clc
  rts
@a:
  lda #0
  beq @t
@b:
  lda #1
@t:
  jsr menu_is_cpu
  bne @no
  sec
  rts
@no:
  clc
  rts
; CPU row: "CPU      STYLE  DIFF  " for CPU players, blanks for humans.  A = player, Y = row
hud_cpu:
  sta tmp3
  lda #22
  jsr hud_hdr
  lda tmp3
  jsr menu_is_cpu
  bne @c
  lda #22
  sta tmp1
@sp:
  lda #' '
  sta hudbuf,x
  inx
  dec tmp1
  bne @sp
  rts
@c:
  ldy #0
@l1:
  lda cpu_lbl,y
  sta hudbuf,x
  inx
  iny
  cpy #9
  bne @l1
  ldy tmp3
  lda cfg_char1,y
  ldy #<(style_names-word6)
  jsr hud_wordn
  lda #' '
  sta hudbuf,x
  inx
  ldy tmp3
  lda cfg_diff1,y
  ldy #<(diff_names-word6)
  jmp hud_wordn

mode_skip_up:              ; RIGHT landed on a CPU mode without a copro
  lda copro_ok
  bne @r
  lda cfg_mode
  cmp #1
  bne @t3
  lda #2
  sta cfg_mode
@t3:
  lda cfg_mode
  cmp #3
  bne @r
  lda #2
  sta cfg_mode
@r: rts
mode_skip_dn:
  lda copro_ok
  bne @r
  lda cfg_mode
  cmp #1
  bne @r
  lda #0
  sta cfg_mode
@r: rts

; hud entry header: A = length, Y = menu value row index; X = hudbuf write offset (advanced)
hud_hdr:
  sta hudbuf,x
  lda val_hi,y
  sta hudbuf+1,x
  lda val_lo,y
  sta hudbuf+2,x
  inx
  inx
  inx
  rts
hud_2d:
  stx tmp2
  jsr two_digits           ; A = ones, X = tens
  ldy tmp2
  sta hudbuf+1,y
  txa
  sta hudbuf,y
  ldx tmp2
  inx
  inx
  rts
hud_speed:
  sta tmp0
  asl a
  adc tmp0
  tay
  lda speed_names,y
  sta hudbuf,x
  lda speed_names+1,y
  sta hudbuf+1,x
  lda speed_names+2,y
  sta hudbuf+2,x
  inx
  inx
  inx
  rts
hud_wordn:                 ; A = word index, Y = table offset from word6
  sta tmp1
  tya
@w:
  dec tmp1
  bmi @z
  clc
  adc #6
  jmp @w
@z:
  tay
  lda #6
  sta tmp1
@l:
  lda word6,y
  sta hudbuf,x
  iny
  inx
  dec tmp1
  bne @l
  rts
hud_hex2:                  ; A -> two hex chars at hudbuf+X
  pha
  lsr a
  lsr a
  lsr a
  lsr a
  jsr hexch
  sta hudbuf,x
  pla
  and #15
  jsr hexch
  sta hudbuf+1,x
  rts
hexch:
  cmp #10
  bcc @d
  adc #'A'-11
  rts
@d:
  adc #'0'
  rts

put_speed:                ; A = speed, X = hudbuf offset
  sta tmp0
  asl a
  adc tmp0
  tay
  lda speed_names,y
  sta hudbuf,x
  lda speed_names+1,y
  sta hudbuf+1,x
  lda speed_names+2,y
  sta hudbuf+2,x
  rts

; ------------------------------------------------------------- match / round
start_match:
  lda #0
  sta P1::wins
  sta P2::wins
  sta round_no
  sta P1::score
  sta P1::score+1
  sta P1::score+2
  lda game_mode
  beq @one
  lda #1
@one:
  sta vs_mode
  sta layout
  lda #0
  sta P1::cpu
  sta P2::cpu
  lda game_mode
  cmp #1
  beq @c2
  cmp #3
  bne @nc
  lda #1
  sta P1::cpu
@c2:
  lda #1
  sta P2::cpu
@nc:
  jsr P1::setup_cpu
  jsr P2::setup_cpu
  ; fall through
start_round:
  jsr screen_off
  lda s0
  ora s1
  bne @seedok
  lda #$89
  sta s0
  lda #$88
  sta s1
@seedok:
  jsr gen_pills
  ; 1P keeps its running score across levels; new_round zeroes it, so save
  lda P1::score
  pha
  lda P1::score+1
  pha
  lda P1::score+2
  pha
  jsr P1::new_round
  pla
  tax
  pla
  tay
  pla
  pha
  lda vs_mode
  bne @noscore            ; versus: scores restart every round
  pla
  sta P1::score
  sty P1::score+1
  stx P1::score+2
  pha
@noscore:
  pla
  lda vs_mode
  beq @clr2
  jsr P2::new_round
  lda boards               ; BOARDS SAME + same level: P2 gets P1's layout
  bne @nop2
  lda P1::level
  cmp P2::level
  bne @nop2
  ldx #127
@cpb:
  lda board1,x
  sta board2,x
  lda mask1,x
  sta mask2,x
  dex
  bpl @cpb
  lda P1::vcount
  sta P2::vcount
  jsr P2::build_tiles
  jmp @nop2
@clr2:
  ldx #0
  txa
@c2l:
  sta board2,x
  inx
  bpl @c2l
@nop2:
  lda #0
  sta gframe
  sta gframe+1
  sta mstate
  sta mtimer
  sta mtimer+1
  inc round_no
  lda #2
  sta mode
  jsr hide_sprites
  lda layout
  bne @vsnt
  lda #<nt_game
  sta ptr
  lda #>nt_game
  sta ptr+1
  jsr draw_nt
  jsr upload_full_1p
  jmp @hud
@vsnt:
  lda #<nt_vs
  sta ptr
  lda #>nt_vs
  sta ptr+1
  jsr draw_nt
  jsr upload_full_vs
@hud:
  jsr build_frame
  ldx cfg_music            ; in-game song (calm variant) per the MUSIC row; OFF = stop
  lda music_calm,x
  jsr audio_song
  jmp screen_on

upload_full_1p:
  jsr upload_1p_top
  jmp upload_1p_bot
upload_full_vs:
  jsr upload_a_top
  jsr upload_a_bot
  jsr upload_b_top
  jmp upload_b_bot

; ------------------------------------------------------------- per frame
game_tick:
  lda mstate
  beq @play
  jmp round_over_tick
@play:
  lda padnew
  and #BTN_START
  beq @np
  lda attract
  beq @tp
  jmp enter_title
@tp:
  lda paused
  eor #1
  sta paused
  bne @np
  jsr hide_sprites
@np:
  lda paused
  beq @run
  jmp pause_frame
@run:
  lda demo
  beq @nodemo
  jsr demo_next
  bcc @nodemo
  jmp enter_title
@nodemo:
  lda P1::cpu
  beq @h1
  jsr P1::drive
  jmp @t1
@h1:
  lda pad1
  ldx game_mode            ; one human (1P, VS CPU): either port drives P1, so a pad
  cpx #2                   ; that the core put on port 2 (e.g. MiSTer SNAC swap) works
  bcs @h1d
  ora pad2
@h1d:
  ldx demo
  beq @h1p
  lda demo_b1
@h1p:
  sta P1::btn
@t1:
  jsr P1::tick
  lda vs_mode
  beq @end1p
  lda P2::cpu
  beq @h2
  jsr P2::drive
  jmp @t2
@h2:
  lda pad2
  ldx demo
  beq @h2p
  lda demo_b2
@h2p:
  sta P2::btn
@t2:
  jsr P2::tick
  inc gframe
  bne @g2
  inc gframe+1
@g2:
  inc ticks
  ; round end?  P1 priority when both resolve on the same frame
  lda P1::state
  cmp #ST_WIN
  beq @p1w
  lda P2::state
  cmp #ST_LOSE
  beq @p1w
  lda P2::state
  cmp #ST_WIN
  beq @p2w
  lda P1::state
  cmp #ST_LOSE
  beq @p2w
  jmp build_frame
@p1w:
  inc P1::wins
  lda #0
  jmp @rend
@p2w:
  inc P2::wins
  lda #1
@rend:
  sta round_winner
  lda #1
  sta mstate
  lda P1::wins
  cmp #2
  bcs @mo
  lda P2::wins
  cmp #2
  bcc @so
@mo:
  lda #2
  sta mstate
@so:
  lda #4
  ldx game_mode
  cpx #1
  bne @sg
  ldx round_winner
  beq @sg
  lda #5                    ; human lost to the CPU
@sg:
  jsr audio_song
  jmp build_frame
@end1p:
  inc gframe
  bne @g1
  inc gframe+1
@g1:
  inc ticks
  lda P1::state
  cmp #ST_WIN
  bne @nw
  lda #4                   ; Stage Clear
  jsr audio_song
  jmp @fin
@nw:
  cmp #ST_LOSE
  bne @bf
  lda #5                   ; Game Over
  jsr audio_song
@fin:
  lda #1
  sta mstate
@bf:
  jmp build_frame

; paused: logic frozen; sprites show PAUSE / SEED / hhhh (bottle rows stay as they are)
pause_frame:
  jsr hide_sprites
  lda #0
  ldx layout
  bne @pv
  lda #76                  ; 1P: text goes in the right panel, clear of the bottle
@pv:
  sta pl_k
  ldx #0
  ldy #0
@l:
  lda pause_txt,y
  beq @dig
  sta oam+1,x
  lda pause_y,y
  sta oam,x
  lda #1
  sta oam+2,x
  lda pause_x,y
  clc
  adc pl_k
  sta oam+3,x
  inx
  inx
  inx
  inx
  iny
  jmp @l
@dig:
  lda seed_s0
  jsr @hx2
  lda seed_s1
  jsr @hx2
  lda #0
  sta hudbuf
  lda #2
  sta nmi_ready
  rts
@hx2:
  pha
  lsr a
  lsr a
  lsr a
  lsr a
  jsr @one
  pla
  and #15
@one:
  jsr hexch
  sta oam+1,x
  lda #119
  sta oam,x
  lda #1
  sta oam+2,x
  txa
  sec
  sbc #36                  ; 9 sprites before the digits; x = 112 + 8*digit
  asl a
  clc
  adc #112
  clc
  adc pl_k
  sta oam+3,x
  inx
  inx
  inx
  inx
  rts

; title flourish: the cast parades along the bottom of the title card, hopping in turn
title_parade:
  lda #0
  sta tmp5
@l:
  lda tmp5
  asl a
  asl a
  asl a
  asl a
  sta tmp4                 ; slot
  lda tmp5                 ; x = frame/2 + 48*i
  asl a
  asl a
  asl a
  asl a
  sta tmp2
  asl a
  adc tmp2
  sta tmp2
  lda nmi_count
  lsr a
  clc
  adc tmp2
  sta tmp2
  lda #0
  sta tmp3
  ldx #183
  lda nmi_count            ; hop when (frame/16) mod 5 == i
  lsr a
  lsr a
  lsr a
  lsr a
@m5:
  cmp #5
  bcc @m
  sbc #5
  jmp @m5
@m:
  cmp tmp5
  bne @nh
  ldx #177
@nh:
  ldy tmp4
  lda tmp5
  jsr avatar_draw
  inc tmp5
  lda tmp5
  cmp #NCHARS
  bne @l
  rts

; 16x16 avatar: A = char, X = top y, tmp2 = left x, Y = 0/16 slot pair (OAM 64+Y..)
avatar_at_208:
  pha
  lda #208
  sta tmp2
  lda #0
  sta tmp3
  pla
avatar_draw:               ; tmp3 = OAM attribute (bit6 = h-flip swaps the columns)
  asl a
  asl a
  ora #$E0
avatar_draw_t:             ; A = first tile of a 2x2 block
  sta tmp1                 ; first tile
  tya
  clc
  adc #64
  tay
  lda #0
  sta tmp0                 ; quadrant
@q:
  txa
  sta oam,y
  lda tmp0
  and #2
  beq @y0
  txa
  clc
  adc #8
  sta oam,y
@y0:
  lda tmp1
  ora tmp0
  sta oam+1,y
  lda tmp3
  sta oam+2,y
  lda tmp3
  asl a
  asl a                    ; C = h-flip
  lda tmp0
  and #1
  bcc @nf
  eor #1
@nf:
  asl a
  asl a
  asl a
  clc
  adc tmp2
  sta oam+3,y
  iny
  iny
  iny
  iny
  inc tmp0
  lda tmp0
  cmp #4
  bne @q
  rts

; waiting for START (or a timeout when no human is playing)
round_over_tick:
  inc mtimer
  bne @t
  inc mtimer+1
@t:
  lda attract
  beq @na
  lda padnew
  and #BTN_START
  bne @tt
  lda demo                 ; demo covers one round: back to the title after it
  beq @auto
  lda mtimer
  cmp #200
  bcc @auto
@tt:
  jmp enter_title
@na:
  lda game_mode
  cmp #3
  beq @auto
  lda padnew
  and #BTN_START
  bne @go
  jmp build_frame
@auto:
  lda mtimer
  cmp #200
  bcs @go
  jmp build_frame
@go:
  lda vs_mode
  bne @vs
  lda P1::state             ; 1P: win -> next level, loss -> menu
  cmp #ST_WIN
  bne @menu
  lda P1::level
  cmp #20
  bcs @same
  inc P1::level
@same:
  lda P1::level
  sta cfg_level
  jmp start_round
@menu:
  jmp enter_menu
@vs:
  lda mstate
  cmp #2
  beq @match
  jmp start_round
@match:
  lda game_mode
  cmp #3
  bne @menu
  jmp start_match           ; CPU vs CPU loops for shows

; ------------------------------------------------------------- display build
build_frame:
  lda nmi_count
  lsr a
  lsr a
  lsr a
  and #3
  tax
  lda ctp_lo,x
  sta ctp
  lda ctp_hi,x
  sta ctp+1
  jsr P1::build_tiles
  lda layout
  bne @vs
  lda #BOARD_X
  sta tmp0
  jsr P1::build_sprites
  ldy P1::nxt_id
  ldx #16
  lda #47
  sta tmp1
  lda #192
  jsr next_sprite
  jsr hud_1p
  lda #208                 ; upper right, beside the next-capsule preview
  sta tmp2
  ldx #39
  ldy #0
  jsr P1::avatar_anim
  jmp @fin
@vs:
  jsr P2::build_tiles
  lda #BOARD_XA
  sta tmp0
  jsr P1::build_sprites
  lda #BOARD_XB
  sta tmp0
  jsr P2::build_sprites
  ldy P1::nxt_id
  ldx #16
  lda #55                  ; right above P1's bottle neck
  sta tmp1
  lda #56
  jsr next_sprite
  ldy P2::nxt_id
  ldx #24
  lda #55
  sta tmp1
  lda #184
  jsr next_sprite
  jsr hud_vs
  lda #80                  ; beside each bottle neck, right of the NEXT preview
  sta tmp2
  ldx #55
  ldy #0
  jsr P1::avatar_anim
  lda #208
  sta tmp2
  ldx #55
  ldy #16
  jsr P2::avatar_anim
@fin:
  jsr music_logic
  lda #3
  sta nmi_ready
  rts

; Y = pill id, X = OAM offset, tmp1 = y, A = x
next_sprite:
  sta oam+3,x
  clc
  adc #8
  sta oam+7,x
  lda tmp1
  sta oam,x
  sta oam+4,x
  lda #0
  sta oam+2,x
  sta oam+6,x
  lda pill_a,y
  ora #$84
  sta oam+1,x
  lda pill_b,y
  ora #$88
  sta oam+5,x
  rts

hud_1p:
  lda #2
  sta hudbuf
  lda #$20
  sta hudbuf+1
  lda #$A3
  sta hudbuf+2
  lda P1::level
  jsr two_digits
  sta hudbuf+4
  stx hudbuf+3
  lda #3
  sta hudbuf+5
  lda #$21
  sta hudbuf+6
  lda #$03
  sta hudbuf+7
  lda P1::speed
  ldx #8
  jsr put_speed
  lda #2
  sta hudbuf+11
  lda #$21
  sta hudbuf+12
  lda #$63
  sta hudbuf+13
  lda P1::vcount
  jsr two_digits
  sta hudbuf+15
  stx hudbuf+14
  lda #8
  sta hudbuf+16
  lda #$21
  sta hudbuf+17
  lda #$C1
  sta hudbuf+18
  jsr score_digits
  ldx #0
@sd: lda digits,x
  sta hudbuf+19,x
  inx
  cpx #8
  bne @sd
  lda #9
  sta hudbuf+27
  sta hudbuf+39
  lda #$22
  sta hudbuf+28
  sta hudbuf+40
  lda #$81
  sta hudbuf+29
  lda #$C1
  sta hudbuf+41
  ldy #0
  lda P1::state
  cmp #ST_WIN
  bne @nw
  ldy #18
@nw:
  cmp #ST_LOSE
  bne @nl
  ldy #36
@nl:
  ldx #0
@m:
  lda messages,y
  sta hudbuf+30,x
  lda messages+9,y
  sta hudbuf+42,x
  iny
  inx
  cpx #9
  bne @m
  lda #0
  sta hudbuf+51
  rts

; versus HUD: virus counts (row 3), wins (row 4), messages (row 6)
hud_vs:
  lda #2
  sta hudbuf
  sta hudbuf+5
  lda #$20
  sta hudbuf+1
  sta hudbuf+6
  lda #$6A
  sta hudbuf+2
  lda #$7A
  sta hudbuf+7
  lda P1::vcount
  jsr two_digits
  sta hudbuf+4
  stx hudbuf+3
  lda P2::vcount
  jsr two_digits
  sta hudbuf+9
  stx hudbuf+8
  lda #1
  sta hudbuf+10
  sta hudbuf+14
  lda #$20
  sta hudbuf+11
  sta hudbuf+15
  lda #$8B
  sta hudbuf+12
  lda #$9B
  sta hudbuf+16
  lda P1::wins
  ora #'0'
  sta hudbuf+13
  lda P2::wins
  ora #'0'
  sta hudbuf+17
  ; messages: 8 chars each at row 6, cols 4 and 20
  lda #8
  sta hudbuf+18
  sta hudbuf+29
  lda #$20
  sta hudbuf+19
  sta hudbuf+30
  lda #$A4
  sta hudbuf+20
  lda #$B4
  sta hudbuf+31
  ldy #0                   ; blank
  lda mstate
  beq @m1
  ldy #8                   ; WIN / LOSE
  lda round_winner
  beq @m1
  ldy #16
@m1:
  lda mstate
  cmp #2
  bne @m1b
  tya
  clc
  adc #16                  ; MATCH WIN / MATCH LOSE variants
  tay
@m1b:
  ldx #0
@ma:
  lda vs_msgs,y
  sta hudbuf+21,x
  iny
  inx
  cpx #8
  bne @ma
  ldy #0
  lda mstate
  beq @m2
  ldy #16
  lda round_winner
  beq @m2
  ldy #8
@m2:
  lda mstate
  cmp #2
  bne @m2b
  tya
  clc
  adc #16
  tay
@m2b:
  ldx #0
@mb:
  lda vs_msgs,y
  sta hudbuf+32,x
  iny
  inx
  cpx #8
  bne @mb
  lda #0
  sta hudbuf+40
  rts

score_digits:
  lda P1::score
  sta tmp0
  lda P1::score+1
  sta tmp1
  lda P1::score+2
  sta tmp2
  ldx #0
@d:
  lda #'0'
  sta digits,x
@s:
  lda tmp0
  sec
  sbc pow10_0,x
  sta tmp3
  lda tmp1
  sbc pow10_1,x
  sta tmp4
  lda tmp2
  sbc pow10_2,x
  bcc @nx
  sta tmp2
  lda tmp4
  sta tmp1
  lda tmp3
  sta tmp0
  inc digits,x
  jmp @s
@nx:
  inx
  cpx #6
  bne @d
  lda #'0'
  sta digits+6
  sta digits+7
  rts

; danger song when anything settled sits in rows 0-3 of columns 2-5 (any bottle)
music_logic:
  lda mstate
  bne @r
  lda P1::state
  cmp #ST_WIN
  bcs @r
  ldx #0
  ldy #0
@l:
  lda board1+2,x
  ora board1+3,x
  ora board1+4,x
  ora board1+5,x
  ora board2+2,x
  ora board2+3,x
  ora board2+4,x
  ora board2+5,x
  beq @e
  iny
@e:
  txa
  clc
  adc #8
  tax
  cpx #32
  bne @l
  lda vs_mode
  bne @v
  lda #0                   ; 1P: board2 is unused but cleared
@v:
  ldx cfg_music
  cpx #2
  bcs @r                   ; music OFF
  tya
  beq @calm
  lda music_danger,x
  jmp audio_song_bar
@calm:
  lda music_calm,x
  jmp audio_song_bar
@r: rts
music_calm:   .byte 0, 2, SONG_STOP   ; ROUNDS, NIGHT SHIFT, OFF
music_danger: .byte 1, 7              ; CODE BLUE, NIGHT SHIFT RX

; ------------------------------------------------------------- NMI
nmi:
  pha
  txa
  pha
  tya
  pha
  lda nmi_ready
  beq nmi_skip
  lda #0
  sta OAMADDR
  lda #>oam
  sta OAMDMA
  lda nmi_ready
  and #1
  beq nmi_hud
  lda layout
  bne @vs
  lda nmi_count
  and #1
  bne @odd
  jsr upload_1p_top
  jmp nmi_hud
@odd:
  jsr upload_1p_bot
  jmp nmi_hud
@vs:
  lda nmi_count
  and #3
  asl a
  tax
  lda vs_up+1,x
  pha
  lda vs_up,x
  pha
  rts                      ; -> upload routine, which returns to nmi_hud via @after
nmi_hud:
  ldx #0
@he:
  ldy hudbuf,x
  beq @hdone
  lda hudbuf+1,x
  sta PPUADDR
  lda hudbuf+2,x
  sta PPUADDR
  inx
  inx
  inx
@hb:
  lda hudbuf,x
  sta PPUDATA
  inx
  dey
  bne @hb
  jmp @he
@hdone:
  lda #0
  sta nmi_ready
nmi_skip:
  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  lda #%10000000
  sta PPUCTRL
  jsr audio_nmi
  inc nmi_count
  pla
  tay
  pla
  tax
  pla
irq:
  rti

vs_up_a_top: jsr upload_a_top
  jmp nmi_hud_entry
vs_up_b_top: jsr upload_b_top
  jmp nmi_hud_entry
vs_up_a_bot: jsr upload_a_bot
  jmp nmi_hud_entry
vs_up_b_bot: jsr upload_b_bot
  jmp nmi_hud_entry
nmi_hud_entry = nmi_hud
vs_up: .word vs_up_a_top-1, vs_up_b_top-1, vs_up_a_bot-1, vs_up_b_bot-1

.macro UPROW buf, bx, r
  .local addr
  addr = $2000 + (BOARD_Y + r)*32 + bx
  lda #>addr
  sta PPUADDR
  lda #<addr
  sta PPUADDR
  .repeat 8, i
    lda buf + r*8 + i
    sta PPUDATA
  .endrepeat
.endmacro
.macro UPHALF buf, bx, first
  .repeat 8, r
    UPROW buf, bx, (r+first)
  .endrepeat
  rts
.endmacro
upload_1p_top: UPHALF tile1, BOARD_X, 0
upload_1p_bot: UPHALF tile1, BOARD_X, 8
upload_a_top:  UPHALF tile1, BOARD_XA, 0
upload_a_bot:  UPHALF tile1, BOARD_XA, 8
upload_b_top:  UPHALF tile2, BOARD_XB, 0
upload_b_bot:  UPHALF tile2, BOARD_XB, 8

; ------------------------------------------------------------- CPU planner (shared)
; A = legal-anchor mask of row X for orientation Y  (preserves X, Y)
mask_of:
  cpx #16
  bcs @z
  tya
  and #1
  bne @v
  lda PL_LH,x
  rts
@v:
  lda PL_LV,x
  rts
@z:
  lda #0
  rts

; in-row closure of pl_sa at row Y under lateral moves and A/B rotation (left kick)
close_fwd:
  lda PL_LH,y              ; fully open row: any seed reaches every state
  cmp #$7F
  bne @loop
  lda PL_LV,y
  cmp #$FF
  bne @loop
  lda pl_sa
  ora pl_sa+1
  ora pl_sa+2
  ora pl_sa+3
  beq @loop
  lda #$7F
  sta pl_sa
  sta pl_sa+2
  lda #$FF
  sta pl_sa+1
  sta pl_sa+3
  rts
@loop:
  ldx #0
@lo:                       ; lateral fill of orientation X within its legal mask
  txa
  and #1
  bne @lv
  lda PL_LH,y
  jmp @lm
@lv:
  lda PL_LV,y
@lm:
  sta tmp3                 ; M
  sty pl_ry
  lda pl_sa,x
  clc
  adc tmp3
  eor tmp3
  and tmp3
  ora pl_sa,x
  sta tmp0                 ; upward fill: ((M+s)^M)&M | s
  ldy pl_sa,x
  lda bitrev,y
  sta tmp1
  ldy tmp3
  lda bitrev,y
  sta tmp4
  clc
  adc tmp1
  eor tmp4
  and tmp4
  ora tmp1
  tay
  lda bitrev,y             ; downward fill, via bit reversal
  ora tmp0
  ldy pl_ry
  sta pl_sa,x
  inx
  cpx #4
  bne @lo
  ; rotations into orientation X from X-1 and X+1
  lda #0
  sta pl_chg
  ldx #0
@o:
  txa
  clc
  adc #3
  and #3
  sta tmp1
  txa
  clc
  adc #1
  and #3
  stx tmp2
  tax
  lda pl_sa,x
  ldx tmp1
  ora pl_sa,x
  ldx tmp2
  sta tmp1                 ; src
  txa
  and #1
  beq @rh
  lda tmp1
  and PL_LV,y
  jmp @acc
@rh:
  lda PL_LH,y
  eor #$FF
  and tmp1
  lsr a
  and PL_LH,y
  sta tmp2
  lda tmp1
  and PL_LH,y
  ora tmp2
@acc:
  ora pl_sa,x
  cmp pl_sa,x
  beq @nc
  sta pl_sa,x
  inc pl_chg
@nc:
  inx
  cpx #4
  bne @o
  lda pl_chg
  beq @done
  jmp @loop
@done:
  rts

; one backward layer at row Y: pl_sa |= predecessors(pl_sa); pl_chg = changed
pred_step:
  ldx #0
@o:
  lda pl_sa,x
  asl a
  sta tmp0
  lda pl_sa,x
  lsr a
  ora tmp0
  sta tmp0                 ; lateral preds (masked below)
  stx tmp2
  ; sources: orientations X-1, X+1 (opposite parity of X)
  txa
  clc
  adc #1
  and #3
  tax
  lda pl_sa,x
  sta tmp1
  ldx tmp2
  txa
  clc
  adc #3
  and #3
  tax
  lda pl_sa,x
  ora tmp1
  sta tmp1                 ; union of target-orientation sets
  ldx tmp2
  txa
  and #1
  bne @xv
  ; X horizontal: rotating into a vertical target keeps x
  lda tmp1
  and PL_LV,y
  ora tmp0
  and PL_LH,y
  jmp @st
@xv:
  ; X vertical: rotating into a horizontal target lands at x (if legal) else x-1
  lda tmp1
  and PL_LH,y
  sta tmp3                 ; t
  asl a
  sta tmp4
  lda PL_LH,y
  eor #$FF
  and tmp4
  ora tmp3
  ora tmp0
  and PL_LV,y
@st:
  ora pl_sa,x
  sta pl_sb,x
  inx
  cpx #4
  bne @o
  lda #0
  sta pl_chg
  ldx #3
@c:
  lda pl_sb,x
  cmp pl_sa,x
  beq @s
  inc pl_chg
  sta pl_sa,x
@s:
  dex
  bpl @c
  rts

.include "audio.inc"
.segment "RODATA"
.include "demo_data.inc"
.segment "CODE"

; ------------------------------------------------------------- data
.segment "RODATA"
bit_tab: .byte 1,2,4,8,16,32,64,128
bitrev:
  .repeat 256, I
    .byte ((I&1)<<7)|((I&2)<<5)|((I&4)<<3)|((I&8)<<1)|((I&16)>>1)|((I&32)>>3)|((I&64)>>5)|((I&128)>>7)
  .endrepeat
palette:
.if PASTEL
  .byte $0F,$25,$38,$31, $0F,$30,$10,$21, $0F,$02,$12,$22, $0F,$30,$27,$38
  .byte $0F,$25,$38,$31, $0F,$30,$10,$21, $0F,$25,$38,$31, $0F,$30,$10,$21
.else
  ; bg: 0 pills/germs, 1 HUD + glass, 2 wallpaper (dark blue), 3 gold title frame
  .byte $0F,$16,$28,$12, $0F,$30,$10,$21, $0F,$01,$11,$21, $0F,$30,$27,$38
  .byte $0F,$16,$28,$12, $0F,$30,$10,$21, $0F,$16,$28,$12, $0F,$30,$10,$21
.endif
speed_names: .byte "LOWMED HI"
mode_names:  .byte "1 PLAYER  ", "VS CPU    ", "2 PLAYERS ", "CPU VS CPU"
menu_max:    .byte 3, 20, 2, NCHARS-1, 2, 20, 2, NCHARS-1, 2, 1, 1, 1, 2
menu_addr:   .byte <cfg_mode, <cfg_level, <cfg_speed, <cfg_char1, <cfg_diff1, <cfg_level2, <cfg_speed2, <cfg_char2, <cfg_diff2, <cfg_boards, <cfg_rng, <cfg_seedm, <cfg_music
MROWS = 0
cur_row_tab: .byte 7*8-1, 9*8-1, 10*8-1, 11*8-1, 12*8-1, 14*8-1, 15*8-1, 16*8-1, 17*8-1, 19*8-1, 20*8-1, 21*8-1, 22*8-1, 23*8-1, 23*8-1, 23*8-1, 23*8-1
cur_col_tab: .byte 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 5*8, 15*8, 17*8, 19*8, 21*8
val_hi: .byte >($2000+7*32+16), >($2000+9*32+16), >($2000+10*32+16), >($2000+11*32+16), >($2000+12*32+7), >($2000+14*32+16), >($2000+15*32+16), >($2000+16*32+16), >($2000+17*32+7), >($2000+19*32+16), >($2000+20*32+16), >($2000+21*32+16), >($2000+22*32+16), >($2000+23*32+16)
val_lo: .byte <($2000+7*32+16), <($2000+9*32+16), <($2000+10*32+16), <($2000+11*32+16), <($2000+12*32+7), <($2000+14*32+16), <($2000+15*32+16), <($2000+16*32+16), <($2000+17*32+7), <($2000+19*32+16), <($2000+20*32+16), <($2000+21*32+16), <($2000+22*32+16), <($2000+23*32+16)
pause_txt: .byte "PAUSESEED", 0
pause_y:   .byte 95,95,95,95,95, 111,111,111,111
pause_x:   .byte 108,116,124,132,140, 112,120,128,136
word6:
boards_names: .byte "SAME  RANDOM"
rng_names:    .byte "CLASSCFAIR  "
char_names:   .byte "GRAD  MONITRPILL  BANDGEPETRI "
seedm_names:  .byte "RANDOMFIXED "
music_names:  .byte "ROUNDSNIGHT OFF   "
style_names:  .byte "METHODDEFENDGREEDYCHAOS AGGRO "
diff_names:   .byte "EASY  MEDIUMHARD  "
pose_tile:    .byte $00, $04, $08, $0C, $10, $14, $18, $1C, $A8, $AC  ; win/lose per avatar
cpu_lbl:      .byte "CPU      "
; CPU personality per avatar: wr wm wg wc tp nz pace react soft tuck mist live alt
pers_tab:
  .byte 2, 6, 4, 24, 4, 0,  2, 6, 1, 1,  4, 0, 0   ; GRAD   METHODICAL
  .byte 3, 5, 3, 24, 6, 0,  0, 2, 1, 1,  4, 0, 0   ; MONITR DEFENSIVE
  .byte 1, 6,10, 28, 3, 1,  0, 0, 1, 1,  8, 1, 0   ; PILL   GREEDY
  .byte 2, 6, 4, 24, 4,15,  1, 4, 2, 1, 10, 0,40   ; BANDGE CHAOTIC
  .byte 0, 8, 2, 12, 2, 1,  0, 0, 1, 1,  6, 1, 0   ; PETRI  AGGRESSIVE
messages:
  .byte "         ", "         "
  .byte "  CLEAR! ", "  START  "
  .byte "GAME OVER", "  START  "
vs_msgs:
  .byte "        ", "  WIN!  ", "  LOSE  ", "        "
  .byte "        ", "CHAMPION", " MATCH  ", "        "
pow10_0: .byte <100000, <10000, <1000, <100, <10, <1
pow10_1: .byte >100000, >10000, >1000, >100, >10, >1
pow10_2: .byte ^100000, ^10000, ^1000, ^100, ^10, ^1
speed_base:  .byte 15, 25, 31
; gravity: counter value that must be exceeded to drop one row, indexed by
; speed_base + speedups (0..80).  Timing parameters taken from the rule spec.
gravity_tab:
  .byte 69,67,65,63,61,59,57,55,53,51,49,47,45,43,41,39,37,35,33,31
  .byte 29,27,25,23,21,19,18,17,16,15,14,13,12,11,10, 9, 9, 8, 8, 7
  .byte  7, 6, 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4
  .byte  3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  .byte  0
pill_a: .byte 1,1,1,2,2,2,3,3,3
pill_b: .byte 1,2,3,1,2,3,1,2,3
link_delta: .byte 0, <-8, 8, <-1, 1, 0, 0, 0
chain_pts: .byte 1, 2, 4, 8, 16, 32
; copro o4 (0 V a-top, 1 V b-top, 2 H a-left, 3 H b-left) -> Med School o
o4_to_o: .byte 3, 1, 0, 2
; garbage column sets (columns 0 and 4 never receive garbage)
gar2: .byte 1,5, 2,6, 3,7
gar3: .byte 1,3,6, 2,5,7
gar4: .byte 1,3,5,7, 2,3,6,7
; cell byte = colour | germ<<2 | link<<4 (link 0 none,1 up,2 down,3 left,4 right)
cell_tile:
  .repeat 80, v
    .if (v & 3) = 0
      .byte $80
    .elseif (v & 4)
      .byte $94 + (v & 3)
    .elseif (v >> 4) = 0
      .byte $80 + (v & 3)
    .elseif (v >> 4) = 1
      .byte $90 + (v & 3)
    .elseif (v >> 4) = 2
      .byte $8C + (v & 3)
    .elseif (v >> 4) = 3
      .byte $88 + (v & 3)
    .else
      .byte $84 + (v & 3)
    .endif
  .endrepeat
cell_tile1:
  .repeat 80, v
    .if (v & 3) = 0
      .byte $80
    .elseif (v & 4)
      .byte $60 + (v & 3)
    .elseif (v >> 4) = 0
      .byte $80 + (v & 3)
    .elseif (v >> 4) = 1
      .byte $90 + (v & 3)
    .elseif (v >> 4) = 2
      .byte $8C + (v & 3)
    .elseif (v >> 4) = 3
      .byte $88 + (v & 3)
    .else
      .byte $84 + (v & 3)
    .endif
  .endrepeat
cell_tile2:
  .repeat 80, v
    .if (v & 3) = 0
      .byte $80
    .elseif (v & 4)
      .byte $64 + (v & 3)
    .elseif (v >> 4) = 0
      .byte $80 + (v & 3)
    .elseif (v >> 4) = 1
      .byte $90 + (v & 3)
    .elseif (v >> 4) = 2
      .byte $8C + (v & 3)
    .elseif (v >> 4) = 3
      .byte $88 + (v & 3)
    .else
      .byte $84 + (v & 3)
    .endif
  .endrepeat
; germ wiggle: phase 0,1,0,2 every 8 frames
ctp_lo: .byte <cell_tile, <cell_tile1, <cell_tile, <cell_tile2
ctp_hi: .byte >cell_tile, >cell_tile1, >cell_tile, >cell_tile2
.include "throw_tab.inc"
copro_enc:
  .repeat 80, v
    .if (v & 3) = 0
      .byte $FF
    .elseif (v & 4)
      .byte $D0 + (v & 3) - 1
    .elseif (v >> 4) = 0
      .byte $80 + (v & 3) - 1
    .elseif (v >> 4) = 1
      .byte $50 + (v & 3) - 1
    .elseif (v >> 4) = 2
      .byte $40 + (v & 3) - 1
    .elseif (v >> 4) = 3
      .byte $70 + (v & 3) - 1
    .else
      .byte $60 + (v & 3) - 1
    .endif
  .endrepeat
nt_title: .incbin "build/nt_title.bin"
nt_menu:  .incbin "build/nt_menu.bin"
nt_game:  .incbin "build/nt_game.bin"
nt_vs:    .incbin "build/nt_vs.bin"

.segment "VECTORS"
  .word nmi, reset, irq
.segment "CHARS"
  .incbin "build/chr.bin"
