# CHANGELOG — ALB_FOREX_EMA_SCALPER_EA

## 1.30 — 2026-11-12 (Scalper Pro: 1:4 target, profit lock, trailing stop)

Both robots: **0 errors, 0 warnings** (MetaEditor 6308), self-tests **115 passed, 0 failed**.
The baseline (pullback) robot's behaviour is unchanged.

Owner request: "let each position run and come out with profit, risk:reward like 1:4, at least 1:3,
and if there are losses we should not come out badly."

Changed: `ALB_FOREX_SCALPER_PRO` defaults (STRATEGY_SPEC §18.1)
- **Entries:** M1 EMA 8/14 crosses only. Continuation entries are off; they lost the most in the
  research.
- **Target 4R.** At +1R the stop moves to +0.25R, then trails 1.5 × ATR(M1) behind the price, only
  in the profit direction.
- **No early exits:** stale, slow-EMA and opposite-cross exits are off.
- **Unchanged protection:** max loss 1R per trade (0.5 %), 3-bar cooldown, 60-min pause after 3
  losses, 2 % daily guard.
- **Order comment** `ALBFX_SCP4R`; magic unchanged (81420262).
- **Simulation (proxy data, Feb–Nov 2026, real commission):** +0.045R per trade (Feb–Jun) and
  +0.039R (Jul–Nov), 5.8 trades/day, PF 1.08, max DD 42R. That is better than the old defaults
  (−0.07R) but **not statistically proven** (t ≈ 1.2), and about break-even with higher costs.
  - A plain fixed 1:3 target without trailing was negative (−12R), so a "let it run" target needs
    the trailing stop.

Added
- Per-robot default macros `AFX_DEF_SC_USE_CONT`, `AFX_DEF_SC_BE_R`, `AFX_DEF_SC_BE_LOCK_R`,
  `AFX_DEF_SC_STALE_BARS`, `AFX_DEF_SC_EMA_EXIT`, `AFX_DEF_CLOSE_OPPOSITE`, `AFX_DEF_TRAIL`,
  `AFX_DEF_TRAIL_ATR`. The baseline values equal the old behaviour.
- Pure `AfxManagedStop()` (profit lock + trailing, never loosens), used by the position manager,
  with 7 new self-tests.
- Dashboard line 4 shows the entry types and exit setup, e.g.
  `Entry: SCALPER PRO X | M5 ON | BE 1.0R trail 1.5ATR | RR 4.0`.
- Extended report shows the trailing parameters.
- `research/r17_v130.py` and its log.

Changed
- **Trailing modifications:** a move is sent only when it improves the stop by at least 10 % of the
  trail distance, so the broker doesn't get a request every 2 seconds. The first move to the
  profit lock is always sent.
- **Presets:**
  - `Backtest_H_CrossTrail` = v1.30 defaults;
  - `Backtest_S_ScalperPro` = old defaults (control);
  - `Demo_ScalperPro` = v1.30.

## 1.22 — 2026-11-11 (Strategy Tester fix)

Both robots: **0 errors, 0 warnings** (MetaEditor 6308), self-tests **108 passed, 0 failed**.
Trading rules unchanged.

Fixed
- **No trades in the Strategy Tester (non-visual).** The owner's first broker-data run
  (MetaQuotes-Demo, XAUUSD M1 real ticks, 2025.01.01 → 2026.11.01) made 0 trades in both variants.
  - Symptom: all 638,414 bar checks were rejected as `DATA_NOT_READY` with
    `indicator 0 not calculated yet`.
  - Cause: the tester calculates standard indicators only when their data is requested.
    `IndicatorsReady()` waited for `BarsCalculated()` to catch up before requesting any data, so
    it never did.
  - Fix: request one value of each indicator first, then check. Live charts were not affected
    (they calculate on every tick); the v1.00 visual-mode test was not affected either.
  - The tester fix itself needs an owner tester run to confirm.

Changed (runner, `tools/run_backtests.ps1`)
- The summary shows trades, net profit and profit factor per variant from the EA's extended
  report.
- A run with 0 trades is flagged `0 TRADES` with the main rejection reason; before, it showed `OK`.
- The summary shows the date the broker's real ticks begin. Earlier dates in a test use ticks
  generated from M1 bars.
- Tested on the owner's real result files and with a PowerShell 7 dry run.

Evidence: `reports/2026-11-11_MetaQuotesDemo_v1.21_S_H_zero_trades/`,
`reports/compile/2026-11-11_v1.22_compile.log`, `reports/selftest/2026-11-11_v1.22_selftest_experts.log`.

## Research — 2026-11-11 (no EA code change; robots stay v1.21)

Owner request after a losing demo day (13 trades, −3.46 USD): make the robot profitable.

Result: **RESEARCH NO-GO** (proxy-data simulation). Full report:
`reports/research/2026-11-11_proxy_research_report.md`.
- **Scalper Pro v1.21:** loses in the simulation. 22 trades/day, −0.070R per trade, t = −6.2, all
  10 months negative.
