; Drop-in audio module: engine + music + SFX. Assemble with: ca65 med_school_audio.s
.include "famistudio_cfg.inc"
.include "famistudio_ca65.s"
.segment "RODATA"
.include "../export/med_school_music.s"
.include "../export/med_school_sfx.s"
.export famistudio_sfx_ptr_hi   ; read by the game to keep the move tick from cutting a CH1 jingle
