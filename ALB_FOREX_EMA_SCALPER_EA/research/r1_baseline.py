import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import time, datetime
from common import *

data = load()
print("M1 bars (market hours):", len(data.t), "days:", data.days)
# price context per month (closing price)
import collections
mc = collections.OrderedDict()
for t, c in zip(data.t[::60], data.c[::60]):
    mc[datetime.datetime.fromtimestamp(int(t), datetime.UTC).strftime("%Y-%m")] = c
print("month-end close:", " ".join(f"{k}:{v:.0f}" for k, v in mc.items()))
E = data.tf(1, 8, 14, 14, 100)
print("median M1 ATR by month:", " ".join(f"{k[5:]}:{v:.2f}" for k, v in
      [(m, float(np.median(E['atr'][(np.array([datetime.datetime.fromtimestamp(int(x), datetime.UTC).strftime('%Y-%m') for x in E['t'][::1]]) == m)]))) for m in list(mc)[:]]))
for name, over in [("SCALPER PRO v1.21", {}),
                   ("PULLBACK baseline", dict(mode="pullback", rr=1.5, max_trades_day=5, flat_filter=False)),
                   ("CROSSOVER", dict(mode="crossover", trend_filter=False, flat_filter=False)),
                   ]:
    t0 = time.time()
    s, tr = split(data, over, "IS", collect=True)
    print(f"{name:22s} IS  {bt.fmt(s)}   ({time.time()-t0:.1f}s)")
    if name.startswith("SCALPER"):
        reasons = bt.by_key(tr, lambda x: x[4])
        print("   exits:", {k: (v[0], round(v[1], 1)) for k, v in reasons.items()})
        kinds = bt.by_key(tr, lambda x: {1: "cross", 2: "cont"}[x[5]])
        print("   kinds:", {k: (v[0], round(v[1], 1), f"{v[2]/v[0]:.0%}") for k, v in kinds.items()})
        hrs = bt.by_key(tr, lambda x: int((x[0] % 86400) // 3600))
        print("   by UTC hour:", " ".join(f"{h}:{hrs[h][1]:+.0f}/{hrs[h][0]}" for h in sorted(hrs)))
        mon = bt.by_month(tr)
        print("   by month:", " ".join(f"{k[2:]}:{v:+.0f}" for k, v in mon.items()))
        costR = np.mean([(0.10 + 2*0.02 + 0.07) / x[6] for x in tr])
        print(f"   avg round-trip cost ~{costR:.3f} R per trade; avg risk {np.mean([x[6] for x in tr]):.2f} USD/oz")
