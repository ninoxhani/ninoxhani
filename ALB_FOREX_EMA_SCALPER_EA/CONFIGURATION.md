# CONFIGURATION — ALB_FOREX_EMA_SCALPER_EA v1.01

The MT5 inputs dialog shows the **label** (text after `//` in the source). Preset `.set` files
and the tester `.ini` use the **variable name** (`Inp…`). Both are listed below.

Units are explicit: **pts** = symbol points (`SYMBOL_POINT`; on a 2-digit gold quote 1 pt = 0.01,
on a 3-digit quote 1 pt = 0.001), **ATR** = multiple of ATR(14) of the stated timeframe,
**%** = percent, **R** = multiples of the initial stop distance.

> Defaults marked *placeholder* were chosen as safe starting points. They are **not**
> optimised or validated values.

## General

| Label | Variable | Default | Unit / notes |
|---|---|---|---|
| TradingMode | `InpTradingMode` | FULL_AUTO (0) | 0 = FULL_AUTO, 1 = ALERT_ONLY |
| TradingSymbol | `InpTradingSymbol` | "" | empty = chart symbol. Attach the EA to a chart of the same symbol. |
| MagicNumber | `InpMagicNumber` | 81420261 | must be unique per EA instance and different from your other EAs; 0 is refused |
| EnableLiveTrading | `InpEnableLiveTrading` | false | **required** to send orders on a REAL-money account. Ignored on demo/tester. |
| Order comment prefix | `InpOrderComment` | ALBFX_EMA | max 31 chars incl. suffix |

## Strategy

| Label | Variable | Default | Unit / notes |
|---|---|---|---|
| FastEMA | `InpFastEMA` | 8 | period |
| SlowEMA | `InpSlowEMA` | 14 | period, must be > FastEMA |
| TrendTF | `InpTrendTF` | M5 | must be higher than EntryTF |
| EntryTF | `InpEntryTF` | M1 | |
| ConfirmationMode | `InpConfirmationMode` | SAME_CANDLE (0) | 0 = Mode A, 1 = Mode B (experimental). Never mix in one run. |
| RequireM1EMAAlignment | `InpRequireM1EMAAlignment` | false | entry-TF EMA8 above/below EMA14 in trade direction |
| Mode B close-through invalidation | `InpModeBInvalidateOnCloseThrough` | true | Mode B only |
| ATR period | `InpATRPeriod` | 14 | used on both timeframes |
| Reject after bar gap | `InpRejectAfterBarGap` | true | signal candle must be adjacent to the current bar |
| Max signal delay | `InpMaxSignalDelaySeconds` | 30 | seconds after the new bar opens |

## Market filters

