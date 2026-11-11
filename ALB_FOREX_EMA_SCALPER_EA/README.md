# ALB FOREX — EMA 8/14 EAs for XAUUSD (MT5)

Two **experimental research** Expert Advisors for **XAUUSD** on MetaTrader 5, built from one
shared core:

| Robot | Use it for | Opens with |
|---|---|---|
| **`ALB_FOREX_SCALPER_PRO`** | scalping: many quick trades | SCALPER PRO mode, unlimited trades, 1R target, magic 81420262 |
| `ALB_FOREX_EMA_SCALPER_EA` | the original pullback strategy | PULLBACK mode, max 5 trades/day, 1.5R, magic 81420261 |

**Scalper Pro (v1.20):** enters on fresh M1 EMA 8/14 crosses **and** on pullbacks to the EMA band
while the M1 trend lasts (max 3 per leg), only with the M5 trend, a strong candle, enough
volatility for the spread and no news spike. Stop behind the last 5 candles, 1R target,
break-even at +0.6R, exit when a candle closes back through EMA14, exit trades that go nowhere
after 10 bars, 3-bar cooldown after a loss, 60-minute pause after 3 losses in a row.

**Pullback baseline:**

- **Trend:** EMA 8/14 on the latest **closed** M5 candle.
- **Entry:** a closed M1 candle touches the EMA 8/14 band and confirms in the trend direction.
- **Exit:** structural swing stop-loss and a fixed **1.5R** take-profit.
- **Risk:** 0.5 % of equity per trade, 2 % daily equity guard, max 5 entries/day, one position per symbol.
- Also available via `EntryMode`: `CROSSOVER` (v1.10, every M1 cross, simple ATR stop).

> **Status: RESEARCH NO-GO (2026-11-11), version 1.22.** Both robots compile with 0 errors / 0 warnings
> (MetaEditor build 6308) and pass their 108 logic self-tests.
> - **Simulation result:** 9 months of 1-minute gold data with broker costs. The Scalper Pro
>   defaults **lose** (−0.07R per trade, about 22 trades/day, every month negative). No tuned
>   variant passed an out-of-sample test.
> - **Do not trade real money with these robots.**
> - Evidence: [research report](reports/research/2026-11-11_proxy_research_report.md) and [STATUS.md](STATUS.md).
>   Confirmation on the broker's real ticks: run `RUN_BACKTESTS.bat` (section 6a).

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
├── ALB_FOREX_SCALPER_PRO.ex5      compiled Scalper Pro robot v1.22
├── ALB_FOREX_EMA_SCALPER_EA.ex5   compiled baseline robot v1.22
├── ALB_FOREX_SCALPER_PRO.mq5      Scalper Pro source (defaults only)
├── ALB_FOREX_EMA_SCALPER_EA.mq5   baseline source (defaults only)
├── ALB_FOREX_EMA_CORE.mqh         shared core: all strategy, risk and execution code
├── presets/                       .set files for each research variant and test
├── research/                      Python simulator + experiment scripts (proxy-data research)
├── tests/                         Strategy Tester .ini configs (command-line backtests)
├── reports/                       put tester reports here (empty until tests are run)
├── RUN_BACKTESTS.bat              one-click: runs the test variants in MT5 and zips the results
├── tools/run_backtests.ps1        the PowerShell script behind RUN_BACKTESTS.bat
├── tools/make_presets.py          regenerates presets from the source defaults
└── *.md                           documentation
```

## 1. Install on Windows 11 / MT5

1. Open MetaTrader 5 → **File → Open Data Folder**.
2. Go to `MQL5\Experts\` and create the folder `ALB_FOREX_EMA_SCALPER_EA`.
3. Copy into it **all five** robot files: `ALB_FOREX_SCALPER_PRO.ex5`, `ALB_FOREX_EMA_SCALPER_EA.ex5`,
   `ALB_FOREX_SCALPER_PRO.mq5`, `ALB_FOREX_EMA_SCALPER_EA.mq5`, `ALB_FOREX_EMA_CORE.mqh`.
   (`RUN_BACKTESTS.bat` does this automatically.)
4. Copy the files from `presets\` to `…\MQL5\Profiles\Tester\` (for the Strategy Tester).
5. In MT5: *Navigator* → right-click *Expert Advisors* → **Refresh**.

## 2. Compile with MetaEditor

1. In MT5 press **F4** (MetaEditor).
2. Open `Experts\ALB_FOREX_EMA_SCALPER_EA\ALB_FOREX_SCALPER_PRO.mq5` (and/or `ALB_FOREX_EMA_SCALPER_EA.mq5`).
3. Press **F7** (Compile). The *Errors* tab must show `0 errors, 0 warnings`.
4. The `.ex5` is created next to the source. `ALB_FOREX_EMA_CORE.mqh` must be in the same folder.

If the compiler reports anything, copy the full *Errors* tab text and send it back for a fix.

Optional check: attach the EA with the `Test_SelfTests.set` preset (or set
**Run built-in logic self-tests on start = true**). The *Experts* tab must show
`[AFX-EMA][SELFTEST] 108 passed, 0 failed`.

## 3. Enable Algo Trading

- Toolbar button **Algo Trading** must be green.
- **Tools → Options → Expert Advisors**: allow algorithmic trading.
- When attaching the EA, tick **Allow Algo Trading** on the *Common* tab.

## 4. Load the EA on an XAUUSD chart

1. Open a chart of your broker's gold symbol (e.g. `XAUUSD`, `XAUUSD+`, `XAUUSD.ecn`,
   `XAUUSDm`). Use that exact symbol — the EA reads all contract data from the broker.
2. Set the chart to **M1** (recommended; the EA always uses M5 and M1 internally).
3. Drag **`ALB_FOREX_SCALPER_PRO`** (scalper) or `ALB_FOREX_EMA_SCALPER_EA` (pullback) from
   *Navigator → Expert Advisors* onto the chart. The panel's line 3 shows which strategy is active:
   `Entry: SCALPER PRO …` for the scalper, `Confirm: A same candle …` for the pullback.
4. Leave **TradingSymbol** empty (= chart symbol).
5. Give each running instance its own **MagicNumber** (the two robots already differ).
6. If other robots or manual trades share the account, set **Daily loss measured on = this robot
   only**; otherwise their losses also count towards the 2 % daily stop.

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
3. Type your gold symbol when asked (Enter = `XAUUSD`, e.g. IC Markets; Lirunex = `XAUUSD.std`).
4. Wait. It runs **S_ScalperPro** (the current Scalper Pro, control) and **H_CrossTrail** (best
   research hypothesis, see the research report) one after another on that symbol, M1, real ticks,
   2025.01.01 → 2026.11.01, deposit 10 000 USD. This can take several hours (overnight is fine).
   The first run also downloads tick data. The PC must stay on.
   If a run fails, the script prints MT5's own reason, stops, and (if MT5 did not use your broker
   account) lets you type your account number to retry. Your password must be saved in MT5.
5. At the end a single file `ALBFX_Backtests_<date>.zip` appears on your Desktop with every
   report, journal and log. Send that file for analysis.

Other symbol, dates or variants: `powershell -ExecutionPolicy Bypass -File tools\run_backtests.ps1 -Symbol XAUUSD -From 2025.01.01 -To 2026.11.01 -Variants S_ScalperPro,H_CrossTrail,A_Baseline`.
No parameter was tuned on broker data, so the whole default period is a fresh test for both variants.

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
