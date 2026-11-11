import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import datetime
d = load()
print("bars", len(d.t), "server days", d.days)
for day in ("2026-01-16", "2026-01-18", "2026-01-19", "2026-06-12", "2026-06-14", "2026-06-15"):
    a = calendar.timegm(time_tuple := datetime.datetime.strptime(day, "%Y-%m-%d").timetuple())
    sel = d.t[(d.t >= a) & (d.t < a + 86400)]
    if len(sel) == 0:
        print(day, "no bars"); continue
    gaps = np.flatnonzero(np.diff(sel) > 60)
    first = datetime.datetime.fromtimestamp(int(sel[0]), datetime.UTC).strftime("%H:%M")
    last = datetime.datetime.fromtimestamp(int(sel[-1]), datetime.UTC).strftime("%H:%M")
    gtxt = ", ".join(datetime.datetime.fromtimestamp(int(sel[g]), datetime.UTC).strftime("%H:%M") + "->" +
                     datetime.datetime.fromtimestamp(int(sel[g + 1]), datetime.UTC).strftime("%H:%M") for g in gaps)
    print(f"{day} UTC bars {len(sel)} first {first} last {last} gaps: {gtxt}")
sp = bt.spread_model(d.t, bt.DEFAULT_CFG)
print("spread distribution:", {float(v): int((sp == v).sum()) for v in np.unique(sp)})
