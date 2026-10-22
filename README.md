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
