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
sfx_q2: .res 1
bar_timer: .res 1
.segment "CODE"
SONG_STOP = $7F
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
audio_sfx:             ; A = sfx id 0..8 (bitmask queues: 0..7 sfx_q, 8.. sfx_q2)
  cmp #8
  bcs @hi
  tax
  lda sfx_bits,x
  ora sfx_q
  sta sfx_q
  rts
@hi:
  and #7
  tax
  lda sfx_bits,x
  ora sfx_q2
  sta sfx_q2
  rts
sfx_bits: .byte 1, 2, 4, 8, 16, 32, 64, 128
.if AUDIO
.import famistudio_init, famistudio_update, famistudio_music_play, famistudio_sfx_init, famistudio_sfx_play, famistudio_music_pause, famistudio_music_stop
.import music_data_med_school, sounds, famistudio_sfx_ptr_hi
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
  lda paused               ; pause/unpause music (engine mutes all channels while paused)
  cmp pause_last
  beq @pp
  sta pause_last
  jsr famistudio_music_pause
@pp:
  lda song_req
  bpl @bar
  and #$7F
  sta song_cur
  cmp #SONG_STOP
  bne @play
  jsr famistudio_music_stop
  jmp @stopped
@play:
  jsr famistudio_music_play
@stopped:
  lda #0
  sta song_req
  sta bar_timer
  lda #$FF
  sta song_pend
  jmp @sfx
@bar:
  inc bar_timer
  ldx song_cur
  cpx #8
  bcs @sfx
  lda bar_len,x
  beq @sfx                 ; only the in-game songs switch calm/danger on a bar
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
  lsr sfx_q                ; 4 move tick (noise, CH1 stream so it never cuts a rotate
  bcc @s5                  ; blip on CH0); a clear/virus jingle on CH1 wins over it
  lda famistudio_sfx_ptr_hi+FAMISTUDIO_SFX_CH1
  bne @s5
  lda #4
  ldx #FAMISTUDIO_SFX_CH1
  jsr famistudio_sfx_play
@s5:
  lsr sfx_q                ; 5 / 6 combo ditty P1 / P2 (CH1; a later one wins)
  bcc @s6
  lda #5
  ldx #FAMISTUDIO_SFX_CH1
  jsr famistudio_sfx_play
@s6:
  lsr sfx_q
  bcc @s7
  lda #6
  ldx #FAMISTUDIO_SFX_CH1
  jsr famistudio_sfx_play
@s7:
  lsr sfx_q                ; 7 falling pieces (CH0)
  bcc @s8
  lda #7
  ldx #FAMISTUDIO_SFX_CH0
  jsr famistudio_sfx_play
@s8:
  lsr sfx_q2               ; 8 speed up (CH1, unless a combo/clear jingle is playing)
  bcc @s9
  lda famistudio_sfx_ptr_hi+FAMISTUDIO_SFX_CH1
  bne @s9
  lda #8
  ldx #FAMISTUDIO_SFX_CH1
  jsr famistudio_sfx_play
@s9:
  lda #0
  sta sfx_q2
  sta sfx_q
  jmp famistudio_update
bar_len: .byte 96, 80, 128, 0, 0, 0, 0, 96   ; frames per bar (0 = not an in-game song)
.else
audio_init:
audio_nmi:
  lda #0
  sta sfx_q
  sta sfx_q2
  sta song_req
  rts
.endif
