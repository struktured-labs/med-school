; Drop-in audio module: engine + music + SFX. Assemble with: ca65 med_school_audio.s
.include "famistudio_cfg.inc"
.include "famistudio_ca65.s"
.segment "RODATA"
.include "../export/med_school_music.s"
.include "../export/med_school_sfx.s"
