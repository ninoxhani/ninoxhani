# STRATEGY_SPEC — ALB_FOREX_EMA_SCALPER_EA v1.22

This document describes **exactly what the source code implements**. Where the master
prompt left a choice open, the chosen default and the reason are recorded under
"Implementation decisions". Nothing here is a claim of profitability.

This EA is a new, independent project. It is **not** the ALB FOREX Supply & Demand EA,
not Tradivo ProShi, not EAGLE and not a TradingView indicator. It shares no code,
magic number, global variables or files with them.

---

## 1. Market and timeframes

| Item | Value |
|---|---|
| Instrument | Chart symbol by default (`TradingSymbol` empty). Works with broker variants such as `XAUUSD`, `XAUUSD+`, `XAUUSD.ecn`, `XAUUSDm`. A warning is logged if the name does not contain `XAU`. |
| Trend timeframe | `TrendTF` = M5 |
| Entry timeframe | `EntryTF` = M1 |
| Contract data | Read from the broker at runtime: digits, point, tick size, volume min/max/step, stops level, freeze level, filling modes. Nothing is hard-coded. |

All decisions use **completed candles only**. The forming candle (shift 0) is never used
for a decision.

## 2. Indicators

Six handles are created in `OnInit` and released in `OnDeinit`:

| Handle | Definition |
|---|---|
| Trend EMA fast | `iMA(symbol, M5, 8, 0, MODE_EMA, PRICE_CLOSE)` |
| Trend EMA slow | `iMA(symbol, M5, 14, 0, MODE_EMA, PRICE_CLOSE)` |
| Entry EMA fast | `iMA(symbol, M1, 8, 0, MODE_EMA, PRICE_CLOSE)` |
| Entry EMA slow | `iMA(symbol, M1, 14, 0, MODE_EMA, PRICE_CLOSE)` |
| Entry ATR | `iATR(symbol, M1, 14)` — drift filter, stop buffer, min/max SL, trailing |
| Trend ATR | `iATR(symbol, M5, 14)` — flat-EMA filter normalisation |

Before any value is used the EA checks:
- `Bars()` on both timeframes is at least the required warm-up (≥ 5 × slow EMA period, ≥ 60 bars).
- `BarsCalculated(handle) >= Bars()` for every handle (indicator has processed the newest bar).
- Every `CopyBuffer` / `CopyRates` call returns the requested count.
- Every value is finite, non-`EMPTY_VALUE` and positive.

If any check fails the bar is retried on the next tick of the **same** bar for at most
`MaxSignalDelaySeconds` (default 30 s); after that the bar is recorded as `DATA_NOT_READY`.

## 3. Evaluation timing

- `OnTick` runs the daily-loss guard, fill reconciliation and position management on every tick.
- New entries are evaluated **once per newly opened M1 bar**. The signal candle is M1 shift 1.
- When the EA starts (or restarts) mid-bar, the current bar is marked as already seen. The EA
  never acts on a candle that closed before it was watching.
- **Latest closed M5 candle**: the M5 bar whose close time is ≤ the open time of the current M1
  bar. If the M5 series has not yet rolled to the bar containing the current time, the
  evaluation waits (`TREND_TF_NOT_SYNCED`) instead of using a possibly incomplete bar.
- `MaxSignalDelaySeconds` (30): if the first usable tick of the new bar arrives later than this,
  the signal is rejected as `STALE_SIGNAL`.
- `RejectAfterBarGap` (true): the signal candle must be directly adjacent to the current bar (and,
  in Mode B, the touch candle adjacent to the confirmation candle). Signals across market gaps are
  rejected as `STALE_SIGNAL`.

## 4. Trend (M5, latest closed bar)

```
dir = +1 (BUY)  if EMA8_M5 > EMA14_M5
dir = -1 (SELL) if EMA8_M5 < EMA14_M5
dir =  0        if equal  -> NO_TREND
```

## 5. EMA band and touch (M1)

```
BandLow  = min(EMA8_M1, EMA14_M1)
BandHigh = max(EMA8_M1, EMA14_M1)
Touch    = CandleLow <= BandHigh AND CandleHigh >= BandLow
```

