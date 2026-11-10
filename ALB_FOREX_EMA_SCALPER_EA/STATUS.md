# STATUS — ALB FOREX EMA 8/14 EAs (baseline + Scalper Pro)

**Version:** 1.20 · **Updated:** 2026-11-10 · **Readiness: INCOMPLETE**

> Read this file first when resuming work. It separates what is implemented, what is verified
> with evidence, and what is still open. Never upgrade a status without evidence in `reports/`.

## Readiness

| Gate | Status |
|---|---|
| Source implemented | ✅ done — two robots over one core (`ALB_FOREX_EMA_CORE.mqh`) |
| Compiles with 0 errors / 0 warnings | ✅ **VERIFIED** (v1.20, both robots) — `reports/compile/2026-11-10_v1.20_compile.log` |
| Self-tests pass (105 checks) | ✅ **VERIFIED** (v1.20, both robots) — `reports/selftest/2026-11-10_v1.20_selftest_experts.log` |
| Functional backtests T1 | ⬜ not done — the owner's runs so far: see "Test results" |
| Edge cases T2 | ⬜ not run |
| Research backtests T3 (in/out-of-sample) | ⬜ not run — **no backtest performance data exists** |
| Demo forward test T4 | 🔶 started by the owner (IC Markets demo, 2026-11-10) — tiny sample, see below |
| **Overall** | **INCOMPLETE** — compiled and self-tested; not DEMO READY until T1 passes; not a LIVE CANDIDATE |

## Robots

| File | Opens in | Magic |
|---|---|---|
| `ALB_FOREX_SCALPER_PRO.ex5` | SCALPER PRO (STRATEGY_SPEC §18), unlimited trades, 1R | 81420262 |
| `ALB_FOREX_EMA_SCALPER_EA.ex5` | PULLBACK baseline (§4–§9), max 5/day, 1.5R | 81420261 |

## Completed implementation

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
| **Both robots compile: 0 errors, 0 warnings** | `reports/compile/2026-11-10_v1.20_compile.log` (MetaEditor64 5.0.0.6308; SHA-256 of all sources and binaries inside) | compilation only |
| **105 self-tests pass at runtime, both robots** — patterns, swings, rounding, TP, sizing, spread, drift, flat filter, day boundary, sessions, news parsing, crossover, scalper leg/momentum/stop/break-even/stale/EMA exit/loss streak, daily-loss model incl. the deposit cases | `reports/selftest/2026-11-10_v1.20_selftest_experts.log` | pure logic functions only |
| Both robots start and stop cleanly; Scalper Pro opens in SCALPER PRO mode, magic 81420262, unlimited trades; presets are read (108 inputs) | same log | EURUSD sample chart, no broker account, no ticks |
| Earlier versions: compile + self-tests v1.00 (72/72), v1.01 (74/74), v1.10 (80/80) | `reports/compile/`, `reports/selftest/` | history |
| Live calendar news filter works on a broker demo | owner screenshots 2026-11-09 (Lirunex) and 2026-11-10 (IC Markets) | live path only |

**Not yet verified:** Scalper Pro trading behaviour (entries, BE/stale/EMA exits, cooldown/pause) on
ticks, the new daily-loss model on a live account, and any backtest performance.

## Compilation status

**VERIFIED — 0 errors, 0 warnings** for every version (v1.00, v1.01, v1.10, v1.20).
Compiler: MetaEditor64.exe **5.0.0.6308** (official MetaQuotes installer, signed by MetaQuotes Ltd),
under WineHQ 11.0 in a Linux cloud sandbox with the owner's approval. Hashes in the compile logs.
Recompiling on your own MetaEditor (F7) is recommended; keep `ALB_FOREX_EMA_CORE.mqh` next to the `.mq5` files.

## Test results

- **T0.1 compile / T0.2 self-tests:** PASSED for every version (latest v1.20: 0/0 and 105/105, both robots).
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
- **No backtest performance statistics exist.**

## Incomplete / unverified

- All functional, edge-case, research tests (TEST_PLAN T1–T3), especially for SCALPER PRO.
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

1. **Owner:** on the IC Markets demo, close the old robot and attach **`ALB_FOREX_SCALPER_PRO`** to
   the XAUUSD M1 chart (panel line 3 must read `Entry: SCALPER PRO`). If other robots or manual
   trades use the same account, set *Daily loss measured on = this robot only*.
2. **Owner:** run `RUN_BACKTESTS.bat` (symbol `XAUUSD` for IC Markets) and send the zip from the
   Desktop — first real backtest data for S_ScalperPro vs S_ScalperPro_NoM5 vs X_Crossover vs A_Baseline.
3. Analyse: trades/day, win rate, average R, costs, rejection funnel; adjust one parameter at a time
   on in-sample only; confirm once on 2026.09.01 → today (out-of-sample).
4. Decide per TEST_PLAN rules: DEMO READY / RESEARCH NO-GO. No live trading before that.
