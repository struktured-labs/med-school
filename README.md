# Med School (NES), Phase 1

A clean-room falling-capsule puzzle for real NES hardware (NROM-256). See CLEANROOM.md for provenance.

    make            # build/medschool.nes (music on)
    make variants   # + medschool_pastel / medschool_copro (COPRO=1 mailbox stubs) / medschool_silent
    .venv/bin/python test/compare.py 1000 12   # ROM vs reference, frame by frame
    test/shots.sh 1 1                          # fceux under a private Xvfb -> shots/

Controls: D-pad moves, DOWN soft-drops, A rotates -1, B rotates +1, START starts or continues.
Menu: UP/DOWN picks the row, LEFT/RIGHT sets level 0-20 and speed LOW/MED/HI.
Harness hooks: write `$0300` level, `$0301` speed, `$0302/$0303` seed and `$0304=$A5` (seed lock) before START.

## Versus
Menu modes: 1P, VS CPU, 2P, CPU vs CPU (attract after ~17 s idle). Best of 3. CPU requires the copro window ($5000/$5200).
Tests: `test/vs.py N workers modes latency` (frame-exact vs `ref/medsim.py` MedMatch), `test/shots_vs.py` (headless cynes screenshots).

## Options added (Oct 2026)
- **1P CHAR / 2P CHAR**: avatar per player. GRAD (grad-cap virus, default), MONITR, PILL, BANDGE, PETRI.
  1P: drawn upper right next to the NEXT preview. 2P: one beside each bottle neck.
- **RNG CLASSIC / FAIR**. CLASSIC (default) is the faithful 128-capsule looping buffer.
  FAIR is a 9-combo bag: refill ids 0..8, Fisher-Yates for i=8..1 with j = lfsr_s0 mod (i+1),
  dealt into the same 128-slot buffer (index 127 down to 0). It is deterministic per seed,
  so FIXED seeds replay. The buffer is shared, so both players get the same sequence.
  The sim mirrors it in `ref/medsim.py: fair_sequence`.
- **Soft drop gate**: if DOWN is still held from the previous capsule, it does nothing for
  the new capsule until it has been released once.
- **Built-in CPU**: when a player has no copro window, VS CPU / CPU VS CPU use an on-6502
  evaluator. It checks 32 straight drops, 4 per frame, then hands off to the row-plan driver.
  It is weaker than the copro.
- **Copro build** `build/medschool_copro.nes` (`make copro`) has the same PRG/CHR with iNES
  mapper 100. MMC1 init at reset gives the NROM layout. The core's Dr. Mario copro window
  is enabled only for mapper 100. Detection is per window: bit0 = $5000, bit1 = $5200.
  On the DRDANGER/winner core only $5200 exists, so P2 (the VS CPU opponent) gets the full
  copro brain and P1 in CPU VS CPU uses the built-in CPU.
- **Copro latency (DRDANGER):** the real firmware answers about 50 frames after GO (p90 60, max 72, measured on the copro RTL).
  Med School now steers toward the live best while the search runs, waits for DONE before it soft-drops, and gets a
  24-frame capsule throw during which the copro is already searching.

## CPU personalities, difficulty, poses (Oct 2026)
Each avatar has a play style that applies only when a CPU is controlling it. When a human picks an avatar it is purely cosmetic, and the menu shows the CPU/style/difficulty row only for CPU players.

| Avatar | Style | How it plays |
|---|---|---|
| GRAD | METHODICAL | slower pace and reaction, few mistakes, row-height aware |
| MONITR | DEFENSIVE | heavy top-of-stack penalty, low stacks preferred |
| PILL | GREEDY | high germ/match weights, soft-drops live answers |
| BANDGE | CHAOTIC | noisy eval, 40/256 capsules use built-in CPU instead of copro, most mistakes |
| PETRI | AGGRESSIVE | instant reaction, no pace limit, combo-weighted |

Difficulty is set per CPU (EASY/MEDIUM/HARD, default MEDIUM).
- EASY: about 25% mistakes, +30 frames reaction, +6 frames pace, no tucks, no soft drop, extra noise.
- HARD: no mistakes or delays, tucks always allowed, half noise.

The CPU's randomness comes from its own 8-bit LFSR, seeded from the match seed. It never touches the game RNG, so seeded games stay identical.

**Copro limits:** DRDANGER firmware is unchanged. With the copro, the personality only controls pace, reaction delay, soft-drop eagerness, tuck permission, mistakes (perturbing the copro answer), and the per-capsule built-in fallback (CHAOTIC). The eval weights affect only built-in CPU picks.

Win/lose: every avatar has a unique win pose (with bounce/flip) and lose pose (pale palette with sink/shiver).

Tests: `test/personality.py h2h|diff N LV,.. workers` (set `COPRO=lat` to use the copro). Results are in `test/results/personality_*.json`.

HARD also applies a per-avatar eval override (`hard_eval` in player.inc, tuned with `test/tune_hard.py`). GRAD gets a sharper germ/run-first eval and MONITR a deeper top-danger zone. BANDGE's noise is only halved, because tuning showed that removing the noise made it weaker.

### Difficulty table (final, built-in CPU)
Match win rate of each avatar against a GRAD MEDIUM reference. Each cell is 72 matches, 24 at each of L5, L11 and L15. Data: `test/results/personality_diff24_final.json` (gitignored, local only).

| avatar | EASY | MEDIUM | HARD |
|---|---|---|---|
| GRAD | 0.11 | 0.54 | 0.76 |
| MONITR | 0.08 | 0.33 | 0.50 |
| PILL | 0.08 | 0.46 | 0.89 |
| BANDGE | 0.07 | 0.74 | 0.85 |
| PETRI | 0.03 | 0.51 | 0.78 |

PILL HARD turns soft-drop off (`hard_soft`). Its always-soft-drop habit cost it at full speed: HARD went from 0.57 to 0.89.

## Music row and gravity (Oct 26 2026)
- Setup screen MUSIC row: ROUNDS (danger: Code Blue) / SCRUBS (jazzy-funk, danger: Scrubs Stat, song 8) / VITALS (bright and bouncy, danger: Vitals Rx, song 9) / OFF.
  Songs 8 and 9 reuse the data of 2 and 7 and play 1.2x faster (header tempo flag, added by music/fastvar.py).
  Stored in cfg_music ($03E2); kept across games until power-off or soft reset. Jingles still play when OFF.
- Garbage and post-clear gravity: 16 frames per row (GRAV_FRAMES). Garbage waits 24 frames before its first row
  (GARB_DELAY), so a volley takes 264 - 16h frames, per the owner timing spec. The attract demo was re-recorded.
- SFX 7 is the falling-pieces sound (garbage and post-clear) and 8 is speed up.
