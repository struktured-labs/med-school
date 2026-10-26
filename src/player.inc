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
throw_t: .res 1     ; frames left of the throw into the bottle
down_ok: .res 1     ; 0 until DOWN has been released once since spawn
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
ai_rel: .res 1      ; (unused, kept zeroed)
ai_ty: .res 1       ; target row of the plan
ai_ok: .res 1       ; 1 = row plan valid
ai_lc: .res 1       ; last adopted live copro column ($FF none)
ai_lo: .res 1       ; last adopted live copro o4
wins: .res 1
avatar: .res 1
; CPU personality knobs (setup_cpu: pers_tab[avatar] then the difficulty layer)
k_wr: .res 1        ; eval: points per landing row (depth)
k_wm: .res 1        ; eval: per same-colour cell in the column run below
k_wg: .res 1        ; eval: extra per germ (virus) cell matched
k_wc: .res 1        ; eval: completing a 4-run (clear)
k_tp: .res 1        ; eval: rows from the top that count as danger (-24)
k_nz: .res 1        ; eval: seeded noise mask added to each score
k_pace: .res 1      ; min idle frames between move/rotate presses
k_react: .res 1     ; frames after the throw before the first input
k_soft: .res 1      ; 0 never soft-drop, 1 always when aligned, 2 coin-flip per capsule
k_tuck: .res 1      ; 1 = execute copro tucks
k_mist: .res 1      ; per-capsule deliberate-mistake chance (/256)
k_live: .res 1      ; 1 = soft-drop on the copro's live (pre-DONE) answer (risky)
k_alt: .res 1       ; per-capsule chance (/256) to use the built-in pick instead of the copro
crng: .res 1        ; per-player CPU RNG (separate from the game LFSR: no gameplay effect)
pace_t: .res 1
react_t: .res 1
pflags: .res 1      ; this capsule: bit0 soft-drop ok, bit1 use built-in, bit2 mistake
mist_n: .res 2

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
  lda #THROW_F
  sta throw_t
  lda #0
  sta down_ok
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
  sta bi_c
  lda #$FF
  sta ai_lc
  sta ai_lo
  lda #0
  sta bi_best
  sta pace_t
  lda k_react
  sta react_t
  jsr cpu_roll
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
  lda btn                  ; a DOWN held over from the previous capsule must be
  and #BTN_DOWN            ; released once before it soft-drops this one
  bne @dh
  lda #1
  sta down_ok
@dh:
  lda throw_t              ; capsule still in flight from the thrower: no gravity/moves
  beq @thr0
  dec throw_t
  rts
@thr0:
  lda gframe
  and #1
  beq @natural
  lda down_ok
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
  bcc @rotate
  lda #4                   ; move tick, only when a cell was actually moved
  jsr audio_sfx
  jmp @rotate
@held:
  inc pdas
  lda pdas
  cmp #16
  bcc @rotate
  jsr shift
  bcc @blocked
  lda #4
  jsr audio_sfx
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
  lda #(5+PNUM)                ; combo (2+ clears in one chain): this player's ditty
  jsr audio_sfx
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
  lda (ctp),y
  sta tilebuf,x
  inx
  bpl @l
  rts
@pop:
  ldy board,x
  lda (ctp),y
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
  ldy throw_t              ; in flight: follow the throw arc from the preview
  beq @inb
  dey
  lda layout
  bne @tv
  lda thr_x_1p,y
  sta tmp2
  lda thr_y_1p,y
  sta tmp1
  jmp @pos
@tv:
  lda thr_x_vs+PNUM*THROW_F,y
  sta tmp2
  lda thr_y_vs,y
  sta tmp1
  jmp @pos
@inb:
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
@pos:
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
  lda avatar               ; DRSTYLES: copro personality register = $A0|style, style = avatar+1
  clc                      ; (1 METHODICAL .. 5 AGGRESSIVE); one-shot, so written before EVERY GO.
  adc #$A1                 ; A DRDANGER/TE core ignores it (scratch cell) -> exact DRDANGER search.
  sta WIN+$89
  lda #1
  sta WIN+$84              ; GO
  rts

