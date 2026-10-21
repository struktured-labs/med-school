; =====================================================================
;  MED SCHOOL  -  clean-room NES falling-capsule puzzle (Phase 1)
;  100% original code. Behaviour follows the written rule specs listed
;  in CLEANROOM.md; nothing here is derived from any commercial ROM image.
;  Build: ca65/ld65, NROM-256 (mapper 0).  Flags: COPRO=0/1, PASTEL=0/1
; =====================================================================
.ifndef COPRO
COPRO = 0
.endif
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
BOARD_X = 12
BOARD_Y = 10
NT_BOARD = $2000 + BOARD_Y*32 + BOARD_X

cfg_level = $0300
cfg_speed = $0301
seed_s0   = $0302
seed_s1   = $0303
seed_lock = $0304
oam     = $0200
board   = $0400
mask    = $0480
tilebuf = $0500
pills   = $0580
hudbuf  = $0700

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
buttons:  .res 1
prev_btn: .res 1
new_btn:  .res 1
mode:     .res 1
state:    .res 1
gframe:   .res 2
px: .res 1
py: .res 1
po: .res 1
pcnt: .res 1
pdas: .res 1
cur_id: .res 1
nxt_id: .res 1
pidx: .res 1
cur_a: .res 1
cur_b: .res 1
s0: .res 1
s1: .res 1
level: .res 1
speed: .res 1
speedups: .res 1
locked: .res 1
vcount: .res 1
chain_v: .res 1
score: .res 3
timer: .res 1
lx: .res 1
ly: .res 1
lo_: .res 1
grav_g: .res 1
menu_row: .res 1
dbg_inp: .res 1
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
copro_col: .res 1
copro_o4: .res 1
sfx_req: .res 1

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
  jsr audio_init
  jsr enter_title
main_loop:
  lda nmi_count
@w: cmp nmi_count
  beq @w
  jsr read_pad
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

read_pad:
  lda buttons
  sta prev_btn
  lda #1
  sta JOY1
  lsr a
  sta JOY1
  ldx #8
@l:
  lda JOY1
  lsr a
  rol buttons
  dex
  bne @l
  lda prev_btn
  eor #$FF
  and buttons
  sta new_btn
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
  lda #3
  jsr audio_song
  jmp screen_on

title_tick:
  lda #0
  sta hudbuf
  lda #2
  sta nmi_ready
  lda new_btn
  and #BTN_START
  beq @r
  jmp enter_menu
@r: rts

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
  lda new_btn
  and #(BTN_UP|BTN_DOWN)
  beq @n0
  lda menu_row
  eor #1
  sta menu_row
@n0:
  lda new_btn
  and #BTN_RIGHT
  beq @nor
  lda menu_row
  bne @spdr
  lda cfg_level
  cmp #20
  bcs @nor
  inc cfg_level
  jmp @nor
@spdr:
  lda cfg_speed
  cmp #2
  bcs @nor
  inc cfg_speed
@nor:
  lda new_btn
  and #BTN_LEFT
  beq @nol
  lda menu_row
  bne @spdl
  lda cfg_level
  beq @nol
  dec cfg_level
  jmp @nol
@spdl:
  lda cfg_speed
  beq @nol
  dec cfg_speed
@nol:
  lda #1
  sta hudbuf
  sta hudbuf+4
  lda #$21
  sta hudbuf+1
  lda #$A7
  sta hudbuf+2
  ldy #' '
  lda menu_row
  bne @c1
  ldy #'>'
@c1:
  sty hudbuf+3
  lda #$22
  sta hudbuf+5
  lda #$07
  sta hudbuf+6
  ldy #' '
  lda menu_row
  beq @c2
  ldy #'>'
