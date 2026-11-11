import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
import itertools, json, multiprocessing as mp
MGMT = {
    "v121": {},
    "pure": dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0),
    "be":   dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=1.0),
    "trail": dict(ema_exit=False, stale_bars=0, opp_cross_exit=False, be_trig=0, trail_start=1.0, trail_atr=1.5),
}
KINDS = {"both": {}, "cross": dict(use_cont=False), "cont": dict(use_cross=False)}
SESS = {"all": None, "AS": [(2, 9)], "LO": [(9, 14)], "NY": [(14, 19)], "LN": [(9, 19)]}
FX = dict(fund_excl=(60, 30))
def configs():
    for etf, trends in ((1, (5, 15, 60)), (5, (15, 60, 240)), (15, (60, 240))):
        for ttf in trends:
            for htf in (0, 240):
                if htf and htf <= ttf:
                    continue
                for kname, mname, rr, sname in itertools.product(KINDS, MGMT, (1.0, 1.5, 2.0, 3.0), SESS):
                    over = dict(entry_tf=etf, trend_tf=ttf, htf=htf, rr=rr, sessions=SESS[sname], **FX)
                    over.update(KINDS[kname]); over.update(MGMT[mname])
                    if mname == "trail":
                        over["rr"] = rr * 2
                    yield f"E{etf}_T{ttf}_H{htf}_{kname}_{mname}_rr{rr}_{sname}", over
D = None
def init():
    global D; D = load()
def work(item):
    name, over = item
    _, tr = bt.run(D, over, collect=True)
    return name, over, seg_stats(D, tr)
if __name__ == "__main__":
    items = list(configs())
    print("configs:", len(items), flush=True)
    with mp.Pool(4, initializer=init) as p:
        res = p.map(work, items, chunksize=8)
    json.dump([(n, s) for n, o, s in res], open(os.path.join(RD, "grid2_is.json"), "w"))
    ok = [r for r in res if r[2]["IS"]["n"] >= 120]
    both = [r for r in ok if r[2]["IS1"]["tot"] > 0 and r[2]["IS2"]["tot"] > 0]
    print("with >=120 IS trades:", len(ok), " positive in both halves:", len(both))
    allavg = np.array([r[2]["IS"]["avg"] for r in ok])
    print("IS avg R over configs: pct5 %.3f median %.3f pct95 %.3f max %.3f" % tuple(np.percentile(allavg, [5, 50, 95, 100])))
    ok.sort(key=lambda r: -min(r[2]["IS1"]["avg"], r[2]["IS2"]["avg"]))
    print("\nTop 40 by the worse half's avg R:")
    for n_, o, s in ok[:40]:
        print(f"{n_:38s} IS1 {s['IS1']['n']:4d} {s['IS1']['avg']:+.3f} | IS2 {s['IS2']['n']:4d} {s['IS2']['avg']:+.3f} | IS {s['IS']['tot']:+7.1f}R PF {s['IS']['pf']:.2f} DD {s['IS']['dd']:5.1f} /day {s['IS']['pday']:.2f}")
    # family summary: median over sessions/kinds per (entry,trend,mgmt,rr)
    print("\nMedian IS avg R by entry TF / management / RR (all sessions/kinds/trends pooled):")
    import collections
    fam = collections.defaultdict(list)
    for n_, o, s in ok:
        p = n_.split("_")
        fam[(p[0], p[4], p[5])].append(s["IS"]["avg"])
    for k in sorted(fam):
        v = np.array(fam[k]); print(f"   {k}: median {np.median(v):+.3f}  share>0 {np.mean(v > 0):.0%}  (n={len(v)})")
