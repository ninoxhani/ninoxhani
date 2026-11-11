# Research report: EMA 8/14 robots on XAUUSD (proxy-data simulation)

**Date:** 2026-11-11 · **EA version tested:** 1.21 (rules re-implemented in `research/afx_bt.py`)

> **Verdict: RESEARCH NO-GO.**
> - The current Scalper Pro (v1.21 defaults) loses in the simulation with high confidence: −0.070R
>   per trade over 4,517 trades (t = −6.2), and all 10 months are negative.
> - No variant of the EMA 8/14 strategy family passed an out-of-sample test.
> - This is a simulation on proxy data, **not** the MT5 Strategy Tester. Confirmation on the
>   broker's real ticks is pending: `RUN_BACKTESTS.bat` is set up for it (section 5).

## 1. Why this research

- **Owner's demo day, 2026-11-11:** IC Markets demo, Scalper Pro v1.21, 500 USD account. 13 trades,
  net −3.46 USD (−0.7 %, ≈ −1.4R at 0.5 % risk). Request: *"turn that in profitable"*.
- **Earlier owner runs:** 3 winning trades on 2026-11-10, too small a sample to mean anything.
- **MT5 tester:** no tester report exists (the tester needs the broker account, see STATUS.md).

## 2. Method

**Data**
- **Source:** Binance XAUUSDT perpetual, 1-minute candles (public data, data.binance.vision),
  2025-12-11 → 2026-11-10, 481,915 minutes, no missing minutes. Proxy for spot gold, which was not
  downloadable from this environment.
- **Low-quality start:** December 2025 has 37 % "frozen" minutes (high = low) and January 2026 has 5 %.
  Both months are used only to warm up the indicators.
- **Research window:** 2026-02-01 → 2026-11-10, with 0 % frozen minutes.

**Market model**
- **Hours (IC Markets style):** server time = New York + 7 h (UTC+2, or UTC+3 during US daylight
  saving). Trading Mon 01:00 – Fri 24:00 server time, daily break 00:00–01:00 server time. The model
  was checked on a winter and a summer week (`logs/t_mask.log`).
- **Rules:** `research/afx_bt.py` re-implements the robots' decision rules from
  `ALB_FOREX_EMA_CORE.mqh` v1.21, checked line by line against the source:
  - signals at the bar open from closed bars only;
  - every Scalper Pro filter (trend, flat EMA, momentum body, slope, leg limit, ATR/spread, ATR spike);
  - the stop behind the last 5 candles (0.8–2.5 ATR), the target, break-even with lock;
  - slow-EMA close, stale and opposite-cross exits;
  - 3-bar cooldown, pause after 3 losses, daily risk budget (2 % = 4R at 0.5 % risk);
  - the PULLBACK swing stop and the CROSSOVER ATR stop.

**Costs (base case)**

| Item | Value |
|---|---|
| Spread, main hours | 0.10 |
| Spread, 02:00–09:00 and 23:00–24:00 server | 0.16 |
| Spread, first 30 / next 30 minutes after the daily open | 0.40 / 0.25 |
| Commission | 0.07 per oz round trip (7 USD per lot) |
| Slippage | 0.02 per market entry, stop exit and bar-close exit |

Stress test: spreads ×1.5 and slippage 0.04, and a ×2 variant.

**Fills and units**
- **Conservative fills:** if one 1-minute candle touches both the stop and the target, the stop
  counts. Break-even and trailing moves take effect from the next minute.
- **Units:** R, where 1R = the planned loss including costs. At the default 0.5 % risk, 1R = 0.5 % of equity.
- **Cross-check against reality:** the simulated v1.21 average is −0.070R × 22.3 trades/day ≈ −1.6R
  per day. The owner's live day was about −1.4R.

**Validation discipline**
- In-sample 2026-02-01 → 2026-06-30, split into two halves (to 04-16 and after). Out-of-sample
  2026-07-01 → 2026-11-10.
- Candidates and pass rules were fixed before the single out-of-sample run.
- Pass rules: OOS profit > 0 and PF > 1.1 at base costs, average R > 0 at ×1.5 costs,
  OOS max drawdown ≤ 2 × in-sample drawdown.

## 3. Results

### 3.1 The robots as they are (no tuning), 2026-02-01 → 2026-11-10 (`logs/r14_meta.log`, `logs/r16_h_stats.log`)