@c2:
  sty hudbuf+7
  lda #2
  sta hudbuf+8
  lda #$21
  sta hudbuf+9
  lda #$B1
  sta hudbuf+10
  lda cfg_level
  jsr two_digits
  sta hudbuf+12
  stx hudbuf+11
  lda #3
  sta hudbuf+13
  lda #$22
  sta hudbuf+14
  lda #$11
  sta hudbuf+15
  lda cfg_speed
  asl a
  adc cfg_speed
  tay
  lda speed_names,y
  sta hudbuf+16
  lda speed_names+1,y
  sta hudbuf+17
  lda speed_names+2,y
  sta hudbuf+18
  lda #0
  sta hudbuf+19
  lda #2
  sta nmi_ready
  lda new_btn
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
  lda #0
  sta score
  sta score+1
  sta score+2
  lda cfg_level
  sta level
  lda cfg_speed
  sta speed
  lda seed_s0
  sta s0
  lda seed_s1
  sta s1
  jmp enter_game
@r: rts

two_digits:
  ldx #'0'
@l: cmp #10
  bcc @d
  sbc #10
  inx
  bne @l
@d: ora #'0'
  rts

; 16-bit LFSR step: feedback = bit1(s0) xor bit1(s1); both bytes shift
; right, s0 bit0 -> s1 bit7.  Returns A = s0.
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

runs:
  lda #1
  sta tmp2
  sta tmp3
  ldx lx
@hl: dex
  bmi @hr0
  jsr cell_at_ly_x
  and #3
  cmp vcolor
  bne @hr0
  inc tmp2
  jmp @hl
@hr0:
  ldx lx
@hr: inx
  cpx #8
  bcs @v0
  jsr cell_at_ly_x
  and #3
  cmp vcolor
  bne @v0
  inc tmp2
  jmp @hr
@v0:
  lda ly
  sta tmp4
@vu: dec tmp4
  bmi @vd0
  jsr cell_at_t4_lx
  and #3
  cmp vcolor
  bne @vd0
  inc tmp3
  jmp @vu
@vd0:
  lda ly
  sta tmp4
@vd: inc tmp4
  lda tmp4
  cmp #16
  bcs @done
  jsr cell_at_t4_lx
  and #3
  cmp vcolor
  bne @done
  inc tmp3
  jmp @vd
@done:
  rts

cell_at_ly_x:
  stx tmp1
  lda ly
  asl a
  asl a
  asl a
  ora tmp1
  tay
  lda board,y
  rts
cell_at_t4_lx:
  lda tmp4
  asl a
  asl a
  asl a
  ora lx
  tay
  lda board,y
  rts

place_viruses:
  lda level
  clc
  adc #1
  asl a
  asl a
  cmp #85
  bcc @c
  lda #84
@c: sta count
  clc
  adc #7
  lsr a
  lsr a
  lsr a
  sta tmp0
  lda #16
  sec
  sbc tmp0
  cmp #7
  bcc @vt
  lda #6
@vt: sta vtop
  lda #16
  sec
  sbc vtop
  sta vrange
  lda #0
  sta max_att
  sta max_att+1
  sta thresh
  sta thresh+1
  sta attempts
  sta attempts+1
  sta placed
  ldx count
@mul:
  clc
  lda max_att
  adc #200
  sta max_att
  bcc @m1
  inc max_att+1
@m1: clc
  lda thresh
  adc #140
  sta thresh
  bcc @m2
  inc thresh+1
@m2: dex
  bne @mul
@loop:
  lda placed
  cmp count
  bcs @out
  lda attempts+1
  cmp max_att+1
  bcc @go
  bne @out
  lda attempts
  cmp max_att
  bcs @out
@go:
  inc attempts
  bne @ai
  inc attempts+1
@ai:
  lda vrange
  sta tmp5
  jsr rng_step
  jsr mod_a
  clc
  adc vtop
  sta ly
  jsr rng_step
  and #7
  sta lx
  lda ly
  asl a
  asl a
  asl a
  ora lx
  sta cellidx
  tay
  lda board,y
  bne @loop
  lda #3
  sta tmp5
  jsr rng_step
  jsr mod_a
  clc
  adc #1
  sta vcolor
  jsr runs
  lda tmp2
  cmp #3
  bcs @three
  lda tmp3
  cmp #3
  bcc @not3
@three:
  lda attempts+1
  cmp thresh+1
  bcc @loop
  bne @not3
  lda attempts
  cmp thresh
  bcc @loop
