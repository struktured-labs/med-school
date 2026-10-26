"""Frame-level reference model for Med School, built ON Carmelo's own sims.

Board rules (clears, unlinking, rigid-body gravity passes, virus placement
algorithm) are imported unchanged from dr_mario_rl@worktree-faithful-sim
src/drmario/faithful_game.py (FaithfulBoard).  The capsule generator is
dr_mario_rl/tmp/pillrng/nes_pills.py (gen_sequence/step_lfsr).  Frame rules
(gravity table, frame order gravity->lateral->rotation, soft-drop parity,
rotation kicks, DAS 16/6) follow dr-mario-te experiments/tuck_enum.py and
MECHANICS_NES.md.  Only the RNG fed to place_viruses differs from the sim's
numpy default: it is the same 16-bit LFSR, so the cart can reproduce it.
"""
import os, sys
HOME = os.path.expanduser("~")
sys.path.insert(0, os.path.join(HOME, "projects/dr_mario_rl/.claude/worktrees/faithful-sim/src"))
sys.path.insert(0, os.path.join(HOME, "projects/dr_mario_rl/tmp/pillrng"))
from drmario.faithful_game import FaithfulBoard, EMPTY          # noqa: E402
from nes_pills import step_lfsr, gen_sequence, PILL_COLORS       # noqa: E402

GRAVITY_TABLE = (
    69, 67, 65, 63, 61, 59, 57, 55, 53, 51, 49, 47, 45, 43, 41, 39, 37, 35, 33, 31,
    29, 27, 25, 23, 21, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 9, 8, 8, 7,
    7, 6, 6, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4,
    3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0)
SPEED_BASE = (15, 25, 31)
DAS_FIRST, DAS_REPEAT = 16, 6
CLEAR_FRAMES, GRAV_FRAMES, GARB_DELAY = 16, 16, 24
SPAWN, FALL, CHECK, CLEARWAIT, GRAV, WIN, LOSE = range(7)
A, B, UP, DOWN, LEFT, RIGHT = 0x80, 0x40, 0x08, 0x04, 0x02, 0x01


class LfsrRng:
    """numpy-Generator-shaped adaptor: integers(lo, hi) = lo + s0 % (hi-lo)."""
    def __init__(self, s0, s1):
        self.s0, self.s1 = s0, s1
    def integers(self, lo, hi):
        self.s0, self.s1 = step_lfsr(self.s0, self.s1)
        return lo + self.s0 % (hi - lo)


GAR2 = ((1, 5), (2, 6), (3, 7))
GAR3 = ((1, 3, 6), (2, 5, 7))
GAR4 = ((1, 3, 5, 7), (2, 3, 6, 7))


def run_colours(color):
    """Colours of every >=4 run, rows (top->bottom) then columns (left->right)."""
    out = []
    for r in range(16):
        c = 0
        while c < 8:
            v = int(color[r, c])
            if v == 0:
                c += 1; continue
            c2 = c
            while c2 < 8 and int(color[r, c2]) == v:
                c2 += 1
            if c2 - c >= 4:
                out.append(v)
            c = c2
    for c in range(8):
        r = 0
        while r < 16:
            v = int(color[r, c])
            if v == 0:
                r += 1; continue
            r2 = r
            while r2 < 16 and int(color[r2, c]) == v:
                r2 += 1
            if r2 - r >= 4:
                out.append(v)
            r = r2
    return out


def fair_sequence(s0, s1):
    """Med School RNG FAIR: 9-combo bag, Fisher-Yates (i=8..1, j=lfsr_s0 % (i+1)),
    dealt into buf[127] down to buf[0] like the classic fill.  Returns (ids, s0, s1)."""
    buf = [0] * 128
    bag, pos = list(range(9)), 9
    for y in range(127, -1, -1):
        if pos == 9:
            bag = list(range(9))
            for i in range(8, 0, -1):
                s0, s1 = step_lfsr(s0, s1)
                j = s0 % (i + 1)
                bag[i], bag[j] = bag[j], bag[i]
            pos = 0
        buf[y] = bag[pos]
        pos += 1
    return buf, s0, s1


def make_sequence(s0, s1, fair=False):
    return fair_sequence(s0, s1) if fair else gen_sequence(s0, s1)


THROW_F = 24   # Med School capsule throw frames (design value)


