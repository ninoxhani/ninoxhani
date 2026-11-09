# CHANGELOG — ALB_FOREX_EMA_SCALPER_EA

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
