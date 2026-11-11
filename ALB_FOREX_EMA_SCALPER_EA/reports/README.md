# reports/

Strategy Tester outputs go here, one sub-folder per run, e.g.

```
reports/2026-11-xx_A_Baseline_XAUUSD_<broker>/
    ALBFX_EMA_SCALPER_A_Baseline.htm        (MT5 tester report)
    ALBFX_EMA_SCALPER_Report_XAUUSD_ModeA.txt (extended report from Common\Files)
    ALBFX_EMA_SCALPER_Journal_XAUUSD_81420261_TESTER.csv
    settings.set                             (exact inputs used)
    notes.md                                 (broker, data source, dates, spread/commission model)
```

`compile/` holds the verified MetaEditor compile logs (v1.00, v1.01, v1.10, v1.20, v1.21, v1.22).
`research/` holds the proxy-data research (2026-11-11): report and the log of every run. It is a
Python simulation on Binance XAUUSDT 1-minute data, **not** the MT5 Strategy Tester. Verdict: NO-GO.
`selftest/` holds the MT5 Experts logs of the self-test runs (v1.00 72/72, v1.01 74/74, v1.10 80/80, v1.20 105/105, v1.21 108/108, v1.22 108/108).
`2026-11-11_MetaQuotesDemo_v1.21_S_H_zero_trades/`: the owner's first tester run on broker data — 0 trades
because of an EA defect (fixed in v1.22); see its `notes.md`.
**No MT5 Strategy Tester reports exist yet.**
Do not add numbers to STATUS.md that are not backed by a file in this folder.