@not3:
  lda tmp2
  cmp #4
  bcs @loop
  lda tmp3
  cmp #4
  bcs @loop
  ldy cellidx
  lda vcolor
  ora #4
  sta board,y
  inc placed
  jmp @loop
@out:
  lda placed
  sta vcount
  rts

enter_game:
  jsr screen_off
  ldx #0
  txa
@cb: sta board,x
  sta mask,x
  inx
  bpl @cb
  lda s0
  ora s1
  bne @seedok
  lda #$89
  sta s0
  lda #$88
  sta s1
@seedok:
  jsr gen_pills
  jsr place_viruses
  lda #<nt_game
  sta ptr
  lda #>nt_game
  sta ptr+1
  jsr draw_nt
  lda #0
  sta gframe
  sta gframe+1
  sta speedups
  sta locked
  sta chain_v
  sta pcnt
  sta pdas
  sta dbg_inp
  sta timer
  lda #ST_SPAWN
  sta state
  lda #1
  sta pidx
  ldx #1
  lda pills,x
  sta cur_id
  inx
  lda pills,x
  sta nxt_id
  lda #2
  sta mode
  jsr hide_sprites
  jsr build_tiles
  lda #<NT_BOARD
  sta ptr
  lda #>NT_BOARD
  sta ptr+1
  ldx #0
@row:
  lda ptr+1
  sta PPUADDR
  lda ptr
  sta PPUADDR
  ldy #8
@col:
  lda tilebuf,x
  sta PPUDATA
  inx
  dey
  bne @col
  lda ptr
  clc
  adc #32
  sta ptr
  bcc @nc
  inc ptr+1
@nc:
  cpx #128
  bne @row
  jsr build_hud
  jsr build_sprites
  lda #0
  jsr audio_song
  jmp screen_on

; carry set if pill (lx,ly,lo_) fits
legal:
  lda lx
  cmp #8
  bcs @no
  lda ly
  cmp #16
  bcs @no
  asl a
  asl a
  asl a
  ora lx
  tay
  lda lo_
  and #1
  bne @vert
  lda lx
  cmp #7
  bcs @no
  lda board,y
  bne @no
  lda board+1,y
  bne @no
  sec
  rts
@vert:
  lda board,y
  bne @no
  lda ly
  beq @yes
  lda board-8,y
  bne @no
@yes:
  sec
  rts
@no:
  clc
  rts

set_l_from_p:
  lda px
  sta lx
  lda py
  sta ly
  lda po
  sta lo_
  rts

game_tick:
  lda buttons
  sta dbg_inp
  lda state
  asl a
  tax
  lda state_tab+1,x
  pha
  lda state_tab,x
  pha
  rts
state_tab:
  .word st_spawn-1, st_fall-1, st_check-1, st_clearwait-1, st_grav-1, st_win-1, st_lose-1

tick_end:
  inc gframe
  bne @g
  inc gframe+1
@g:
  jsr build_tiles
  jsr build_sprites
  jsr build_hud
  jsr music_logic
  lda #3
  sta nmi_ready
  rts

st_spawn:
  lda board+3
  ora board+4
  beq @ok
  lda #ST_LOSE
  sta state
  lda #5
  jsr audio_song
  jmp tick_end
@ok:
  ldx pidx
  lda pills,x
  sta cur_id
  tay
  lda pill_a,y
  sta cur_a
  lda pill_b,y
  sta cur_b
  inx
  txa
  and #127
  sta pidx
  tax
  lda pills,x
  sta nxt_id
  lda #3
  sta px
  lda #0
  sta py
  sta po
  sta pcnt
  sta pdas
.if COPRO
  jsr copro_publish
.endif
  lda #ST_FALL
  sta state
  jmp tick_end

st_fall:
.if COPRO
  jsr copro_poll
.endif
  ldx speed
  lda speed_base,x
  clc
  adc speedups
  cmp #81
  bcc @gi
  lda #80
@gi: tax
  lda gravity_tab,x
  sta grav_g
  ; 1. gravity (soft drop on odd frames when DOWN is the only direction)
  lda gframe
  and #1
  beq @natural
  lda buttons
  and #$0F
  cmp #BTN_DOWN
  bne @natural
  jmp @try_drop
