# Owner tester run 2026-11-11 — v1.21, MetaQuotes-Demo — 0 trades (EA defect, fixed in v1.22)

**Run settings**
- **Who and where:** the owner's PC, via `RUN_BACKTESTS.bat`. The log shows an Intel Core i3-6100,
  MT5 agent build 6316.
- **Account and data:** MetaQuotes-Demo (not IC Markets), XAUUSD M1, *Every tick based on real
  ticks*, 2025.01.01 → 2026.11.01, 10,000 USD, zero-latency execution.
- **Variants:** S_ScalperPro (control) and H_CrossTrail.

**Result**
- Both variants made **0 trades** in about 3 minutes each.
- Extended report: `evaluated 638414`, every one rejected with `DATA_NOT_READY` and the detail
  `indicator 0 not calculated yet (355673/355674)`.
- The two runs produced identical graphs.

**Cause: EA defect, present since v1.00**
- `IndicatorsReady()` required `BarsCalculated(handle) >= Bars()` before any `CopyBuffer()` call.
- In a non-visual Strategy Tester run, MT5 calculates standard indicators only when their data is
  requested. `BarsCalculated` therefore stayed at the 355,673 pre-test bars (see "history cache …
  contains 355673 bars" in `S_ScalperPro_tester_log_head.txt`), and every bar was rejected.
- Live charts and visual mode calculate indicators on every tick. That is why the live demo robot
  trades normally and the owner's v1.00 visual test did trade.

**Fix in v1.22**
- `IndicatorsReady()` first requests one value from each indicator, then checks `BarsCalculated`.
- Live behaviour is unchanged.
- The runner now prints trades, net and PF per variant, warns on 0 trades and reports the date
  real ticks begin.

**Data note.** MetaQuotes-Demo has real XAUUSD ticks only from **2025-05-27** (`ticks data begins
from 2025.05.27`). Earlier dates in that test would use ticks generated from M1 bars.

**What this run tells us about the strategy: nothing.** No trade was simulated. Files here are a
small extract; the full logs were 0.2–0.4 GB.
