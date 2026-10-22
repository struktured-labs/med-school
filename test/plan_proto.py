"""Prototype of the row-plan CPU driver on ref/medsim (1P), answers from the C port."""
import sys, random, ctypes, os
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
import medsim as M
from vs import enc_cart, expected_cells, O4_TO_O
lib = ctypes.CDLL(os.path.abspath("copro/libmscopro.so"))
L, R, DN, A, B = M.LEFT, M.RIGHT, M.DOWN, M.A, M.B

def moves(g, y, st):
    """single-frame-step successors within row y (lateral, rotation with left kick)"""
    x, o = st
    out = []
    for d in (-1, 1):
        if g.legal(y, x + d, o): out.append((x + d, o))
    for no in ((o - 1) & 3, (o + 1) & 3):
        if g.legal(y, x, no): out.append((x, no))
        elif no & 1 == 0 and x > 0 and g.legal(y, x - 1, no): out.append((x - 1, no))
    return out

def rowbfs(g, y, src):
    dist = {s: 0 for s in src}; q = list(src)
    for s in q:
        for n in moves(g, y, s):
            if n not in dist: dist[n] = dist[s] + 1; q.append(n)
    return dist

def plan(g, t, ty, o):
    y0 = g.y
    reach = {y0: rowbfs(g, y0, [(g.x, g.o)])}
    for y in range(y0 + 1, ty + 1):
        seed = [s for s in reach[y - 1] if g.legal(y, s[0], s[1])]
        reach[y] = rowbfs(g, y, seed) if seed else {}
    if (t, o) not in reach.get(ty, {}): return None
    p = {ty: (t, o)}
    for y in range(ty - 1, y0 - 1, -1):
        best = None
        for e in reach[y]:
            if not g.legal(y + 1, *e): continue
            dd = rowbfs(g, y + 1, [e]).get(p[y + 1])
            if dd is not None and (best is None or dd < best[0]): best = (dd, e)
        p[y] = best[1]
    return p

def step_toward(g, y, cur, goal):
    """first move of a shortest in-row path cur->goal, as (dx, rot) ; rot -1/+1"""
    if cur == goal: return None
    back = rowbfs(g, y, [goal])   # moves are reversible enough; use forward bfs instead
    dist = rowbfs(g, y, [cur])
    # pick successor minimising remaining distance to goal
    best = None
    for n in moves(g, y, cur):
        dn = rowbfs(g, y, [n]).get(goal)
        if dn is not None and (best is None or dn < best[0]): best = (dn, n)
    return best[1] if best else None

class Drv:
    def __init__(s): s.ans = None; s.prev = 0; s.p = None
    def inp(s, g):
        out = s._inp(g); s.prev = out; return out
    def _inp(s, g):
        if g.state != M.FALL or s.ans is None: return 0
        a = s.ans; t = a["done_col"]; o = O4_TO_O[a["done_o4"]]
        if s.p is None:
            if a["tuck_col"] != 0xFF: ty = a["tuck_row"]
            else:
                ty = g.y
                while g.legal(ty + 1, t, o): ty += 1
            s.p = plan(g, t, ty, o); s.pn = s.p is None
            if s.p is None: s.p = {g.y: (t, o)}
            s.ty = max(s.p); s.start = (g.x, g.y)
        gv = M.GRAVITY_TABLE[min(M.SPEED_BASE[g.speed] + g.speedups, 80)]
        D = g.cnt + 1 > gv and g.legal(g.y + 1, g.x, g.o)
        yy = g.y + 1 if D else g.y
        want = s.p.get(yy, (t, o)) if yy <= s.ty else (t, o)
        cur = (g.x, g.o)
        if os.environ.get('DBG') and yy != g.y: print('DROPFRAME', g.y, cur, want, s.p.get(yy), s.ty)
        if cur != want:
            n = step_toward(g, yy, cur, want)
            if n is None: n = want
            if n[1] == cur[1]:
                d = L if n[0] < cur[0] else R
                return 0 if s.prev & d else d
            btn = A if n[1] == ((cur[1] - 1) & 3) else B
            return 0 if s.prev & (A | B) else btn
        if all(s.p.get(y, (t, o)) == cur for y in range(yy, s.ty + 1)): return DN
        return 0

def run(seed, lv, sp, n_frames=20000):
    rng = random.Random(seed)
    g = M.MedGame(lv, sp, rng.randrange(256), rng.randrange(256))
    d = Drv(); st = dict(locks=0, exact=0, tuck=0, tex=0, same=0, sex=0)
    prev = g.state; board = None
    for f in range(n_frames):
        if g.state in (M.WIN, M.LOSE): break
        before = g.encode(); ps = g.state
        iv = d.inp(g)
        if d.ans and d.ans['tuck_col'] != 0xFF and g.state == M.FALL: d.tr = getattr(d,'tr',[])+[(g.x,g.y,g.o,g.cnt,g.gframe&1,iv)]
        g.frame(iv)
        if ps == M.FALL and g.state != M.FALL:
            placed = {(k // 8, k % 8, v & 3) for k, v in enumerate(g.encode()) if v and not before[k]}
            exp = expected_cells(board, d.ans, cur); tk = d.ans["tuck_col"] != 0xFF
            same = tk and d.ans["tuck_col"] == d.ans["done_col"]; ok = placed == exp
            st["locks"] += 1; st["exact"] += ok; st["tuck"] += tk; st["tex"] += tk and ok
            st["same"] += same; st["sex"] += same and ok
            if tk and not ok and st["tuck"]-st["tex"] <= 6:
                print("MISS", d.ans, "pn", d.pn, "start", d.start, "plan", d.p, "placed", sorted(placed), "exp", sorted(exp), "spd", g.speed, g.speedups); print(d.tr)
                for r in range(16): print("".join(".#"[bool(board[r*8+c])] for c in range(8)))
            d.ans = None; d.tr = []
        if ps == M.SPAWN and g.state == M.FALL:
                board = g.encode(); cur = g.cur
                inb = enc_cart(board, g.cur, g.nxt, g.speed, g.speedups)
                out = (ctypes.c_ubyte * 8)()
                lib.ms_search((ctypes.c_ubyte * 132)(*inb), out)
                d.ans = dict(col=out[0], o4=out[1], done_col=out[2], done_o4=out[3], tuck_col=out[4], tuck_row=out[5], tuck_rest=out[6])
                d.p = None
        prev = g.state
    return st

if __name__ == "__main__":
    tot = {}
    for s in range(int(sys.argv[1])):
        st = run(s, [4, 8, 12, 16, 20][s % 5], s % 3)
        for k, v in st.items(): tot[k] = tot.get(k, 0) + v
    print(tot)