; CPU input synthesis (Med School driver; register protocol unchanged).
; On the first frame an answer is available, plan a ROW PLAN to the target state:
;   target = (done col, done orientation) at the tuck trigger row, or at the straight
;   landing row when there is no tuck descriptor.
; Forward: reachable (x,o) sets per row under the frame rules (lateral, A/B rotation with
; left kick, then descend).  Backward: for each row, the state the pill must hold when
; gravity carries it to the next row (fewest in-row moves to the next row's state).
; Every frame: predict whether gravity drops the pill THIS frame (lateral/rotation run
; after gravity in the same frame), take the row it will be on, and press the first move
; of a shortest in-row path to that row's planned state (new presses only: release if the
; same button was held last frame).  Soft-drop only when no further move is planned.
PLAN = $03C0 + PNUM * 16

; empty / legal-anchor masks of every row into the shared scratch (bit c = column c)
build_masks:               ; rows max(py-1,0)..15 (rows above are never consulted)
  ldx py
  beq @s
  dex
@s:
  txa
  asl a
  asl a
  asl a
  tay
@l:
  lda board+7,y
  cmp #1
  rol tmp0
  lda board+6,y
  cmp #1
  rol tmp0
  lda board+5,y
  cmp #1
  rol tmp0
  lda board+4,y
  cmp #1
  rol tmp0
  lda board+3,y
  cmp #1
  rol tmp0
  lda board+2,y
  cmp #1
  rol tmp0
  lda board+1,y
  cmp #1
  rol tmp0
  lda board+0,y
  cmp #1
  rol tmp0
  lda tmp0
  eor #$FF
  sta PL_EM,x
  lsr a
  and PL_EM,x
  and #$7F
  sta PL_LH,x
  lda PL_EM,x
  cpx #0
  beq @v0
  and PL_EM-1,x
@v0:
  sta PL_LV,x
  tya
  clc
  adc #8
  tay
  inx
  cpx #16
  bne @l
  rts

; empty bits of row X -> A (bit c = column c empty); preserves X
row_empty:
  txa
  asl a
  asl a
  asl a
  tay
  lda board+7,y
  cmp #1
  rol tmp0
  lda board+6,y
  cmp #1
  rol tmp0
  lda board+5,y
  cmp #1
  rol tmp0
  lda board+4,y
  cmp #1
  rol tmp0
  lda board+3,y
  cmp #1
  rol tmp0
  lda board+2,y
  cmp #1
  rol tmp0
  lda board+1,y
  cmp #1
  rol tmp0
  lda board+0,y
  cmp #1
  rol tmp0
  lda tmp0
  eor #$FF
  rts

; masks of row X only (EM, LH, LV); uses EM of row X-1 recomputed directly
build_row:
  jsr row_empty
  sta PL_EM,x
  lsr a
  and PL_EM,x
  and #$7F
  sta PL_LH,x
  cpx #0
  beq @t
  dex
  jsr row_empty
  inx
  and PL_EM,x
  sta PL_LV,x
  rts
@t:
  lda PL_EM,x
  sta PL_LV,x
  rts

; straight landing row for anchor ai_fin / ai_o from the current row -> ai_ty
straight_row:
  lda py
  sta ai_ty
@l:
  lda ai_fin
  sta lx
  lda ai_o
  sta lo_
  ldx ai_ty
  inx
  stx ly
  jsr legal
  bcc @d
  inc ai_ty
  jmp @l
@d:
  rts

plan_rows:
  lda #0
  sta ai_ok
  lda ai_ty
  cmp py
  bcs @ok0
  rts
@ok0:
  jsr build_masks
  ; seed: {(px,po)} at row py
  lda #0
  sta pl_sa
  sta pl_sa+1
  sta pl_sa+2
  sta pl_sa+3
  ldx px
  lda bit_tab,x
  ldx po
  sta pl_sa,x
  lda py
  sta pl_y
