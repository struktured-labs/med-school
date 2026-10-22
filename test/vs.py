"""Versus + copro harness.

The patched cynes exposes the cart's copro window: CPU writes to $5000-$53FF land in an
input register file (GO at W+$84 bumps a counter at $57F0+w), and W+$84..$8F reads come
from an output register file that the harness fills by writing $5400+off.  This script plays
the copro role by calling the unmodified C port (copro/libmscopro.so) on exactly the bytes the
cart uploaded, after a configurable latency, and checks:
  * register format: uploaded board/colour bytes == what the protocol says for the ROM board
  * CPU execution: every CPU lock lands exactly where the C port's DONE answer says
  * mechanics: both bottles frame-by-frame vs ref/medsim.MedMatch (garbage, rounds included)
"""
import sys, os, json, random, time, ctypes
from multiprocessing import Pool
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from emu import Rom
import medsim as M
from compare import Bot, rom_snap

ROM, LAB = "build/medschool.nes", "build/medschool.labels"
LIB = os.path.abspath("copro/libmscopro.so")
O4_TO_O = (3, 1, 0, 2)

def enc_cart(board, cur, nxt, speed, speedups):
    out = []
    for v in board:
        c = v & 3
        if c == 0: out.append(0xFF); continue
        lk = v >> 4
        if v & 4: out.append(0xD0 + c - 1)
        else: out.append({0: 0x80, 1: 0x50, 2: 0x40, 3: 0x70, 4: 0x60}[lk] + c - 1)
    a, b = M.PILL_COLORS[cur]; na, nb = M.PILL_COLORS[nxt]
    regs = [a - 1, b - 1, ((speedups & 15) << 4) | 0x08 | (na - 1),
            (((((speed + 1) << 2) | ((speedups >> 4) & 3))) << 4) | (nb - 1)]
    return out + regs

def expected_cells(board, ans, cur):
    """Cells (r, c, colour) the C port's DONE answer asks for, on our board encoding."""
    col, o4, rest = ans["done_col"], ans["done_o4"], ans["tuck_rest"]
    a, b = M.PILL_COLORS[cur]
    pa, pb = (b, a) if o4 & 1 else (a, b)
    top = lambda c: next((r for r in range(16) if board[r * 8 + c] & 3), 16)
    if o4 & 2:
        r = rest if rest != 0xFF else min(top(col), top(col + 1)) - 1
        return {(r, col, pa), (r, col + 1, pb)}
    r = rest if rest != 0xFF else top(col) - 1
    cells = {(r, col, pb)}
    if r > 0: cells.add((r - 1, col, pa))
    return cells

class Copro:
    def __init__(self, r, latency):
        self.r, self.lat = r, latency
        self.lib = ctypes.CDLL(LIB)
        self.lib.ms_search.restype = ctypes.c_uint
        self.go = [r.nes[0x57F0], r.nes[0x57F1]]
        self.pending = [None, None]
        self.answers = [None, None]
        self.searches = 0; self.fmt_bad = 0; self.us = 0.0
    def poll(self, expect):
        r = self.r
        for w in (0, 1):
            g = r.nes[0x57F0 + w]
            if g != self.go[w]:
                self.go[w] = g
                base = 0x5000 + w * 0x200
                inb = bytes(r.nes[base + i] for i in range(132))
                if expect and expect[w] is not None and list(inb) != expect[w]:
                    self.fmt_bad += 1
                buf = (ctypes.c_ubyte * 132).from_buffer_copy(inb)
                out = (ctypes.c_ubyte * 8)()
                t0 = time.perf_counter()
                self.lib.ms_search(buf, out)
                self.us += (time.perf_counter() - t0) * 1e6
                self.searches += 1
                ans = dict(col=out[0], o4=out[1], done_col=out[2], done_o4=out[3],
                           tuck_col=out[4], tuck_row=out[5], tuck_rest=out[6])
                self.answers[w] = ans
                self.pending[w] = [self.lat, ans]
            if self.pending[w] is not None:
                if self.pending[w][0] <= 0:
                    a = self.pending[w][1]; ob = 0x5400 + w * 0x200
                    r.nes[ob + 0x85] = a["done_col"]; r.nes[ob + 0x86] = a["done_o4"]
                    r.nes[ob + 0x87] = a["tuck_col"]; r.nes[ob + 0x88] = a["tuck_row"]
                    r.nes[ob + 0x84] = 1
                    self.pending[w] = None
                else:
                    self.pending[w][0] -= 1

