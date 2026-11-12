#!/usr/bin/env python3
"""Generate MT5 .set preset files for ALB_FOREX_EMA_SCALPER_EA.

Defaults are parsed from the shared EA core (ALB_FOREX_EMA_CORE.mqh), resolving the
AFX_DEF_* macros to the baseline robot's defaults, so presets never drift from the code.
Each preset only overrides the inputs that define its research variant.
Output: UTF-16 LE with BOM and CRLF line endings (the format MT5 writes itself).

Usage:  python3 tools/make_presets.py      (run from the project directory)
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "ALB_FOREX_EMA_CORE.mqh")
OUT = os.path.join(ROOT, "presets")

ENUM_VALUES = {
    "AFX_FULL_AUTO": "0", "AFX_ALERT_ONLY": "1",
    "AFX_CONFIRM_SAME_CANDLE": "0", "AFX_CONFIRM_NEXT_CANDLE": "1",
    "AFX_NEWS_HIGH_ONLY": "0", "AFX_NEWS_MEDIUM_HIGH": "1",
    "AFX_ENTRY_PULLBACK": "0", "AFX_ENTRY_CROSSOVER": "1", "AFX_ENTRY_SCALPER": "2",
    "AFX_LOSS_ACCOUNT": "0", "AFX_LOSS_THIS_EA": "1",
    "PERIOD_M1": "1", "PERIOD_M5": "5", "PERIOD_M15": "15",
}

INPUT_RE = re.compile(r'^input\s+(\w+)\s+(Inp\w+)\s*=\s*(.+?);\s*//\s*(.*)$')
DEFINE_RE = re.compile(r'^#define\s+(AFX_DEF_\w+)\s+(.+?)\s*$')


def parse_defaults():
    defaults = []
    macros = {}
    with open(SRC, encoding="ascii") as fh:
        lines = fh.readlines()
    for line in lines:
        m = DEFINE_RE.match(line.strip())
        if m and m.group(1) not in macros:
            macros[m.group(1)] = m.group(2).strip()
    for line in lines:
        m = INPUT_RE.match(line.strip())
        if not m:
            continue
        _type, name, value, _label = m.groups()
        value = macros.get(value.strip(), value.strip())
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        value = ENUM_VALUES.get(value, value)
        defaults.append((name, value))
    if not defaults:
        sys.exit("no inputs parsed from " + SRC)
    return defaults


BACKTEST = {
    "InpTradingMode": "0",
    "InpEnableNewsFilter": "false",      # tester has no calendar; limitation is reported
    "InpEnableChartDashboard": "false",
    "InpEnableAlerts": "false",
    "InpWriteJournalCsv": "true",
    "InpWriteTesterReport": "true",
}

# SCALPER PRO as it was up to v1.22 (1R target, BE 0.6R, stale/EMA exits, crosses + continuations):
# kept as the control variant S. The robot's own defaults changed in v1.30 (see SCALPER_PRO_V130).
SCALPER_PRO = {
    "InpEntryMode": "2",
    "InpMaxTradesPerDay": "0",
    "InpRewardRisk": "1.0",
    "InpEnableFlatEMAFilter": "true",
    "InpMagicNumber": "81420262",
    "InpOrderComment": "ALBFX_SCP",
}

SCALPER = {
    "InpEntryMode": "1",
    "InpMaxTradesPerDay": "0",
    "InpRewardRisk": "1.0",
}

# Defaults of the ALB_FOREX_SCALPER_PRO robot from v1.30 (owner request 2026-11-12: let winners run,
# RR >= 1:3, protect trades in profit) = research hypothesis H + profit lock at +1R:
# crosses only, no early exits, at +1R the stop locks +0.25R and trails 1.5 x ATR(M1), 4R target.
CROSS_TRAIL = {
    "InpScUseContinuation": "false",
    "InpScExitOnSlowEMAClose": "false",
    "InpScStaleBars": "0",
    "InpCrossCloseOnOpposite": "false",
    "InpScBreakEvenR": "1.0",
    "InpScBreakEvenLockR": "0.25",
    "InpEnableTrailingStop": "true",
    "InpTrailStartR": "1.0",
    "InpTrailDistanceATR": "1.5",
    "InpRewardRisk": "4.0",
}
SCALPER_PRO_V130 = {**SCALPER_PRO, **CROSS_TRAIL, "InpOrderComment": "ALBFX_SCP4R"}

PRESETS = {
    "Backtest_A_Baseline": dict(BACKTEST),
    "Backtest_B_NextCandle": dict(BACKTEST, InpConfirmationMode="1"),
    "Backtest_C_FlatFilter": dict(BACKTEST, InpEnableFlatEMAFilter="true"),
    "Backtest_D_BreakEven": dict(BACKTEST, InpEnableBreakEven="true"),
    "Backtest_A_NewsCSV": dict(BACKTEST, InpEnableNewsFilter="true"),
    "Test_DailyLimit_Emergency": dict(BACKTEST, InpMaxDailyLossPercent="0.4",
                                      InpCheckDailyBudgetBeforeEntry="false",
                                      InpEmergencyCloseOnDailyLimit="true"),
    "Test_SelfTests": dict(BACKTEST, InpRunSelfTests="true"),
    # CROSSOVER scalper: every M1 EMA 8/14 cross, ATR stop 1.5, TP 1R, no daily trade cap
    "Backtest_X_Crossover": dict(BACKTEST, **SCALPER),
    "Backtest_X_CrossTrend": dict(BACKTEST, **SCALPER, InpCrossUseTrendFilter="true"),
    "Demo_Scalper": dict({"InpTradingMode": "0", "InpEnableLiveTrading": "false",
                          "InpEnableNewsFilter": "true"}, **SCALPER),
    # SCALPER PRO (v1.20)
    "Backtest_S_ScalperPro": dict(BACKTEST, **SCALPER_PRO),
    "Backtest_S_ScalperPro_NoM5": dict(BACKTEST, **SCALPER_PRO, InpScTrendFilter="false"),
    "Demo_ScalperPro": {"InpTradingMode": "0", "InpEnableLiveTrading": "false",
                        "InpEnableNewsFilter": "true", **SCALPER_PRO_V130},
    # H = Scalper Pro v1.30 defaults (see CROSS_TRAIL). About break-even to slightly positive in the
    # proxy-data simulation (+0.04R/trade, t = 1.2) - NOT proven profitable.
    "Backtest_H_CrossTrail": {**BACKTEST, **SCALPER_PRO_V130},
    "Demo_FullAuto": {"InpTradingMode": "0", "InpEnableLiveTrading": "false",
                      "InpEnableNewsFilter": "true"},
    "AlertOnly": {"InpTradingMode": "1", "InpEnableNewsFilter": "true"},
}


def write_set(name, overrides, defaults):
    known = {n for n, _ in defaults}
    unknown = set(overrides) - known
    if unknown:
        sys.exit(f"{name}: unknown inputs {sorted(unknown)}")
    lines = [f"; ALB_FOREX_EMA_SCALPER_EA preset: {name}",
             "; generated by tools/make_presets.py from the EA source defaults"]
    for n, v in defaults:
        lines.append(f"{n}={overrides.get(n, v)}")
    path = os.path.join(OUT, name + ".set")
    with open(path, "wb") as fh:
        fh.write(b"\xff\xfe")
        fh.write("\r\n".join(lines).encode("utf-16-le") + "\r\n".encode("utf-16-le"))
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    defaults = parse_defaults()
    for name, ov in PRESETS.items():
        p = write_set(name, ov, defaults)
        print(f"{os.path.relpath(p, ROOT)}  ({len(defaults)} inputs, {len(ov)} overrides)")


if __name__ == "__main__":
    main()