@fwd:
  ldy pl_y
  jsr close_fwd
  lda pl_y
  asl a
  asl a
  tax
  lda pl_sa
  sta PL_RCH,x
  lda pl_sa+1
  sta PL_RCH+1,x
  lda pl_sa+2
  sta PL_RCH+2,x
  lda pl_sa+3
  sta PL_RCH+3,x
  lda pl_y
  cmp ai_ty
  beq @fwd_done
@fwd_next:
  inc pl_y
  ldy pl_y                 ; seed next row: reach(y-1) & legal(y)
  lda pl_sa
  and PL_LH,y
  sta pl_sa
  lda pl_sa+2
  and PL_LH,y
  sta pl_sa+2
  lda pl_sa+1
  and PL_LV,y
  sta pl_sa+1
  lda pl_sa+3
  and PL_LV,y
  sta pl_sa+3
  jmp @fwd
@fwd_done:
  ; target reachable?
  lda ai_ty
  asl a
  asl a
  ora ai_o
  tax
  ldy ai_fin
  lda PL_RCH,x
  and bit_tab,y
  bne @tgt
  ; trigger cell itself unreachable (the C port's tier-3 descriptor assumes an open
  ; slide at the trigger row): aim one row lower along the fall to the rest cell
  lda ai_fin
  sta lx
  lda ai_o
  sta lo_
  ldx ai_ty
  inx
  stx ly
  jsr legal
  bcs @lower
  rts
@lower:
  inc ai_ty
  jmp @fwd_next
@tgt:
  lda ai_o
  asl a
  asl a
  asl a
  ora ai_fin
  ldx ai_ty
  sta PLAN,x
  stx pl_y
@back:
  lda pl_y
  cmp py
  bne @b1
  lda #1
  sta ai_ok
  rts
@b1:
  dec pl_y                 ; row y; goal = PLAN[y+1]
  ldx pl_y
  lda PLAN+1,x
  sta pl_want
  ; fast path: the goal itself is reachable at row y and can descend
  lsr a
  lsr a
  lsr a
  sta tmp0                 ; o
  txa
  asl a
  asl a
  ora tmp0
  tay                      ; y*4+o
  lda pl_want
  and #7
  tax
  lda PL_RCH,y
  and bit_tab,x
  beq @slow
  ldy pl_y
  iny
  lda tmp0
  and #1
  bne @fv
  lda PL_LH,y
  jmp @fm
@fv:
  lda PL_LV,y
@fm:
  and bit_tab,x
  beq @slow
  lda pl_want
  ldx pl_y
  sta PLAN,x
  jmp @back
@slow:
  lda pl_want
  jsr set_single           ; pl_sa = {goal}
  lda pl_y
  asl a
  asl a
  tax
  ldy pl_y
  iny
  lda PL_RCH,x
  and PL_LH,y
  sta pl_sc
  lda PL_RCH+1,x
  and PL_LV,y
  sta pl_sc+1
  lda PL_RCH+2,x
  and PL_LH,y
  sta pl_sc+2
  lda PL_RCH+3,x
  and PL_LV,y
  sta pl_sc+3
  lda #16
  sta pl_k
@lay:
  ldx #0
@ti:
  lda pl_sa,x
  and pl_sc,x
  bne @pick
  inx
  cpx #4
  bne @ti
  ldy pl_y
  iny
  jsr pred_step
  lda pl_chg
  beq @fail
  dec pl_k
  bne @lay
@fail:
  rts
@pick:                     ; X = orientation, A = column bits -> lowest column
  ldy #0
@lb:
  lsr a
  bcs @gotc
  iny
  bne @lb
@gotc:
  txa
  asl a
  asl a
  asl a
  sty tmp0
  ora tmp0
  ldx pl_y
  sta PLAN,x
  jmp @back

