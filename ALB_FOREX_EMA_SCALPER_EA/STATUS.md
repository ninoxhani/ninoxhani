# STATUS — ALB_FOREX_EMA_SCALPER_EA

**Version:** 1.01 · **Updated:** 2026-11-09 · **Readiness: INCOMPLETE**

> Read this file first when resuming work. It separates what is implemented, what is verified
> with evidence, and what is still open. Never upgrade a status without evidence in `reports/`.

## Readiness

| Gate | Status |
|---|---|
| Source implemented | ✅ done |
| Compiles with 0 errors / 0 warnings | ✅ **VERIFIED** (v1.01) — MetaEditor build 6308, `reports/compile/2026-11-09_v1.01_compile.log` |
| Self-tests pass (74 checks) | ✅ **VERIFIED** (v1.01) — 74 passed, 0 failed in MT5 build 6308, `reports/selftest/2026-11-09_v1.01_selftest_experts.log` |
| Functional backtests T1 | ⬜ not completed — first owner run (Lirunex demo, XAUUSD.std M1, 2026.10.01–10.05, v1.00) showed the BUY drift defect fixed in v1.01; rerun with v1.01 |
| Edge cases T2 | ⬜ not run |
| Research backtests T3 (in/out-of-sample) | ⬜ not run — **no performance data exists** |
| Demo forward test T4 | ⬜ not run |
| **Overall** | **INCOMPLETE** — compiles and pure logic is self-tested, but no trading test yet; not DEMO READY until T1 passes; not a LIVE CANDIDATE |

## Completed implementation (v1.00 + v1.01 fix)

All items of the master prompt Phases 1–6 are implemented in `ALB_FOREX_EMA_SCALPER_EA.mq5`:

- Signal engine: M5 closed-bar EMA 8/14 trend, M1 band touch, Mode A / Mode B, optional M1 alignment.
- Closed-candle-only evaluation, once per M1 bar, M5 closed-bar synchronisation, stale/gap rejection.
- Filters: flat-EMA (separation/slope, ATR-normalised, independent toggles), spread/SL ratio,
  absolute spread (off), quote validity/age, entry drift, news (live calendar, tester CSV,
  fail-closed, export), optional session window, broker trade session, symbol trade mode.
- Structural SL from confirmed unbroken 2/2 pivots, ATR buffer, SELL spread compensation,
  min/max distance, stops level, tick-grid rounding.
- 1.5R TP rounded away from entry, R:R re-check, TP re-anchored to the actual fill.
- Equity-risk sizing via `OrderCalcProfit` (+ slippage, commission), floor to step, min-lot skip,
  volume max/limit/cap, margin check, `OrderCheck`, daily-budget pre-check.
- Daily equity guard with cash-flow-adjusted baseline, persistence + reconstruction after restart,
  optional emergency close.
- Max entries/day (history-reconstructed), one position per symbol, max open positions,
  duplicate-signal prevention (persisted), netting foreign-position protection, hedging magic isolation.
- Execution: filling-mode selection, return-code verification, position reconciliation,
  partial fills, missing-SL protection, single controlled requote retry, no resend on unknown result.
- FULL_AUTO / ALERT_ONLY with real-money lock (`EnableLiveTrading`).
- Optional break-even / trailing / time exit (off by default).
- Diagnostics: rejection codes, CSV journal, dashboard, extended tester report with all 16 metrics,
  74 self-tests.

## Verified features

| What | Evidence | Scope |
|---|---|---|
| Presets contain every EA input with source defaults | `tools/make_presets.py` parses 78 inputs from the source | presets only |
| Source file is plain ASCII, single copy of every function | checked in this session | text only |
| **Compiles: 0 errors, 0 warnings** | v1.00: `reports/compile/2026-11-08_v1.00_compile.log`; v1.01: `reports/compile/2026-11-09_v1.01_compile.log` (MetaEditor64 5.0.0.6308) | compilation only |
| **74 self-tests pass at runtime** (v1.01; v1.00: 72/72) (trend, band touch, Mode A/B patterns, swing detection, tick rounding, TP, volume sizing, spread ratio, entry drift, flat filter, day boundary, sessions, news parsing) | `reports/selftest/2026-11-09_v1.01_selftest_experts.log` | pure logic functions only |
| EA initialises and deinitialises cleanly on a live chart; preset file is read (79 inputs) | same log + terminal journal | EURUSD sample chart, no broker account, no ticks |
| EA runs on a real broker demo: dashboard live, M5 trend read, **live news calendar verified** ("LIVE calendar OK, 6 relevant events"), signal evaluation and rejection codes active | owner screenshot 2026-11-09 (Lirunex demo, XAUUSD.std, hedging, v1.00) | no trade observed yet |