| Robot (defaults) | Trades/day | Win rate | Avg R per trade | Total | PF | Max DD |
|---|---|---|---|---|---|---|
| **Scalper Pro v1.21** | 22.3 | 47 % | **−0.070** (t = −6.2) | **−316R** | 0.81 | 336R |
| Pullback baseline (robot 1) | 4.8 | 39 % | −0.043 | −43R | 0.93 | 67R |
| Crossover v1.10 | 26.6 | 44 % | −0.077 | −413R | 0.84 | 428R |

- **Scalper Pro by month (R):** Feb −24, Mar −7, Apr −26, May −42, Jun −40, Jul −44, Aug −31,
  Sep −57, Oct −31, Nov (10 days) −15.
- **Daily cost to the account:** at 0.5 % risk the robot loses about 0.8 % of equity per trading
  day before the daily guard stops it.

### 3.2 What loses money in Scalper Pro: one change at a time (`logs/r2_ablation.log`)

| Variant | Trades/day | Avg R Feb–Jun | Avg R Jul–Nov | Total R | PF |
|---|---|---|---|---|---|
| v1.21 defaults | 22.3 | −0.056 | −0.088 | −316 | 0.81 |
| no slow-EMA close exit | 23.9 | −0.048 | −0.041 | −217 | 0.88 |
| no early exits at all (pure SL/TP) | 20.4 | −0.038 | −0.039 | −158 | 0.92 |
| target 2R | 21.3 | −0.011 | −0.073 | −167 | 0.90 |
| cross entries only | 6.6 | −0.037 | −0.068 | −67 | 0.84 |
| trend filter H1 instead of M5 | 20.0 | −0.037 | −0.065 | −202 | 0.86 |
| London + New York only | 14.0 | −0.044 | −0.093 | −187 | 0.82 |
| entries on M5, trend H1 | 7.0 | +0.001 | −0.022 | −14 | 0.97 |
| entries on M15, trend H1 | 3.1 | +0.010 | −0.078 | −21 | 0.90 |
| **H: cross entries + trailing stop** | 5.8 | +0.046 | +0.043 | +53 | 1.09 |

What the table shows:
- **Biggest single leak: the slow-EMA close exit.** It cuts about a third of all trades at a loss
  (−0.57R on average in the first run).
- **No directional edge at M1:** the raw signals do not predict direction. After an M1 cross in the
  M5 trend direction, the price moves on average −0.02 to −0.005 ATR in the trade direction over
  the next 1–10 minutes, i.e. nothing or slightly against (`logs/r3_edge.log`).
- **Costs:** about 0.06R per trade, which is the whole loss.

### 3.3 Search (`logs/r12_grid2.log`)

- **Variants:** 3,360 on in-sample data only. The search covered:
  - entries on M1, M5 or M15;
  - trend on M5, M15, H1 or H4, with an optional H4 filter;
  - cross, continuation or both entry types;
  - v1.21 exits, pure SL/TP, break-even or a trailing stop;
  - targets 1–3R (trailing: 2–6R);
  - all hours, Asia, London, New York or London+NY.
- **Outcome:** 600 of 2,025 variants (≥ 120 trades) were positive in both in-sample halves.

### 3.4 A false edge, found and rejected: Binance funding times (`logs/r10_funding.log`, `logs/r11_funding2.log`)

**What looked good.** An "Asian session" continuation variant (M1, RR 3, no early exits) looked
strong in-sample:
- +0.19R per trade, PF 1.27, every month positive;
- still positive at ×2 costs;
- not dependent on a few trades.

**What it really was.** The profit sat in the 60 minutes before the Binance perpetual **funding**
times (00:00, 08:00, 16:00 UTC):

| Entry window | Trades | Avg R |
|---|---|---|
| 60 min before 00/08/16 UTC (funding) | 207 | **+0.417** |
| placebo: 60 min before 04/12/20 UTC | 172 | +0.042 |
| placebo: 60 min before 02/10/18 UTC | 200 | −0.042 |
| placebo: 60 min before 06/14/22 UTC | 136 | +0.091 |
| all other times | 1,207 | +0.035 |

Funding exists only on the Binance contract, not on spot gold at a broker, so this is an artifact of
the proxy data. From then on, research runs blocked entries from 60 min before to 30 min after each
funding time.

### 3.5 Out-of-sample test of the two best robust candidates (`logs/r5_refine_P5_P15.log`, `logs/r13_oos.log`)