; pl_sa = {state A}  (state = x | o<<3)
set_single:
  pha
  lda #0
  sta pl_sa
  sta pl_sa+1
  sta pl_sa+2
  sta pl_sa+3
  pla
  pha
  and #7
  tax
  lda bit_tab,x
  sta tmp0
  pla
  lsr a
  lsr a
  lsr a
  tax
  lda tmp0
  sta pl_sa,x
  rts


; ------------------------------------------------------------- built-in CPU (no copro)
; Weaker on-6502 opponent: scores the 32 (column, orientation) straight drops from the
; current row, 4 per frame; the 9th frame hands the best one to the row-plan driver.
; score = 40 + landing row + 4 per same-colour neighbour (+4 more if it is a germ)
;         - 1 per other-colour neighbour, - 24 if the capsule rests in the top 4 rows.
BI = $03AC + PNUM * 10
bi_c  = BI+0
bi_best = BI+1
bi_bc = BI+2
bi_n  = BI+3
bi_x  = BI+4
bi_y  = BI+5
bi_o  = BI+6
bi_p  = BI+7
bi_s  = BI+8
bi_c2 = BI+9
bi_k  = pl_k
bi_q  = pl_chg

bi_think:
  lda bi_c
  cmp #32
  bcc @eval
  lda bi_best
  bne @use
  lda px
  sta ai_fin
  lda po
  sta ai_o
  jmp @fin
@use:
  lda bi_bc
  lsr a
  lsr a
  sta ai_fin
  lda bi_bc
  and #3
  sta ai_o
@fin:
  lda pflags
  and #4
  beq @fn
  jsr mistake
@fn:
  jsr straight_row
  jsr plan_rows
  lda #2
  sta ai_have
  rts
@eval:
  lda #4
  sta bi_n
@loop:
  jsr bi_cand
  inc bi_c
  dec bi_n
  bne @loop
  rts

bi_cand:
  lda bi_c
  and #3
  sta bi_o
  sta lo_
  lda bi_c
  lsr a
  lsr a
  sta bi_x
  sta lx
  lda py
  sta bi_y
  sta ly
  jsr legal
  bcs @dn
  rts
@dn:
  ldx bi_y
  inx
  stx ly
  lda bi_x
  sta lx
  lda bi_o
  sta lo_
  jsr legal
  bcc @land
  inc bi_y
  jmp @dn
@land:
  lda bi_y
  asl a
  asl a
  asl a
  ora bi_x
  sta bi_p
  lda #20
  ldx bi_y
  beq @b0
@bm:
  clc
  adc k_wr
  dex
  bne @bm
@b0:
  sta bi_s
  lda bi_o
  beq @o0
  cmp #2
  beq @o2
  cmp #1
  beq @o1
  lda cur_b
  ldx cur_a
  jmp @v
@o1:
  lda cur_a
  ldx cur_b
@v:
  stx bi_c2
  ldy bi_p
  jsr bi_cell
  lda bi_y
  beq @tot
  lda bi_p
  sec
  sbc #8
  tay
  lda bi_c2
  jsr bi_cell
  jmp @tot
@o0:
  lda cur_a
  ldx cur_b
  jmp @h
@o2:
  lda cur_b
  ldx cur_a
@h:
  stx bi_c2
  ldy bi_p
  jsr bi_cell
  ldy bi_p
  iny
  lda bi_c2
  jsr bi_cell
@tot:
  lda k_nz
  beq @tp
  jsr cpu_rand
  and k_nz
  jsr bi_add
@tp:
  lda bi_y
  cmp k_tp
  bcs @cmp
  lda bi_s
  sec
  sbc #24
  bcs @st
  lda #1
@st:
  sta bi_s
@cmp:
  lda bi_s
  cmp bi_best
  bcc @r
  beq @r
  sta bi_best
  lda bi_c
  sta bi_bc
@r:
  rts

bi_cell:                   ; A = colour, Y = cell index; neighbours -> bi_s
  sta bi_k
  sty bi_q
  ; column run below: +6 per same-colour cell (germ +4 more), 3 below = a clear (+24)
  ldx #0
