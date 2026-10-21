"""Lock-step ROM vs reference diff over many seeded games with scripted inputs."""
import sys, os, json, random, time
from multiprocessing import Pool
sys.path.insert(0, "test"); sys.path.insert(0, "ref")
from emu import Rom
import medsim as M

ROM, LAB = "build/medschool.nes", "build/medschool.labels"

def rom_snap(r):
    st = r.r("state")
    return dict(board=r.ram(0x400, 128), state=st,
                pill=(r.r("px"), r.r("py"), r.r("po")) if st == M.FALL else None,
                cur=r.r("cur_id"), pidx=r.r("pidx"),
                score=r.r("score") | r.r("score", 1) << 8 | r.r("score", 2) << 16,
                vcount=r.r("vcount"), speedups=r.r("speedups"))

class Bot:
    """Mix of random button mashing and a greedy placer driven from the sim."""
    def __init__(self, rng, style):
        self.rng, self.style, self.seq, self.plan_for = rng, style, [], None
    def random_inp(self):
        if not self.seq:
            combo = self.rng.choice([0, M.LEFT, M.RIGHT, M.DOWN, M.A, M.B, M.LEFT | M.A,
                                     M.RIGHT | M.B, M.DOWN | M.LEFT, M.A | M.B, M.UP])
            self.seq = [combo] * self.rng.choice([1, 1, 2, 3, 5, 8, 17, 24, 40])
            if self.rng.random() < 0.5:
                self.seq += [0] * self.rng.randint(1, 3)
        return self.seq.pop(0)
    def greedy_inp(self, g):
        if g.state != M.FALL:
            self.plan_for = None
            return 0
        key = (g.pidx, g.locked, g.speedups)
        if self.plan_for != key:
            self.plan_for = key
            self.seq = self.plan(g)
        return self.seq.pop(0) if self.seq else M.DOWN
    def plan(self, g):
        import copy
        from drmario.planner import GreedyPlanner
        from drmario.faithful_game import Pill
        if not hasattr(Bot, "_P"):
            Bot._P = GreedyPlanner(depth=1)
        a, b = M.PILL_COLORS[g.cur]
        na, nb = M.PILL_COLORS[g.nxt]
        act = Bot._P.choose(copy.deepcopy(g.b), Pill(a, b), Pill(na, nb))
        if act is None:
            return [M.DOWN] * 40
        variant, x = divmod(act, 8)
        o = {0: 0, 1: 2, 2: 3, 3: 1}[variant]
        rot = {0: [], 1: [M.B], 2: [M.B, 0, M.B], 3: [M.A]}[o]
        seq = rot + [0]
        step = M.RIGHT if x > 3 else M.LEFT
        for _ in range(abs(x - 3)):
            seq += [step, 0]
        return seq + [M.DOWN] * 40

def run_game(args):
    gid, level, speed, s0, s1, style, maxf = args
    rng = random.Random(gid * 7919 + 1)
    r = Rom(ROM, LAB)
    r.start_game(level, speed, s0, s1)
    g = M.MedGame(level, speed, s0, s1)
    res = dict(gid=gid, level=level, speed=speed, seed=(s0 << 8) | s1, style=style,
               frames=0, match_frames=0, first_diff=None, outcome=None, locks=0)
    # initial board (viruses) check before any frame
    if rom_snap(r)["board"] != g.encode():
        res["first_diff"] = dict(frame=-1, field="virus_board")
        return res
    bot = Bot(rng, style)
    last_gf = r.r("gframe") | r.r("gframe", 1) << 8
    stalls = 0
    while res["frames"] < maxf:
        inp = bot.greedy_inp(g) if style == "greedy" else bot.random_inp()
        r.step(inp)
        gf = r.r("gframe") | r.r("gframe", 1) << 8
        if gf == last_gf:
            stalls += 1
            if stalls > 5:
                res["first_diff"] = dict(frame=res["frames"], field="rom_stalled"); break
            continue
        stalls = 0
        last_gf = gf
        used = r.r("dbg_inp")
        g.frame(used)
        a, b = rom_snap(r), g.snapshot()
        res["frames"] += 1
        if a != b:
            bad = [k for k in a if a[k] != b[k]]
            res["first_diff"] = dict(frame=res["frames"], field=bad,
                                     rom={k: a[k] for k in bad if k != "board"},
                                     sim={k: b[k] for k in bad if k != "board"})
            break
        res["match_frames"] += 1
        if g.state in (M.WIN, M.LOSE):
            res["outcome"] = "win" if g.state == M.WIN else "lose"
            break
    res["score"] = g.score * 100
    res["vleft"] = g.vcount
    return res

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    workers = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    maxf = 30000
    rng = random.Random(2026)
    jobs = []
    for i in range(n):
        level = rng.choice(list(range(0, 21)) + [0, 0, 1, 1, 2, 3])
        speed = rng.randrange(3)
        s = rng.randrange(1, 65536)
        style = "greedy" if i % 2 == 0 else "random"
        jobs.append((i, level, speed, s >> 8, s & 255, style, maxf))
    t0 = time.time()
    with Pool(workers) as p:
        results = p.map(run_game, jobs, chunksize=1)
    tot = sum(x["frames"] for x in results); ok = sum(x["match_frames"] for x in results)
    full = sum(1 for x in results if x["first_diff"] is None)
    wins = sum(1 for x in results if x["outcome"] == "win")
    loses = sum(1 for x in results if x["outcome"] == "lose")
    summary = dict(games=n, games_fully_matched=full, frames=tot, frames_matched=ok,
                   frame_match_rate=ok / max(tot, 1), wins=wins, losses=loses,
                   capped=n - wins - loses - (n - full), seconds=round(time.time() - t0, 1))
    os.makedirs("test/results", exist_ok=True)
    json.dump(dict(summary=summary, games=results), open("test/results/compare.json", "w"), indent=1)
    print(json.dumps(summary, indent=1))
    for x in results:
        if x["first_diff"]:
            print("DIFF", x["gid"], x["level"], x["speed"], hex(x["seed"]), x["style"], x["first_diff"])
