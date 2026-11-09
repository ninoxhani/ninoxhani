# ALB FOREX — EMA 8/14 Scalper EA (MT5)

`ALB_FOREX_EMA_SCALPER_EA` is an **experimental research** Expert Advisor for **XAUUSD** on
MetaTrader 5:

- **Trend:** EMA 8/14 on the latest **closed** M5 candle.
- **Entry:** a closed M1 candle touches the EMA 8/14 band and confirms in the trend direction.
- **Exit:** structural swing stop-loss and a fixed **1.5R** take-profit.
- **Risk:** 0.5 % of equity per trade, 2 % daily equity guard, max 5 entries/day, one position per symbol.

> **Status: NOT VALIDATED.** Compiles with 0 errors / 0 warnings (MetaEditor build 6308) and passes
> its 74 logic self-tests, but no
> backtest has been run yet and there is no evidence of a
> positive edge. Do not trade real money with it. See [STATUS.md](STATUS.md).

This project is independent. It does **not** change or share code with the ALB FOREX
Supply & Demand EA, Tradivo ProShi, EAGLE or any TradingView indicator.

| Document | Content |
|---|---|
| [STRATEGY_SPEC.md](STRATEGY_SPEC.md) | exact implemented rules and design decisions |
| [CONFIGURATION.md](CONFIGURATION.md) | every input, unit, default and rejection code |
| [TEST_PLAN.md](TEST_PLAN.md) | compile, functional, edge-case and research test plan |
| [STATUS.md](STATUS.md) | what is done, verified, unverified, and the next action |
| [CHANGELOG.md](CHANGELOG.md) | version history |

## Project layout

```
ALB_FOREX_EMA_SCALPER_EA/
├── ALB_FOREX_EMA_SCALPER_EA.mq5   EA source (single file, no external includes)
├── ALB_FOREX_EMA_SCALPER_EA.ex5   compiled EA v1.01 (MetaEditor build 6308)
├── presets/                       .set files for each research variant and test
├── tests/                         Strategy Tester .ini configs (command-line backtests)
├── reports/                       put tester reports here (empty until tests are run)
├── RUN_BACKTESTS.bat              one-click: runs variants A-D in MT5 and zips the results
├── tools/run_backtests.ps1        the PowerShell script behind RUN_BACKTESTS.bat
├── tools/make_presets.py          regenerates presets from the source defaults
└── *.md                           documentation
```

## 1. Install on Windows 11 / MT5

