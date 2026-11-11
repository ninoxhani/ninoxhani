"""ONE-SHOT out-of-sample check (Jul 1 - Nov 10 2026). Candidates and pass rules fixed before running:
   pass = OOS totR > 0 and PF > 1.1 (base costs, no funding blackout = how the EA trades),
          avg R > 0 with x1.5 costs, max DD <= 2 x IS max DD."""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
data = load()
MG = dict(use_cross=False, ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0, trail_start=1.0, trail_atr=1.5, rr=6.0)
C = {"P5": dict(entry_tf=5, trend_tf=60, htf=240, **MG), "P15": dict(entry_tf=15, trend_tf=60, htf=240, **MG)}
STRESS = dict(spread=0.15, spread_asia=0.24, spread_open1=0.60, spread_open2=0.40, slip=0.04)
for name, base in C.items():
    print(f"\n===== {name}")
    for lab, over in (("EA as traded (no blackout)", dict(base)), ("funding blackout 60/30", dict(base, fund_excl=(60, 30))),
                      ("x1.5 costs, no blackout", dict(base, **STRESS)), ("x1.5 costs + blackout", dict(base, fund_excl=(60, 30), **STRESS))):
        _, tr = bt.run(data, over, collect=True)
        si, _ = segment(data, tr, IS_START, OOS_START)
        so, tro = segment(data, tr, OOS_START, END)
        print(f"  {lab:28s} IS : {bt.fmt(si)}")
        print(f"  {'':28s} OOS: {bt.fmt(so)}")
        if lab.startswith("EA as traded"):
            mon = bt.by_month(tro)
            print(f"  {'':28s} OOS by month: " + " ".join(f"{k[2:]}:{v:+.1f}" for k, v in mon.items()))
            risk = np.array([x[6] for x in tro])
            print(f"  {'':28s} OOS risk per trade: median {np.median(risk):.2f} USD/oz (= USD per 0.01 lot), p90 {np.percentile(risk, 90):.2f}")
            ok = so["tot"] > 0 and so["pf"] > 1.1 and so["dd"] <= 2 * si["dd"]
            base_ok = ok
        if lab.startswith("x1.5 costs, no"):
            print(f"  -> PASS RULES: base {'OK' if base_ok else 'FAIL'}, stress avg>0 {'OK' if so['avg'] > 0 else 'FAIL'}")