**Candidates (fixed before the test).** Continuation pullbacks to the EMA band with the H1 EMA 8/14
trend and an H4 filter, H1 flat filter, trailing stop of 1.5 ATR after +1R, no early exits:
- **P5:** entries on M5;
- **P15:** entries on M15.

In-sample, nearly every one-parameter change kept both candidates positive in both halves, a broad
plateau.

| | In-sample avg R / PF | OOS trades | OOS avg R | OOS PF | OOS max DD | Result |
|---|---|---|---|---|---|---|
| P5 | +0.240 / 1.51 | 348 | −0.096 | 0.82 | 44R (in-sample 11R) | **FAIL** |
| P15 | +0.233 / 1.45 | 153 | −0.088 | 0.83 | 20R (in-sample 9R) | **FAIL** |

They also fail with the funding blackout and with ×1.5 costs. In-sample, gold rallied into February
and then fell about 1,200 USD into June (month-end closes 5,255 → 4,017); Jul–Nov was choppier.

### 3.6 Does in-sample performance predict out-of-sample? No (`logs/r14_meta.log`)

Across 2,249 variants:
- **Correlation** of in-sample with out-of-sample average R: **−0.05**.
- **Share profitable:** 59 % in-sample, 30 % out-of-sample.
- **Best 3 % in-sample:** only 29 % were profitable out-of-sample (median −0.088R), worse than the
  average variant.

Tuning these rules on past data therefore does not select better variants for the future.

### 3.7 The only consistent group: hypothesis H (`logs/r15_trailfam.log`, `logs/r16_h_stats.log`)

M1 cross entries with a trailing stop were slightly positive in both periods. This group was found
**by looking at both periods** (hindsight), so it is a hypothesis, not evidence.

**Rules:**
- Scalper Pro with cross entries only;
- no break-even, no slow-EMA, stale or opposite-cross exits;
- trailing stop 1.5 × ATR(M1) once +1R is reached, 4R target.

**Result (2026-02-01 → 2026-11-10):**
- 1,187 trades (5.8/day), +0.045R per trade, PF 1.09, max DD 42R.
- t = +1.3; day-block bootstrap P(total ≤ 0) = 0.10; 6 of 10 months positive.
- Statistically indistinguishable from zero; 0.03R more cost per trade would erase it.

Preset: `presets/Backtest_H_CrossTrail.set`. It is for the broker-data test only.

## 4. Conclusions

1. **Scalper Pro v1.21 should not trade money that matters.** In the simulation it loses in every
   month, and the size of the loss matches the owner's live day.
2. **Re-tuning the EMA 8/14 rules does not produce a reliable edge on this data.**
   - Higher timeframes and wider targets cut the cost drag.
   - Their in-sample edge did not persist out-of-sample.
3. **More trades do not help.** With no directional edge, every extra trade adds about 0.06R of cost.

## 5. Next step: confirm on the broker's real data

`RUN_BACKTESTS.bat` now runs two variants by default: **S_ScalperPro** (current robot, the control)
and **H_CrossTrail**. Settings: XAUUSD M1, real ticks, 2025.01.01 → 2026.11.01, 10,000 USD. No
parameter was tuned on broker data, so the whole period is a fresh test for both.

| Outcome | Meaning |
|---|---|
| S loses there too (expected) | the simulator is confirmed and this report stands |
| H meets the TEST_PLAN T3 rules (PF ≥ 1.2, avg R > 0, DD ≤ 10 %, ≥ 100 trades, no single month > ½ of profit) | demo forward test only |
| H fails | stop the EMA 8/14 scalper line and research a different edge |

## 6. Limitations

- **Proxy instrument.** The data is a Binance perpetual, not IC Markets spot: different
  microstructure, funding, and a basis of a few USD. One perp-specific artifact was found (3.4);
  others may exist.
- **Short history.** Only 9 months of clean data: one main regime per half-period.
- **Simplified costs.** Spreads are fixed per hour, not tick spreads; there is no swap and no
  requotes.
- **No news filter.** The EA blocks ±15 min around high-impact USD news; the simulation does not.
- **Fills from 1-minute candles,** not from the tick path.
- **Re-implementation.** The simulator re-implements the EA. It was checked against the source rule
  by rule, not against MT5 tester output.

Reproduce everything: [`research/README.md`](../../research/README.md).
