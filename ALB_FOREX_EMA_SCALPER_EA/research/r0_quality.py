import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import datetime
data = load()
E = data.tf(1, 8, 14, 14, 100)
flat = (data.h == data.l)
print("M1 bars:", len(data.t), "zero-range bars:", int(flat.sum()), f"({flat.mean():.2%})")
z = np.flatnonzero(E["atr"] == 0)
print("bars with ATR14==0:", len(z))
if len(z):
    # group into runs
    runs = np.split(z, np.flatnonzero(np.diff(z) != 1) + 1)
    for r in runs[:10]:
        print("  run", datetime.datetime.fromtimestamp(int(E["t"][r[0]]), datetime.UTC), "len", len(r), "price", E["c"][r[0]])
# zero-range share by hour
hr = (data.t % 86400) // 3600
print("zero-range share by UTC hour:", " ".join(f"{h}:{flat[hr==h].mean():.1%}" for h in range(24) if (hr==h).any()))
# median M1 range by hour
rngv = data.h - data.l
print("median M1 range by UTC hour:", " ".join(f"{h}:{np.median(rngv[hr==h]):.2f}" for h in range(24) if (hr==h).any()))
