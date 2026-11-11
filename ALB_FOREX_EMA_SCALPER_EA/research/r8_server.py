import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import multiprocessing as mp
PURE = dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0)
A = dict(entry_tf=1, trend_tf=5, use_cross=False, rr=3.0, **PURE)
C = dict(entry_tf=1, trend_tf=5, htf=240, use_cont=False, rr=6.0, ema_exit=False, stale_bars=0, opp_cross_exit=False,
         be_trig=0, trail_start=1.0, trail_atr=1.5)
SV = {"01-09": [(1, 9)], "01.5-09": [(1.5, 9)], "02-09": [(2, 9)], "03-09": [(3, 9)], "01-05": [(1, 5)],
      "02-06": [(2, 6)], "05-09": [(5, 9)], "09-14": [(9, 14)], "14-19": [(14, 19)], "19-24": [(19, 24)],
      "09-19": [(9, 19)], "all": None}
D = None
def init():
    global D; D = load()
def work(it):
    k, over = it
    _, tr = bt.run(D, over, collect=True)
    return k, seg_stats(D, tr)
if __name__ == "__main__":
    items = [("v1.21 default (all hours)", {}), ("v1.21 default 01.5-09", dict(sessions=[(1.5, 9)]))]
    for k, v in SV.items():
        items.append((f"A {k}", dict(A, sessions=v)))
    for k in ("01-09", "01.5-09", "02-09"):
        for t in (15, 60):
            items.append((f"A {k} T{t}", dict(A, sessions=SV[k], trend_tf=t)))
        items.append((f"A {k} T5+H240", dict(A, sessions=SV[k], htf=240)))
        items.append((f"A {k} no trend", dict(A, sessions=SV[k], trend_filter=False)))
    for k in ("09-14", "14-19", "09-19", "all"):
        items.append((f"C {k}", dict(C, sessions=SV[k])))
    with mp.Pool(4, initializer=init) as p:
        res = p.map(work, items)
    for k, s in res:
        print(f"{k:26s} IS1 {s['IS1']['n']:4d} {s['IS1']['avg']:+.3f} | IS2 {s['IS2']['n']:4d} {s['IS2']['avg']:+.3f} | IS {s['IS']['tot']:+7.1f}R PF {s['IS']['pf']:.2f} DD {s['IS']['dd']:5.1f} /day {s['IS']['pday']:.2f} win {s['IS']['win']:.0%}")
