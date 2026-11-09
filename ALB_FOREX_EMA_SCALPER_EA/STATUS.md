# STATUS — ALB_FOREX_EMA_SCALPER_EA

**Version:** 1.00 · **Date:** 2026-11-08 · **Readiness: INCOMPLETE**

> Read this file first when resuming work. It separates what is implemented, what is verified
> with evidence, and what is still open. Never upgrade a status without evidence in `reports/`.

## Readiness

| Gate | Status |
|---|---|
| Source implemented | ✅ done |
| Compiles with 0 errors / 0 warnings | ⬜ **NOT VERIFIED** — no MetaEditor run yet (see below) |
| Self-tests pass (72 checks) | ⬜ not run (need a compiled `.ex5`) |
| Functional backtests T1 | ⬜ not run |
| Edge cases T2 | ⬜ not run |
| Research backtests T3 (in/out-of-sample) | ⬜ not run — **no performance data exists** |
| Demo forward test T4 | ⬜ not run |
| **Overall** | **INCOMPLETE** — not DEMO READY until T0 passes; not a LIVE CANDIDATE |

## Completed implementation (v1.00)

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
  72 self-tests.

## Verified features

| What | Evidence | Scope |
|---|---|---|
| Presets contain every EA input with source defaults | `tools/make_presets.py` parses 78 inputs from the source | presets only |
| Source file is plain ASCII, single copy of every function | checked in this session | text only |

**Nothing about runtime behaviour, compilation or trading performance has been verified.**
The logic was reviewed line by line, but review is not evidence.

## Compilation status

**NOT VERIFIED.**

- This work was done in a Linux cloud sandbox without MetaTrader. The official MetaQuotes
  installer (`mt5setup.exe`, signed by MetaQuotes Ltd, SHA-256
  `a879492dd9d7b168d0538edd1c0dc5604ca43dc0951825b3501818e8b18f4c93`) was downloaded to set up
  MetaEditor under Wine, but running it was blocked by the sandbox's safety policy pending owner
  approval. **No compiler has processed this source yet.**
- No `.ex5` is included. One will only be added together with a real compiler log.
- Risk: MQL5 compile errors or warnings are possible. They are expected to be small (type casts,
  API signature details) but are unknown until compiled.

## Test results

None. No backtest, forward test or self-test has been executed. **No performance statistics exist.**

## Incomplete / unverified

- Compilation (T0.1) and self-tests (T0.2).
- All functional, edge-case, research and demo tests (TEST_PLAN T1–T4).
- News filter: live calendar path, CSV export and tester CSV path are untested. Calendar time
  stamps for past events may reflect the broker's current UTC offset (DST) — verify a few known
  events (e.g. NFP) in the exported CSV before relying on it.
- Emergency close on daily limit: implemented, not yet tested (preset `Test_DailyLimit_Emergency.set`).
- Flat-filter, drift, buffer and min/max SL thresholds are placeholders, not calibrated.
- `EstimatedCommissionPerLot` (7.0) must be set to the real broker value.

## Known defects / limitations

- No verified defects (nothing has run yet).
- `MaxTradesPerDay` in ALERT_ONLY counts alerts; position-based rules cannot be simulated there
  (no virtual positions).
- If `TradingSymbol` differs from the chart symbol, signals are evaluated only on chart ticks.
- Strategy Tester remote/cloud agents cannot read the news CSV from `Common\Files`; use local agents.
- The daily guard is equity-based and not a guaranteed loss cap.

## Next required action

1. **Compile** `ALB_FOREX_EMA_SCALPER_EA.mq5` in MetaEditor (F7) on Windows, or approve running
   the MetaQuotes installer in the sandbox. Fix every error and warning. Record the log here.
2. Run `Test_SelfTests.set` → expect `72 passed, 0 failed`.
3. Run TEST_PLAN **T1** functional checks on 1–2 weeks of real-tick data, especially T1.1 (look-ahead),
   T1.4 (TP), T1.5 (sizing), T1.11 (daily limit + emergency close).
4. Only then run **T3** variants A–D with identical dates and an untouched out-of-sample period,
   and store reports in `reports/`.
5. Decide per TEST_PLAN decision rules: DEMO READY / RESEARCH NO-GO. If out-of-sample results are
   negative or insufficient, mark the strategy **NOT VALIDATED** and continue demo research only.