EMA values are those of the same candle (their value at that candle's close). Wick contact
counts. The candle body does not need to overlap the band.

## 6. Confirmation modes

### Mode A — SAME_CANDLE (default, baseline)
Signal candle = M1 shift 1.

| BUY | SELL |
|---|---|
| M5 trend = BUY | M5 trend = SELL |
| candle touches band | candle touches band |
| Close > Open | Close < Open |
| Close > EMA8_M1 | Close < EMA8_M1 |

### Mode B — NEXT_CANDLE (experimental)
Touch candle = M1 shift 2, confirmation candle = M1 shift 1 (the immediately following candle).

- Touch candle must intersect **its own** band (EMAs at shift 2).
- `ModeBInvalidateOnCloseThrough` (true): a BUY setup is discarded if the touch candle closed
  below its BandLow; a SELL setup if it closed above its BandHigh (`SETUP_INVALIDATED`).
- Confirmation candle: BUY = bullish close above EMA8_M1 (shift 1); SELL = bearish close below EMA8_M1.
- Trend is read at confirmation time (latest closed M5 bar).
- Only the immediately following candle may confirm. There is no stored setup state: the rule is
  re-derived from closed bars, so it is deterministic and restart-safe, and a touch can never
  confirm two candles later.

Modes are never mixed inside one run. The confirmation mode is printed in the start-up log, in
every journal row and in the extended tester report.

### Optional entry-TF alignment
`RequireM1EMAAlignment` (false). When true, a BUY also needs EMA8_M1 > EMA14_M1 on the
confirmation candle (SELL: below). Rejection code `ENTRY_TF_EMA_ALIGNMENT`.

M1 EMA crossovers are **never** used as standalone entry signals.

## 7. Filters (evaluated after a pattern is confirmed)

Order of evaluation: flat-EMA → session → symbol session open → direction allowed by symbol
→ news → daily-loss halt → trades per day → unreconciled order → open position → max open
positions → foreign netting position → pending order → duplicate signal → trading permission
→ structural swing → quote validity/age → SL side/min/max → spread → drift → TP/R:R → stops
level → volume/risk → daily budget → margin → `OrderCheck`.

The first failing condition is the logged rejection reason.

### 7.1 Flat-EMA filter (`EnableFlatEMAFilter`, default **false**)
On the latest closed M5 bar, normalised by M5 ATR(14):
- Separation: `|EMA8 − EMA14| / ATR ≥ MinimumEMASeparationATR` (0.10) — toggle `UseSeparationCheck`.
- Slope: `(EMA14[closed] − EMA14[closed + SlopeBars]) / ATR`, signed in trade direction,
  `≥ MinimumEMASlopeATR` (0.10, `SlopeBars` = 3) — toggle `UseSlopeCheck`.

Thresholds are **initial placeholders, not optimised values**.

### 7.2 Spread filter (`EnableSpreadFilter`, true)
Spread is measured from the live quote (`Ask − Bid`), not `SYMBOL_SPREAD`.
- `spread ≤ MaxSpreadToStopRatio × SL distance` (0.15). Example: SL 100 points → spread ≤ 15 points.
- `spread ≤ MaxSpreadPoints` only if `MaxSpreadPoints > 0` (default 0 = disabled until calibrated).
- Invalid quotes (`bid ≤ 0`, `ask < bid`) → `QUOTE_INVALID`. Quotes older than
  `MaxQuoteAgeSeconds` (15) → `QUOTE_STALE`.

### 7.3 Entry drift (`EnableEntryDriftFilter`, true)
`|Bid − signal close| / ATR_M1 ≤ MaxEntryDriftATR` (0.20), for BUY and SELL.

Chart candles are Bid prices, so measuring on the Bid gives the **price movement since the signal**
for both directions. The spread is controlled separately by the spread filter (§7.2).
`DriftExcludesSpread=false` restores the v1.00 behaviour (executable quote: Ask for BUY, Bid for SELL).
That behaviour was a defect: on XAUUSD with a 0.20 USD spread and ATR(M1) ≈ 1.0–1.4 USD, the
spread alone consumed most of the 0.20-ATR allowance, so BUYs were almost always rejected while
SELLs were not. A late entry never widens the SL or increases risk; it is skipped.

### 7.4 News filter (`EnableNewsFilter`, true)
- Live/demo: MT5 economic calendar (`CalendarValueHistory`, `CalendarEventById`), currencies
  `NewsCurrencies` ("USD"), importance `HIGH` (option: medium + high), only events with an exact
  time (`CALENDAR_TIMEMODE_DATETIME`). Block window: 15 min before to 15 min after.
- Data verification: the calendar must return events for the first currency in the ±7-day
  window **including at least one future event**. Otherwise → `NEWS_DATA_UNVERIFIED` and **all new
  entries are blocked** (fail closed). Refresh every 10 min (every 1 min while unverified).
- Strategy Tester: calendar functions are not available there. The EA loads a CSV from
  `Terminal\Common\Files\` (`NewsCsvFile`). Missing file, empty file, or a test date outside the
  file's coverage → entries blocked. To backtest without news protection, set
  `EnableNewsFilter=false`; the extended report then prints
  `News filter: DISABLED - backtest has NO news protection (limitation)`.
- `NewsExportDays` > 0 (live/demo only) exports calendar history to that CSV so a backtest can use a
  reproducible dataset. Calendar times are broker server time.

### 7.5 Sessions
- Always: the symbol must be inside one of the broker's trade sessions for the current weekday
  (`SymbolInfoSessionTrade`). If the broker defines no sessions this check does not block; the
  server's `MARKET_CLOSED` return code still applies.
- Optional `EnableSessionFilter` (false): `[SessionStart, SessionEnd)` in broker server time,
  wrap past midnight supported. No London/New York hours are hard-coded.

## 8. Structural stop-loss

Swing pivots on completed M1 bars, searched over shifts `1 … SwingLookback` (20):

- Swing low at shift *i*: `Low[i]` strictly lower than the `SwingLeftBars` (2) older and
  `SwingRightBars` (2) newer bars. Therefore the newest possible pivot is shift 3; no forming-bar
  data is used.
- `SwingRequireUnbroken` (true): no completed bar newer than the pivot may trade below it
  (BUY) / above it (SELL). A broken pivot is skipped and the search continues to older pivots.
- The most recent qualifying pivot is used. None found → `NO_STRUCTURAL_SWING`, trade skipped.

```
buffer  = StopBufferPoints × point + StopBufferATR × ATR_M1     (defaults 0 pts + 0.10 ATR)
BUY  SL = swingLow  − buffer                      → rounded DOWN to the tick grid
SELL SL = swingHigh + buffer + spread (option)    → rounded UP   to the tick grid
```

`AddSpreadToSellStop` (true): chart candles are Bid prices but a SELL stop triggers on Ask, so the
current spread is added to keep BUY and SELL stops symmetric.

Validation (any failure skips the trade; the SL is never replaced by a fixed stop):
- BUY SL < Bid, SELL SL > Ask (`SL_WRONG_SIDE`).
- Distance `|entry − SL| ≥ max(MinStopATR × ATR_M1, MinStopPoints × point)` (0.25 ATR) (`SL_TOO_CLOSE`).
- Distance `≤ MaxStopATR × ATR_M1` (3.0 ATR, 0 = off) (`SL_TOO_FAR`).
- Broker stops level: BUY `Bid − SL` and `TP − Bid`, SELL `SL − Ask` and `Ask − TP` must be
  ≥ `SYMBOL_TRADE_STOPS_LEVEL × point` (`BROKER_STOPS_LEVEL`).

## 9. Take-profit

```
entry = Ask (BUY) / Bid (SELL) at decision time
BUY  TP = entry + RewardRisk × (entry − SL)     → rounded UP   to the tick grid
SELL TP = entry − RewardRisk × (SL − entry)     → rounded DOWN to the tick grid
```

Rounding away from the entry keeps R:R ≥ target after normalisation. The R:R is recomputed
after rounding; if it is below `RewardRisk − 0.01` the order is rejected.

After the fill, `ReanchorTPToFill` (true) recomputes the TP from the **actual fill price** and the
unchanged SL, and modifies the position if it differs by at least one tick (subject to stops/freeze
level). The SL is never moved or widened by this step.

## 10. Exits and holding time

Default exits: structural SL or fixed 1.5R TP. Expected holding time 5–15 minutes is an
**observation target only**; nothing closes a trade because of time unless enabled.

Optional, all **disabled by default** (they change the baseline and must be tested separately):
- Break-even: at `BreakEvenTriggerR` (1.0R) move SL to entry ± `BreakEvenOffsetPoints`.
- Trailing: after `TrailStartR` (1.0R) trail at `TrailDistanceATR` × ATR_M1; only tightens.
- Time exit: close after `MaxHoldMinutes` (30).

The R unit for management is the initial SL distance recorded at fill time (fallback:
`|TP − entry| / RewardRisk`).

## 11. Position sizing

```
riskBudget  = equity × RiskPercent / 100                   (0.5 %)
lossPerLot  = |OrderCalcProfit(type, 1 lot, entry ± slippage, SL ∓ slippage)|
              + EstimatedCommissionPerLot                  (round trip, account currency)
volume      = floor(riskBudget / lossPerLot / step) × step
```

- Slippage estimate `EstimatedSlippagePoints` (10) is applied adversely on both entry and stop.
- Volume is never rounded up; it is reduced step by step until `volume × lossPerLot ≤ budget`.
- Capped by `SYMBOL_VOLUME_MAX`, `SYMBOL_VOLUME_LIMIT` and optional `MaxLots`.
- If the minimum lot would exceed the budget → `MIN_LOT_EXCEEDS_RISK`, trade skipped.
- If `OrderCalcProfit` fails, the EA falls back to `SYMBOL_TRADE_TICK_VALUE_LOSS` and logs a warning.
- Margin: `OrderCalcMargin` must be ≤ `MaxMarginUsagePercent` (50 %) of free margin, then
  `OrderCheck` must pass.
- `CheckDailyBudgetBeforeEntry` (true): skip the trade if today's loss + this trade's full planned
  loss would exceed the daily limit.

## 12. Daily loss protection (model rewritten in v1.20)

- Broker day starts at server midnight (`DayResetHour` = 0).
- **Baseline** (set on the first tick of the day, or on the robot's first tick): equity `E0`,
  balance + credit `B0`, floating P/L `F0 = E0 − B0`, time `T0`. Live, the baseline is set only on
  the **first tick** after start, when the account data is synchronised (never during an account
  switch); until then new entries are blocked with `DATA_NOT_READY`.
- **Day loss (money)**, scope `DailyLossScope`:
  - `WHOLE ACCOUNT` (default): `loss = −(realised trading P/L since T0 + floating P/L now − F0)`.
    Realised trading P/L = profit + commission + swap + fee of every non-cash-flow deal after `T0`
    (all symbols).
  - `THIS ROBOT ONLY`: `loss = −(this robot's realised P/L today + its floating P/L now)`.
- **Deposits/withdrawals never enter the loss formula.** They are only used to scale the
  percentage: `cash flow = (balance + credit − B0) − realised trading P/L since T0`, i.e. every
  balance change not explained by trading. `loss % = loss / (E0 + cash flow) × 100`.
  v1.00–v1.10 added deposit *deals* time-stamped after `T0` to the baseline; when the robot started
  while MT5 was still loading the account (or a deposit was booked a second after start), the
  deposit could be counted twice and produce a false halt (seen on 2026-11-10: three winning trades,
  `Day P/L −7.37% HALTED`).
- Checked on **every tick and every second** (timer). Before halting, the deal history is refreshed
  and the loss recomputed, so a closed trade that is not yet in the history can not trigger a halt.
- At `MaxDailyLossPercent` (2 %): new entries disabled until the next broker day; the log line
  shows scope, loss, base, realised and floating parts. Existing SL/TP stay in place.
- `EmergencyCloseOnDailyLimit` (false): also close **this EA's** positions while at/below the floor.
- First start on a day without stored state (live): `T0` = day start, so today's realised losses
  before the robot started still count. `F0` = floating P/L of the positions that were already open
  at the day start (taken as unchanged); positions opened later today start from 0, so their P/L is
  counted once (v1.20 used all current floating P/L and could count a same-day position twice).
  Tester: snapshot at the start.
- Persistence (terminal global variables per login + magic + symbol, state version 121): day,
  `E0`, `B0`, `F0`, `T0`, halt flag, entry/alert counts, last acted-on signal candle. States from
  older versions are ignored (a new baseline is built). Disabled in the Strategy Tester.

This is a safety mechanism, **not a guaranteed loss cap**: gaps and slippage can push losses past
the threshold, and in `WHOLE ACCOUNT` scope other robots or manual trades on the same account count.

## 13. Trade frequency and duplicate prevention

- `MaxTradesPerDay` (5) executed entries per broker day, counted as unique position IDs from
  `DEAL_ENTRY_IN` deals of this magic/symbol (history-reconstructed after restarts).
- One open EA position per symbol; `MaxOpenPositions` (1) across all symbols for this magic.
- One evaluation per M1 bar; the last acted-on signal candle is persisted, so a signal is never
  acted on twice (also after a restart).
- No order while a previous order is still being reconciled.
- Netting accounts: if any manual or other-EA position exists on the symbol, no order is sent
  (it would merge into that position).
- Hedging accounts: only positions with this magic number are managed/counted.
- No reversal, no simultaneous BUY/SELL, no martingale, no grid, no averaging, no lot increase after losses.

## 14. Execution engine

- Native `OrderCheck` + `OrderSend` (`TRADE_ACTION_DEAL`) with SL/TP attached, unique magic,
  `MaxDeviationPoints` (30), filling mode chosen from `SYMBOL_FILLING_MODE` (FOK → IOC → RETURN).
- Success = server return code `DONE`, `DONE_PARTIAL` or `PLACED`, followed by **position
  reconciliation**: the EA looks for its position, reads the actual fill price, SL, TP and volume.
  - Missing SL after fill → try to attach it; if that fails the position is closed.
  - Partial fill → logged; for RETURN filling any remainder order is cancelled.
  - Risk overshoot from slippage (> 10 % above budget) → logged; SL is not widened.
  - No position after 30 s → `FILL NOT RECONCILED` error.
- Requote / price changed / price off → at most `MaxSendRetries` (1) retry, rebuilding and
  re-validating every quote-dependent check from scratch.
- Timeout / connection loss / unknown result → **no resend**; the signal is marked as used and the
  EA reconciles from positions.
- Before sending (live): terminal connected, Algo Trading on, EA trading allowed, account trading
  allowed, broker allows expert trading, symbol trade mode allows the direction.

## 15. Trading modes

| Mode | Behaviour |
|---|---|
| `FULL_AUTO` | Same signal engine and filters; sends orders. On a **real-money** account it sends orders **only if `EnableLiveTrading=true`**; otherwise it runs as alert-only and says so on the chart, in the log and in every alert. |
| `ALERT_ONLY` | Same signal engine and filters; never sends orders. Valid signals raise `Alert()` (and optional push) with entry/SL/TP/volume and draw an arrow. `MaxTradesPerDay` counts alerts. |

Demo and Strategy Tester accounts may run `FULL_AUTO` without `EnableLiveTrading`.

## 16. Implementation decisions (where the prompt left a choice)

| Decision | Choice | Reason |
|---|---|---|
| Flat-EMA filter default | **OFF** | Phase 8 defines "baseline + slope/separation filters" as variant C, so the baseline must run without it. |
| Slope EMA | slow EMA (14) over 3 closed M5 bars | Less noisy than EMA8; configurable via thresholds. |
| SELL stop spread | added (option) | SELL SL triggers on Ask; keeps BUY/SELL symmetric. |
| Unbroken swing rule | ON (option) | A pivot already violated by later candles is not valid structure. |
| Stop buffer | 0 pts + 0.10 × ATR_M1 | ATR keeps the default broker-independent (2- vs 3-digit gold quotes). |
| Min/max SL | 0.25 / 3.0 × ATR_M1 | Placeholders; skip, never widen. |
| Commission estimate | 7.0 per lot round trip | Conservative default; set to your broker's real value. |
| TP after fill | re-anchored to actual fill | Spec defines TP from the entry; the real entry is the fill. |
| Mode B invalidation | touch candle closing through the far side of the band | "Discard invalidated setups" needed a concrete rule. |
| Daily budget pre-check | ON (option) | Reduces overshoot of the daily limit by the next trade. |
| Default `TradingMode` | FULL_AUTO with `EnableLiveTrading=false` | Backtests/demo trade normally; real money is locked until explicitly enabled. |
| Drift price basis (v1.01) | Bid for both directions | The prompt said "executable quote"; taken literally it adds the spread to BUY drift only, a BUY/SELL bias found in the first XAUUSD test. The intent ("must not chase price") is price movement; spread has its own filter. Literal mode kept as an option. |

## 17. Entry mode CROSSOVER — scalper (v1.10, owner request 2026-11-09)

`EntryMode = CROSSOVER`. A separate, experimental strategy inside the same EA. The PULLBACK
baseline (§4–§9) is unchanged and remains the default (`EntryMode = PULLBACK`).

The original prompt said not to use M1 EMA crossovers as standalone signals. The owner explicitly
asked for this mode on 2026-11-09 ("enter every time the EMAs cross, not only 5 trades a day"),
so it exists as an opt-in mode with its own presets and must be evaluated separately.

| Item | Rule |
|---|---|
| Signal | Closed M1 bars: BUY when EMA8 ≤ EMA14 on shift 2 and EMA8 > EMA14 on shift 1; SELL mirrored. One signal per cross, evaluated once per new M1 bar. |
| Trend filter | `CrossUseTrendFilter` (default **false** = every cross). When true, only crosses in the direction of the latest closed M5 EMA 8/14 trend (`CROSS_AGAINST_TREND` otherwise). |
| Stop-loss | ATR stop: BUY SL = Bid − `CrossSLATR` × ATR(M1); SELL SL = Ask + `CrossSLATR` × ATR(M1) (default 1.5). Same spread cost for both sides. Min/max SL, spread, stops-level checks as in §8. |
| Take-profit | `RewardRisk` × SL distance (scalper presets use **1.0R**). |
| Opposite cross | `CrossCloseOnOpposite` (true): a cross the other way closes this EA's open position (`OPPOSITE CROSS`), even if the new entry is then rejected by a filter. A new entry in the new direction follows if all filters pass. |
| Trades per day | `MaxTradesPerDay = 0` = unlimited (scalper presets). |
| Unchanged protections | 0.5 % risk sizing, 2 % daily loss guard, spread/SL ratio, entry drift, news, sessions, one position per symbol, no martingale/grid. |

Why SL 1.5 × ATR(M1): with ~0.20 USD spread and ATR(M1) ≈ 1.0–1.4 USD, a stop of 1 ATR fails the
0.15 spread/SL rule; 1.5 ATR passes it. **All values are untested placeholders.**

Risk note: M1 crossovers on XAUUSD whipsaw often and every trade pays the spread. Whether this
mode has any edge is unknown until the CROSSOVER backtests (`Backtest_X_*`) are run.

## 18. Entry mode SCALPER PRO (v1.20, owner request 2026-11-10)

Owner request: more trades than the pullback baseline, quick in and out, but only "valuable" trades.
`EntryMode = SCALPER PRO` (default of the robot `ALB_FOREX_SCALPER_PRO`). All rules use closed bars.

**Entries (M1)**
| Type | Rule |
|---|---|
| CROSS | EMA8/EMA14 cross on shift 1 (`AfxCrossDirection`); the cross candle must close beyond **both** EMAs. `ScUseCrossEntries`. |
| CONTINUATION | While EMA8/EMA14 stay aligned (M1 leg), a candle touches the EMA band and closes back beyond EMA8 in the leg direction (rule of §6 Mode A on M1). EMA14 slope over `ScSlopeBars` (3) bars ≥ `ScMinSlopeATR` (0.10) × ATR in the trade direction. At most `ScMaxEntriesPerLeg` (3) entries per M1 leg (the leg starts at the bar of the last cross; entries are counted from deal history, restart-safe). `ScUseContinuation`. |

**Quality filters (both types)**
- `ScTrendFilter` (true): direction must equal the latest closed M5 EMA 8/14 trend.
- Momentum candle: body ≥ `ScMinBodyRatio` (0.40) × range, closing in the trade direction.
- Cost/volatility: ATR(M1) ≥ `ScMinATRSpread` (5) × current spread.
- Spike: ATR(M1, 14) ≤ `ScMaxATRRatio` (2.5) × ATR(M1, `ScATRLongPeriod` = 100) (avoids news bursts).
- Flat-EMA filter on M5 (§7.1) is **ON** by default in the Scalper Pro robot.
- All other gates of §7 apply (spread/SL ratio, drift, news, sessions, daily loss, one position).
- Cooldown: no entry for `ScCooldownBars` (3) bars after a losing trade.
- Loss streak: after `ScMaxConsecLosses` (3) losses in a row, pause `ScPauseMinutes` (60).
- Optional day target `ScDailyTargetPct` (0 = off): stop new entries above +N % day profit.

**Stop and target**
- Stop behind the lowest low (BUY) / highest high (SELL) of the last `ScSLBars` (5) closed bars,
  plus `ScSLBufferATR` (0.15) × ATR; SELL adds the spread (SELL stops trigger on Ask). Measured from
  Bid (BUY) / Ask (SELL): closer than `ScMinSLATR` (0.8) × ATR → widened to that distance; farther
  than `ScMaxSLATR` (2.5) × ATR → trade skipped (`SL_TOO_FAR`).
- Target `RewardRisk` × stop (Scalper Pro default **1.0R**), re-anchored to the fill.

**Active management ("get out fast")**
- Break-even: at +`ScBreakEvenR` (0.6R) the stop moves to entry + `ScBreakEvenLockR` (0.10R).
- Slow-EMA exit: on each new bar, if the closed candle closed beyond EMA14 against the trade → close.
- Stale exit: after `ScStaleBars` (10) bars with progress < `ScStaleMinR` (0.25R) → close.
- Opposite cross closes the open position (`CrossCloseOnOpposite`), before any entry filter.

**Unchanged:** 0.5 % risk sizing via `OrderCalcProfit`, 2 % daily guard, one position per symbol,
no martingale/grid/averaging, no lot increase after losses.

All Scalper Pro thresholds are **untested placeholders** chosen from trading logic, not optimised.
Whether this mode has an edge after costs is unknown until the `Backtest_S_*` runs are done.

### 18.1 Scalper Pro robot defaults from v1.30 (owner request 2026-11-12)

Owner request: let winners run (risk:reward at least 1:3, ideally 1:4), and protect trades that are
already in profit. Research (reports/research/) showed:
- the v1.21 defaults above lose (−0.07R per trade);
- the least-bad variant was cross entries with a trailing stop (hypothesis H).

The `ALB_FOREX_SCALPER_PRO` robot therefore opens with:

| Input | v1.21 | **v1.30 default** | Why |
|---|---|---|---|
| `ScUseContinuation` | true | **false** | continuation entries were the biggest losers |
| `RewardRisk` | 1.0 | **4.0** | 1:4 target; most winners exit earlier through the trailing stop |
| `ScBreakEvenR` / `ScBreakEvenLockR` | 0.6 / 0.10 | **1.0 / 0.25** | at +1R the stop locks +0.25R: a trade that reached +1R no longer ends in a loss (except gaps) |
| `EnableTrailingStop` / `TrailStartR` / `TrailDistanceATR` | off | **on / 1.0 / 1.5** | from +1R the stop follows the price 1.5 × ATR(M1) behind, only in the profit direction |
| `ScStaleBars`, `ScExitOnSlowEMAClose`, `CrossCloseOnOpposite` | 10, true, true | **0, false, false** | early exits cut trades at a loss before they could run |

Unchanged:
- entry filters, stop (max loss 1R), sizing, cooldown, loss-streak pause, daily guard;
- magic 81420262;
- order comment, which is now `ALBFX_SCP4R` so the v1.30 trades can be told apart.

Stop management (`AfxManagedStop`, self-tested):
- the new stop is the best of the current stop, the profit-lock level and price − 1.5 ATR, and it
  never loosens;
- trailing-only moves are sent in steps of at least 10 % of the trail distance;
- the first move to the profit lock is always sent.

**Simulation result (proxy data, Feb–Nov 2026, real IC Markets commission):**
- 5.8 trades/day, 49 % winners;
- +0.045R per trade (Feb–Jun) and +0.039R (Jul–Nov);
- PF 1.08, max drawdown 42R, t ≈ 1.2.

That is better than v1.21 (−0.07R, every month negative) but **not statistically proven**, and
with 1.5× spreads it is about break-even. Demo only until the broker-data test confirms it.

## 19. Robot files (v1.20)

| File | Opens in | Magic | Notes |
|---|---|---|---|
| `ALB_FOREX_EMA_SCALPER_EA.ex5` | PULLBACK (baseline), max 5/day, 1.5R | 81420261 | all modes available via `EntryMode` |
| `ALB_FOREX_SCALPER_PRO.ex5` | SCALPER PRO, unlimited trades, 1.0R, M5 flat filter on | 81420262 | can run next to the baseline robot |

Both are built from the shared `ALB_FOREX_EMA_CORE.mqh`; the `.mq5` files only change defaults.