def run_match(args):
    gid, mode, lv1, sp1, lv2, sp2, s0, s1, latency, maxf = args
    rng = random.Random(gid * 31 + 7)
    r = Rom(ROM, LAB)
    same = gid % 3 == 0
    if same: lv2 = lv1
    r.start_game(lv1, sp1, s0, s1, mode=mode, level2=lv2, speed2=sp2, boards=0 if same else 1)
    m = M.MedMatch(lv1, sp1, lv2, sp2, s0, s1, same=same)
    cop = Copro(r, latency)
    cpu = [mode == 3, mode in (1, 3)]
    bots = [Bot(random.Random(gid * 2 + i), "greedy") for i in (0, 1)]
    styles = ["greedy", "greedy" if mode == 2 and gid % 2 == 0 else "random"]
    res = dict(gid=gid, mode=mode, lv=(lv1, lv2), sp=(sp1, sp2), seed=(s0 << 8) | s1, latency=latency,
               frames=0, match_frames=0, first_diff=None, rounds=[], cpu_locks=0, cpu_exact=0,
               cpu_miss=[], tucks=0, tuck_exact=0, garbage_events=0, searches=0, fmt_bad=0)
    def check_round_start():
        for i, base in ((0, 0x400), (1, 0x500)):
            if r.ram(base, 128) != m.p[i].encode():
                return False
        return True
    if not check_round_start():
        res["first_diff"] = dict(frame=-1, field="virus_board"); return res
    last_t = r.r("ticks"); last_round = r.r("round_no")
    prev_state = [M.SPAWN, M.SPAWN]; go_board = [None, None]; go_cur = [None, None]
    stall = 0
    while res["frames"] < maxf:
        expect = [None, None]
        for i in (0, 1):
            g = m.p[i]
            if cpu[i] and g.state == M.SPAWN and not g.gq and not g.b.spawn_blocked():
                # cart publishes on the spawn frame with the NEW current/next capsule
                nid_cur = g.ids[g.pidx]; nid_nxt = g.ids[(g.pidx + 1) & 127]
                expect[i] = enc_cart(g.encode(), nid_cur, nid_nxt, g.speed, g.speedups)
        ins = []
        for i in (0, 1):
            if cpu[i]: ins.append(0)
            elif styles[i] == "greedy": ins.append(bots[i].greedy_inp(m.p[i]))
            else: ins.append(bots[i].random_inp())
        ms = r.r("mstate")
        if ms != 0:
            ins = [0x10 if (res["frames"] + stall) % 8 == 0 else 0, 0]
        r.step(ins[0], btn2=ins[1])
        cop.poll(expect)
        t = r.r("ticks"); rn = r.r("round_no")
        if rn != last_round:
            last_round = rn
            if r.r("mode") != 2: break
            m.new_round()
            prev_state = [M.SPAWN, M.SPAWN]
            if not check_round_start():
                res["first_diff"] = dict(frame=res["frames"], field="virus_board_round%d" % rn); break
            last_t = t
            continue
        if t == last_t:
            stall += 1
            if r.r("mstate") == 2 and stall > 30: break
            if stall > 400:
                res["first_diff"] = dict(frame=res["frames"], field="stalled"); break
            continue
        stall = 0; last_t = t
        u1, u2 = r.r("P1::dbg_inp"), r.r("P2::dbg_inp")
        before = [m.p[i].encode() for i in (0, 1)]
        gq_before = [len(m.p[i].gq) for i in (0, 1)]
        w = m.frame(u1, u2)
        res["frames"] += 1
        bad = []
        for i, (p, base) in enumerate((("P1::", 0x400), ("P2::", 0x500))):
            a, b = rom_snap(r, p, base), m.p[i].snapshot()
            for k in a:
                if a[k] != b[k]:
                    bad.append("%s%s" % (p, k) if k == "board" else "%s%s rom=%s sim=%s" % (p, k, a[k], b[k]))
        if bad:
            res["first_diff"] = dict(frame=res["frames"], field=bad); break
        res["match_frames"] += 1
        for i in (0, 1):
            g = m.p[i]
            if len(g.gq) > gq_before[i]: res["garbage_events"] += 1
            if cpu[i] and prev_state[i] == M.SPAWN and g.state == M.FALL:
                go_board[i] = before[i]; go_cur[i] = g.cur
            if cpu[i] and prev_state[i] == M.FALL and g.state == M.CHECK:
                ans = cop.answers[i]
                placed = {(k // 8, k % 8, v & 3) for k, v in enumerate(g.encode())
                          if v and not before[i][k]}
                res["cpu_locks"] += 1
                if ans is not None:
                    exp = expected_cells(go_board[i], ans, go_cur[i])
                    tuck = ans["tuck_col"] != 0xFF
                    res["tucks"] += tuck
                    same = tuck and ans["tuck_col"] == ans["done_col"]
                    res["tuck_samecol"] = res.get("tuck_samecol", 0) + same
                    if same and placed == exp: res["tuck_samecol_exact"] = res.get("tuck_samecol_exact", 0) + 1
                    if placed == exp:
                        res["cpu_exact"] += 1; res["tuck_exact"] += tuck
                    elif len(res["cpu_miss"]) < 5:
                        res["cpu_miss"].append(dict(p=i, ok=r.r("P%d::ai_ok" % (i + 1)), ty=r.r("P%d::ai_ty" % (i + 1)), frame=res["frames"], ans=ans, placed=sorted(placed), exp=sorted(exp), board=go_board[i]))
            prev_state[i] = g.state
        if w is not None:
            res["rounds"].append(dict(winner=w, by=("clear" if m.p[w].state == M.WIN else "topout")))
            if max(m.wins) >= 2:
                pass
    res["wins"] = m.wins
    res["rom_wins"] = (r.r("P1::wins"), r.r("P2::wins"))
    res["searches"] = cop.searches; res["fmt_bad"] = cop.fmt_bad
    res["search_us_avg"] = cop.us / max(cop.searches, 1)
    return res

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 24
    workers = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    modes = [int(x) for x in (sys.argv[3] if len(sys.argv) > 3 else "3,2,1").split(",")]
    lat = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    rng = random.Random(4242 + lat)
    jobs = []
    for i in range(n):
        mode = modes[i % len(modes)]
        lv1, lv2 = rng.choice([0, 2, 4, 6, 8, 10, 12, 15, 20]), rng.choice([0, 2, 4, 6, 8, 10, 12, 15, 20])
        s = rng.randrange(1, 65536)
        jobs.append((i, mode, lv1, rng.randrange(3), lv2, rng.randrange(3), s >> 8, s & 255, lat, 60000))
    t0 = time.time()
    with Pool(workers) as p:
        out = p.map(run_match, jobs, chunksize=1)
    tot = sum(x["frames"] for x in out); ok = sum(x["match_frames"] for x in out)
    summ = dict(matches=n, latency=lat, fully_matched=sum(x["first_diff"] is None for x in out),
                frames=tot, frames_matched=ok, rate=ok / max(tot, 1),
                rounds=sum(len(x["rounds"]) for x in out),
                cpu_locks=sum(x["cpu_locks"] for x in out), cpu_exact=sum(x["cpu_exact"] for x in out),
                tucks=sum(x["tucks"] for x in out), tuck_exact=sum(x["tuck_exact"] for x in out),
                tuck_samecol=sum(x.get("tuck_samecol", 0) for x in out),
                tuck_samecol_exact=sum(x.get("tuck_samecol_exact", 0) for x in out),
                garbage_events=sum(x["garbage_events"] for x in out),
                searches=sum(x["searches"] for x in out), fmt_bad=sum(x["fmt_bad"] for x in out),
                seconds=round(time.time() - t0, 1))
    by = {}
    for x in out:
        for rd in x["rounds"]:
            key = "mode%d_P%d_%s" % (x["mode"], rd["winner"] + 1, rd["by"])
            by[key] = by.get(key, 0) + 1
    summ["round_outcomes"] = by
    os.makedirs("test/results", exist_ok=True)
    json.dump(dict(summary=summ, matches=out), open("test/results/vs_lat%d.json" % lat, "w"), indent=1)
    print(json.dumps(summ, indent=1))
    for x in out:
        if x["first_diff"] or x["cpu_miss"]:
            print("ISSUE", x["gid"], x["mode"], x["lv"], hex(x["seed"]), x["first_diff"], x["cpu_miss"][:1])
