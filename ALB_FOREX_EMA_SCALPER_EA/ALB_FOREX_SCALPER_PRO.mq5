//+------------------------------------------------------------------+
//|                                        ALB_FOREX_SCALPER_PRO.mq5 |
//|               ALB FOREX - Scalper Pro (EMA 8/14, XAUUSD M1)       |
//|                                              https://albforex.al |
//+------------------------------------------------------------------+
//| Opens directly in SCALPER PRO mode (v1.30 defaults):             |
//|  - entries on fresh M1 EMA 8/14 crosses only, with the M5 trend, |
//|    a solid momentum candle, enough volatility for the spread,   |
//|    no news spikes                                                |
//|  - stop behind the last 5 candles (max loss 1R = 0.5 %)          |
//|  - target 1:4; at +1R the stop locks +0.25R, then trails 1.5 x   |
//|    ATR(M1) behind the price - winners run, trades in profit are  |
//|    protected; no early exits                                     |
//|  - cooldown after a loss, pause after 3 losses in a row          |
//|  - 0.5% risk per trade, 2% daily loss guard, unlimited trades    |
//| Own magic number (81420262): can run next to the baseline EA.    |
//| All logic lives in ALB_FOREX_EMA_CORE.mqh (keep it next to this  |
//| file to compile). NOT validated for live trading.                |
//+------------------------------------------------------------------+
#property copyright   "ALB FOREX"
#property link        "https://albforex.al"
#property version     "1.30"
#property description "ALB FOREX Scalper Pro - XAUUSD M1 EMA 8/14 scalper with M5 trend filter."
#property description "M1 crosses, 1:4 target, profit lock at +1R + trailing stop, 2% daily guard."
#property description "Experimental research EA - NOT validated for live trading."

#define AFX_EA_NAME            "ALB_FOREX_SCALPER_PRO"
#define AFX_DASH_TITLE         "ALB FOREX | SCALPER PRO"
#define AFX_DEF_ENTRY_MODE     AFX_ENTRY_SCALPER
#define AFX_DEF_MAGIC          81420262
#define AFX_DEF_MAX_TRADES     0
#define AFX_DEF_RR             4.0
#define AFX_DEF_FLAT_FILTER    true
#define AFX_DEF_COMMENT        "ALBFX_SCP4R"
//--- v1.30 (owner request 2026-11-12: let winners run, RR >= 1:3, protect trades in profit;
//--- research: reports/research/, hypothesis H + profit lock)
#define AFX_DEF_SC_USE_CONT    false
#define AFX_DEF_SC_BE_R        1.0
#define AFX_DEF_SC_BE_LOCK_R   0.25
#define AFX_DEF_SC_STALE_BARS  0
#define AFX_DEF_SC_EMA_EXIT    false
#define AFX_DEF_CLOSE_OPPOSITE false
#define AFX_DEF_TRAIL          true
#define AFX_DEF_TRAIL_ATR      1.5

#include "ALB_FOREX_EMA_CORE.mqh"
//+------------------------------------------------------------------+
