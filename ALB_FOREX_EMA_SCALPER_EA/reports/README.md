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

`compile/` holds the verified MetaEditor compile logs (v1.00, v1.01, v1.10, v1.20).
`selftest/` holds the MT5 Experts logs of the self-test runs (v1.00 72/72, v1.01 74/74, v1.10 80/80, v1.20 105/105).
**No backtest reports exist yet.** No backtest has been executed for v1.00.
Do not add numbers to STATUS.md that are not backed by a file in this folder.