@natural:
  inc pcnt
  lda pcnt
  cmp grav_g
  beq @lateral
  bcc @lateral
@try_drop:
  jsr set_l_from_p
  inc ly
  jsr legal
  bcc @lock
  inc py
  lda #0
  sta pcnt
  jmp @lateral
@lock:
  jsr lock_pill
  lda #1
  jsr audio_sfx
  jmp tick_end
  ; 2. lateral: rising edge moves; hold repeats at 16 then every 6;
  ;    blocked hold retries every frame
@lateral:
  lda buttons
  and #BTN_LEFT
  beq @tryright
  lda #$FF
  sta tmp0
  lda new_btn
  and #BTN_LEFT
  jmp @dir
@tryright:
  lda buttons
  and #BTN_RIGHT
  beq @nodir
  lda #1
  sta tmp0
  lda new_btn
  and #BTN_RIGHT
@dir:
  beq @held
  lda #0
  sta pdas
  jsr shift
  jmp @rotate
@held:
  inc pdas
  lda pdas
  cmp #16
  bcc @rotate
  jsr shift
  bcc @blocked
  lda #10
  sta pdas
  jmp @rotate
@blocked:
  lda #15
  sta pdas
  jmp @rotate
@nodir:
  lda #0
  sta pdas
  ; 3. rotation: A = -1, B = +1; in place, else one left kick for horizontal
@rotate:
  lda new_btn
  and #BTN_A
  beq @rb
  lda po
  sec
  sbc #1
  jmp @rot
@rb:
  lda new_btn
  and #BTN_B
  beq @done
  lda po
  clc
  adc #1
@rot:
  and #3
  sta tmp1
  jsr set_l_from_p
  lda tmp1
  sta lo_
  jsr legal
  bcc @kick
  lda tmp1
  sta po
  jmp @rotsfx
@kick:
  lda tmp1
  and #1
  bne @done
  lda px
  beq @done
  dec lx
  jsr legal
  bcc @done
  dec px
  lda tmp1
  sta po
@rotsfx:
  lda #0
  jsr audio_sfx
@done:
  jmp tick_end

shift:
  jsr set_l_from_p
  lda px
  clc
  adc tmp0
  sta lx
  jsr legal
  bcc @r
  lda lx
  sta px
  sec
@r: rts

lock_pill:
  lda py
  asl a
  asl a
  asl a
  ora px
  tay
  lda po
  beq @h0
  cmp #2
  beq @h2
  cmp #1
  beq @v1
  lda cur_b            ; o=3: top a, bottom b
  ldx cur_a
  jmp @vert
@v1:
  lda cur_a            ; o=1: top b, bottom a
  ldx cur_b
@vert:
  sta tmp0
  stx tmp1
  lda py
  bne @vfull
  lda tmp0
  sta board,y
  jmp @after
@vfull:
  lda tmp0
  ora #$10
  sta board,y
  lda tmp1
  ora #$20
  sta board-8,y
  jmp @after
@h0:
  lda cur_a
  ldx cur_b
  jmp @horiz
@h2:
  lda cur_b
  ldx cur_a
@horiz:
  ora #$40
  sta board,y
  txa
  ora #$30
  sta board+1,y
@after:
  inc locked
  lda locked
  cmp #10
  bne @nos
  lda #0
  sta locked
  lda speedups
  cmp #49
  bcs @nos
  inc speedups
@nos:
  lda #0
  sta chain_v
  lda #ST_CHECK
  sta state
  rts

st_check:
  jsr find_clears
  lda any
  beq @none
  jsr apply_clear
  lda #CLEAR_FRAMES
  sta timer
  lda #ST_CLEARWAIT
  sta state
  jmp tick_end
@none:
  ldx #0
  txa
@cm: sta mask,x
  inx
  bpl @cm
  lda vcount
  bne @spawn
  lda #ST_WIN
  sta state
  lda #4
  jsr audio_song
  jmp tick_end
@spawn:
  lda #ST_SPAWN
  sta state
  jmp tick_end

