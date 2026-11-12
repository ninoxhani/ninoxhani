# TEST_PLAN — ALB_FOREX_EMA_SCALPER_EA v1.22

Status of every item is tracked in [STATUS.md](STATUS.md). An item is **PASSED** only with
evidence (compiler log, tester report, journal lines). Nothing below has been passed yet
unless STATUS.md says so.

## T0 — Compilation

| ID | Test | Pass criterion | Evidence |
|---|---|---|---|
| T0.1 | Compile in MetaEditor (F7) | `0 errors, 0 warnings` | copy of the *Errors* tab |
| T0.2 | Self-tests (`Test_SelfTests.set`) | `[AFX-EMA][SELFTEST] 115 passed, 0 failed` (both robots) and EA starts | *Experts*/*Journal* line |

The self-tests cover: trend direction, band touch, Mode A BUY/SELL, Mode B touch/confirm/
invalidation, entry-TF alignment, swing detection (strictness, right-bar confirmation,
unbroken rule, lookback limit, highs), tick-grid rounding, TP, volume sizing (min lot,
max cap, step flooring, never over budget), spread ratio, flat filter, day boundary,
session parsing/window, news CSV parsing and window.

## T1 — Functional backtests (correctness, not performance)

Run in the Strategy Tester, XAUUSD M1, *Every tick based on real ticks*, a 1–2 week period,
`Visual mode` on for T1.1–T1.3.

| ID | Check | How | Pass criterion |
|---|---|---|---|
| T1.1 | No look-ahead | For 20 random `SIGNAL` lines, compare with the chart: signal candle is the **closed** M1 bar, M5 trend matches the **previous closed** M5 bar's EMA8/14, entry tick time ≥ signal candle close | all 20 match |
| T1.2 | Pattern rules | Same 20 signals: candle range intersects band, direction and close vs EMA8 correct | all match |
| T1.3 | Structural SL | SL = last unbroken pivot low/high (2/2) ∓ buffer, on correct side | all match |
| T1.4 | TP = 1.5R | `FILL VERIFIED` TP vs fill and SL | `|TP−fill| / |fill−SL|` = 1.50 ± 1 tick |
| T1.4b | Drift symmetry | Journal: compare `ENTRY_DRIFT` counts for BUY vs SELL | no large BUY/SELL imbalance caused by spread |
| T1.5 | Risk sizing | For each fill: `risk@SL + est. commission` ≤ 0.5 % equity (+ slippage) | no overshoot except logged slippage |
| T1.6 | One position | Journal: never two open positions; `POSITION_ALREADY_OPEN` while one is open | holds |
| T1.7 | Max 5 entries/day | Count fills per server day | ≤ 5 every day |
| T1.8 | Duplicate signal | No two orders with the same `signal_bar` | holds |
| T1.9 | Mode B | `Backtest_B_NextCandle.set`: touch on candle N, confirmation on N+1 only | 20 samples match |
| T1.10 | ALERT_ONLY | `AlertOnly.set` in tester: `ALERT` decisions, **zero** deals | holds |
| T1.11 | Daily loss limit + emergency close | `Test_DailyLimit_Emergency.set` (limit 0.4 % < 0.5 % risk) | `DAILY LOSS LIMIT REACHED` logged; `Position … closed (DAILY LIMIT)`; no new entries the same day; trading resumes next day |
| T1.12 | Daily reset | Any multi-day run | `New broker day` line at server midnight; counters reset |
| T1.13 | News fail-closed | `Backtest_A_NewsCSV.set` **without** the CSV present | every setup `NEWS_DATA_UNVERIFIED`, zero trades |
| T1.14 | News CSV | Export CSV on demo (`InpNewsExportDays=400`), run `Backtest_A_NewsCSV.set` | `NEWS_WINDOW` rejections around NFP/CPI/FOMC times |

## T2 — Edge cases

| ID | Case | Method | Expected behaviour |
|---|---|---|---|
| T2.1 | Insufficient candles | Tester start date at the beginning of available history | `DATA_NOT_READY` only, no crash |
| T2.2 | Indicator init failure | (a) invalid periods, e.g. `SlowEMA=0`; (b) handle failure (e.g. symbol without M5 data) | (a) `INIT_PARAMETERS_INCORRECT`; (b) `Indicator handle creation failed` + `INIT_FAILED` |
| T2.3 | Flat EMAs | Variant C on a range day | `FLAT_EMA_SEPARATION` / `FLAT_EMA_SLOPE` logged |
| T2.4 | Spread spikes | Run over a rollover hour (≈ 23:00–01:00 server) | `SPREAD_TO_STOP_RATIO` logged, no entry |
| T2.5 | Missing news data | Demo, disconnect internet, restart EA | `NEWS_DATA_UNVERIFIED`, entries blocked |
| T2.6 | Invalid stops | Broker with high stops level, or `MinStopATR=5` | `SL_TOO_CLOSE` / `BROKER_STOPS_LEVEL` |
| T2.7 | Different contract specs | Backtest on two brokers (100 oz and other) | same risk % per trade in account currency |
| T2.8 | Requotes | Demo with instant-execution symbol | ≤ 1 retry, logged, re-validated |
| T2.9 | Partial fills | IOC broker or exchange symbol | `PARTIAL FILL` warning, risk ≤ budget |
| T2.10 | Disconnection | Demo: disconnect during session | `TRADING_NOT_PERMITTED: terminal is disconnected`; no order |
| T2.11 | Market closure | Weekend / daily break | `MARKET_CLOSED`, no order |
| T2.12 | Terminal restart | Demo: open a trade, close terminal, reopen same day | baseline `RESTORED_FROM_PERSISTED_STATE`, entry count restored, no duplicate trade |
| T2.13 | Duplicate ticks | Inherent: evaluation keyed on bar open time | one evaluation per bar |
| T2.14 | Min lot > risk | Deposit 100 USD | `MIN_LOT_EXCEEDS_RISK`, no trade |
| T2.15 | Netting vs hedging | Run on both account types | netting: no order when a manual position exists (`FOREIGN_NETTING_POSITION`) |
| T2.16 | Manual position, hedging | Open a manual XAUUSD trade | EA ignores it, counts only its magic |
| T2.17 | Stale price data | `MaxQuoteAgeSeconds=1` on a quiet demo market | `QUOTE_STALE` |
| T2.18 | Modification errors | Enable trailing on a broker with a freeze level | `SL management skipped: … freeze level`, no error loop (2 s throttle) |
| T2.19 | Real account lock | Real account, FULL_AUTO, `EnableLiveTrading=false` | dashboard `LOCKED`, alerts with `(LIVE EXECUTION LOCKED)`, zero orders |
| T2.20 | Deposit/withdrawal | Demo deposit during the day | `Deposits/withdrawals since the baseline` log; Day P/L unchanged; no halt |
| T2.21 | Start right after account login / new demo account (v1.20) | Attach the robot, then log into a fresh demo with a deposit | Panel shows `waiting for account data` until the first tick; baseline log shows the real equity; no false halt |
| T2.22 | Scalper Pro exits (v1.20) | Demo, Scalper Pro, 1 day | log lines `SCALPER exit: … beyond EMA14`, `only xR after 10 bars`, `modified (break-even/trailing)` appear and match the chart |
| T2.23 | Loss-streak pause (v1.20) | Demo or tester, Scalper Pro | after 3 losses in a row: `LOSS_STREAK_PAUSE` until +60 min; panel shows `PAUSED->hh:mm` |

## T3 — Research backtests (performance)

**Data:** XAUUSD (broker symbol), M1, *Every tick based on real ticks*, the broker's real
variable spread, real commission. Deposit 10 000 USD. Risk 0.5 %, RR 1.5, daily loss 2 %,
5 entries/day.

**Periods:** at least 6–12 months total, split before looking at any result:

| Segment | Example (adjust to available data) | Use |
|---|---|---|
| In-sample | 2025.11.01 – 2026.06.30 | development, any tuning |
| Out-of-sample | 2026.07.01 – 2026.10.31 | **one** run per variant, no tuning afterwards |

`tests/tester_*.ini` implement this split with `ForwardMode=4`. Label regimes inside the
period (trend, range, high/low volatility) from the monthly table.

**Variants (identical dates, costs, risk):**

| Variant | Preset | Difference from A |
|---|---|---|
| A | `Backtest_A_Baseline.set` | baseline: Mode A, no flat filter, no BE |
| B | `Backtest_B_NextCandle.set` | Mode B |
| C | `Backtest_C_FlatFilter.set` | + flat-EMA filter (placeholder thresholds) |
| D | `Backtest_D_BreakEven.set` | + break-even at 1R |
| X | `Backtest_X_Crossover.set` | **different strategy**: CROSSOVER scalper, every M1 cross, SL 1.5 ATR, TP 1R, unlimited trades |
| X-T | `Backtest_X_CrossTrend.set` | X + only crosses in the M5 trend direction |
| S | `Backtest_S_ScalperPro.set` | **Scalper Pro up to v1.22** (§18): crosses + continuations, filters, BE/stale/EMA exits, 1R (control) |
| S-noM5 | `Backtest_S_ScalperPro_NoM5.set` | S without the M5 trend filter (more trades) |
| H | `Backtest_H_CrossTrail.set` | **Scalper Pro v1.30 defaults**: crosses only, no early exits, profit lock +0.25R at +1R, trailing 1.5 ATR from +1R, 4R target |

**Status 2026-11-11:**
- **Proxy-data part:** done. 1-minute gold data and the `research/` simulator; in-sample Feb–Jun
  2026, out-of-sample Jul–Nov 2026. Result **NO-GO**; see
  `reports/research/2026-11-11_proxy_research_report.md`.
- **Broker part:** pending. `RUN_BACKTESTS.bat` defaults to S vs H on 2025.01.01 → 2026.11.01
  (real ticks). Nothing was tuned on broker data, so the whole period is out-of-sample for both,
  and the decision rules below apply to it.

**Metrics (extended report + MT5 report):** total trades, win rate, net profit, profit factor,
max equity drawdown, average win, average loss, average realised R, expectancy, average and
median duration, trading costs, monthly results, max consecutive losses, BUY vs SELL, signal
funnel and rejection frequencies, daily-limit activations.

**Decision rules (set before testing):**
- At 1.5R the break-even win rate is 40 % **before** costs; with costs the required win rate is higher.
- A variant is a candidate only if the **out-of-sample** segment shows: ≥ 100 trades, profit
  factor ≥ 1.2 after costs, average realised R > 0, max equity drawdown ≤ 10 %, and no single
  month contributing more than half of the net profit.
- A higher win rate alone is not evidence of a better variant.
- If no variant meets the rules → **RESEARCH NO-GO** for live; continue demo research or stop.
- Avoid optimisation sweeps; if any parameter is tuned, it is tuned on in-sample only and the
  out-of-sample result is reported once.

## T4 — Demo forward test

Minimum 4 weeks on a demo account of the intended broker with `Demo_FullAuto.set`. Compare
fill slippage, spread at entry, commission and trade frequency with the backtest assumptions.
