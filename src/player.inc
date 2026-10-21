; =====================================================================
;  Per-player game logic. Included twice: .scope P1 (PNUM=0) / P2 (PNUM=1).
;  Before inclusion the scope defines PNUM, board, mask, tilebuf, WIN.
;  Every handler consumes `btn` (this frame's buttons) and the shared
;  global frame counter `gframe`.
; =====================================================================
.segment "ZEROPAGE"
state:  .res 1
btn:    .res 1
prev:   .res 1
new:    .res 1
dbg_inp: .res 1
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
level: .res 1
speed: .res 1
speedups: .res 1
locked: .res 1
vcount: .res 1
chain_v: .res 1
score: .res 3
timer: .res 1
lines: .res 1
from_lock: .res 1
gcol: .res 4
cpu: .res 1
ai_have: .res 1
ai_o: .res 1
ai_col: .res 1      ; column steered to now
ai_fin: .res 1      ; final column (tuck target)
ai_trig: .res 1     ; tuck trigger row ($FF none)
ai_rel: .res 1      ; 1 = next frame is a release frame
wins: .res 1
sa_d: .res 1
sa_side: .res 1
sa_a: .res 1
sa_x: .res 1

.segment "CODE"

; ------------------------------------------------------------- setup
; clear board, place viruses for `level` (shared LFSR), reset play state
new_round:
  ldx #0
  txa
@cb: sta board,x
  sta mask,x
  inx
  bpl @cb
  jsr place_viruses
  lda #0
  sta speedups
  sta locked
  sta chain_v
  sta pcnt
  sta pdas
  sta dbg_inp
  sta timer
  sta prev
  sta btn
  sta lines
  sta from_lock
  sta ai_have
  sta ai_rel
  sta score
  sta score+1
  sta score+2
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
  ldx #PNUM
  lda #0
  sta gq_n,x
  jmp build_tiles

; ------------------------------------------------------------- virus placement
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

; ------------------------------------------------------------- legality
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

; ------------------------------------------------------------- frame entry
tick:
  lda prev
  eor #$FF
  and btn
  sta new
  lda btn
  sta prev
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
  .word st_spawn-1, st_fall-1, st_check-1, st_clearwait-1, st_grav-1, st_idle-1, st_idle-1
st_idle:
  rts

st_spawn:
  ; pending garbage drops first (versus only)
  ldx #PNUM
  lda gq_n,x
  beq @nog
  sta tmp0
  ldx #(PNUM*4)
@gl:
  ldy gq_col,x
  lda board,y
  bne @gs
  lda gq_clr,x
  sta board,y
@gs:
  inx
  dec tmp0
  bne @gl
  ldx #PNUM
  lda #0
  sta gq_n,x
  sta from_lock
  sta lines
  sta chain_v
  sta timer
  lda #ST_GRAV
  sta state
  rts
@nog:
  lda board+3
  ora board+4
  beq @ok
  lda #ST_LOSE
  sta state
  rts
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
  sta ai_have
  sta ai_rel
  lda cpu
  beq @h
  jsr copro_publish
@h:
  lda #ST_FALL
  sta state
  rts

st_fall:
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
  lda gframe
  and #1
  beq @natural
  lda btn
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
  jmp audio_sfx
@lateral:
  lda btn
  and #BTN_LEFT
  beq @tryright
  lda #$FF
  sta tmp0
  lda new
  and #BTN_LEFT
  jmp @dir
@tryright:
  lda btn
  and #BTN_RIGHT
  beq @nodir
  lda #1
  sta tmp0
  lda new
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
@rotate:
  lda new
  and #BTN_A
  beq @rb
  lda po
  sec
  sbc #1
  jmp @rot
@rb:
  lda new
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
  jmp audio_sfx
@done:
  rts

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
  lda cur_b
  ldx cur_a
  jmp @vert
@v1:
  lda cur_a
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
  sta lines
  lda #1
  sta from_lock
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
  rts
@none:
  ldx #0
  txa
@cm: sta mask,x
  inx
  bpl @cm
  lda from_lock
  beq @nosend
  lda lines
  cmp #2
  bcc @nosend
  lda vs_mode
  beq @nosend
  jsr send_garbage
@nosend:
  lda #0
  sta from_lock
  lda vcount
  bne @spawn
  lda #ST_WIN
  sta state
  rts
@spawn:
  lda #ST_SPAWN
  sta state
  rts

; lines >= 2 : queue min(lines,4) garbage singles for the opponent
send_garbage:
  ldx #(1-PNUM)
  lda gq_n,x
  bne @r                       ; opponent still has an undelivered batch
  lda lines
  cmp #5
  bcc @n
  lda #4
@n: sta tmp4                   ; n = 2..4
  jsr rng_step
  ldx tmp4
  cpx #2
  bne @n3
  ldy #3
  sty tmp5
  jsr mod_a
  asl a                        ; idx*2
  clc
  adc #<(gar2-gar2)
  tay
  lda #<gar2
  sta ptr
  lda #>gar2
  sta ptr+1
  jmp @copy
@n3:
  and #1
  cpx #3
  bne @n4
  sta tmp5
  asl a
  adc tmp5                     ; idx*3
  tay
  lda #<gar3
  sta ptr
  lda #>gar3
  sta ptr+1
  jmp @copy
@n4:
  asl a
  asl a                        ; idx*4
  tay
  lda #<gar4
  sta ptr
  lda #>gar4
  sta ptr+1
@copy:
  ldx #((1-PNUM)*4)
  lda #0
  sta tmp5
@cl:
  lda (ptr),y
  sta gq_col,x
  sty tmp3
  ldy tmp5
  lda gcol,y
  sta gq_clr,x
  ldy tmp3
  iny
  inx
  inc tmp5
  lda tmp5
  cmp tmp4
  bne @cl
  ldx #(1-PNUM)
  lda tmp4
  sta gq_n,x
@r: rts

st_clearwait:
  dec timer
  bne @r
  lda #ST_GRAV
  sta state
@r: rts

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
@r: rts

note_run:                      ; colour in tmp3; records it, counts lines
  lda lines
  cmp #4
  bcs @c
  tay
  lda tmp3
  sta gcol,y
@c:
  inc lines
  bne @r
  dec lines
@r: rts

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
  jsr note_run
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
  jsr note_run
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

; ------------------------------------------------------------- display
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

; sprites: falling pill at OAM+OAMOFF; tmp0 = screen board x (tiles)
build_sprites:
  lda state
  cmp #ST_FALL
  beq @pill
  lda #$FF
  sta oam+OAMOFF
  sta oam+OAMOFF+4
  rts
@pill:
  lda px
  clc
  adc tmp0
  asl a
  asl a
  asl a
  sta tmp2
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
  sta oam+OAMOFF
  sta oam+OAMOFF+4
  lda tmp2
  sta oam+OAMOFF+3
  clc
  adc #8
  sta oam+OAMOFF+7
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
  sta oam+OAMOFF+1
  tya
  ora #$88
  sta oam+OAMOFF+5
  jmp @attr
@vs:
  lda tmp1
  sta oam+OAMOFF
  sec
  sbc #8
  sta oam+OAMOFF+4
  lda tmp2
  sta oam+OAMOFF+3
  sta oam+OAMOFF+7
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
  sta oam+OAMOFF+1
  tya
  ora #$8C
  sta oam+OAMOFF+5
@attr:
  lda #0
  sta oam+OAMOFF+2
  sta oam+OAMOFF+6
  rts

; ------------------------------------------------------------- copro (mailbox WIN)
; Board -> WIN+$00..$7F (cart byte format: $FF empty, $Dc germ, $4c/$5c/$6c/$7c
; linked down/up/right/left, $8c single; c = colour 0..2), capsule colours ->
; WIN+$80..$83 (na/nb high nibbles carry speed + speed-ups, tap period 2), GO -> WIN+$84.
copro_publish:
  ldx #0
@b:
  ldy board,x
  lda copro_enc,y
  sta WIN,x
  inx
  bpl @b
  ldx cur_a
  dex
  stx WIN+$80
  ldx cur_b
  dex
  stx WIN+$81
  lda speedups
  asl a
  asl a
  asl a
  asl a
  ldy nxt_id
  ora pill_a,y
  sec
  sbc #1
  ora #$08                 ; tap period low bits (pp = 2)
  sta WIN+$82
  lda speed
  clc
  adc #1
  asl a
  asl a
  sta tmp1
  lda speedups
  lsr a
  lsr a
  lsr a
  lsr a
  and #3
  ora tmp1
  asl a
  asl a
  asl a
  asl a
  ora pill_b,y
  sec
  sbc #1
  sta WIN+$83
  lda #1
  sta WIN+$84              ; GO
  rts

; CPU input synthesis: reads the copro answer and produces `btn` like a pad.
; Rotate first, then tap to the column (press/release), soft-drop; for a tuck
; descriptor, steer to the approach column, soft-drop to the trigger row,
; then tap into the final column and drop.
drive:
  lda #0
  sta btn
  lda state
  cmp #ST_FALL
  bne @r
  lda ai_have
  bne @have
  lda WIN+$84
  beq @r
  lda WIN+$85
  cmp #8
  bcs @r
  sta ai_fin
  sta ai_col
  ldx WIN+$86
  cpx #4
  bcs @r
  lda o4_to_o,x
  sta ai_o
  lda #$FF
  sta ai_trig
  lda WIN+$87
  cmp #8
  bcs @nt
  sta ai_col
  lda WIN+$88
  sta ai_trig
  lda ai_col
  cmp ai_fin
  bne @nt
  jsr side_approach        ; approach == target: pick an open neighbour column
@nt:
  lda #1
  sta ai_have
@have:
  lda ai_rel
  beq @act
  lda #0
  sta ai_rel
@r: rts
@act:
  lda po
  cmp ai_o
  beq @col
  lda ai_o
  sec
  sbc po
  and #3
  cmp #3
  beq @ra
  lda #BTN_B
  jmp @press
@ra:
  lda #BTN_A
  jmp @press
@col:
  lda px
  cmp ai_col
  beq @there
  bcc @right
  lda #BTN_LEFT
  jmp @press
@right:
  lda #BTN_RIGHT
  jmp @press
@there:
  lda ai_trig
  cmp #$FF
  beq @drop
  lda py
  cmp ai_trig
  bcs @slide
  lda #BTN_DOWN
  sta btn
  rts
@slide:
  lda #$FF
  sta ai_trig
  lda ai_fin
  sta ai_col
  jmp @col
@drop:
  lda #BTN_DOWN
  sta btn
  rts
@press:
  sta btn
  lda #1
  sta ai_rel
  rts

; first occupied row of column X (16 if empty) -> A
col_top:
  stx tmp2
  ldy #0
@l:
  lda board,y
  bne @f
  tya
  clc
  adc #8
  tay
  bpl @l
  lda #16
  rts
@f:
  tya
  lsr a
  lsr a
  lsr a
  rts
  ; (unreachable)

; lowest anchor row a straight drop reaches at anchor column X for ai_o -> A
land_row:
  txa
  clc
  adc #0
  sta tmp3
  jsr col_top_x
  sta tmp4
  lda ai_o
  and #1
  bne @v
  ldx tmp3
  inx
  jsr col_top_x
  cmp tmp4
  bcs @v
  sta tmp4
@v:
  lda tmp4
  sec
  sbc #1
  rts
col_top_x:                 ; column X, preserves nothing
  txa
  tay
@l:
  lda board,y
  bne @f
  tya
  clc
  adc #8
  tay
  bpl @l
  lda #16
  rts
@f:
  tya
  lsr a
  lsr a
  lsr a
  rts

; approach == target: search d = 1..7 (left, then right) for an approach column that a
; straight fall carries down to the trigger row and from which the trigger row is open
; all the way to the target (Med School driver extension; protocol unchanged)
side_approach:
  lda #1
  sta sa_d
@dl:
  lda #0
  sta sa_side
@sl:
  lda ai_fin
  ldx sa_side
  bne @r
  sec
  sbc sa_d
  bcc @next                ; < 0
  jmp @cand
@r:
  clc
  adc sa_d
  cmp #8
  bcs @next
  tax
  lda ai_o
  and #1
  bne @rv
  cpx #7
  bcs @next
@rv:
  txa
@cand:
  sta sa_a
  tax
  jsr land_row
  bmi @next
  cmp ai_trig
  bcc @next
  ; row ai_trig must be legal for every column from sa_a to ai_fin
  lda sa_a
  sta sa_x
@pl:
  lda sa_x
  sta lx
  lda ai_trig
  sta ly
  lda ai_o
  sta lo_
  jsr legal
  bcc @next
  lda sa_x
  cmp ai_fin
  beq @found
  bcc @inc
  dec sa_x
  jmp @pl
@inc:
  inc sa_x
  jmp @pl
@found:
  lda sa_a
  sta ai_col
  rts
@next:
  inc sa_side
  lda sa_side
  cmp #2
  bcc @sl
  inc sa_d
  lda sa_d
  cmp #8
  bcc @dl
  rts
