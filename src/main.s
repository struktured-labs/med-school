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
GRAV_FRAMES  = 4
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
nmi_count: .res 1
nmi_ready: .res 1
layout: .res 1          ; 0 = 1P screen, 1 = versus screen
pad1: .res 1
pad2: .res 1
padprev: .res 1
padprev2: .res 1
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
  lda #5
  sta cfg_level2
  jsr audio_init
  jsr enter_title
main_loop:
  lda nmi_count
@w: cmp nmi_count
  beq @w
  jsr read_pads
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

read_pads:
  lda pad1
  sta padprev
  lda pad2
  sta padprev2
  lda #1
  sta JOY1
  lsr a
  sta JOY1
  ldx #8
@l:
  lda JOY1
  and #3                   ; bit 0 = standard pad, bit 1 = Famicom expansion pad
  cmp #1                   ; C = 1 if either bit set
  rol pad1
  lda JOY2
  and #3
  cmp #1
  rol pad2
  dex
  bne @l
  ; a port that reports opposite directions at once (floating / unplugged line reading
  ; all 1s, or a stuck adapter) is treated as "no controller" so it can't mask the other
  lda pad1
  jsr pad_sane
  sta pad1
  lda pad2
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
  sta title_idle
  sta title_idle+1
  lda #3
  jsr audio_song
  jmp screen_on

title_tick:
  lda #0
  sta hudbuf
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
  lda #1
  sta attract
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
  inc menu_row
  lda menu_row
  cmp #5
  bcc @nu
  lda #0
  sta menu_row
@nu:
  lda padnew
  and #BTN_UP
  beq @nd
  dec menu_row
  bpl @nd
  lda #4
  sta menu_row
@nd:
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
  ; cursors: 5 single-char entries at col 5 of rows 8,11,13,16,18
  ldx #0
  ldy #0
@cur:
  lda #1
  sta hudbuf,x
  lda menu_rows_hi,y
  sta hudbuf+1,x
  lda menu_rows_lo,y
  sta hudbuf+2,x
  lda #' '
  cpy menu_row
  bne @c
  lda #'>'
@c: sta hudbuf+3,x
  inx
  inx
  inx
  inx
  iny
  cpy #5
  bne @cur
  ; mode name (10) at row 8 col 16
  lda #10
  sta hudbuf+20
  lda #$21
  sta hudbuf+21
  lda #$10
  sta hudbuf+22
  lda cfg_mode
  asl a
  sta tmp0
  asl a
  asl a
  adc tmp0
  tay
  ldx #0
@mn:
  lda mode_names,y
  sta hudbuf+23,x
  iny
  inx
  cpx #10
  bne @mn
  ; P1 level (row 11 col 16), P1 speed (row 13), P2 level (16), P2 speed (18)
  lda #2
  sta hudbuf+33
  lda #$21
  sta hudbuf+34
  lda #$70
  sta hudbuf+35
  lda cfg_level
  jsr two_digits
  sta hudbuf+37
  stx hudbuf+36
  lda #3
  sta hudbuf+38
  lda #$21
  sta hudbuf+39
  lda #$B0
  sta hudbuf+40
  lda cfg_speed
  ldx #41
  jsr put_speed
  lda #2
  sta hudbuf+44
  lda #$22
  sta hudbuf+45
  lda #$10
  sta hudbuf+46
  lda cfg_level2
  jsr two_digits
  sta hudbuf+48
  stx hudbuf+47
  lda #3
  sta hudbuf+49
  lda #$22
  sta hudbuf+50
  lda #$50
  sta hudbuf+51
  lda cfg_speed2
  ldx #52
  jsr put_speed
  lda #0
  sta hudbuf+55
  lda #2
  sta nmi_ready
  lda padnew
  and #BTN_START
  beq @r
  lda seed_lock
  cmp #$A5
  beq @keep
  lda nmi_count
  sta seed_s0
  eor #$5A
  adc gframe
  sta seed_s1
@keep:
  lda seed_s0
  sta s0
  lda seed_s1
  sta s1
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
  jmp start_match
@r: rts

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
  lda #0
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
  lda P1::cpu
  beq @h1
  jsr P1::drive
  jmp @t1
@h1:
  lda pad1
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
  beq @fin
  cmp #ST_LOSE
  bne @bf
  lda #5
  jsr audio_song
@fin:
  lda #1
  sta mstate
@bf:
  jmp build_frame

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
  beq @auto
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
  lda #87
  sta tmp1
  lda #120
  jsr next_sprite
  ldy P2::nxt_id
  ldx #24
  lda #135
  sta tmp1
  lda #120
  jsr next_sprite
  jsr hud_vs
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
  lda #$C4
  sta hudbuf+20
  lda #$D4
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
  tya
  beq @calm
  lda #1
  jmp audio_song_bar
@calm:
  lda #0
  jmp audio_song_bar
@r: rts

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

; ------------------------------------------------------------- data
.segment "RODATA"
bit_tab: .byte 1,2,4,8,16,32,64,128
bitrev:
  .repeat 256, I
    .byte ((I&1)<<7)|((I&2)<<5)|((I&4)<<3)|((I&8)<<1)|((I&16)>>1)|((I&32)>>3)|((I&64)>>5)|((I&128)>>7)
  .endrepeat
palette:
.if PASTEL
  .byte $0F,$25,$38,$31, $0F,$30,$10,$21, $0F,$25,$38,$31, $0F,$30,$10,$21
  .byte $0F,$25,$38,$31, $0F,$30,$10,$21, $0F,$25,$38,$31, $0F,$30,$10,$21
.else
  .byte $0F,$16,$28,$12, $0F,$30,$10,$21, $0F,$16,$28,$12, $0F,$30,$10,$21
  .byte $0F,$16,$28,$12, $0F,$30,$10,$21, $0F,$16,$28,$12, $0F,$30,$10,$21
.endif
speed_names: .byte "LOWMED HI"
mode_names:  .byte "1 PLAYER  ", "VS CPU    ", "2 PLAYERS ", "CPU VS CPU"
menu_max:    .byte 3, 20, 2, 20, 2          ; mode, lvl1, spd1, lvl2, spd2
menu_addr:   .byte <cfg_mode, <cfg_level, <cfg_speed, <cfg_level2, <cfg_speed2
menu_rows_hi: .byte >($2000+8*32+5), >($2000+11*32+5), >($2000+13*32+5), >($2000+16*32+5), >($2000+18*32+5)
menu_rows_lo: .byte <($2000+8*32+5), <($2000+11*32+5), <($2000+13*32+5), <($2000+16*32+5), <($2000+18*32+5)
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
