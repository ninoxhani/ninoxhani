"""Checks for the v1.30 default (hypothesis H + owner's wish: let winners run, RR >= 1:3, protect trades in profit)."""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import multiprocessing as mp
H = dict(use_cont=False, ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0, trail_start=1.0, trail_atr=1.5, rr=4.0)
REAL = dict(comm=0.08)                                   # IC Markets on 0.01 lot (rounded)
STRESS = dict(comm=0.08, spread=0.15, spread_asia=0.24, spread_open1=0.60, spread_open2=0.40, slip=0.04)
T = [
    ("H (research)", H),
    ("H, real commission 0.08", dict(H, **REAL)),
    ("H, x1.5 spreads + slip 0.04 + comm 0.08", dict(H, **STRESS)),
    ("H + break-even at +1R (lock 0.10R)", dict(H, be_trig=1.0, be_lock=0.10, **REAL)),
    ("H + break-even at +1R (lock 0.25R)", dict(H, be_trig=1.0, be_lock=0.25, **REAL)),
    ("H, target 3R", dict(H, rr=3.0, **REAL)),
    ("H, target 6R", dict(H, rr=6.0, **REAL)),
    ("H, trail 1.0 ATR", dict(H, trail_atr=1.0, **REAL)),
    ("H, trail 2.0 ATR", dict(H, trail_atr=2.0, **REAL)),
    ("H, trail starts +1.5R", dict(H, trail_start=1.5, **REAL)),
    ("fixed 1:3, no trailing (owner idea)", dict(H, trail_start=0.0, rr=3.0, **REAL)),
    ("fixed 1:4, no trailing (owner idea)", dict(H, trail_start=0.0, rr=4.0, **REAL)),
    ("v1.21 Scalper Pro (now on demo)", dict(REAL)),
]
D = None
def init():
    global D; D = load()
def work(it):
    k, over = it
    _, tr = bt.run(D, over, collect=True)
    a, sel = segment(D, tr, IS_START, END)
    r = np.array([x[3] for x in sel])
    t = r.mean() / (r.std() / np.sqrt(len(r))) if len(r) > 1 else 0
    ex = bt.by_key(sel, lambda x: x[4])
    big = sum(1 for x in sel if x[3] >= 2.0)
    return k, segment(D, tr, IS_START, OOS_START)[0], segment(D, tr, OOS_START, END)[0], a, t, ex, big
if __name__ == "__main__":
    with mp.Pool(4, initializer=init) as p:
        res = p.map(work, T)
    print(f"{'variant':42s} {'tr/day':>6s} {'win':>4s} {'avgR F-J':>8s} {'avgR J-N':>8s} {'totR':>7s} {'PF':>5s} {'maxDD':>6s} {'t':>5s} {'>=2R':>5s}")
    for k, si, so, a, t, ex, big in res:
        print(f"{k:42s} {a['pday']:6.1f} {a['win']:4.0%} {si['avg']:+8.3f} {so['avg']:+8.3f} {a['tot']:+7.1f} {a['pf']:5.2f} {a['dd']:6.1f} {t:+5.2f} {big:5d}")
    for k, si, so, a, t, ex, big in res[:1]:
        print("\nH exits:", {kk: (v[0], round(v[1], 1), f"{v[2]/v[0]:.0%} win") for kk, v in ex.items()})
