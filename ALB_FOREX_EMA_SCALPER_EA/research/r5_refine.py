"""One-at-a-time refinement of secondary parameters around base configs (IS only)."""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import json, multiprocessing as mp

VARS = {
    "flat_sep": [0.0, 0.05, 0.10, 0.20, 0.30],
    "flat_slope": [0.0, 0.05, 0.10, 0.20, 0.30],
    "body_ratio": [0.0, 0.25, 0.40, 0.55],
    "sl_bars": [3, 5, 8, 12],
    "sl_buf": [0.0, 0.15, 0.30],
    "sl_min": [0.5, 0.8, 1.2, 1.6],
    "sl_max": [1.5, 2.5, 3.5],
    "min_slope": [0.0, 0.05, 0.10, 0.20],
    "max_per_leg": [1, 2, 3, 5, 0],
    "be_trig": [0.0, 0.6, 1.0, 1.5],
    "cooldown_bars": [0, 3, 6],
    "max_consec": [0, 2, 3, 5],
    "atr_spike_max": [0, 2.0, 2.5, 3.5],
    "trail_start": [0.5, 1.0, 1.5, 2.0],
    "trail_atr": [1.0, 1.5, 2.0, 3.0],
    "rr": [3.0, 4.0, 6.0, 10.0],
    "trend_tf": [15, 30, 60, 120, 240],
    "htf": [0, 120, 240, 1440],
    "use_cross": [True, False],
    "fund_excl": [(0, 0), (60, 30), (90, 60)],
    "stale_bars": [0, 6, 12],
    "ema_exit": [True, False],
    "sessions": [None, [(2, 23)], [(9, 23)], [(2, 9)]],
}

D = None
def init():
    global D
    D = load()

def work(item):
    tag, over = item
    _, tr = bt.run(D, over, collect=True)
    return tag, seg_stats(D, tr)

def line(tag, s):
    return (f"{tag:34s} IS1 {s['IS1']['n']:4d} {s['IS1']['avg']:+.3f} | IS2 {s['IS2']['n']:4d} {s['IS2']['avg']:+.3f} | "
            f"IS {s['IS']['tot']:+7.1f}R PF {s['IS']['pf']:.2f} DD {s['IS']['dd']:5.1f} /day {s['IS']['pday']:.2f} win {s['IS']['win']:.0%}")

if __name__ == "__main__":
    bases = json.loads(sys.argv[1])
    items = []
    for bname, base in bases.items():
        items.append((f"{bname} | BASE", base))
        for k, vals in VARS.items():
            for v in vals:
                if base.get(k, bt.DEFAULT_CFG[k]) == v:
                    continue
                if k == "htf" and v and v <= base.get("trend_tf", 5):
                    continue
                o = dict(base); o[k] = v
                items.append((f"{bname} | {k}={v}", o))
    with mp.Pool(4, initializer=init) as p:
        res = p.map(work, items, chunksize=4)
    for tag, s in res:
        print(line(tag, s))