class MedGame:
    def __init__(self, level, speed, s0=None, s1=None, ids=None, rng=None, fair=False):
        """1P: MedGame(level, speed, s0, s1).  Versus: pass shared ids + rng."""
        if ids is None:
            if s0 == 0 and s1 == 0:
                s0, s1 = 0x89, 0x88
            ids, s0, s1 = make_sequence(s0, s1, fair)
            rng = LfsrRng(s0, s1)
        self.level, self.speed = level, speed
        self.ids, self.rng = ids, rng
        self.b = FaithfulBoard(rng=rng)
        self.vcount = self.b.place_viruses(level)
        self.vs = False
        self.opp = None
        self.gq = []                 # incoming garbage [(col, colour)]
        self.lines = 0
        self.gcol = []
        self.from_lock = False
        self.state = SPAWN
        self.gframe = 0
        self.pidx = 1
        self.cur = self.ids[1]
        self.nxt = self.ids[2]
        self.x = self.y = self.o = self.cnt = self.das = 0
        self.prev = 0
        self.down_ok = False
        self.speedups = 0
        self.locked = 0
        self.chain = 0
        self.score = 0           # units of 100
        self.timer = 0

    # ------------------------------------------------------------ helpers
    def cell(self, r, c):
        return int(self.b.color[r, c])
    def legal(self, y, x, o):
        if not (0 <= x < 8 and 0 <= y < 16):
            return False
        if o & 1 == 0:
            return x <= 6 and self.cell(y, x) == 0 and self.cell(y, x + 1) == 0
        return self.cell(y, x) == 0 and (y == 0 or self.cell(y - 1, x) == 0)

    def encode(self):
        out = []
        for r in range(16):
            for c in range(8):
                v = int(self.b.color[r, c])
                if v:
                    v |= (4 if self.b.is_virus[r, c] else 0) | (int(self.b.link[r, c]) << 4)
                out.append(v)
        return out

    def _put(self, r, c, color, link):
        self.b.color[r, c] = color; self.b.is_virus[r, c] = False; self.b.link[r, c] = link

    def lock(self):
        a, bb = PILL_COLORS[self.cur]
        x, y, o = self.x, self.y, self.o
        if o == 0:
            self._put(y, x, a, 4); self._put(y, x + 1, bb, 3)
        elif o == 2:
            self._put(y, x, bb, 4); self._put(y, x + 1, a, 3)
        else:
            bottom, top = (a, bb) if o == 1 else (bb, a)
            if y == 0:
                self._put(y, x, bottom, 0)
            else:
                self._put(y, x, bottom, 1); self._put(y - 1, x, top, 2)
        self.locked += 1
        if self.locked == 10:
            self.locked = 0
            if self.speedups < 49:
                self.speedups += 1
        self.chain = 0
        self.lines = 0
        self.gcol = []
        self.from_lock = True
        self.state = CHECK

    def send_garbage(self):
        o = self.opp
        if o.gq:
            return
        n = min(self.lines, 4)
        self.rng.s0, self.rng.s1 = step_lfsr(self.rng.s0, self.rng.s1)
        v = self.rng.s0
        cols = GAR2[v % 3] if n == 2 else (GAR3 if n == 3 else GAR4)[v & 1]
        o.gq = [(cols[i], self.gcol[i]) for i in range(n)]

    def gravity_pass(self):
        b = self.b
        bodies = b._bodies()
        bodies.sort(key=lambda bd: max(r for r, _ in bd), reverse=True)
        moved = False
        for bd in bodies:
            if b._can_fall(bd):
                b._move_body_down(bd); moved = True
        return moved

    # ------------------------------------------------------------ one frame
    def frame(self, inp):
        new = inp & ~self.prev & 0xFF
        self.prev = inp
        st = self.state
        if st == SPAWN and self.gq:
            for col, colour in self.gq:
                if self.b.color[0, col] == 0:
                    self._put(0, col, colour, 0)
            self.gq = []
            self.from_lock = False
            self.lines = 0
            self.chain = 0
            self.timer = GRAV_FRAMES - GARB_DELAY
            self.state = GRAV
        elif st == SPAWN:
            if self.b.spawn_blocked():
                self.state = LOSE
            else:
                self.cur = self.ids[self.pidx]
                self.pidx = (self.pidx + 1) & 127
                self.nxt = self.ids[self.pidx]
                self.x, self.y, self.o, self.cnt, self.das = 3, 0, 0, 0, 0
                self.down_ok = False
                self.throw = THROW_F
                self.state = FALL
        elif st == FALL:
            g = GRAVITY_TABLE[min(SPEED_BASE[self.speed] + self.speedups, 80)]
            if not inp & DOWN:
                self.down_ok = True     # held DOWN must be released once per capsule (Med School)
            if self.throw:
                self.throw -= 1         # capsule still being thrown in: no gravity / moves
                self.gframe = (self.gframe + 1) & 0xFFFF
                return
            soft = (self.gframe & 1) == 1 and (inp & 0x0F) == DOWN and self.down_ok
            drop = soft
            if not soft:
                self.cnt += 1
                drop = self.cnt > g
            locked = False
            if drop:
                if self.legal(self.y + 1, self.x, self.o):
                    self.y += 1; self.cnt = 0
                else:
                    self.lock(); locked = True
            if not locked:
                d, isnew = 0, False
                if inp & LEFT:
                    d, isnew = -1, bool(new & LEFT)
                elif inp & RIGHT:
                    d, isnew = 1, bool(new & RIGHT)
                if d == 0:
                    self.das = 0
                elif isnew:
                    self.das = 0; self.shift(d)
                else:
                    self.das += 1
                    if self.das >= DAS_FIRST:
                        self.das = DAS_FIRST - DAS_REPEAT if self.shift(d) else DAS_FIRST - 1
                cand = None
                if new & A:
                    cand = (self.o - 1) & 3
                elif new & B:
                    cand = (self.o + 1) & 3
                if cand is not None:
                    if self.legal(self.y, self.x, cand):
                        self.o = cand
                    elif cand & 1 == 0 and self.x > 0 and self.legal(self.y, self.x - 1, cand):
                        self.o = cand; self.x -= 1
        elif st == CHECK:
            mask = self.b._find_clears()
            if mask.any():
                for colour in run_colours(self.b.color):
                    if len(self.gcol) < 4:
                        self.gcol.append(colour)
                    self.lines = min(self.lines + 1, 255)
                v = self.b._apply_clear(mask)
                for _ in range(v):
                    self.vcount -= 1
                    self.chain += 1
                    self.score += (1 << (min(self.chain, 6) - 1)) * (self.speed + 1)
                self.timer = CLEAR_FRAMES
                self.state = CLEARWAIT
            else:
                if self.from_lock and self.lines >= 2 and self.vs:
                    self.send_garbage()
                self.from_lock = False
                self.state = WIN if self.vcount == 0 else SPAWN
        elif st == CLEARWAIT:
            self.timer -= 1
            if self.timer == 0:
                self.state = GRAV
        elif st == GRAV:
            self.timer += 1
            if self.timer == GRAV_FRAMES:
                self.timer = 0
                if not self.gravity_pass():
                    self.state = CHECK
        self.gframe = (self.gframe + 1) & 0xFFFF

    def shift(self, d):
        if self.legal(self.y, self.x + d, self.o):
            self.x += d
            return True
        return False

    def snapshot(self):
        falling = (self.x, self.y, self.o) if self.state == FALL else None
        return dict(board=self.encode(), state=self.state, pill=falling,
                    cur=self.cur, pidx=self.pidx, score=self.score,
                    vcount=self.vcount, speedups=self.speedups)


