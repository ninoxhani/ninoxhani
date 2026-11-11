"""One-at-a-time changes to Scalper Pro v1.21 (final market model), whole clean period split IS / OOS."""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import multiprocessing as mp
PURE = dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0)
TESTS = [
    ("v1.21 defaults", {}),
    ("no slow-EMA close exit", dict(ema_exit=False)),
    ("no stale exit", dict(stale_bars=0)),
    ("no break-even", dict(be_trig=0)),
    ("no early exits at all", PURE),
    ("target 2R", dict(rr=2.0)),
    ("target 3R, no early exits", dict(PURE, rr=3.0)),
    ("cross entries only", dict(use_cont=False)),
    ("continuation only", dict(use_cross=False)),
    ("trend filter H1 instead of M5", dict(trend_tf=60)),
    ("no flat filter", dict(flat_filter=False)),
    ("London+NY only (09-19 server)", dict(sessions=[(9, 19)])),
    ("entries on M5, trend H1", dict(entry_tf=5, trend_tf=60)),
    ("entries on M15, trend H1", dict(entry_tf=15, trend_tf=60)),
    ("H: cross + trailing stop", dict(use_cont=False, ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0,
                                      trail_start=1.0, trail_atr=1.5, rr=4.0)),
]
D = None
def init():
    global D; D = load()
def work(it):
    k, over = it
    _, tr = bt.run(D, over, collect=True)
    return k, segment(D, tr, IS_START, OOS_START)[0], segment(D, tr, OOS_START, END)[0], segment(D, tr, IS_START, END)[0]
if __name__ == "__main__":
    with mp.Pool(4, initializer=init) as p:
        res = p.map(work, TESTS)
    print(f"{'variant':32s} {'trades/day':>10s} {'win':>5s} {'avgR Feb-Jun':>12s} {'avgR Jul-Nov':>12s} {'total R':>8s} {'PF':>5s} {'maxDD R':>8s}")
    for k, si, so, sa in res:
        print(f"{k:32s} {sa['pday']:10.1f} {sa['win']:5.0%} {si['avg']:+12.3f} {so['avg']:+12.3f} {sa['tot']:+8.1f} {sa['pf']:5.2f} {sa['dd']:8.1f}")
