# CHANGELOG — ALB_FOREX_EMA_SCALPER_EA

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