@dl:
  cpy #120
  bcs @de
  lda board+8,y
  and #3
  cmp bi_k
  bne @dm
  lda board+8,y
  and #4
  beq @dg
  lda k_wg
  jsr bi_add
@dg:
  lda k_wm
  jsr bi_add
  inx
  tya
  clc
  adc #8
  tay
  cpx #3
  bcc @dl
  lda k_wc
  jsr bi_add
  jmp @de
@dm:
  cpx #0                   ; first cell below is another colour: burying penalty
  bne @de
  lda board+8,y
  beq @de
  lda bi_s
  sec
  sbc #6
  bcs @dp
  lda #0
@dp:
  sta bi_s
@de:
@l:
  lda bi_q
  and #7
  beq @rt
  ldy bi_q
  lda board-1,y
  jsr bi_nb
@rt:
  lda bi_q
  and #7
  cmp #7
  beq @e
  ldy bi_q
  lda board+1,y
  jsr bi_nb
@e:
  rts

bi_nb:
  tax
  and #3
  beq @r
  cmp bi_k
  bne @mis
  lda #4
  jsr bi_add
  txa
  and #4
  beq @r
  lda k_wg
  jsr bi_add
@r:
  rts
@mis:
  lda bi_s
  beq @r
  dec bi_s
  rts

bi_add:                    ; bi_s += A, saturating at 255
  clc
  adc bi_s
  bcc @o
  lda #255
@o:
  sta bi_s
  rts

; avatar with mood: tmp2 = x, X = y, Y = slot (0/16).  Victory bounce + dance flip,
; defeat sink + pale palette + shiver, hop on a clear, shake in danger, idle bob.
avatar_anim:
  lda #0
  sta tmp3
  lda mstate
  beq @live
  lda layout
  beq @live
  lda round_winner
  cmp #PNUM
  beq @win
  jmp @lose
@live:
  lda state
  cmp #ST_WIN
  beq @win
  cmp #ST_LOSE
  beq @lose
  cmp #ST_CLEARWAIT
  beq @hop
  lda board+16             ; danger: anything in rows 2-3 of the centre columns
  ora board+18
  ora board+19
  ora board+20
  ora board+21
  ora board+26
  ora board+27
  ora board+28
  ora board+29
  bne @shake
  lda nmi_count            ; idle: 1px bob
  and #16
  beq @go
  dex
  jmp @go
@shake:
  lda nmi_count
  and #2
  beq @go
  inc tmp2
  inc tmp2
  jmp @go
@hop:
  txa
  sec
  sbc #5
  tax
  lda nmi_count
  and #4
  beq @go
  lda #$40
  sta tmp3
  jmp @go
@win:
  lda nmi_count            ; triangle bounce 0..7 px
  and #15
  cmp #8
  bcc @w1
  eor #15
@w1:
  sta tmp4
  txa
  sec
  sbc tmp4
  tax
  lda nmi_count
  and #16
  beq @pw
  lda #$40
  sta tmp3
@pw:
  lda avatar               ; hand-drawn victory pose
  asl a
  sty tmp4
  tay
  lda pose_tile,y
  ldy tmp4
  jmp avatar_draw_t
@lose:
  inx
  inx
  inx
  inx
  lda #1                   ; pale (sprite palette 1)
  sta tmp3
  lda nmi_count
  and #8
  beq @pl
  inc tmp2
@pl:
  lda avatar               ; hand-drawn defeat pose
  asl a
  sty tmp4
  tay
  lda pose_tile+1,y
  ldy tmp4
  jmp avatar_draw_t
@go:
  lda avatar
  jmp avatar_draw

; ---- CPU personality / difficulty layer
setup_cpu:
  ldx #0
  ldy avatar
  beq @c0
@m: txa
  clc
  adc #13
  tax
  dey
  bne @m
@c0:
  ldy #0