| Label | Variable | Default | Unit / notes |
|---|---|---|---|
| EnableFlatEMAFilter | `InpEnableFlatEMAFilter` | **false** | OFF = baseline. ON = research variant C. |
| use separation check | `InpUseSeparationCheck` | true | |
| MinimumEMASeparationATR | `InpMinimumEMASeparationATR` | 0.10 | `|EMA8−EMA14|` / ATR(M5) — *placeholder* |
| use slope check | `InpUseSlopeCheck` | true | |
| Slope lookback | `InpSlopeBars` | 3 | closed M5 bars |
| MinimumEMASlopeATR | `InpMinimumEMASlopeATR` | 0.10 | EMA14 change over lookback / ATR(M5), signed — *placeholder* |
| EnableSpreadFilter | `InpEnableSpreadFilter` | true | |
| MaxSpreadToStopRatio | `InpMaxSpreadToStopRatio` | 0.15 | spread / SL distance |
| MaxSpreadPoints | `InpMaxSpreadPoints` | 0 | pts; 0 = disabled until calibrated for your broker |
| Max quote age | `InpMaxQuoteAgeSeconds` | 15 | seconds; 0 = off |
| EnableEntryDriftFilter | `InpEnableEntryDriftFilter` | true | |
| MaxEntryDriftATR | `InpMaxEntryDriftATR` | 0.20 | `|price − signal close|` / ATR(M1) |
| Drift on Bid basis | `InpDriftExcludesSpread` | true | true = Bid for both directions (price move only). false = v1.00 behaviour (Ask for BUY, includes spread — biased against BUY). |
| EnableNewsFilter | `InpEnableNewsFilter` | true | fails **closed**: no verified data = no new entries |
| NewsBlockBeforeMinutes | `InpNewsBlockBeforeMinutes` | 15 | minutes |
| NewsBlockAfterMinutes | `InpNewsBlockAfterMinutes` | 15 | minutes |
| News currencies | `InpNewsCurrencies` | USD | comma separated, e.g. `USD,EUR` |
| News importance | `InpNewsImportance` | High only (0) | 0 = high, 1 = medium + high |
| News CSV | `InpNewsCsvFile` | ALBFX_news_events.csv | in `Terminal\Common\Files\`, used **only in the Strategy Tester** |
| News export days | `InpNewsExportDays` | 0 | live/demo only: export N days of calendar history to the CSV on start (max 3650) |
| EnableSessionFilter | `InpEnableSessionFilter` | false | |
| Session start | `InpSessionStart` | 00:00 | broker server time, inclusive |
| Session end | `InpSessionEnd` | 23:59 | broker server time, exclusive; start > end wraps past midnight; start = end = always |

## Stop loss / take profit

| Label | Variable | Default | Unit / notes |
|---|---|---|---|
| SwingLookback | `InpSwingLookback` | 20 | completed M1 bars searched |
| SwingLeftBars | `InpSwingLeftBars` | 2 | older bars of the pivot |
| SwingRightBars | `InpSwingRightBars` | 2 | newer (completed) bars of the pivot |
| Require unbroken swing | `InpSwingRequireUnbroken` | true | skip pivots already violated by later candles |
| StopBufferPoints | `InpStopBufferPoints` | 0 | pts |
| Stop buffer ATR | `InpStopBufferATR` | 0.10 | × ATR(M1), added to the points buffer — *placeholder* |
| Add spread to SELL stop | `InpAddSpreadToSellStop` | true | SELL SL triggers on Ask |
| Minimum SL distance ATR | `InpMinStopATR` | 0.25 | × ATR(M1); closer stops are skipped, never widened — *placeholder* |
| Minimum SL distance pts | `InpMinStopPoints` | 0 | pts, 0 = off |
| Maximum SL distance ATR | `InpMaxStopATR` | 3.0 | × ATR(M1), 0 = off — *placeholder* |
| RewardRisk | `InpRewardRisk` | 1.5 | TP = entry ± RR × risk |
| Re-anchor TP to fill | `InpReanchorTPToFill` | true | TP recomputed from the actual fill; SL unchanged |
| EnableBreakEven | `InpEnableBreakEven` | false | research variant D |
| Break-even trigger | `InpBreakEvenTriggerR` | 1.0 | R |
| Break-even offset | `InpBreakEvenOffsetPoints` | 0 | pts beyond entry |
| EnableTrailingStop | `InpEnableTrailingStop` | false | |
| Trailing start | `InpTrailStartR` | 1.0 | R |
| Trailing distance | `InpTrailDistanceATR` | 1.0 | × ATR(M1) |
| EnableTimeExit | `InpEnableTimeExit` | false | |
| Time exit | `InpMaxHoldMinutes` | 30 | minutes |

## Risk

| Label | Variable | Default | Unit / notes |
|---|---|---|---|
| RiskPercent | `InpRiskPercent` | 0.5 | % of current equity per trade. Hard limit 5.0. |
| MaxDailyLossPercent | `InpMaxDailyLossPercent` | 2.0 | % of the daily equity baseline. Hard limit 20.0. |
| MaxTradesPerDay | `InpMaxTradesPerDay` | 5 | executed entries per broker day (alerts in ALERT_ONLY) |
| MaxOpenPositions | `InpMaxOpenPositions` | 1 | across all symbols for this magic; one per symbol is always enforced |
| EstimatedCommissionPerLot | `InpEstimatedCommissionPerLot` | 7.0 | account currency per 1.0 lot, **round trip**. Set to your broker's value. |
| EstimatedSlippagePoints | `InpEstimatedSlippagePoints` | 10 | pts per side, added to the risk budget |
| EmergencyCloseOnDailyLimit | `InpEmergencyCloseOnDailyLimit` | false | close this EA's positions while equity is at the floor |
| Daily budget pre-check | `InpCheckDailyBudgetBeforeEntry` | true | skip trades whose full SL loss would breach the daily limit |
| Max margin usage | `InpMaxMarginUsagePercent` | 50 | % of free margin for one entry |
| Hard lot cap | `InpMaxLots` | 0 | lots; 0 = broker maximum only |
| Daily reset hour | `InpDayResetHour` | 0 | broker server hour |
| Max deviation | `InpMaxDeviationPoints` | 30 | pts, market order slippage tolerance |
| Send retries | `InpMaxSendRetries` | 1 | 0–3, only after requote / price changed / price off |

## Diagnostics

| Label | Variable | Default | Notes |
|---|---|---|---|
| EnableDetailedLogs | `InpEnableDetailedLogs` | true | one line per evaluated setup with the exact rejection reason |
| Log no-setup bars | `InpLogNoSetupBars` | false | verbose: also bars without trend/touch |
| EnableChartDashboard | `InpEnableChartDashboard` | true | live and visual tester only |
| EnableAlerts | `InpEnableAlerts` | true | |
| Push notifications | `InpEnablePushNotifications` | false | live only; needs MetaQuotes ID in terminal settings |
| Journal CSV | `InpWriteJournalCsv` | true | `Common\Files\ALBFX_EMA_SCALPER_Journal_<symbol>_<magic>_<TESTER|LIVE>.csv` |
| Extended tester report | `InpWriteTesterReport` | true | `Common\Files\ALBFX_EMA_SCALPER_Report_<symbol>_<ModeA|ModeB>.txt` + journal log |
| Run self-tests | `InpRunSelfTests` | false | runs 74 logic checks in `OnInit`; the EA refuses to start if any fail |

## Rejection codes (log, journal, report)

| Code | Meaning |
|---|---|
| `DATA_NOT_READY` | history, indicator or copy failure after retries |
| `TREND_TF_NOT_SYNCED` | M5 series not rolled forward yet |
| `STALE_SIGNAL` | evaluation too late after bar open, or market gap |
| `NO_TREND` / `NO_BAND_TOUCH` | no setup (not logged unless `InpLogNoSetupBars`) |
| `CANDLE_DIRECTION` / `CLOSE_VS_EMA8` / `SETUP_INVALIDATED` / `ENTRY_TF_EMA_ALIGNMENT` | touch occurred, confirmation failed |
| `FLAT_EMA_SEPARATION` / `FLAT_EMA_SLOPE` | flat-EMA filter |
| `SESSION_FILTER` / `MARKET_CLOSED` / `DIRECTION_NOT_ALLOWED` | time / symbol trade mode |
| `NEWS_WINDOW` / `NEWS_DATA_UNVERIFIED` | news filter (blocked / fail-closed) |
| `DAILY_LOSS_HALT` / `DAILY_RISK_BUDGET` / `MAX_TRADES_PER_DAY` | daily risk limits |
| `POSITION_ALREADY_OPEN` / `MAX_OPEN_POSITIONS` / `FOREIGN_NETTING_POSITION` / `PENDING_ORDER_EXISTS` / `DUPLICATE_SIGNAL` / `PREVIOUS_ORDER_UNRECONCILED` | exposure & duplicate protection |
| `TRADING_NOT_PERMITTED` | disconnected, Algo Trading off, investor login, broker disabled EAs |
| `QUOTE_INVALID` / `QUOTE_STALE` | bad or old quote |
| `NO_STRUCTURAL_SWING` / `SL_WRONG_SIDE` / `SL_TOO_CLOSE` / `SL_TOO_FAR` / `BROKER_STOPS_LEVEL` | stop validation |
| `SPREAD_ABSOLUTE` / `SPREAD_TO_STOP_RATIO` / `ENTRY_DRIFT` / `RR_AFTER_NORMALIZATION` | execution quality |
| `RISK_CALC_FAILED` / `MIN_LOT_EXCEEDS_RISK` / `MARGIN` | sizing |
| `ORDER_CHECK_FAILED` / `ORDER_SEND_FAILED` | server-side rejection |

## Presets (`presets/`)

| File | Purpose |
|---|---|
| `Backtest_A_Baseline.set` | Variant A: Mode A, flat filter OFF, news OFF (documented limitation) |
| `Backtest_B_NextCandle.set` | Variant B: Mode B, otherwise identical to A |
| `Backtest_C_FlatFilter.set` | Variant C: A + flat-EMA filter |
| `Backtest_D_BreakEven.set` | Variant D: A + break-even at 1R |
| `Backtest_A_NewsCSV.set` | A with news filter ON using the exported CSV |
| `Test_DailyLimit_Emergency.set` | forces daily-limit activation and emergency close (functional test only) |
| `Test_SelfTests.set` | runs the built-in self-tests |
| `Demo_FullAuto.set` | demo account forward test, news ON |
| `AlertOnly.set` | signals only |

Copy `.set` files to `MQL5\Profiles\Tester\` (tester) or load them via the EA inputs dialog
**Load** button. They are UTF-16 LE, the format MT5 writes itself.