class MedMatch:
    """Versus: two MedGame players sharing the capsule buffer and LFSR, best of 3."""
    def __init__(self, lv1, sp1, lv2, sp2, s0, s1, same=False, fair=False):
        self.same = same
        self.fair = fair            # BOARDS SAME: P2 copies P1's virus layout when levels match
        if s0 == 0 and s1 == 0:
            s0, s1 = 0x89, 0x88
        self.cfg = (lv1, sp1, lv2, sp2)
        self.s0, self.s1 = s0, s1
        self.wins = [0, 0]
        self.round_no = 0
        self.new_round()

    def new_round(self):
        lv1, sp1, lv2, sp2 = self.cfg
        if self.s0 == 0 and self.s1 == 0:
            self.s0, self.s1 = 0x89, 0x88
        ids, s0, s1 = make_sequence(self.s0, self.s1, self.fair)
        rng = LfsrRng(s0, s1)
        self.rng = rng
        self.p = [MedGame(lv1, sp1, ids=ids, rng=rng), MedGame(lv2, sp2, ids=ids, rng=rng)]
        if self.same and lv1 == lv2:
            import copy
            src, dst = self.p[0].b, copy.copy(self.p[0].b)
            for k, v in vars(src).items():
                if hasattr(v, "copy") and not isinstance(v, (dict,)) and k != "rng":
                    setattr(dst, k, v.copy())
            self.p[1].b = dst
            self.p[1].vcount = self.p[0].vcount
        for i in (0, 1):
            self.p[i].vs = True
            self.p[i].opp = self.p[1 - i]
        self.round_no += 1
        self.winner = None

    def frame(self, in1, in2):
        """One logic frame (P1 then P2, shared gframe). Returns winner index or None."""
        a, b = self.p
        g = a.gframe
        a.frame(in1)
        b.gframe = g
        b.frame(in2)
        if a.state == WIN or b.state == LOSE:
            self.winner = 0
        elif b.state == WIN or a.state == LOSE:
            self.winner = 1
        if self.winner is not None:
            self.wins[self.winner] += 1
            self.s0, self.s1 = self.rng.s0, self.rng.s1
        return self.winner