**Not yet verified:** order execution, SL/TP placement, sizing against a real contract,
daily limit, news filter, and any trading performance. The self-tests cover the pure decision
functions only; the terminal-dependent code (orders, history, calendar) has not run with ticks.

## Compilation status

**VERIFIED — 0 errors, 0 warnings** (v1.00 and v1.01).

- Compiler: MetaEditor64.exe FileVersion **5.0.0.6308** (official MetaQuotes installer, signed by
  MetaQuotes Ltd, installer SHA-256 `a879492d…4c93`), run under WineHQ 11.0 in a Linux cloud sandbox
  with the owner's approval. Ubuntu's Wine 9.0 could not run MetaEditor (false "debugger detected").
- v1.01 (current): `Result: 0 errors, 0 warnings, 3020 ms elapsed`; source SHA-256
  `6871315a2c70e03b77fb964a3819c0a5ee9531bba0b746652bde0d835481e4c1`; `.ex5` SHA-256
  `c05b0f258af414de7db063ce4689a757ddb58005ba375b357a05c864a4263ecc`; log `reports/compile/2026-11-09_v1.01_compile.log`
- v1.00: `Result: 0 errors, 0 warnings`; log `reports/compile/2026-11-08_v1.00_compile.log`
- Recompiling on your own MetaEditor (F7) is still recommended; any newer build should also report 0/0.

## Test results

- **T0.1 compile:** PASSED (0 errors, 0 warnings) — v1.00 and v1.01.
- **T0.2 self-tests:** PASSED — v1.00 72/72, v1.01 74/74 — MT5 build 6308, 2026-11-09.
- **Owner demo run (v1.00, Lirunex XAUUSD.std):** EA live, news calendar verified, evaluations logged.
- **Owner tester run (v1.00, XAUUSD.std M1, 2026.10.01–10.05, visual):** no trades visible in the shown window.
  Review found a defect: BUY drift was measured on the Ask, so the ~0.20 USD spread alone used up
  most of the 0.20 × ATR(M1) ≈ 0.21–0.28 USD drift limit → BUYs almost always rejected (`ENTRY_DRIFT`),
  SELLs not. **Fixed in v1.01** (drift on Bid basis). Full journal of that run not yet reviewed.
- **Strategy Tester:** NOT RUN. Attempted on the terminal's offline EURUSD sample data as a
  functional check; MT5 refused: `tester not started because the account is not specified`. A broker
  (demo) account is required, which this sandbox does not have.
- **No backtest, forward test or performance statistics exist.**

## Incomplete / unverified

- All functional, edge-case, research and demo tests (TEST_PLAN T1–T4).
- News filter: live calendar path, CSV export and tester CSV path are untested. Calendar time
  stamps for past events may reflect the broker's current UTC offset (DST) — verify a few known
  events (e.g. NFP) in the exported CSV before relying on it.
- Emergency close on daily limit: implemented, not yet tested (preset `Test_DailyLimit_Emergency.set`).
- Flat-filter, drift, buffer and min/max SL thresholds are placeholders, not calibrated.
- `EstimatedCommissionPerLot` (7.0) must be set to the real broker value.

## Known defects / limitations

- Fixed in v1.01: BUY-only entry-drift bias (spread counted as drift for BUY). No other verified defects.
- `Last:` dashboard line shows the most recent evaluated setup only; use the Experts log / journal CSV for history.
- `MaxTradesPerDay` in ALERT_ONLY counts alerts; position-based rules cannot be simulated there
  (no virtual positions).
- If `TradingSymbol` differs from the chart symbol, signals are evaluated only on chart ticks.
- Strategy Tester remote/cloud agents cannot read the news CSV from `Common\Files`; use local agents.
- The daily guard is equity-based and not a guaranteed loss cap.

## Next required action

1. ~~Compile~~ — done (0 errors, 0 warnings).
2. ~~Self-tests~~ — done (v1.01: 74/74).
3. On your Windows MT5 (logged in to a demo account of your broker, XAUUSD real ticks available): run TEST_PLAN **T1** functional checks on 1–2 weeks of real-tick data, especially T1.1 (look-ahead),
   T1.4 (TP), T1.5 (sizing), T1.11 (daily limit + emergency close).
4. Only then run **T3** variants A–D with identical dates and an untouched out-of-sample period,
   and store reports in `reports/`.
5. Decide per TEST_PLAN decision rules: DEMO READY / RESEARCH NO-GO. If out-of-sample results are
   negative or insufficient, mark the strategy **NOT VALIDATED** and continue demo research only.
