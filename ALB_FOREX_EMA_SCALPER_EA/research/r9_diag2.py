import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
data = load()
PURE = dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0)
A = dict(entry_tf=1, trend_tf=5, use_cross=False, rr=3.0, sessions=[(2, 9)], **PURE)
C = dict(entry_tf=1, trend_tf=5, htf=240, use_cont=False, rr=6.0, ema_exit=False, stale_bars=0, opp_cross_exit=False,
         be_trig=0, trail_start=1.0, trail_atr=1.5)
STRESS1 = dict(spread=0.15, spread_asia=0.24, spread_open1=0.60, spread_open2=0.40, slip=0.04)
STRESS2 = dict(spread=0.20, spread_asia=0.32, spread_open1=0.80, spread_open2=0.50, slip=0.06, comm=0.10)
def shour(x):
    t = np.array([x[0]])
    return int(((t + bt.server_offset(t)) % 86400 // 3600)[0])
for name, over in (("A Asia 02-09", A), ("C all hours", C)):
    s, tr = split(data, over, "IS", collect=True)
    print(f"\n=== {name}\n    IS            {bt.fmt(s)}")
    print(f"    stress x1.5   {bt.fmt(split(data, dict(over, **STRESS1), 'IS'))}")
    print(f"    stress x2     {bt.fmt(split(data, dict(over, **STRESS2), 'IS'))}")
    mon = bt.by_month(tr)
    print("    by month:", " ".join(f"{k[2:]}:{v:+.1f}" for k, v in mon.items()))
    hrs = bt.by_key(tr, shour)
    print("    by SERVER hour (R/n):", " ".join(f"{h}:{hrs[h][1]:+.0f}/{hrs[h][0]}" for h in sorted(hrs)))
    wd = bt.by_key(tr, lambda x: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][int(((x[0] + 10800) // 86400 + 3) % 7)])
    print("    by weekday:", {k: (v[0], round(v[1], 1)) for k, v in wd.items()})
    r = np.array([x[3] for x in tr])
    # bootstrap of mean R (by day blocks) for a rough confidence interval
    days = np.array([int((x[0] + 10800) // 86400) for x in tr])
    ud = np.unique(days)
    dayR = np.array([r[days == u].sum() for u in ud])
    rng = np.random.default_rng(1)
    bs = [rng.choice(dayR, len(dayR)).sum() for _ in range(4000)]
    print(f"    total {r.sum():+.1f}R over {len(ud)} trading days; day-block bootstrap 5-95%: {np.percentile(bs, 5):+.1f} .. {np.percentile(bs, 95):+.1f} R; P(total<=0) = {np.mean(np.array(bs) <= 0):.3f}")
    top = np.sort(r)[::-1]
    print(f"    best 10 trades sum {top[:10].sum():+.1f}R; total without them {r.sum() - top[:10].sum():+.1f}R")
