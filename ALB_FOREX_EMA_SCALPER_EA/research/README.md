# research/: proxy-data simulator for the EMA 8/14 robots

Tools behind [`reports/research/2026-11-11_proxy_research_report.md`](../reports/research/2026-11-11_proxy_research_report.md).

They are **not** part of the EA and are **not** the MT5 Strategy Tester. They re-implement the
robots' decision rules (`ALB_FOREX_EMA_CORE.mqh` v1.21) in Python. This lets thousands of variants
be compared on 1-minute data with a broker cost model.

## Reproduce (Linux/macOS/WSL, Python 3.10+ with numpy and pandas)

```bash
bash research/download_data.sh      # Binance XAUUSDT perpetual 1m candles -> research/xau_m1.npz
cd research
python3 -I t_mask.py                # market-hours model check (winter/summer week)
python3 -I r2_ablation.py           # v1.21 and one-change variants, both periods
python3 -I r12_grid2.py             # 3,360-variant in-sample search (about 5 min on 4 cores)
python3 -I r13_oos.py               # one-shot out-of-sample test of P5 / P15
python3 -I r14_meta.py              # in-sample vs out-of-sample over all variants (writes grid_is_oos.json)
python3 -I r15_trailfam.py          # breakdown of the trailing-stop group (needs grid_is_oos.json)
python3 -I r16_h_stats.py           # hypothesis H and v1.21: t-stat, bootstrap, months
```

The downloaded zips go to a folder **outside** the repository (untrusted data). The data file and
the JSON outputs are not committed (`.gitignore`).

## Files

| File | Purpose |
|---|---|
| `afx_bt.py` | simulator: market hours (server = New York + 7 h), spread model, resampling, EMA/ATR (MT5 style), SCALPER PRO / CROSSOVER / PULLBACK rules, exits, daily guard, statistics |
| `common.py` | periods: warm-up Dec–Jan, in-sample 2026-02-01 → 06-30 (halves at 04-16), out-of-sample 07-01 → 11-10 |
| `load_data.py` | builds `xau_m1.npz` from the Binance zips |
| `download_data.sh` | downloads the zips and runs `load_data.py` |
| `r0_quality.py` | frozen-minute share by month and hour |
| `r1_baseline.py`, `r3_edge.py` | first look: robots as they are; raw forward move after EMA signals |
| `r2_ablation.py` | one change at a time to v1.21 |
| `r5_refine.py` | one-parameter sensitivity around a base config (in-sample) |
| `r8_server.py`, `r9_diag2.py` | session windows in server time; robustness of the "Asian" variant |
| `r10_funding.py`, `r11_funding2.py` | Binance funding-time artifact and placebo test |
| `r12_grid2.py` | in-sample search with the funding blackout |
| `r13_oos.py` | one-shot out-of-sample test (pass rules in the file header) |
| `r14_meta.py`, `r15_trailfam.py`, `r16_h_stats.py` | reporting after the test |

Saved outputs: [`reports/research/logs/`](../reports/research/logs/).

## Model notes

- **Prices:** the candles are treated as the Bid chart; Ask = Bid + spread.
- **Signal timing:** signals are evaluated at the entry-timeframe bar open from closed bars, like the EA.
- **Ambiguous candles:** when one 1-minute candle touches both the stop and the target, the stop counts.
- **Stop moves:** break-even and trailing changes apply from the next minute (the EA acts within
  the minute, so the simulation is slightly conservative).
- **Costs:** in price units per ounce (`spread`, `spread_asia`, `spread_open1/2`, `comm`, `slip`
  in `DEFAULT_CFG`).
- **Not modelled:** news blocks, swaps, requotes and tick-level paths.
- **`fund_excl`:** a research-only switch. It removes entries near Binance funding times, which do
  not exist on spot gold.
