"""Reporting only (selection is finished): does in-sample performance predict out-of-sample performance?"""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import json, multiprocessing as mp, collections
import r12_grid2 as g
D = None
def init():
    global D; D = load()
def work(item):
    name, over = item
    over = dict(over, fund_excl=(0, 0))            # as the EA would trade
    _, tr = bt.run(D, over, collect=True)
    return name, segment(D, tr, IS_START, OOS_START)[0], segment(D, tr, OOS_START, END)[0]
if __name__ == "__main__":
    items = list(g.configs())
    with mp.Pool(4, initializer=init) as p:
        res = p.map(work, items, chunksize=8)
    json.dump(res, open(os.path.join(RD, "grid_is_oos.json"), "w"))
    ok = [r for r in res if r[1]["n"] >= 120 and r[2]["n"] >= 60]
    isr = np.array([r[1]["avg"] for r in ok]); oos = np.array([r[2]["avg"] for r in ok])
    print(f"variants with enough trades: {len(ok)}")
    print(f"share profitable: IS {np.mean(isr > 0):.0%}, OOS {np.mean(oos > 0):.0%}")
    print(f"correlation IS avgR vs OOS avgR across variants: {np.corrcoef(isr, oos)[0, 1]:+.2f}")
    for q in (0.5, 0.9, 0.97):
        thr = np.quantile(isr, q)
        sel = oos[isr >= thr]
        print(f"best {1 - q:.0%} by IS (avgR >= {thr:+.3f}, n={len(sel)}): OOS median {np.median(sel):+.3f}, OOS profitable {np.mean(sel > 0):.0%}")
    print(f"OOS avgR over all variants: median {np.median(oos):+.3f}, p95 {np.percentile(oos, 95):+.3f}, max {oos.max():+.3f}")
    print("\nOOS median avg R by entry timeframe and management:")
    fam = collections.defaultdict(list)
    for n_, si, so in ok:
        pp = n_.split("_"); fam[(pp[0], pp[4])].append((si["avg"], so["avg"]))
    for k in sorted(fam):
        v = np.array(fam[k]); print(f"   {k[0]:4s} {k[1]:6s} IS median {np.median(v[:, 0]):+.3f}  OOS median {np.median(v[:, 1]):+.3f}  OOS>0 {np.mean(v[:, 1] > 0):.0%}  (n={len(v)})")
    print("\nTop 10 by OOS (for information only - choosing from this list would be hindsight):")
    ok.sort(key=lambda r: -r[2]["avg"])
    for n_, si, so in ok[:10]:
        print(f"   {n_:38s} IS {si['n']:4d} {si['avg']:+.3f}  OOS {so['n']:4d} {so['avg']:+.3f}")
    # fixed (never tuned) strategies, whole clean period
    print("\nFixed original strategies (no tuning), Feb 1 - Nov 10 2026:")
    for lab, over in (("SCALPER PRO v1.21 defaults", {}),
                      ("PULLBACK baseline (robot 1)", dict(mode="pullback", rr=1.5, max_trades_day=5, flat_filter=False)),
                      ("CROSSOVER v1.10", dict(mode="crossover", trend_filter=False, flat_filter=False))):
        _, tr = bt.run(D if D is not None else load(), over, collect=True) if D is not None else bt.run(load(), over, collect=True)
        dd = load() if D is None else D
        sa, sela = segment(dd, tr, IS_START, END)
        so, selo = segment(dd, tr, OOS_START, END)
        print(f"   {lab:28s} ALL {bt.fmt(sa)}")
        print(f"   {'':28s} OOS {bt.fmt(so)}")
