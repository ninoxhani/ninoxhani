import sys, os, datetime, calendar
RD = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, RD)
import numpy as np
import afx_bt as bt

# Dec 2025 (37% frozen minutes) and Jan 2026 (5%) are low-quality data: used only as indicator warm-up.
IS_START = calendar.timegm((2026, 2, 1, 0, 0, 0))
IS_MID = calendar.timegm((2026, 4, 16, 0, 0, 0))
OOS_START = calendar.timegm((2026, 7, 1, 0, 0, 0))
END = calendar.timegm((2026, 11, 11, 0, 0, 0))

def load():
    return bt.Data(os.path.join(RD, "xau_m1.npz"))

def _days(data, a, b):
    return len(np.unique(data.sday[(data.t >= a) & (data.t < b)]))

def segment(data, trades, a, b):
    sel = [x for x in trades if a <= x[0] < b]
    return bt.summarize(sel, _days(data, a, b)), sel

def split(data, over, part="IS", collect=False):
    _, tr = bt.run(data, over, collect=True)
    a, b = {"IS": (IS_START, OOS_START), "OOS": (OOS_START, END), "ALL": (IS_START, END)}[part]
    s, sel = segment(data, tr, a, b)
    return (s, sel) if collect else s

def seg_stats(data, trades):
    """In-sample only: first half, second half, whole. OOS is never included here."""
    return {name: segment(data, trades, a, b)[0] for name, a, b in
            (("IS1", IS_START, IS_MID), ("IS2", IS_MID, OOS_START), ("IS", IS_START, OOS_START))}