1. Open MetaTrader 5 → **File → Open Data Folder**.
2. Go to `MQL5\Experts\` and create the folder `ALB_FOREX_EMA_SCALPER_EA`.
3. Copy `ALB_FOREX_EMA_SCALPER_EA.mq5` into it:
   `…\MQL5\Experts\ALB_FOREX_EMA_SCALPER_EA\ALB_FOREX_EMA_SCALPER_EA.mq5`
4. Copy the files from `presets\` to `…\MQL5\Profiles\Tester\` (for the Strategy Tester).

## 2. Compile with MetaEditor

1. In MT5 press **F4** (MetaEditor).
2. Open `Experts\ALB_FOREX_EMA_SCALPER_EA\ALB_FOREX_EMA_SCALPER_EA.mq5`.
3. Press **F7** (Compile). The *Errors* tab must show `0 errors, 0 warnings`.
4. `ALB_FOREX_EMA_SCALPER_EA.ex5` is created next to the source.

If the compiler reports anything, copy the full *Errors* tab text and send it back for a fix.

Optional check: attach the EA with the `Test_SelfTests.set` preset (or set
**Run built-in logic self-tests on start = true**). The *Experts* tab must show
`[AFX-EMA][SELFTEST] 74 passed, 0 failed`.

## 3. Enable Algo Trading

- Toolbar button **Algo Trading** must be green.
- **Tools → Options → Expert Advisors**: allow algorithmic trading.
- When attaching the EA, tick **Allow Algo Trading** on the *Common* tab.

## 4. Load the EA on an XAUUSD chart

1. Open a chart of your broker's gold symbol (e.g. `XAUUSD`, `XAUUSD+`, `XAUUSD.ecn`,
   `XAUUSDm`). Use that exact symbol — the EA reads all contract data from the broker.
2. Set the chart to **M1** (recommended; the EA always uses M5 and M1 internally).
3. Drag the EA from *Navigator → Expert Advisors* onto the chart.
4. Leave **TradingSymbol** empty (= chart symbol).
5. Give each running instance its own **MagicNumber**.

## 5. Choose FULL_AUTO or ALERT_ONLY

| Account | TradingMode | EnableLiveTrading | Result |
|---|---|---|---|
| Demo | FULL_AUTO | false | trades automatically |
| Demo / real | ALERT_ONLY | any | alerts only, never sends orders |
| **Real money** | FULL_AUTO | **false** | **locked**: runs as alerts-only and says so on the chart |
| Real money | FULL_AUTO | true | sends real orders — only after validation (see STATUS.md) |

The dashboard (top-left) shows the mode, execution status, M5 trend, daily P/L vs limit,
entries today, news-filter status, open position and the last evaluation result.

## 6. Run a Strategy Tester backtest

### 6a. One click (recommended)

1. Log in to your broker account in MT5 once with **Save password** ticked, then **close MT5**.
2. Double-click **`RUN_BACKTESTS.bat`** in this folder. (If Windows SmartScreen warns:
   *More info → Run anyway*.)
3. Wait. It runs variants A, B, C and D one after another on `XAUUSD.std`, M1, real ticks,
   2026.04.01 → 2026.08.31, deposit 10 000 USD. The first run also downloads tick data.
   The PC must stay on.
4. At the end a single file `ALBFX_Backtests_<date>.zip` appears on your Desktop with every
   report, journal and log. Send that file for analysis.

Other symbol or dates: `powershell -ExecutionPolicy Bypass -File tools\run_backtests.ps1 -Symbol XAUUSD -From 2026.04.01 -To 2026.08.31`.
The out-of-sample period (2026.09.01 onward) is deliberately not part of the default run.

### 6b. Manually

1. **View → Strategy Tester** (Ctrl+R).
2. Expert: `ALB_FOREX_EMA_SCALPER_EA\ALB_FOREX_EMA_SCALPER_EA`.
3. Symbol: your gold symbol. Timeframe: **M1**.
4. Modelling: **Every tick based on real ticks**.
5. Deposit **10 000 USD**, leverage as your broker offers.
6. Dates: at least 6–12 months. Use **Forward = Custom** with a date to keep a separate
   out-of-sample period.
7. **Inputs → Load** → `Backtest_A_Baseline.set`.
8. Start. When finished, the *Journal* tab prints the **extended report** and saves it to
   `Common\Files\ALBFX_EMA_SCALPER_Report_<symbol>_ModeA.txt`
   (**File → Open Data Folder**, go up one level, then `Common\Files`).

Command-line alternative: `tests\tester_A_Baseline.ini` (instructions inside the file).

**News filter in backtests:** MT5 calendar functions do not work in the Strategy Tester. The
backtest presets therefore set `EnableNewsFilter=false`, and the report states that the backtest
has no news protection. For a news-filtered backtest, first export a dataset on a demo chart
(`News export days = 400`, any mode), then use `Backtest_A_NewsCSV.set`. If the filter is enabled
without valid data, the EA **blocks every entry** on purpose (fail-closed).

Run variants A–D with **identical dates and costs**. Do not optimise on the full period and
then call it validation. See [TEST_PLAN.md](TEST_PLAN.md).

## 7. Read logs and diagnose skipped trades

- **Experts tab** (live) / **Journal tab** (tester): every evaluated setup prints one line, e.g.
  `EVAL BUY mode A bar 2026.11.06 14:32 -> REJECTED [SPREAD_TO_STOP_RATIO] spread 32 pts > 0.15 x SL 180 pts`
- Valid signals: `SIGNAL BUY mode A … entry … SL … TP … vol … risk …`
- Orders: `ORDER ACCEPTED …`, then `FILL VERIFIED …` (actual fill, slippage, risk at SL).
- Journal CSV: `Common\Files\ALBFX_EMA_SCALPER_Journal_<symbol>_<magic>_<LIVE|TESTER>.csv` —
  one row per setup with all values (open in Excel).
- Every rejection code is explained in [CONFIGURATION.md](CONFIGURATION.md#rejection-codes-log-journal-report).
- Bars without trend or band touch are silent unless **Log no-setup bars = true**.

Common reasons for "no trades":
`NEWS_DATA_UNVERIFIED` (news filter on but no data — always in the tester without a CSV),
`TRADING_NOT_PERMITTED` (Algo Trading off), `SPREAD_TO_STOP_RATIO` (spread too wide for the
stop), `MIN_LOT_EXCEEDS_RISK` (account too small for the stop distance), `LOCKED: real account`.

## 8. Use on a demo account

1. Open a demo account with the broker you intend to use (same symbol, spreads, commission).
2. Set **EstimatedCommissionPerLot** to that broker's real round-trip commission.
3. Load `Demo_FullAuto.set`, attach to the gold M1 chart, Algo Trading on.
4. Keep the terminal running (VPS recommended). The daily baseline and counters survive
   restarts on the same broker day.
5. Compare demo fills (journal CSV, `FILL VERIFIED` lines) with backtest assumptions for
   slippage, spread and commission for several weeks before drawing any conclusion.

## Safety notes

- No martingale, grid, averaging, recovery or lot increase after losses.
- The 2 % daily guard is equity-based and **not a guaranteed cap** (gaps, slippage, other EAs).
- Real-money execution requires an explicit `EnableLiveTrading=true`; it is never activated silently.

---
ALB FOREX · [albforex.al](https://albforex.al) · Telegram @Alb_Forex
