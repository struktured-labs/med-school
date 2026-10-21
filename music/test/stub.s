; Minimal NROM test harness (NOT game code): init engine, play Rounds, switch to Code Blue on Select.
.import famistudio_init, famistudio_update, famistudio_music_play, famistudio_sfx_init, famistudio_sfx_play
.import music_data_med_school, sounds
.segment "HEADER"
.byte "NES",$1A,2,1,0,0,0,0,0,0,0,0,0,0
.segment "ZEROPAGE"
nmi_flag: .res 1
.segment "CODE"
reset: sei
 cld
 ldx #$FF
 txs
 inx
 stx $2000
 stx $2001
 ldx #<music_data_med_school
 ldy #>music_data_med_school
 lda #1          ; 1 = NTSC
 jsr famistudio_init
 ldx #<sounds
 ldy #>sounds
 jsr famistudio_sfx_init
 lda #0          ; song_rounds
 jsr famistudio_music_play
 lda #$80
 sta $2000      ; NMI on
loop: lda nmi_flag
 beq loop
 lda #0
 sta nmi_flag
 jmp loop
nmi: pha
 txa
 pha
 tya
 pha
 jsr famistudio_update
 inc nmi_flag
 pla
 tay
 pla
 tax
 pla
irq: rti
.segment "VECTORS"
.word nmi, reset, irq
