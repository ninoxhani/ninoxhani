import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
data = load()
H = dict(use_cont=False, ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0, trail_start=1.0, trail_atr=1.5, rr=4.0)
for lab, over in (("H", H), ("v1.21", {})):
    _, tr = bt.run(data, over, collect=True)
    s, sel = segment(data, tr, IS_START, END)
    r = np.array([x[3] for x in sel])
    days = np.array([int((x[0] + 10800) // 86400) for x in sel])
    ud = np.unique(days); dayR = np.array([r[days == u].sum() for u in ud])
    rng = np.random.default_rng(7)
    bs = np.array([rng.choice(dayR, len(dayR)).sum() for _ in range(5000)])
    print(f"{lab}: n={len(r)} avg={r.mean():+.4f} sd={r.std():.3f} t={r.mean()/(r.std()/np.sqrt(len(r))):+.2f} total={r.sum():+.1f}R "
          f"bootstrap90%=[{np.percentile(bs,5):+.1f},{np.percentile(bs,95):+.1f}] P(<=0)={np.mean(bs<=0):.2f} median risk {np.median([x[6] for x in sel]):.2f} USD/oz")
    mon = bt.by_month(sel); print("   by month:", " ".join(f"{k[2:]}:{v:+.1f}" for k, v in mon.items()))
