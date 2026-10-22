# Med School: clean-room provenance

Med School is an original NES game. Its rules match the falling-capsule puzzle behaviour that
Carmelo's own simulators and rule notes describe. **No Nintendo ROM was opened, disassembled,
dumped or byte-copied to build this project.** No code, tiles, music, text, title or trade dress
was taken from any commercial game.

## Behaviour sources (the only ones used)
| What | Source (owner's own work) | How it was used |
|---|---|---|
| Board rules: 4+ row/column clears, simultaneous clears, unlinking partners, rigid-body gravity passes, cascades, spawn-blocked loss | `struktured-labs/dr_mario_rl` @ `worktree-faithful-sim` (7ec4d5e): `src/drmario/faithful_game.py` (`FaithfulBoard`) | Re-implemented in 6502. The reference model imports `FaithfulBoard` unchanged. |
| Virus count `min(4(L+1),84)`, top row `min(6, 16-ceil(n/8))`, rejection loop (no 4-runs; avoid 3-runs for the first 70% of attempts) | same file, `place_viruses` | Same algorithm. Its RNG is the capsule LFSR below, not numpy, so the cart can reproduce it. |
| Capsule generator: 16-bit LFSR, `id = (id + nibble) mod 9`, 128-entry buffer filled backwards, first capsule is element 1 | `dr_mario_rl/tmp/pillrng/nes_pills.py`; `struktured-labs/dr-mario-te` `MECHANICS_NES.md` §1 | Re-implemented in 6502. The reference model imports `gen_sequence`. |
| Frame rules: gravity→lateral→rotation order, lock on first failed drop, soft drop on odd frames with DOWN as the only direction held, rising-edge rotation (A = -1, B = +1), one left kick, gravity table and speed bases (15/25/31), speed-up cap 49, DAS 16/6 | `dr-mario-te` `experiments/tuck_enum.py` docstring and constants; `MECHANICS_NES.md` §4 | Numbers transcribed from the spec into `src/main.s` and `ref/medsim.py`. |
| Speed-up every 10 capsules | `MECHANICS_NES.md` §4, `docs/ROM_ARCHITECTURE_SURVEY.md` | Implemented as "+1 after every 10th lock". The exact phase is a spec assumption. |
| Copro register map `$5000-$5086` | `dr-mario-te` @ `grok/c-port` `c_port/drm_copro.h` | Stub only, behind `COPRO=1`. |

### Not covered by the owner's specs
These come from general public knowledge and our own design choices. None comes from the ROM.
- **Scoring:** each virus in one lock's cascade is worth 100 x 2^(k-1), capped at 3200. The total is multiplied by 1 on LOW, 2 on MED and 3 on HI. This is commonly documented public play knowledge and has not been checked against hardware.
- **Timing between pieces** (our own choice): the clear flash lasts 16 frames, gravity passes run every 4 frames, and checking a clear and spawning a piece take 1 frame each.
- **DAS blocked-retry:** when a held move is blocked, it is retried every frame. This follows a note in the tuck_enum docstring.
- **Simultaneous-button quirks** are not modelled: there is no extra left shift after a kick while LEFT is held.

### Legal-review flag
The gravity table (81 numbers) and the speed bases are functional timing parameters. They were taken
from the owner's spec file, and that file says it extracted them from the original ROM. They are
facts about game behaviour, not creative expression. Still, they are the one place where data
traceable to the original appears in this project, so they are flagged for counsel. If needed,
they can be replaced with a re-derived curve, which would change gravity timing.

## Original assets
- Every tile (font, capsule halves, germs, pop burst, bottle, 2x title letters) is drawn as ASCII art in `tools/mkassets.py`.
- The palette is classic red/yellow/blue. A pastel build is available with `PASTEL=1`.
- The name "MED SCHOOL" and the menu text ("PRESCRIPTION", etc.) are original.
- Music and SFX are original FamiStudio compositions in `music/` (see `music/README.md`). The engine is stock FamiStudio, MIT license.

## Tools
ca65/ld65 (cc65 2.19), cynes (headless emulator used for verification), fceux 2.6.5 (screenshots under a private Xvfb).

## Phase 2 additions (versus + copro CPU)
- Copro register protocol (W=$5000 P1 / $5200 P2; board $00-$7F, $80-$83 capsule/speed bytes, GO/DONE $84, answers $85-$88) was taken from Carmelo's own `drm_copro.h` and C port (grok/c-port 785105c0). No Nintendo code involved.
- The emulator-side copro used in tests is a patched cynes (`tools/cynes_copro_window.patch`) plus a shim (`copro/ms_copro_shim.c`) linked against the unmodified C port. Test-only; not part of the ROM.
- Garbage rules (≥2 lines per cascade → min(lines,4) singles, column sets, colours, no-send-while-pending) are our own design following MECHANICS_NES.md §5 in spirit; exact column/colour/timing details are UNVERIFIED against real hardware.
- Driver extension: for tuck descriptors whose approach column equals the target, the CPU searches nearby columns for a straight-fall approach with an open trigger row. This is Med School behaviour, not cart behaviour; registers unchanged.
- Without a copro on the cart, CPU pills free-fall (open-bus answers fail validation).

## Oct 2026 additions
- Avatar art (GRAD cap virus, MONITR heart-monitor robot, PILL capsule with stethoscope,
  BANDGE walking bandage, PETRI petri-dish slime) is original pixel art drawn in
  `tools/mkassets.py` (AVATARS). Nothing was traced from or modelled on Nintendo sprites.
- RNG FAIR (bag) is a Med School design. It is not in any spec.
- The DOWN release gate is a Med School design choice. The rule docs do not specify DOWN
  carry-over between capsules (no documented spawn delay). The gate addresses the playtest
  report that held DOWN carries into the next pill too easily.
- The built-in CPU evaluator is original. The mapper-100 window protocol ($5000-$5088) comes
  from the NES_MiSTer-dist CoproDrMario.sv header comment and xlate().