st_clearwait:
  dec timer
  bne @r
  lda #ST_GRAV
  sta state
@r: jmp tick_end

st_grav:
  inc timer
  lda timer
  cmp #GRAV_FRAMES
  bne @r
  lda #0
  sta timer
  jsr gravity_pass
  lda moved
  bne @r
  lda #ST_CHECK
  sta state
@r: jmp tick_end

find_clears:
  ldx #0
  txa
  sta any
@cm: sta mask,x
  inx
  bpl @cm
  lda #0
  sta tmp0
@row:
  lda #0
  sta tmp1
@rc:
  lda tmp1
  cmp #8
  bcs @rnext
  ora tmp0
  tay
  lda board,y
  and #3
  bne @rrun
  inc tmp1
  jmp @rc
@rrun:
  sta tmp3
  ldx tmp1
@rr2:
  inx
  cpx #8
  bcs @rend
  txa
  ora tmp0
  tay
  lda board,y
  and #3
  cmp tmp3
  beq @rr2
@rend:
  stx tmp2
  txa
  sec
  sbc tmp1
  cmp #4
  bcc @rskip
  ldx tmp1
@rmark:
  txa
  ora tmp0
  tay
  lda tmp3
  sta mask,y
  sta any
  inx
  cpx tmp2
  bne @rmark
@rskip:
  lda tmp2
  sta tmp1
  jmp @rc
@rnext:
  lda tmp0
  clc
  adc #8
  sta tmp0
  cmp #128
  bcc @row
  lda #0
  sta tmp0
@col:
  lda #0
  sta tmp1
@cc:
  lda tmp1
  cmp #16
  bcs @cnext
  asl a
  asl a
  asl a
  ora tmp0
  tay
  lda board,y
  and #3
  bne @crun
  inc tmp1
  jmp @cc
@crun:
  sta tmp3
  ldx tmp1
@cr2:
  inx
  cpx #16
  bcs @cend
  txa
  asl a
  asl a
  asl a
  ora tmp0
  tay
  lda board,y
  and #3
  cmp tmp3
  beq @cr2
@cend:
  stx tmp2
  txa
  sec
  sbc tmp1
  cmp #4
  bcc @cskip
  ldx tmp1
@cmark:
  txa
  asl a
  asl a
  asl a
  ora tmp0
  tay
  lda tmp3
  sta mask,y
  sta any
  inx
  cpx tmp2
  bne @cmark
@cskip:
  lda tmp2
  sta tmp1
  jmp @cc
@cnext:
  inc tmp0
  lda tmp0
  cmp #8
  bcc @col
  rts

link_delta: .byte 0, <-8, 8, <-1, 1, 0, 0, 0

apply_clear:
  lda #0
  sta tmp4
  ldx #0
@p1:
  lda mask,x
  beq @n1
  lda board,x
  lsr a
  lsr a
  lsr a
  lsr a
  and #7
  beq @n1
  tay
  txa
  clc
  adc link_delta,y
  tay
  lda mask,y
  bne @n1
  lda board,y
  and #$07
  sta board,y
@n1:
  inx
  bpl @p1
  ldx #0
@p2:
  lda mask,x
  beq @n2
  lda board,x
  and #4
  beq @nv
  inc tmp4
@nv:
  lda #0
  sta board,x
@n2:
  inx
  bpl @p2
  lda tmp4
  beq @nov
  lda #3
  jsr audio_sfx
  jmp @sc
@nov:
  lda #2
  jsr audio_sfx
@sc:
  lda tmp4
  beq @r
  dec tmp4
  dec vcount
  inc chain_v
  ldy chain_v
  cpy #7
  bcc @cy
  ldy #6
@cy:
  ldx speed
@add:
  lda chain_pts-1,y
  clc
  adc score
  sta score
  bcc @c2
  inc score+1
  bne @c2
  inc score+2
@c2:
  dex
  bpl @add
  jmp @sc
@r: rts
chain_pts: .byte 1, 2, 4, 8, 16, 32

; one rigid-body pass, rows bottom->top, cols left->right
gravity_pass:
  lda #0
  sta moved
  ldx #112
