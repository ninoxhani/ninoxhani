"""
ALB FOREX EMA 8/14 research backtester (proxy data, NOT the MT5 Strategy Tester).

Replicates the decision rules of ALB_FOREX_EMA_CORE.mqh v1.21 (SCALPER PRO, CROSSOVER and the
PULLBACK baseline) on 1-minute bars so that variants can be compared quickly.

Model
- Input candles are treated as the BID chart. Ask = bid + spread (spread depends on the hour).
- Signals are evaluated at the open of each entry-TF bar from closed bars only (as the EA does).
- Fills: market entry at ask/bid + slippage; SL = stop order (adverse slippage); TP = limit (no
  slippage); bar-close exits at the next bar open + slippage. Commission per round trip.
- Inside one M1 candle the order of high/low is unknown: if SL and TP are both touched, the SL is
  taken (conservative). Break-even / trailing moves are applied from the next M1 candle.
- Results in R: 1R = planned loss incl. 2x slippage and commission (what the EA sizes for).
"""
import numpy as np

DEFAULT_CFG = dict(
    mode="scalper",            # scalper | crossover | pullback
    entry_tf=1, trend_tf=5,    # minutes
    htf=0,                     # extra higher-timeframe trend filter (minutes, 0 = off)
    fast=8, slow=14, atr_p=14, atr_long=100,
    # scalper entries
    use_cross=True, use_cont=True, max_per_leg=3, leg_lookback=120, body_ratio=0.40,
    slope_bars=3, min_slope=0.10, trend_filter=True,
    flat_filter=True, flat_sep=0.10, flat_slope=0.10, flat_bars=3,
    atr_spread_min=5.0, atr_spike_max=2.5,
    # scalper stop / target / management
    sl_bars=5, sl_buf=0.15, sl_min=0.8, sl_max=2.5,
    rr=1.0, be_trig=0.6, be_lock=0.10, stale_bars=10, stale_min_r=0.25,
    ema_exit=True, opp_cross_exit=True,
    cooldown_bars=3, max_consec=3, pause_min=60,
    trail_start=0.0, trail_atr=1.0,      # trailing stop (start R, 0 = off; distance x entry ATR)
    # pullback baseline
    swing_lookback=20, swing_left=2, swing_right=2, pb_buf_atr=0.10, pb_be=0.0,
    # crossover
    cross_sl_atr=1.5,
    # generic gates
    min_stop_atr=0.25, max_stop_atr=3.0, spread_ratio=0.15, drift_atr=0.20,
    max_trades_day=0, daily_loss_r=4.0, budget_check=True,
    sessions=None,             # list of (start_hour, end_hour) in SERVER time; None = all market hours
    side=0,                    # 0 both, 1 long only, -1 short only
    fund_excl=(0, 0),          # research only: no entries from N min before to M min after 00/08/16 UTC (Binance funding)
    # costs, price units per 1 oz (IC Markets raw-like)
    spread=0.10, spread_asia=0.16, spread_open1=0.40, spread_open2=0.25, comm=0.07, slip=0.02,
)


def _nth_sunday(year, month, nth):
    import calendar as _c
    d = [w for w in _c.Calendar().itermonthdates(year, month) if w.month == month and w.weekday() == 6]
    return d[nth - 1] if nth > 0 else d[-1]


def server_offset(t):
    """IC Markets-style server time = New York + 7h: UTC+3 while US DST is in effect, else UTC+2."""
    import calendar as _c
    t = np.asarray(t)
    off = np.full(t.shape, 7200, dtype=np.int64)
    for y in range(2024, 2028):
        a = _nth_sunday(y, 3, 2)
        b = _nth_sunday(y, 11, 1)
        ta = _c.timegm((a.year, a.month, a.day, 7, 0, 0))     # 02:00 New York (EST)
        tb = _c.timegm((b.year, b.month, b.day, 6, 0, 0))     # 02:00 New York (EDT)
        off[(t >= ta) & (t < tb)] = 10800
    return off


