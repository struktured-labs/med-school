# Med School (NES), Phase 1

A clean-room falling-capsule puzzle for real NES hardware (NROM-256). See CLEANROOM.md for provenance.

    make            # build/medschool.nes (music on)
    make variants   # + medschool_pastel / medschool_copro (COPRO=1 mailbox stubs) / medschool_silent
    .venv/bin/python test/compare.py 1000 12   # ROM vs reference, frame by frame
    test/shots.sh 1 1                          # fceux under a private Xvfb -> shots/

Controls: D-pad moves, DOWN soft-drops, A rotates -1, B rotates +1, START starts or continues.
Menu: UP/DOWN picks the row, LEFT/RIGHT sets level 0-20 and speed LOW/MED/HI.
Harness hooks: write `$0300` level, `$0301` speed, `$0302/$0303` seed and `$0304=$A5` (seed lock) before START.