@l:
  lda board,x
  beq @n
  and #4
  bne @n
  lda board,x
  lsr a
  lsr a
  lsr a
  lsr a
  beq @single
  cmp #4
  beq @hpair
  cmp #1
  beq @vpair
  jmp @n
@single:
  lda board+8,x
  bne @n
  lda board,x
  sta board+8,x
  lda #0
  sta board,x
  inc moved
  jmp @n
@hpair:
  lda board+8,x
  ora board+9,x
  bne @n
  lda board,x
  sta board+8,x
  lda board+1,x
  sta board+9,x
  lda #0
  sta board,x
  sta board+1,x
  inc moved
  jmp @n
@vpair:
  lda board+8,x
  bne @n
  lda board,x
  sta board+8,x
  lda board-8,x
  sta board,x
  lda #0
  sta board-8,x
  inc moved
@n:
  txa
  and #7
  cmp #7
  beq @up
  inx
  jmp @l
@up:
  txa
  sec
  sbc #15
  bmi @done
  tax
  jmp @l
@done:
  rts

st_win:
st_lose:
  lda new_btn
  and #BTN_START
  beq @r
  pla
  pla
  lda state
  cmp #ST_WIN
  bne @menu
  lda level
  cmp #20
  bcs @same
  inc level
@same:
  lda level
  sta cfg_level
  jmp enter_game
@menu:
  jmp enter_menu
@r: jmp tick_end

; danger music: Code Blue when anything settled sits in rows 0-3 of spawn cols 2-5
music_logic:
  lda state
  cmp #ST_WIN
  bcs @r
  ldx #0
  ldy #0
@l:
  lda board+2,x
  ora board+3,x
  ora board+4,x
  ora board+5,x
  beq @e
  iny
@e:
  txa
  clc
  adc #8
  tax
  cpx #32
  bne @l
  tya
  beq @calm
  lda #1
  jmp audio_song_bar
@calm:
  lda #0
  jmp audio_song_bar
@r: rts

build_tiles:
  ldx #0
  lda state
  cmp #ST_CLEARWAIT
  beq @pop
@l:
  ldy board,x
  lda cell_tile,y
  sta tilebuf,x
  inx
  bpl @l
  rts
@pop:
  ldy board,x
  lda cell_tile,y
  ldy mask,x
  beq @st
  tya
  ora #$98
@st:
  sta tilebuf,x
  inx
  bpl @pop
  rts

build_sprites:
  lda state
  cmp #ST_FALL
  beq @pill
  lda #$FF
  sta oam
  sta oam+4
  jmp @next
@pill:
  lda px
  clc
  adc #BOARD_X
  asl a
  asl a
  asl a
  sta tmp0
  lda py
  clc
  adc #BOARD_Y
  asl a
  asl a
  asl a
  sec
  sbc #1
  sta tmp1
  ldx po
  lda po
  and #1
  bne @vs
  lda tmp1
  sta oam
  sta oam+4
  lda tmp0
  sta oam+3
  clc
  adc #8
  sta oam+7
  cpx #0
  bne @hrev
  lda cur_a
  ldy cur_b
  jmp @hset
@hrev:
  lda cur_b
  ldy cur_a
@hset:
  ora #$84
  sta oam+1
  tya
  ora #$88
  sta oam+5
  jmp @attr
@vs:
  lda tmp1
  sta oam
  sec
  sbc #8
  sta oam+4
  lda tmp0
  sta oam+3
  sta oam+7
  cpx #1
  bne @vrev
  lda cur_a
  ldy cur_b
  jmp @vset
@vrev:
  lda cur_b
  ldy cur_a
@vset:
  ora #$90
  sta oam+1
  tya
  ora #$8C
  sta oam+5
@attr:
  lda #0
  sta oam+2
  sta oam+6
@next:
  lda #47
  sta oam+8
  sta oam+12
  lda #192
  sta oam+11
  lda #200
  sta oam+15
  lda #0
  sta oam+10
  sta oam+14
  ldy nxt_id
  lda pill_a,y
  ora #$84
  sta oam+9
  lda pill_b,y
  ora #$88
  sta oam+13
  rts

