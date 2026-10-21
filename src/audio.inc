; Audio glue. AUDIO=0: silent stubs. Requests are queued by game code and
; serviced inside NMI so the engine is only ever entered from one context.
.ifndef AUDIO
AUDIO = 0
.endif
.segment "ZEROPAGE"
song_req: .res 1
song_cur: .res 1
song_pend: .res 1
sfx_q: .res 1
bar_timer: .res 1
.segment "CODE"
audio_song:            ; immediate song change (A = song)
  ora #$80
  sta song_req
  rts
audio_song_bar:        ; change between Rounds/Code Blue on a bar boundary
  cmp song_cur
  beq @same
  sta song_pend
  rts
@same:
  lda #$FF
  sta song_pend
  rts
audio_sfx:             ; A = sfx id 0..3 (bitmask queue)
  tax
  lda sfx_bits,x
  ora sfx_q
  sta sfx_q
  rts
sfx_bits: .byte 1, 2, 4, 8
.if AUDIO
.import famistudio_init, famistudio_update, famistudio_music_play, famistudio_sfx_init, famistudio_sfx_play
.import music_data_med_school, sounds
FAMISTUDIO_SFX_CH0 = 0
FAMISTUDIO_SFX_CH1 = 15
audio_init:
  lda #$FF
  sta song_pend
  ldx #<music_data_med_school
  ldy #>music_data_med_school
  lda #1
  jsr famistudio_init
  ldx #<sounds
  ldy #>sounds
  jsr famistudio_sfx_init
  rts
audio_nmi:
  lda song_req
  bpl @bar
  and #$7F
  sta song_cur
  jsr famistudio_music_play
  lda #0
  sta song_req
  sta bar_timer
  lda #$FF
  sta song_pend
  jmp @sfx
@bar:
  inc bar_timer
  lda song_cur
  cmp #2
  bcs @sfx
  ldx song_cur
  lda bar_timer
  cmp bar_len,x
  bcc @sfx
  lda #0
  sta bar_timer
  lda song_pend
  bmi @sfx
  sta song_cur
  jsr famistudio_music_play
  lda #$FF
  sta song_pend
@sfx:
  lsr sfx_q
  bcc @s1
  lda #0
  ldx #FAMISTUDIO_SFX_CH0
  jsr famistudio_sfx_play
@s1:
  lsr sfx_q
  bcc @s2
  lda #1
  ldx #FAMISTUDIO_SFX_CH0
  jsr famistudio_sfx_play
@s2:
  lsr sfx_q
  bcc @s3
  lda #2
  ldx #FAMISTUDIO_SFX_CH1
  jsr famistudio_sfx_play
@s3:
  lsr sfx_q
  bcc @s4
  lda #3
  ldx #FAMISTUDIO_SFX_CH1
  jsr famistudio_sfx_play
@s4:
  lda #0
  sta sfx_q
  jmp famistudio_update
bar_len: .byte 96, 80
.else
audio_init:
audio_nmi:
  lda #0
  sta sfx_q
  sta song_req
  rts
.endif
