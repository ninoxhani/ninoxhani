# STATUS — ALB FOREX EMA 8/14 EAs (baseline + Scalper Pro)

**Version:** 1.21 · **Updated:** 2026-11-11 · **Readiness: RESEARCH NO-GO** (proxy-data simulation; broker-data confirmation pending)

> Read this file first when resuming work. It separates what is implemented, what is verified
> with evidence, and what is still open. Never upgrade a status without evidence in `reports/`.

## Readiness

| Gate | Status |
|---|---|
| Source implemented | ✅ done — two robots over one core (`ALB_FOREX_EMA_CORE.mqh`) |
| Compiles with 0 errors / 0 warnings | ✅ **VERIFIED** (v1.21, both robots) — `reports/compile/2026-11-10_v1.21_compile.log` |
| Self-tests pass (108 checks) | ✅ **VERIFIED** (v1.21, both robots) — `reports/selftest/2026-11-10_v1.21_selftest_experts.log` |
| Functional backtests T1 | ⬜ not done — the owner's runs so far: see "Test results" |
| Edge cases T2 | ⬜ not run |
| Research backtests T3 — **proxy data** | ❌ **done 2026-11-11 → NO-GO**: [`reports/research/2026-11-11_proxy_research_report.md`](reports/research/2026-11-11_proxy_research_report.md) |
| Research backtests T3 — broker real ticks (MT5 tester) | ⬜ pending — `RUN_BACKTESTS.bat` is set up for it (S_ScalperPro vs H_CrossTrail, 2025.01.01 → 2026.11.01) |
| Demo forward test T4 | 🔶 owner demo (IC Markets) — full day 2026-11-11: 17 trades (W7 L10), −3.31 USD (−0.66 %), consistent with the simulation |
| **Overall** | **RESEARCH NO-GO** — the Scalper Pro defaults lose in simulation with high confidence and no tuned variant passed out-of-sample. Not for real money. |

## Research result (2026-11-11, proxy-data simulation — not the MT5 tester)

**Data and costs**
- Binance XAUUSDT perpetual 1-minute candles, clean window 2026-02-01 → 2026-11-10.
- IC Markets trading hours (server = New York + 7 h).
- Costs: spread 0.10–0.40 by hour, commission 7 USD/lot, slippage.
- The simulator `research/afx_bt.py` re-implements the v1.21 rules.

**Findings**
- **Scalper Pro v1.21 defaults:** 4,517 trades (22/day), −0.070R per trade (t = −6.2), −316R in
  total, PF 0.81.
  - All 10 months are negative.
  - About −0.8 % of equity per day at 0.5 % risk; the owner's live day was about −0.7 %.
- **Pullback robot:** −0.043R per trade (PF 0.93). **Crossover:** −0.077R per trade (PF 0.84).
- **Search:** 3,360 variants were tested on in-sample data (Feb–Jun).
  - The two best robust candidates (M5/M15 pullbacks with the H1 trend and a trailing stop) failed
    the one-shot out-of-sample test (Jul–Nov): −0.10R and −0.09R per trade.
  - Across all variants, in-sample and out-of-sample results are uncorrelated (−0.05). Tuning on
    the past does not pick better variants.
- **False edge found and rejected:** an "Asian session" edge came from Binance funding times, which
  do not exist on spot gold.
- **Best remaining idea, H_CrossTrail:** crosses only, trailing stop after +1R.
  - +0.045R per trade, PF 1.09, t = 1.3 — statistically indistinguishable from zero.
  - Found with hindsight; it is a hypothesis for the broker-data test, not a result.

## Robots

| File | Opens in | Magic |
|---|---|---|
| `ALB_FOREX_SCALPER_PRO.ex5` | SCALPER PRO (STRATEGY_SPEC §18), unlimited trades, 1R | 81420262 |
| `ALB_FOREX_EMA_SCALPER_EA.ex5` | PULLBACK baseline (§4–§9), max 5/day, 1.5R | 81420261 |

## Completed implementation

- **v1.21** (2026-11-10): mid-day start no longer counts a same-day position twice in the day P/L
  (owner screen: `Day P/L +0.56` with the account at +0.28). State version 121.