build_hud:
  lda #2
  sta hudbuf
  lda #$20
  sta hudbuf+1
  lda #$A3
  sta hudbuf+2
  lda level
  jsr two_digits
  sta hudbuf+4
  stx hudbuf+3
  lda #3
  sta hudbuf+5
  lda #$21
  sta hudbuf+6
  lda #$03
  sta hudbuf+7
  lda speed
  asl a
  adc speed
  tay
  lda speed_names,y
  sta hudbuf+8
  lda speed_names+1,y
  sta hudbuf+9
  lda speed_names+2,y
  sta hudbuf+10
  lda #2
  sta hudbuf+11
  lda #$21
  sta hudbuf+12
  lda #$63
  sta hudbuf+13
  lda vcount
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
  lda state
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

score_digits:
  lda score
  sta tmp0
  lda score+1
  sta tmp1
  lda score+2
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
pow10_0: .byte <100000, <10000, <1000, <100, <10, <1
pow10_1: .byte >100000, >10000, >1000, >100, >10, >1
pow10_2: .byte ^100000, ^10000, ^1000, ^100, ^10, ^1

messages:
  .byte "         ", "         "
  .byte "  CLEAR! ", "  START  "
  .byte "GAME OVER", "  START  "

nmi:
  pha
  txa
  pha
  tya
  pha
  lda nmi_ready
  beq @skip
  lda #0
  sta OAMADDR
  lda #>oam
  sta OAMDMA
  lda nmi_ready
  and #1
  beq @hud
  lda nmi_count
  and #1
  bne @odd
  jsr upload_top
  jmp @hud
@odd:
  jsr upload_bottom
@hud:
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
@skip:
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

.macro UPROW r
  .local addr
  addr = NT_BOARD + r*32
  lda #>addr
  sta PPUADDR
  lda #<addr
  sta PPUADDR
  .repeat 8, i
    lda tilebuf + r*8 + i
    sta PPUDATA
  .endrepeat
.endmacro
upload_top:
  .repeat 8, r
    UPROW r
  .endrepeat
  rts
upload_bottom:
  .repeat 8, r
    UPROW (r+8)
  .endrepeat
  rts

.if COPRO
; Copro mailbox stubs ($5000-$5086).  Board -> $5000-$507F, capsule colours
; -> $5080-$5083, GO pulse -> $5084.  DONE/col/o4 latched from $5084-$5086.
copro_publish:
  ldx #0
@b:
  ldy board,x
  lda copro_enc,y
  sta $5000,x
  inx
  bpl @b
  ldx cur_a
  dex
  stx $5080
  ldx cur_b
  dex
  stx $5081
  ldy nxt_id
  ldx pill_a,y
  dex
  stx $5082
  ldx pill_b,y
  dex
  stx $5083
  lda #1
  sta $5084
  rts
copro_poll:
  lda $5084
  and #$80
  beq @r
  lda $5085
  sta copro_col
  lda $5086
  sta copro_o4
@r: rts
.endif

.include "audio.inc"

.segment "RODATA"
palette:
.if PASTEL
  .byte $0F,$25,$38,$31, $0F,$30,$10,$21, $0F,$25,$38,$31, $0F,$30,$10,$21
  .byte $0F,$25,$38,$31, $0F,$30,$10,$21, $0F,$25,$38,$31, $0F,$30,$10,$21
.else
  .byte $0F,$16,$28,$12, $0F,$30,$10,$21, $0F,$16,$28,$12, $0F,$30,$10,$21
  .byte $0F,$16,$28,$12, $0F,$30,$10,$21, $0F,$16,$28,$12, $0F,$30,$10,$21
.endif
speed_names: .byte "LOWMED HI"
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
.if COPRO
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
.endif
nt_title: .incbin "build/nt_title.bin"
nt_menu:  .incbin "build/nt_menu.bin"
nt_game:  .incbin "build/nt_game.bin"

.segment "VECTORS"
  .word nmi, reset, irq
.segment "CHARS"
  .incbin "build/chr.bin"
