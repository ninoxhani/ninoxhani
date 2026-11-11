import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
data = load()

def fwd_table(etf, ttf, label_extra=""):
    E = data.tf(etf, 8, 14, 14, 100)
    T = data.tf(ttf, 8, 14, 14, 100) if ttf else None
    t, o, c, ef, es, a = E["t"], E["o"], E["c"], E["ef"], E["es"], E["atr"]
    n = len(t)
    isk = (t >= IS_START) & (t < OOS_START)
    f1, w1, f2, w2 = bt._sh(ef, 1), bt._sh(es, 1), bt._sh(ef, 2), bt._sh(es, 2)
    a1 = bt._sh(a, 1)
    with np.errstate(invalid="ignore"):
        cross = np.where((f2 <= w2) & (f1 > w1), 1, np.where((f2 >= w2) & (f1 < w1), -1, 0))
        state = np.nan_to_num(np.sign(f1 - w1)).astype(int)
    if T is not None:
        tdir, fu, fd = bt._trend_cols(T, t, dict(flat_bars=3, flat_sep=0.10, flat_slope=0.10))
    else:
        tdir = np.zeros(n, int)
    H = [1, 3, 5, 10, 20, 40]
    def stats(mask, d):
        idx = np.flatnonzero(mask & isk)
        idx = idx[(idx > 200) & (idx < n - 41)]
        idx = idx[a1[idx] > 0]
        out = []
        for h in H:
            fr = (c[idx + h - 1] - o[idx]) * d[idx] / a1[idx]
            out.append(np.nanmean(fr))
        return len(idx), out
    rows = [
        ("cross (any)", cross != 0, cross),
        ("cross with trend", (cross != 0) & (cross == tdir), cross),
        ("cross against trend", (cross != 0) & (cross == -tdir), cross),
        ("EMA state, every bar", state != 0, state),
        ("trend dir, every bar", tdir != 0, tdir),
        ("state==trend, every bar", (state != 0) & (state == tdir), state),
    ]
    print(f"--- entry M{etf}, trend M{ttf}  (mean forward move in ATR(entry) units, in signal direction; IS only)")
    print("   " + " ".join(f"{'h='+str(h):>8s}" for h in H) + "   n")
    for name, m, d in rows:
        nn, st = stats(m, d)
        print(f"{name:24s}" + " ".join(f"{v:+8.3f}" for v in st) + f"   {nn}")

for etf, ttf in [(1, 5), (1, 60), (5, 60), (15, 60), (15, 240), (60, 240)]:
    fwd_table(etf, ttf)
