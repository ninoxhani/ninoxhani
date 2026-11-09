# STATUS — ALB_FOREX_EMA_SCALPER_EA

**Version:** 1.00 · **Date:** 2026-11-08 · **Readiness: INCOMPLETE**

> Read this file first when resuming work. It separates what is implemented, what is verified
> with evidence, and what is still open. Never upgrade a status without evidence in `reports/`.

## Readiness

| Gate | Status |
|---|---|
| Source implemented | ✅ done |
| Compiles with 0 errors / 0 warnings | ✅ **VERIFIED** — MetaEditor build 6308, `reports/compile/2026-11-08_v1.00_compile.log` |
| Self-tests pass (72 checks) | ⬜ not run (need a compiled `.ex5`) |
| Functional backtests T1 | ⬜ not run |
| Edge cases T2 | ⬜ not run |
| Research backtests T3 (in/out-of-sample) | ⬜ not run — **no performance data exists** |
| Demo forward test T4 | ⬜ not run |
| **Overall** | **INCOMPLETE** — compiled, but no runtime test yet; not DEMO READY until T0.2 + T1 pass; not a LIVE CANDIDATE |

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
| **Compiles: 0 errors, 0 warnings** | `reports/compile/2026-11-08_v1.00_compile.log` (MetaEditor64 5.0.0.6308, source SHA-256 `cd2e91c7…88f4`) | compilation only |

**Nothing about runtime behaviour or trading performance has been verified.** Compiling proves
the code is valid MQL5 — not that the logic behaves correctly at runtime.
The logic was reviewed line by line, but review is not evidence.

## Compilation status

**VERIFIED — 0 errors, 0 warnings.**

- Compiler: MetaEditor64.exe FileVersion **5.0.0.6308** (official MetaQuotes installer, signed by
  MetaQuotes Ltd, installer SHA-256 `a879492d…4c93`), run under WineHQ 11.0 in a Linux cloud sandbox
  with the owner's approval. Ubuntu's Wine 9.0 could not run MetaEditor (false "debugger detected").
- Result: `Result: 0 errors, 0 warnings, 2627 ms elapsed, cpu='X64 Regular'`
- Source SHA-256: `cd2e91c70c48bf00a70b1d3980c68e5687d832e06c206aae42fa45f24be288f4`
- `ALB_FOREX_EMA_SCALPER_EA.ex5` SHA-256: `33683b75cc8a3cea30087298922067d734a2ec27ba9abacf8c969a2fec592947`
- Full log: `reports/compile/2026-11-08_v1.00_compile.log`
- Recompiling on your own MetaEditor (F7) is still recommended; any newer build should also report 0/0.

## Test results

None. No backtest, forward test or self-test has been executed. **No performance statistics exist.**

## Incomplete / unverified

- Self-tests (T0.2) — need a running MT5 terminal.
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

1. ~~Compile~~ — done (0 errors, 0 warnings).
2. Run `Test_SelfTests.set` → expect `72 passed, 0 failed`.
3. Run TEST_PLAN **T1** functional checks on 1–2 weeks of real-tick data, especially T1.1 (look-ahead),
   T1.4 (TP), T1.5 (sizing), T1.11 (daily limit + emergency close).
4. Only then run **T3** variants A–D with identical dates and an untouched out-of-sample period,
   and store reports in `reports/`.
5. Decide per TEST_PLAN decision rules: DEMO READY / RESEARCH NO-GO. If out-of-sample results are
   negative or insufficient, mark the strategy **NOT VALIDATED** and continue demo research only.