@cp:
  lda pers_tab,x
  sta k_wr,y
  inx
  iny
  cpy #13
  bne @cp
  lda cfg_diff1+PNUM
  beq @easy
  cmp #2
  bne @seed
  lda #0                   ; HARD: full strength
  sta k_mist
  sta k_pace
  sta k_react
  lda #1
  sta k_tuck
  lsr k_nz
  lsr k_alt
  lda avatar               ; per-avatar HARD eval override (wr wm wg wc tp), $FF = keep
  asl a
  asl a
  adc avatar
  tax
  ldy #0
@gh: lda hard_eval,x
  cmp #$FF
  beq @gk
  sta k_wr,y
@gk: inx
  iny
  cpy #5
  bne @gh
  ldx avatar               ; per-avatar HARD soft-drop override ($FF = keep)
  lda hard_soft,x
  cmp #$FF
  beq @hs
  sta k_soft
@hs:
  jmp @seed
@easy:
  lda #64                  ; EASY: 1 in 4 capsules is a deliberate mistake
  sta k_mist
  lda k_react
  clc
  adc #30
  sta k_react
  lda k_pace
  clc
  adc #6
  sta k_pace
  lda #0
  sta k_tuck
  sta k_soft
  sta k_live
  lda k_nz
  ora #7
  sta k_nz
@seed:
  lda s0
  eor s1
  eor #($A5 ^ (PNUM * $FF))
  bne @s1
  lda #1
@s1:
  sta crng
  lda #0
  sta mist_n
  sta mist_n+1
  rts

hard_eval:                 ; HARD eval overrides (tuned: test/tune_hard.py)
  .byte 1, 7, 3, 16, 3     ; GRAD: sharper germ/run-first, still depth-aware
  .byte 2, 6, 4, 24, 6     ; MONITR: keeps the deep top-danger zone
  .byte $FF,$FF,$FF,$FF,$FF ; PILL (eval kept; soft-drop off at HARD, see hard_soft)
  .byte $FF,$FF,$FF,$FF,$FF ; BANDGE (noise helps it; HARD only halves it)
  .byte $FF,$FF,$FF,$FF,$FF ; PETRI
hard_soft:                 ; HARD k_soft override per avatar (PILL: always-soft-drop costs it at full speed)
  .byte $FF, $FF, 0, $FF, $FF

cpu_rand:                  ; 8-bit Galois LFSR (x^8+x^4+x^3+x^2+1)
  lda crng
  asl a
  bcc @n
  eor #$1D
@n:
  sta crng
  rts

cpu_roll:                  ; per-capsule seeded decisions
  lda #0
  sta pflags
  lda k_soft
  cmp #1
  beq @s
  cmp #2
  bne @a
  jsr cpu_rand
  and #1
  beq @a
@s:
  lda #1
  sta pflags
@a:
  jsr cpu_rand
  cmp k_alt
  bcs @b
  lda pflags
  ora #2
  sta pflags
@b:
  jsr cpu_rand
  cmp k_mist
  bcs @r
  lda pflags
  ora #4
  sta pflags
  lda cpu
  beq @r
  inc mist_n
  bne @r
  inc mist_n+1
@r:
  rts

mistake:                   ; nudge the chosen target: wrong rotation or column +-1
  jsr cpu_rand
  and #3
  beq @rot
  and #1
  beq @lf
  lda ai_fin
  cmp #7
  bcs @lf
  inc ai_fin
  jmp @fix
@lf:
  lda ai_fin
  beq @rt
  dec ai_fin
  jmp @fix
@rt:
  inc ai_fin
  jmp @fix
@rot:
  lda ai_o
  clc
  adc #1
  and #3
  sta ai_o
@fix:
  lda ai_o
  and #1
  bne @x
  lda ai_fin
  cmp #7
  bcc @x
  lda #6
  sta ai_fin
@x:
  rts

drive:                     ; pace limiter around the planner/driver
  jsr drive_core
  lda btn
  and #(BTN_A|BTN_B|BTN_LEFT|BTN_RIGHT)
  beq @np
  lda pace_t
  beq @ok
  lda btn
  and #BTN_DOWN
  sta btn
  dec pace_t
  rts