- **Out-of-sample:** none of 3,360 tuned variants produced an edge that survived the test, so no
  "profitable version" is shipped.
- **False edge:** an apparent Asian-session edge was traced to Binance funding times and rejected.

Added
- `research/`: Python simulator of the robots' rules (`afx_bt.py`) on 1-minute data, with IC
  Markets trading hours (server = New York + 7 h), an hourly spread model, commission and
  slippage. Also the data loader, the download script and all experiment scripts.
- `reports/research/`: report and the logs of every run.
- Preset `Backtest_H_CrossTrail.set`: the best remaining hypothesis.
  - Rules: Scalper Pro crosses only, no early exits, trailing stop 1.5 × ATR after +1R, 4R target.
  - About break-even in the simulation; for the broker-data test only.

Changed
- **Runner defaults:** `RUN_BACKTESTS.bat` / `tools/run_backtests.ps1` now test **S_ScalperPro**
  (control) and **H_CrossTrail** on 2025.01.01 → 2026.11.01 (real ticks). Other variants are
  still available with `-Variants`. Checked with a PowerShell 7 dry run.
- **Docs:** STATUS (readiness RESEARCH NO-GO), README, TEST_PLAN, CONFIGURATION.

## 1.21 — 2026-11-10 (day P/L fix)

Both robots: **0 errors, 0 warnings** (MetaEditor 6308), self-tests **108 passed, 0 failed**.

Fixed
- When a robot started mid-day while another position opened **today** was still open, that
  position's P/L before the start was counted twice (once in its realised result, once through the
  floating baseline). Seen on the owner's panel: `Day P/L +0.56` with the account at +0.28. Only
  profit was overstated there, but the mirror case could overstate a loss and halt the robot.
  The day-start floating P/L now includes only positions opened before the day start.
- State version 121: a baseline saved by v1.20 is rebuilt on restart.

Added
- 3 self-tests for the reconstruction (`AfxFloatingAtDayStart`).

## 1.20 — 2026-11-10 (Scalper Pro robot + daily-loss fix)

Both robots compile with MetaEditor build 6308: **0 errors, 0 warnings**. Self-tests: **105 passed,
0 failed** in both robots. PULLBACK and CROSSOVER behaviour unchanged.

Owner feedback (IC Markets demo): only a few trades, wants a real scalper with more but valuable trades;
panel showed `Day P/L −7.37% HALTED` while the robot's own 3 trades were all winners.

Added
- **`ALB_FOREX_SCALPER_PRO`**: second robot file, opens in the new SCALPER PRO mode (magic 81420262,
  unlimited trades, 1R, M5 flat filter on). All code moved to the shared `ALB_FOREX_EMA_CORE.mqh`;
  the two `.mq5` files only set defaults.
- `EntryMode = SCALPER PRO`: fresh M1 crosses (close beyond both EMAs) + trend-continuation
  pullbacks (max 3 per M1 leg, EMA14 slope), M5 trend filter, momentum candle (body ≥ 40 %),
  ATR ≥ 5 × spread, ATR spike filter, stop behind the last 5 candles (0.8–2.5 ATR), 1R target,
  break-even at +0.6R (+0.1R locked), slow-EMA close exit, stale-trade exit (10 bars / 0.25R),
  3-bar cooldown after a loss, 60-minute pause after 3 losses in a row, optional day target.
- `InpDailyLossScope`: daily loss on the whole account (default) or on this robot's trades only.
- Dashboard: strategy line, day P/L in % and money with scope, robot's trades today and loss streak.
- Presets `Backtest_S_ScalperPro`, `Backtest_S_ScalperPro_NoM5`, `Demo_ScalperPro`.
- Runner: asks for the gold symbol, installs all robot files, default variants S_ScalperPro,
  S_ScalperPro_NoM5, X_Crossover, A_Baseline.
- 25 new self-tests (scalper helpers and the daily-loss model).

Fixed
- **Daily loss could be overstated (false halt).** The old model added deposit deals time-stamped
  after the baseline to it; a baseline captured while MT5 was still loading the account (or a deposit
  booked a second later) could count a deposit twice. New model: loss = −(realised trading P/L since
  the baseline + change of floating P/L); deposits only scale the percentage (inferred from the
  balance); baseline set on the first synchronised tick; history refreshed before any halt; persisted
  states of older versions are ignored.
- Dashboard labels longer than 63 characters (MT5 limit) were cut (e.g. "research EA - not valid").

## 1.10 — 2026-11-09 (new entry mode: CROSSOVER scalper)

Compiled with MetaEditor build 6308: **0 errors, 0 warnings**. Self-tests: **80 passed, 0 failed**
(run in CROSSOVER mode). PULLBACK baseline behaviour unchanged.

Added (owner request)
- `InpEntryMode = CROSSOVER`: enter on every closed-bar M1 EMA 8/14 cross; ATR stop
  (`InpCrossSLATR` = 1.5); TP = `RewardRisk` × stop; opposite cross closes the open position
  (`InpCrossCloseOnOpposite`); optional M5 trend filter (`InpCrossUseTrendFilter`, off).