- **v1.20** (2026-11-10, owner request "more trades, but valuable ones; get in and out fast"):
  - SCALPER PRO entry mode: fresh M1 crosses + trend-continuation pullbacks (max 3 per leg), M5
    trend alignment, momentum candle, EMA14 slope, ATR-vs-spread and ATR-spike filters, stop behind
    the last 5 candles (0.8–2.5 ATR), 1R target, break-even at +0.6R, slow-EMA close exit, stale-trade
    exit, cooldown after a loss, pause after 3 losses in a row, optional day target.
  - **Daily-loss model rewritten** (false-halt fix): loss = −(realised trading P/L since the baseline
    + change of floating P/L); deposits/withdrawals inferred from the balance and used only to scale
    the %; baseline set on the first tick (synchronised account data); fresh history before any halt;
    state version check; new option *Daily loss measured on: whole account / this robot only*.
  - Dashboard: active strategy shown on line 3, day P/L in % and money, robot's trades today
    (closed, wins, losses, net, loss streak, pause), 63-character label limit respected.
  - Separate Scalper Pro robot file with its own defaults and magic number.
  - Runner: asks for the gold symbol name, installs all robot files, tests S_ScalperPro,
    S_ScalperPro_NoM5, X_Crossover, A_Baseline.
- **v1.10:** CROSSOVER mode (every M1 cross, ATR stop) — §17.
- **v1.01:** BUY-only entry-drift bias fixed.
- **v1.00:** all master-prompt Phases 1–6: signal engine, filters, structural SL, 1.5R TP,
  equity-risk sizing, daily guard, trade limits, execution engine with reconciliation,
  FULL_AUTO/ALERT_ONLY with real-money lock, diagnostics, extended tester report.

## Verified features

| What | Evidence | Scope |
|---|---|---|
| **Both robots compile: 0 errors, 0 warnings** | `reports/compile/2026-11-10_v1.21_compile.log` (MetaEditor64 5.0.0.6308; SHA-256 of all sources and binaries inside) | compilation only |
| **108 self-tests pass at runtime, both robots** — patterns, swings, rounding, TP, sizing, spread, drift, flat filter, day boundary, sessions, news parsing, crossover, scalper leg/momentum/stop/break-even/stale/EMA exit/loss streak, daily-loss model incl. the deposit cases | `reports/selftest/2026-11-10_v1.21_selftest_experts.log` | pure logic functions only |
| Both robots start and stop cleanly; Scalper Pro opens in SCALPER PRO mode, magic 81420262, unlimited trades; presets are read (108 inputs) | same log | EURUSD sample chart, no broker account, no ticks |
| Earlier versions: compile + self-tests v1.00 (72/72), v1.01 (74/74), v1.10 (80/80), v1.20 (105/105) | `reports/compile/`, `reports/selftest/` | history |
| Live calendar news filter works on a broker demo | owner screenshots 2026-11-09 (Lirunex) and 2026-11-10 (IC Markets) | live path only |

**Not yet verified:** Scalper Pro trading behaviour (entries, BE/stale/EMA exits, cooldown/pause) on
ticks, the new daily-loss model on a live account, and any backtest performance.

## Compilation status

**VERIFIED — 0 errors, 0 warnings** for every version (v1.00, v1.01, v1.10, v1.20, v1.21).
Compiler: MetaEditor64.exe **5.0.0.6308** (official MetaQuotes installer, signed by MetaQuotes Ltd),
under WineHQ 11.0 in a Linux cloud sandbox with the owner's approval. Hashes in the compile logs.
Recompiling on your own MetaEditor (F7) is recommended; keep `ALB_FOREX_EMA_CORE.mqh` next to the `.mq5` files.

## Test results

- **T0.1 compile / T0.2 self-tests:** PASSED for every version (latest v1.21: 0/0 and 108/108, both robots).
- **T3 proxy-data research (2026-11-11):** NO-GO. See the section above and
  `reports/research/` (report and logs of every run).
- **Owner demo, full day 2026-11-11 (IC Markets demo, Scalper Pro v1.21, 500 USD):**
  - 17 trades: 7 wins (+9.43), 10 losses (−11.32), gross −1.89; commission −1.42; net −3.31 USD
    (−0.66 % ≈ −1.3R). The simulation expects about −1.2R for 17 trades.
  - The commission is 0.08 per 0.01 lot round trip (0.035 per side, rounded), not the 0.07 the
    research assumed, so real micro-lot costs are slightly higher than simulated.
  - The panel showed `Day P/L −0.66% (−3.31)`, matching the account to the cent. This is a
    single-day live check of the v1.20/v1.21 daily-loss model.