@ok:
  lda k_pace
  sta pace_t
  rts
@np:
  lda pace_t
  beq @r
  dec pace_t
@r:
  rts

drive_core:
  lda #0
  sta btn
  lda state
  cmp #ST_FALL
  beq @f
  rts
@f:
  lda throw_t
  bne @f2
  lda react_t
  beq @f2
  dec react_t              ; reaction delay: no input yet
  rts
@f2:
  lda ai_have
  cmp #2
  bne @nf
  jmp @have                ; final plan in force
@nf:
  lda pflags
  and #2
  bne @bi                  ; personality: this capsule uses the built-in pick
  lda copro_ok
  and #(1 << PNUM)
  bne @cop
@bi:
  jmp bi_think             ; no copro: built-in 6502 CPU picks the target (over 9 frames)
@cop:
  lda WIN+$84
  bne @a0
  ; ANYTIME: the copro live-publishes its running best ($86 = $FF until it has one).
  ; Steer toward it while the search refines, like the copro cart does; never wait.
  lda WIN+$86
  cmp #4
  bcs @lnone
  ldx WIN+$85
  cpx #8
  bcs @lnone
  cmp WIN+$86              ; torn-read guard
  bne @lnone
  cmp ai_lo
  bne @adopt
  cpx ai_lc
  bne @adopt
@lnone:
  lda ai_have
  beq @lr
  jmp @have
@lr:
  rts
@adopt:
  sta ai_lo
  stx ai_lc
  stx ai_fin
  tax
  lda o4_to_o,x
  sta ai_o
  jsr straight_row
  jsr plan_rows
  lda #1
  sta ai_have
  rts
@a0:
  lda WIN+$85
  cmp #8
  bcc @a1
  rts
@a1:
  sta ai_fin
  ldx WIN+$86
  cpx #4
  bcc @a2
  rts
@a2:
  lda o4_to_o,x
  sta ai_o
  lda pflags
  and #4
  beq @a3
  jsr mistake
  jmp @nt
@a3:
  lda k_tuck
  beq @nt
  lda WIN+$87
  cmp #8
  bcs @nt
  lda WIN+$88
  sta ai_ty
  jmp @pl
@nt:
  jsr straight_row
@pl:
  jsr plan_rows
  lda #2
  sta ai_have
@have:
  lda throw_t
  beq @hv
  rts                      ; capsule in flight: plan is ready, wait for it to arrive
@hv:
  ; will gravity move the pill down this frame?  (pcnt+1 > g and the cell below is free)
  lda py
  sta pl_yy
  ldx speed
  lda speed_base,x
  clc
  adc speedups
  cmp #81
  bcc @gi
  lda #80
@gi:
  tax
  lda gravity_tab,x
  cmp pcnt
  beq @dn
  bcs @nodrop
@dn:
  jsr set_l_from_p
  inc ly
  jsr legal
  bcc @nodrop
  inc pl_yy
@nodrop:
  ; want = PLAN[yy] (yy <= ai_ty) else the target state
  lda ai_o
  asl a
  asl a
  asl a
  ora ai_fin
  sta pl_want
  lda ai_ok
  beq @w1
  lda ai_ty
  cmp pl_yy
  bcc @w1
  ldx pl_yy
  lda PLAN,x
  sta pl_want
@w1:
  lda po
  asl a
  asl a
  asl a
  ora px
  sta pl_cur
  cmp pl_want
  bne @move
  ; no move this frame: soft-drop if every remaining planned row is this state
  lda ai_ok
  beq @down
  ldx pl_yy
@sc:
  cpx ai_ty
  beq @sc1
  bcs @down
@sc1:
  lda PLAN,x
  cmp pl_cur
  bne @idle
  inx
  jmp @sc
@down:
  lda ai_have              ; live (not yet DONE) target: steer only, never soft-drop --
  cmp #2                   ; the final answer may be a tuck under an overhang
  beq @dk                  ; (unless the personality takes that risk: k_live)
  lda k_live
  beq @idle
