import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
data = load()
PURE = dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0)
A_all = dict(entry_tf=1, trend_tf=5, use_cross=False, rr=3.0, **PURE)
s, tr = split(data, A_all, "IS", collect=True)
def before(x, hours, a=60):
    m = int((x[0] % 86400) // 60)
    return any(0 < ((h * 60 - m) % 1440) <= a for h in hours)
groups = {"60 min before 00/08/16 UTC (funding)": (0, 8, 16),
          "placebo: before 04/12/20 UTC": (4, 12, 20),
          "placebo: before 02/10/18 UTC": (2, 10, 18),
          "placebo: before 06/14/22 UTC": (6, 14, 22)}
for lab, hs in groups.items():
    sel = [x for x in tr if before(x, hs)]
    r = np.array([x[3] for x in sel])
    print(f"{lab:40s} n={len(r):4d} R={r.sum():+7.1f} avg={r.mean():+.3f}")
rest = [x for x in tr if not before(x, (0, 8, 16))]
r = np.array([x[3] for x in rest]); print(f"{'all other times':40s} n={len(r):4d} R={r.sum():+7.1f} avg={r.mean():+.3f}")
# market-level test (no strategy): trend persistence of 1-min returns in the hour before each UTC hour
t, c = data.t, data.c
m = (t >= IS_START) & (t < OOS_START)
ret = np.diff(c) ; tt = t[1:]; ok = (np.diff(t) == 60) & m[1:]
hour_of = (tt % 86400) // 3600
print("\nlag-1 autocorrelation of 1-min returns by UTC hour (IS, positive = trending):")
out = []
for h in range(24):
    sel = ok & (hour_of == h)
    idx = np.flatnonzero(sel)
    idx = idx[idx > 0]
    idx = idx[ok[idx - 1]]
    if len(idx) < 500:
        continue
    a, b = ret[idx], ret[idx - 1]
    out.append(f"{h}:{np.corrcoef(a, b)[0, 1]:+.3f}")
print("  " + " ".join(out))
# 5-min returns: variance ratio VR(5) = var(5-min) / (5 var(1-min)) by UTC hour, >1 trending
print("variance ratio VR(5) of returns by UTC hour (>1 = trending, <1 = mean-reverting):")
out = []
for h in range(24):
    sel = ok & (hour_of == h)
    r1 = ret[sel]
    idx = np.flatnonzero(sel)
    r5 = np.array([c[i + 5] - c[i] for i in idx if i + 5 < len(c) and t[i + 5] - t[i] == 300])
    if len(r1) < 500:
        continue
    out.append(f"{h}:{np.var(r5) / (5 * np.var(r1)):.2f}")
print("  " + " ".join(out))