def market_open_mask(t):
    """Spot-gold hours in server time: Mon 01:00 - Fri 24:00, daily break 00:00-01:00 (17-18 New York)."""
    st = t + server_offset(t)
    wd = ((st // 86400) + 3) % 7          # 0 = Monday (1970-01-01 was a Thursday)
    hr = (st % 86400) // 3600
    return ~((wd >= 5) | (hr == 0))


def resample(t, o, h, l, c, minutes):
    if minutes == 1:
        return t.copy(), o.copy(), h.copy(), l.copy(), c.copy()
    b = t // (60 * minutes)
    starts = np.flatnonzero(np.r_[True, b[1:] != b[:-1]])
    ends = np.r_[starts[1:], len(t)] - 1
    return (b[starts] * 60 * minutes, o[starts], np.maximum.reduceat(h, starts),
            np.minimum.reduceat(l, starts), c[ends])


def ema(x, p):
    a = 2.0 / (p + 1.0)
    xs = x.tolist()
    out = [0.0] * len(xs)
    v = xs[0]
    for i, xi in enumerate(xs):
        v = v + a * (xi - v)
        out[i] = v
    return np.array(out)


def atr(h, l, c, p):
    pc = np.r_[c[0], c[:-1]]
    tr = np.maximum(h, pc) - np.minimum(l, pc)
    cs = np.cumsum(tr)
    out = np.empty_like(tr)
    out[:p] = cs[:p] / np.arange(1, p + 1)
    out[p:] = (cs[p:] - cs[:-p]) / p
    return out


def server_minute(t):
    return ((t + server_offset(t)) % 86400) // 60


def spread_model(t, cfg):
    """Spread by server time: wide just after the daily open, Asian hours, end of day, main sessions."""
    m = server_minute(t)
    sp = np.full(len(t), cfg["spread"], dtype=float)
    sp[(m >= 120) & (m < 540)] = cfg["spread_asia"]                 # 02:00-09:00 server
    sp[(m >= 1380)] = cfg["spread_asia"]                            # 23:00-24:00 server
    sp[(m >= 60) & (m < 120)] = cfg["spread_open2"]                 # 01:00-02:00
    sp[(m >= 60) & (m < 90)] = cfg["spread_open1"]                  # 01:00-01:30
    return sp


class Data:
    def __init__(self, npz_path, start=None, end=None):
        z = np.load(npz_path)
        t = z["t"].astype(np.int64)
        m = market_open_mask(t)
        if start is not None:
            m &= t >= start
        if end is not None:
            m &= t < end
        self.t, self.o, self.h, self.l, self.c = t[m], z["o"][m], z["h"][m], z["l"][m], z["c"][m]
        self.off = server_offset(self.t)
        self.sday = (self.t + self.off) // 86400
        self.days = len(np.unique(self.sday))
        self._cache = {}

    def tf(self, minutes, fast, slow, atr_p, atr_long):
        key = (minutes, fast, slow, atr_p, atr_long)
        if key not in self._cache:
            T, O, H, L, C = resample(self.t, self.o, self.h, self.l, self.c, minutes)
            self._cache[key] = dict(t=T, o=O, h=H, l=L, c=C, ef=ema(C, fast), es=ema(C, slow),
                                    atr=atr(H, L, C, atr_p), atrl=atr(H, L, C, atr_long), sec=60 * minutes)
        return self._cache[key]


def _sh(a, s):
    out = np.empty(len(a), dtype=float)
    out[:s] = np.nan
    out[s:] = a[:-s]
    return out


def _trend_cols(TT, et, cfg):
    """Direction and flat-filter pass flags of the latest CLOSED trend bar at each entry bar open."""
    tt, tef, tes, tat, tsec = TT["t"], TT["ef"], TT["es"], TT["atr"], TT["sec"]
    fb = cfg["flat_bars"]
    j = np.searchsorted(tt, et - tsec, side="right") - 1
    ok = j >= fb
    jj = np.where(ok, j, fb)
    tdir = np.where(ok, np.sign(tef[jj] - tes[jj]), 0).astype(int)
    sep = np.abs(tef[jj] - tes[jj]) / tat[jj]
    slope = (tes[jj] - tes[jj - fb]) / tat[jj]
    flat_up = ok & (sep >= cfg["flat_sep"]) & (slope >= cfg["flat_slope"])
    flat_dn = ok & (sep >= cfg["flat_sep"]) & (-slope >= cfg["flat_slope"])
    return tdir, flat_up, flat_dn


def _find_swing(h, l, k, find_low, left, right, lookback):
    """Latest strict, unbroken pivot among closed bars k-1..k-lookback (k = forming bar)."""
    for s in range(right + 1, lookback + 1):
        i = k - s
        if i - left < 0:
            break
        v = l[i] if find_low else h[i]
        ok = True
        for q in range(1, left + 1):
            w = l[i - q] if find_low else h[i - q]
            if not (v < w if find_low else v > w):
                ok = False
                break
        if ok:
            for q in range(1, right + 1):
                w = l[i + q] if find_low else h[i + q]
                if not (v < w if find_low else v > w):
                    ok = False
                    break
        if ok:
            for q in range(i + 1, k):
                w = l[q] if find_low else h[q]
                if (w < v if find_low else w > v):
                    ok = False
                    break
        if ok:
            return v
    return None


def run(data, over=None, collect=False):
    cfg = dict(DEFAULT_CFG)
    if over:
        unknown = set(over) - set(cfg)
        if unknown:
            raise KeyError(unknown)
        cfg.update(over)
    mode = cfg["mode"]
    E = data.tf(cfg["entry_tf"], cfg["fast"], cfg["slow"], cfg["atr_p"], cfg["atr_long"])
    TT = data.tf(cfg["trend_tf"], cfg["fast"], cfg["slow"], cfg["atr_p"], cfg["atr_long"])
    et, eo, eh, el, ec, ef, es, ea, eal, sec = (E[k] for k in ("t", "o", "h", "l", "c", "ef", "es", "atr", "atrl", "sec"))
    n = len(et)
    t1, o1, h1, l1 = data.t, data.o, data.h, data.l
    sp1 = spread_model(t1, cfg)
    sday1 = data.sday
    m1s = np.searchsorted(t1, et)
    m1e = np.r_[m1s[1:], len(t1)]

    # ---------------- vectorised signal candidates (value at k uses closed bars k-1, k-2) -------
    f1, w1, f2, w2 = _sh(ef, 1), _sh(es, 1), _sh(ef, 2), _sh(es, 2)
    o_, h_, l_, c_, a_, al_ = _sh(eo, 1), _sh(eh, 1), _sh(el, 1), _sh(ec, 1), _sh(ea, 1), _sh(eal, 1)
    contig = np.zeros(n, bool)
    contig[2:] = (et[2:] - et[1:-1] == sec) & (et[1:-1] - et[:-2] == sec)
    with np.errstate(invalid="ignore"):
        cross = np.where((f2 <= w2) & (f1 > w1), 1, np.where((f2 >= w2) & (f1 < w1), -1, 0))
        state = np.nan_to_num(np.sign(f1 - w1)).astype(int)
        rng = h_ - l_
        body = np.abs(c_ - o_)
        br = cfg["body_ratio"]
        mom_up = (rng > 0) & (c_ > o_) & (body >= br * rng - 1e-12)
        mom_dn = (rng > 0) & (c_ < o_) & (body >= br * rng - 1e-12)
        bhi, blo = np.maximum(f1, w1), np.minimum(f1, w1)
        touch = (l_ <= bhi) & (h_ >= blo)
        slope = (w1 - _sh(es, 1 + cfg["slope_bars"])) / np.where(a_ > 0, a_, np.nan)
    tdir, flat_up, flat_dn = _trend_cols(TT, et, cfg)
    kind = np.zeros(n, int)     # 1 cross, 2 continuation, 3 pullback
    cand = np.zeros(n, int)
    if mode == "scalper":
        xc = cfg["use_cross"] & (cross != 0)
        x_ok = xc & (((cross > 0) & mom_up & (c_ > bhi)) | ((cross < 0) & mom_dn & (c_ < blo)))
        cand[x_ok] = cross[x_ok]
        kind[x_ok] = 1
        if cfg["use_cont"]:
            cu = ~xc & (state > 0) & touch & mom_up & (c_ > f1) & (slope >= cfg["min_slope"])
            cd = ~xc & (state < 0) & touch & mom_dn & (c_ < f1) & (-slope >= cfg["min_slope"])
            cand[cu], kind[cu] = 1, 2
            cand[cd], kind[cd] = -1, 2
        if cfg["trend_filter"]:
            cand[cand != tdir] = 0
    elif mode == "crossover":
        cand = cross.copy()
        kind[cand != 0] = 1
        if cfg["trend_filter"]:
            cand[cand != tdir] = 0
    else:
        pu = (tdir > 0) & touch & (c_ > o_) & (c_ > f1)
        pd = (tdir < 0) & touch & (c_ < o_) & (c_ < f1)
        cand[pu], kind[pu] = 1, 3
        cand[pd], kind[pd] = -1, 3
    if cfg["flat_filter"]:
        cand[(cand > 0) & ~flat_up] = 0
        cand[(cand < 0) & ~flat_dn] = 0
    if cfg["htf"]:
        H = data.tf(cfg["htf"], cfg["fast"], cfg["slow"], cfg["atr_p"], cfg["atr_long"])
        hdir, _, _ = _trend_cols(H, et, cfg)
        cand[cand != hdir] = 0
    if cfg["side"]:
        cand[cand != cfg["side"]] = 0
    sp_e = sp1[np.minimum(m1s, len(t1) - 1)]
    if mode == "scalper":
        with np.errstate(invalid="ignore"):
            if cfg["atr_spread_min"]:
                cand[a_ < cfg["atr_spread_min"] * sp_e] = 0
            if cfg["atr_spike_max"]:
                cand[a_ > cfg["atr_spike_max"] * al_] = 0
    if cfg["sessions"]:
        hh = ((et + server_offset(et)) % 86400) / 3600.0
        sm = np.zeros(n, bool)
        for a, b in cfg["sessions"]:
            sm |= ((hh >= a) & (hh < b)) if a < b else ((hh >= a) | (hh < b))
        cand[~sm] = 0
    fb, fa = cfg["fund_excl"]
    if fb or fa:
        mu = (et % 86400) // 60
        near = np.zeros(n, bool)
        for fh in (0, 480, 960):
            dlt = (mu - fh + 720) % 1440 - 720          # minutes relative to the funding time
            near |= (dlt >= -fb) & (dlt < fa)
        cand[near] = 0
    cand[~contig] = 0
    warm = max(cfg["atr_long"], 5 * cfg["slow"], cfg["swing_lookback"] + 5, cfg["slope_bars"] + 5, cfg["sl_bars"] + 2) + 2
    cand[:warm] = 0
    use_opp = cfg["opp_cross_exit"] and (mode == "crossover" or (mode == "scalper" and cfg["use_cross"]))
    cross_ex = np.where(contig, cross, 0) if use_opp else np.zeros(n, int)

    # ---------------- event loop (python lists are much faster than numpy scalars) -------------
    L = lambda a: a.tolist()
    et_, eh_, el_, ec_, es_, ea_ = L(et), L(eh), L(el), L(ec), L(es), L(ea)
    c_l, a_l = L(c_), L(a_)
    t1_, o1_, h1_, l1_, sp1_, sd1_ = L(t1), L(o1), L(h1), L(l1), L(sp1), L(sday1)
    m1s_, m1e_ = L(m1s), L(m1e)
    cand_, kind_, state_, cross_ex_ = L(cand), L(kind), L(state), L(cross_ex)
    comm, slip = cfg["comm"], cfg["slip"]
    rr = cfg["rr"]
    scal = mode == "scalper"
    be_trig = cfg["be_trig"] if scal else cfg["pb_be"]
    be_lock = cfg["be_lock"] if scal else 0.0
    trail_start, trail_atr = cfg["trail_start"], cfg["trail_atr"]
    ema_exit = scal and cfg["ema_exit"]
    stale_bars = cfg["stale_bars"] if scal else 0
    stale_min = cfg["stale_min_r"]
    cool = cfg["cooldown_bars"] * sec if scal else 0
    max_consec, pause = (cfg["max_consec"], cfg["pause_min"] * 60) if scal else (0, 0)
    max_leg = cfg["max_per_leg"]
    mtd = cfg["max_trades_day"]
    dlr = cfg["daily_loss_r"]
    budget = cfg["budget_check"]

    trades = []
    pos = None
    day_r = {}
    day_n = {}
    st8 = dict(consec=0, cday=-1, last_loss=-10**12)

    def close(p, px, ts, why, dd):
        d = p[0]
        r = ((px - p[1]) * d - comm) / p[5]
        day_r[dd] = day_r.get(dd, 0.0) + r
        if dd != st8["cday"]:
            st8["consec"], st8["cday"] = 0, dd
        if r < 0:
            st8["consec"] += 1
            st8["last_loss"] = ts
        else:
            st8["consec"] = 0
        trades.append((p[6], ts, d, r, why, p[7], p[5]))

    leg_dir, leg_n = 0, 0
    for k in range(warm, n):
        T = et_[k]
        i0, i1 = m1s_[k], m1e_[k]
        if i0 >= i1:
            continue
        dday = sd1_[i0]
        bid0 = o1_[i0]
        st = state_[k]
        if st != leg_dir:
            leg_dir, leg_n = st, 0

        # ---- bar-boundary exits in EA order: slow-EMA close, stale, opposite cross ----
        if pos is not None:
            d = pos[0]
            xpx = bid0 - slip if d > 0 else bid0 + sp1_[i0] + slip
            if ema_exit and pos[6] < T and ((d > 0 and ec_[k - 1] < es_[k - 1]) or (d < 0 and ec_[k - 1] > es_[k - 1])):
                close(pos, xpx, T, "ema", dday)
                pos = None
            elif stale_bars and (T - pos[6]) // sec >= stale_bars:
                cur = bid0 if d > 0 else bid0 + sp1_[i0]
                if (cur - pos[1]) * d < stale_min * pos[4]:
                    close(pos, xpx, T, "stale", dday)
                    pos = None
            if pos is not None and cross_ex_[k] == -pos[0]:
                close(pos, xpx, T, "opp", dday)
                pos = None

        # ---- entry ----
        d = cand_[k]
        if d and pos is None:
            lossr = -day_r.get(dday, 0.0)
            ok = True
            if (budget and lossr > dlr - 1.0 + 1e-9) or lossr >= dlr:
                ok = False
            elif mtd and day_n.get(dday, 0) >= mtd:
                ok = False
            elif max_consec and st8["cday"] == dday and st8["consec"] >= max_consec and T - st8["last_loss"] < pause:
                ok = False
            elif cool and T - st8["last_loss"] < cool:
                ok = False
            elif kind_[k] == 2 and max_leg and leg_n >= max_leg:
                ok = False
            if ok:
                sp = sp1_[i0]
                bid, ask = bid0, bid0 + sp
                atrv = a_l[k]
                sl = None
                if scal:
                    nb = cfg["sl_bars"]
                    buf = cfg["sl_buf"] * atrv
                    mn, mx = cfg["sl_min"] * atrv, cfg["sl_max"] * atrv
                    if d > 0:
                        slb = min(el_[k - nb:k]) - buf
                        db = bid - slb
                        sl = bid - mn if db < mn else (None if (mx > 0 and db > mx) else slb)
                    else:
                        sls = max(eh_[k - nb:k]) + sp + buf
                        ds = sls - ask
                        sl = ask + mn if ds < mn else (None if (mx > 0 and ds > mx) else sls)
                elif mode == "crossover":
                    sl = bid - cfg["cross_sl_atr"] * atrv if d > 0 else ask + cfg["cross_sl_atr"] * atrv
                else:
                    pv = _find_swing(eh_, el_, k, d > 0, cfg["swing_left"], cfg["swing_right"], cfg["swing_lookback"])
                    if pv is not None:
                        b = cfg["pb_buf_atr"] * atrv
                        sl = pv - b if d > 0 else pv + b + sp
                if sl is not None and ((d > 0 and sl < bid) or (d < 0 and sl > ask)):
                    q = ask if d > 0 else bid
                    dist = abs(q - sl)
                    if (dist >= cfg["min_stop_atr"] * atrv and (not cfg["max_stop_atr"] or dist <= cfg["max_stop_atr"] * atrv)
                            and sp <= cfg["spread_ratio"] * dist and abs(bid - c_l[k]) <= cfg["drift_atr"] * atrv):
                        fill = q + slip * d
                        fd = abs(fill - sl)
                        risk = dist + 2 * slip + comm
                        # [dir, fill, sl, tp, init risk dist, R units, t_open, kind, be_done, pending_sl]
                        pos = [d, fill, sl, fill + rr * fd * d, fd, risk, T, kind_[k], False, None]
                        day_n[dday] = day_n.get(dday, 0) + 1
                        if kind_[k] in (1, 2):
                            leg_n += 1

        # ---- M1 path of entry bar k ----
        if pos is not None:
            for i in range(i0, i1):
                d = pos[0]
                if pos[9] is not None:
                    if (d > 0 and pos[9] > pos[2]) or (d < 0 and pos[9] < pos[2]):
                        pos[2] = pos[9]
                    pos[9] = None
                sp = sp1_[i]
                if d > 0:
                    lo, hi = l1_[i], h1_[i]
                    if lo <= pos[2]:
                        close(pos, min(pos[2], o1_[i]) - slip, t1_[i] + 30, "be" if pos[8] else "sl", sd1_[i])
                        pos = None
                        break
                    if hi >= pos[3]:
                        close(pos, pos[3], t1_[i] + 30, "tp", sd1_[i])
                        pos = None
                        break
                    prog, ext = hi - pos[1], hi
                else:
                    lo, hi = l1_[i] + sp, h1_[i] + sp
                    if hi >= pos[2]:
                        close(pos, max(pos[2], o1_[i] + sp) + slip, t1_[i] + 30, "be" if pos[8] else "sl", sd1_[i])
                        pos = None
                        break
                    if lo <= pos[3]:
                        close(pos, pos[3], t1_[i] + 30, "tp", sd1_[i])
                        pos = None
                        break
                    prog, ext = pos[1] - lo, lo
                new = None
                if be_trig > 0 and not pos[8] and prog >= be_trig * pos[4]:
                    new = pos[1] + be_lock * pos[4] * d
                    pos[8] = True
                if trail_start > 0 and prog >= trail_start * pos[4]:
                    tr = ext - trail_atr * ea_[k - 1] * d
                    if new is None or (d > 0 and tr > new) or (d < 0 and tr < new):
                        new = tr
                if new is not None:
                    pos[9] = new
    if pos is not None:
        close(pos, o1_[-1], t1_[-1], "end", sd1_[-1])
    res = summarize(trades, data.days)
    return (res, trades) if collect else res


def summarize(trades, days):
    n = len(trades)
    if n == 0:
        return dict(n=0, tot=0.0, avg=0.0, win=0.0, pf=0.0, dd=0.0, pday=0.0, L=0.0, S=0.0)
    r = np.array([x[3] for x in trades])
    d = np.array([x[2] for x in trades])
    eq = np.r_[0.0, np.cumsum(r)]
    dd = float(np.max(np.maximum.accumulate(eq) - eq))
    gp, gl = r[r > 0].sum(), -r[r < 0].sum()
    return dict(n=n, tot=float(r.sum()), avg=float(r.mean()), win=float((r > 0).mean()),
                pf=float(gp / gl) if gl > 0 else float("inf"), dd=dd, pday=n / max(days, 1),
                L=float(r[d > 0].sum()), S=float(r[d < 0].sum()))


def fmt(res):
    return ("n={n:5d} /day={pday:5.2f} win={win:5.1%} avgR={avg:+.3f} totR={tot:+8.1f} PF={pf:4.2f} "
            "maxDD={dd:6.1f}R  long={L:+7.1f} short={S:+7.1f}").format(**res)


def by_month(trades):
    import datetime
    out = {}
    for x in trades:
        key = datetime.datetime.fromtimestamp(int(x[1]), datetime.UTC).strftime("%Y-%m")
        out[key] = out.get(key, 0.0) + x[3]
    return out


def by_key(trades, keyf):
    out = {}
    for x in trades:
        kk = keyf(x)
        a = out.setdefault(kk, [0, 0.0, 0])
        a[0] += 1
        a[1] += x[3]
        a[2] += x[3] > 0
    return out