@dk:
  lda pflags
  and #1
  beq @idle
  lda down_ok
  bne @dn2
  lda prev
  and #BTN_DOWN
  bne @idle                ; one release frame so the new capsule accepts soft drop
@dn2:
  lda #BTN_DOWN
  sta btn
@idle:
  rts
@move:
  ldx pl_yy
  jsr build_row
  lda pl_want
  jsr set_single
  lda #16
  sta pl_k
@bl:
  ; cur in pl_sa ?
  lda pl_cur
  lsr a
  lsr a
  lsr a
  tax
  lda pl_cur
  and #7
  tay
  lda pl_sa,x
  and bit_tab,y
  bne @found
  ldx #3
@cp:
  lda pl_sa,x
  sta pl_sc,x
  dex
  bpl @cp
  ldy pl_yy
  jsr pred_step
  lda pl_chg
  beq @greedy
  dec pl_k
  bne @bl
  jmp @greedy
@found:
  ; pick a move from cur landing in pl_sc (distance one less)
  lda px
  beq @tr
  sec
  sbc #1
  sta tmp4
  lda po
  sta tmp5
  jsr in_sc_legal
  bcc @tr
  lda #BTN_LEFT
  jmp @lat
@tr:
  lda px
  cmp #7
  bcs @ta
  adc #1
  sta tmp4
  lda po
  sta tmp5
  jsr in_sc_legal
  bcc @ta
  lda #BTN_RIGHT
  jmp @lat
@ta:
  lda po
  sec
  sbc #1
  and #3
  jsr rot_result
  bcc @tb
  lda #BTN_A
  jmp @rot
@tb:
  lda po
  clc
  adc #1
  and #3
  jsr rot_result
  bcc @greedy
  lda #BTN_B
  jmp @rot
@greedy:                   ; fallback: rotate, then tap toward the column
  lda po
  cmp ai_o
  beq @gc
  lda ai_o
  sec
  sbc po
  and #3
  cmp #3
  beq @ga
  lda #BTN_B
  jmp @rot
@ga:
  lda #BTN_A
  jmp @rot
@gc:
  lda px
  cmp ai_fin
  bne @gn
  lda ai_have
  cmp #2
  beq @gk                  ; live target: no soft drop before DONE
  lda k_live
  beq @gx
@gk:
  lda pflags
  and #1
  beq @gx
  lda #BTN_DOWN
  sta btn
@gx:
  rts
@gn:
  bcc @gr
  lda #BTN_LEFT
  jmp @lat
@gr:
  lda #BTN_RIGHT
@lat:
  sta tmp0
  and prev
  bne @rel
  lda tmp0
  sta btn
@rel:
  rts
@rot:
  sta tmp0
  lda prev
  and #(BTN_A|BTN_B)
  bne @rel
  lda tmp0
  sta btn
  rts

; rotation of cur to orientation A at row pl_yy: C=1 if the result is legal and in pl_sc
rot_result:
  sta tmp5
  lda px
  sta tmp4
  jsr in_sc_legal_l
  bcs @y
  bne @n                   ; legal but not in pl_sc
  lda tmp5
  and #1
  bne @n                   ; vertical: no kick
  lda tmp4
  beq @n
  dec tmp4
  jmp in_sc_legal
@y: rts
@n: clc
  rts

; (tmp4 = x, tmp5 = o) at row pl_yy: C=1 if legal and in pl_sc
in_sc_legal:
  jsr in_sc_legal_l
  rts
; same, but on C=0 also returns Z=1 when the state was ILLEGAL (Z=0: legal, not in set)
in_sc_legal_l:
  ldx pl_yy
  ldy tmp5
  jsr mask_of
  ldx tmp4
  and bit_tab,x
  beq @ill
  ldy tmp5
  lda pl_sc,y
  and bit_tab,x
  beq @nin
  sec
  rts
@nin:
  lda #1                   ; Z=0
  clc
  rts
@ill:
  lda #0                   ; Z=1
  clc
  rts
