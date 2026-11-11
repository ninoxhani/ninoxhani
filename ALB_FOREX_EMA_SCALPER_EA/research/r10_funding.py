import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
data = load()
PURE = dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0)
A_all = dict(entry_tf=1, trend_tf=5, use_cross=False, rr=3.0, **PURE)
DST = calendar.timegm((2026, 3, 8, 7, 0, 0))
s, tr = split(data, A_all, "IS", collect=True)
def uh(x): return int((x[0] % 86400) // 3600)
for lab, sel in (("WINTER Feb1-Mar7 (server=UTC+2)", [x for x in tr if x[0] < DST]),
                 ("SUMMER Mar8-Jun30 (server=UTC+3)", [x for x in tr if x[0] >= DST])):
    h = bt.by_key(sel, uh)
    print(lab)
    print("   UTC hour R/n:", " ".join(f"{k}:{h[k][1]:+.0f}/{h[k][0]}" for k in sorted(h)))
# minutes around 00:00 UTC (both seasons), also around the other funding times 08:00 and 16:00 UTC
def mwin(x, c):
    m = int((x[0] % 86400) // 60)
    d = (m - c + 720) % 1440 - 720
    return d
for c, lab in ((0, "00:00 UTC (Tokyo open + funding)"), (8 * 60, "08:00 UTC (funding, ~London open)"), (16 * 60, "16:00 UTC (funding)"), (60, "01:00 UTC (Shanghai open)")):
    for a, b in ((-60, -30), (-30, 0), (0, 30), (30, 60), (60, 120)):
        sel = [x for x in tr if a <= mwin(x, c) < b]
        if sel:
            r = np.array([x[3] for x in sel])
            print(f"   {lab:36s} [{a:+4d},{b:+4d}) min: n={len(r):4d} R={r.sum():+6.1f} avg={r.mean():+.3f}")