- `InpMaxTradesPerDay = 0` means unlimited.
- Rejection codes `NO_EMA_CROSS`, `CROSS_AGAINST_TREND`; mode tag `X` in journal, comments, report.
- Presets `Backtest_X_Crossover`, `Backtest_X_CrossTrend`, `Demo_Scalper` (RR 1.0, unlimited trades).
- `AfxCrossDirection` pure function + 6 self-tests.
- One-click runner now tests X_Crossover, X_CrossTrend and A_Baseline by default.

## 1.01 — 2026-11-09 (defect fix)

Compiled with MetaEditor build 6308: **0 errors, 0 warnings**. Self-tests: **74 passed, 0 failed**.

Fixed
- **Entry drift was biased against BUY trades.** v1.00 measured BUY drift on the Ask, so the spread
  counted as "drift" for BUY only. On XAUUSD (spread ≈ 0.20 USD, ATR(M1) ≈ 1.0–1.4 USD) the spread
  alone used up most of the 0.20 × ATR limit, rejecting almost every BUY. Found while reviewing the
  first XAUUSD.std backtest (2026.10.01–10.05). Drift is now measured on the Bid for both directions
  (price movement only); the spread has its own filter.

Added
- Input `InpDriftExcludesSpread` (default true). false = v1.00 behaviour, for comparison only.
- Pure function `AfxDriftATR` + 2 self-tests (72 → 74).

Added (tools, EA code unchanged)
- `RUN_BACKTESTS.bat` + `tools/run_backtests.ps1`: one double-click finds MT5 (via `origin.txt`), installs
  the EA and presets, runs variants A–D unattended (real ticks, M1, in-sample period) and zips every
  report/journal/log to the Desktop. Tested with PowerShell 7 dry run + simulated terminal; the generated
  `.ini` was parsed by real MT5 build 6308.
- Runner self-diagnosis: after a failed run it prints the reason from the MT5 log, stops instead of
  repeating the failure, and can retry with an explicit `Login`/`Server` (`[Common]` section). New
  parameters `-Login`, `-Server`, `-Install`. Found in the first owner run: all variants ended in ~6 s
  with no report.

Changed (cosmetic)
- Dashboard panel widened so the last line is no longer cut off.
- Dashboard shows `+0.00%` instead of `-0.00%` when daily P/L is zero.
- Presets regenerated (79 inputs).

## 1.00 — 2026-11-08 (initial implementation)

Compiled with MetaEditor build 6308: **0 errors, 0 warnings** (`reports/compile/`).
Built-in self-tests: **72 passed, 0 failed** in MT5 build 6308 (`reports/selftest/`).
Trading behaviour and performance are not yet tested (Strategy Tester needs a broker account).

New standalone project. No existing ALB FOREX EA files were present in this repository or modified.

Added
- `ALB_FOREX_EMA_SCALPER_EA.mq5`: complete EA source (single file).
  - M5 EMA 8/14 trend on the latest closed bar; M1 EMA-band touch entries.
  - Confirmation Mode A (same candle, default) and Mode B (next candle, experimental).
  - Optional entry-TF EMA alignment.
  - Flat-EMA filter (ATR-normalised separation + slope, independently switchable, default off).
  - Spread filter (spread/SL ratio 0.15; absolute cap disabled by default), quote validity/age.
  - Entry drift filter (0.20 × ATR M1).
  - News filter: MT5 calendar live, CSV dataset in the tester, fail-closed, CSV export tool.
  - Optional broker-time session filter + symbol trade-session check.
  - Structural swing SL (2/2 strict pivots, unbroken rule, 20-bar lookback) with ATR buffer,
    min/max distance and stops-level validation; tick-grid normalisation.
  - 1.5R TP rounded away from entry; TP re-anchored to the actual fill.
  - Equity-risk position sizing via `OrderCalcProfit` with slippage and commission estimates,
    never rounding up; margin check; daily-budget pre-check.
  - Daily equity loss guard (2 %) with cash-flow-adjusted baseline, persistence across restarts,
    optional emergency close.
  - Max 5 entries/day, one position per symbol, duplicate-signal protection, netting/hedging rules.
  - Execution engine: `OrderCheck`, filling-mode selection, controlled requote retry, unknown-result
    reconciliation without resend, partial-fill handling, missing-SL protection.
  - FULL_AUTO / ALERT_ONLY with real-money lock (`EnableLiveTrading`).
  - Optional break-even, trailing stop, time exit (all off).
  - Diagnostics: rejection codes, CSV journal, branded chart dashboard, extended tester report
    (all required metrics), 72 built-in logic self-tests.
- Documentation: README, STRATEGY_SPEC, CONFIGURATION, TEST_PLAN, STATUS.
- `presets/` (9 `.set` files), `tests/` (4 tester `.ini` files), `tools/make_presets.py`.
- `ALB_FOREX_EMA_SCALPER_EA.ex5` compiled binary and `reports/compile/2026-11-08_v1.00_compile.log`.
