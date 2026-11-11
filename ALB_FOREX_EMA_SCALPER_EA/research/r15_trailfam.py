import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import json, numpy as np, collections
res = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "grid_is_oos.json")))
fam = [r for r in res if r[0].startswith("E1_") and "_trail_" in r[0] and r[1]["n"] >= 120]
def grp(idx, label):
    g = collections.defaultdict(list)
    for n_, si, so in fam:
        g[n_.split("_")[idx]].append((si["avg"], so["avg"], si["n"] + so["n"]))
    print(label)
    for k in sorted(g):
        v = np.array(g[k]); print(f"   {k:6s} IS med {np.median(v[:,0]):+.3f}  OOS med {np.median(v[:,1]):+.3f}  both>0 {np.mean((v[:,0]>0)&(v[:,1]>0)):.0%}  trades(med) {np.median(v[:,2]):.0f}  n={len(v)}")
grp(1, "by trend TF"); grp(2, "by H4 filter"); grp(3, "by entry kind"); grp(5, "by target"); grp(6, "by session")
print("\nE1 trail, no H4 filter, all sessions (EA-compatible):")
for n_, si, so in sorted(fam, key=lambda r: r[0]):
    p = n_.split("_")
    if p[2] == "H0" and p[6] == "all":
        print(f"   {n_:36s} IS {si['n']:4d} {si['avg']:+.3f} PF {si['pf']:.2f} | OOS {so['n']:4d} {so['avg']:+.3f} PF {so['pf']:.2f}")