- **Owner demo, 2026-11-10 ~20:25 server (IC Markets demo 53134733, v1.20 Scalper Pro on XAUUSD):** robot
  active and evaluating (`Entry: SCALPER PRO`, executing, live news OK, no halt), 0 trades yet.
  Panel `Day P/L +0.56` vs account +0.28: a position open at the robot's start was counted twice by
  the mid-day reconstruction → fixed in v1.21 (only overstated profit here, but the mirror case
  could overstate a loss).
- **Owner demo run, 2026-11-10 (IC Markets demo 53134676, hedging, XAUUSD M1, v1.10):**
  - The robot ran in **PULLBACK** mode with default inputs (panel: `Confirm: A same candle`, `RR 1:1.50`,
    `Entries today 3/5`), not in the scalper mode the owner intended → reason for the low trade count.
    v1.20 adds the separate Scalper Pro robot so the mode can not be mixed up.
  - 3 trades, all SELL 0.01, all winners: +5.97, +6.72, +4.92 = **+17.61** on a 1 000 deposit.
    Sample far too small to mean anything.
  - Panel showed **`Day P/L −7.37% HALTED`** although the robot's own trades were +17.61. Cause not
    proven (no Experts log). Two candidates: (a) other trades on the account, (b) the v1.00–v1.10
    baseline counting the 1 000 deposit (booked at 18:00:46) on top of a baseline captured while MT5
    was still loading the new account. (b) is a real weakness of the old model and is **fixed in
    v1.20**; (a) is by design in *whole account* scope — use *this robot only* if other trades share
    the account.
- **Owner one-click run #1 (v1.01, 2026-11-09):** all variants `NO REPORT` (MT5 did not start the
  tester; account not used). Runner since then reports MT5's reason and retries with the account.
- **Owner tester run (v1.00, XAUUSD.std M1, 2026.10.01–10.05, visual):** exposed the BUY drift
  defect (fixed in v1.01).
- **Strategy Tester in the sandbox:** impossible — MT5 requires a broker account.
- **No MT5 Strategy Tester performance report exists.** The only performance evidence is the
  proxy-data simulation above.

## Incomplete / unverified

- MT5 Strategy Tester on the broker's real ticks (T3 broker part); functional and edge-case tests (T1, T2).
- The simulator is a re-implementation, checked against the source rule by rule, not against MT5
  tester output. The S_ScalperPro run on real ticks will show whether both agree.
- New daily-loss model on a live account with deposits (TEST_PLAN T2.20, T2.21).
- News CSV export/tester path; emergency close (`Test_DailyLimit_Emergency.set`).
- All thresholds (pullback filters, Scalper Pro filters and exits) are placeholders, not calibrated.
- `EstimatedCommissionPerLot` (7.0) must match the broker (IC Markets raw ≈ 7 per lot round trip).

## Known defects / limitations

- No open verified defects. Fixed: v1.01 BUY drift bias; v1.20 deposit/baseline false-halt risk and
  dashboard text cut at 63 characters (MT5 label limit).
- `MaxTradesPerDay` in ALERT_ONLY counts alerts (no virtual positions).
- If `TradingSymbol` differs from the chart symbol, signals are evaluated only on chart ticks.
- Tester remote/cloud agents cannot read the news CSV from `Common\Files`; use local agents.
- The daily guard is not a guaranteed loss cap (gaps, slippage).
- Scalper Pro's leg counter reads deal history for continuation candidates (once per candidate bar).

## Next required action

1. **Owner:** do not run Scalper Pro (or Crossover) with money that matters. On demo it only
   repeats the measured loss. Remove it from the chart, or switch `TradingMode` to `ALERT_ONLY`.
2. **Owner:** run `RUN_BACKTESTS.bat` once (symbol `XAUUSD` for IC Markets; it may run for hours,
   overnight is fine). Send the zip from the Desktop.
   - It tests **S_ScalperPro** (the control) and **H_CrossTrail** on the broker's real ticks,
     2025.01.01 → 2026.11.01.
3. **Analyse the zip:**
   - If S_ScalperPro loses there too, the simulation is confirmed.
   - **H** is a demo candidate only if it meets the TEST_PLAN T3 rules on real ticks (PF ≥ 1.2,
     avg R > 0, DD ≤ 10 %, ≥ 100 trades, no single month > ½ of profit).
   - Otherwise close the EMA 8/14 scalper line and research a different edge. Do not re-tune these
     rules; the meta-analysis shows that tuning does not carry over to new data.
