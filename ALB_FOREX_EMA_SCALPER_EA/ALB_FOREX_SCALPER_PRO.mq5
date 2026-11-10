//+------------------------------------------------------------------+
//|                                        ALB_FOREX_SCALPER_PRO.mq5 |
//|               ALB FOREX - Scalper Pro (EMA 8/14, XAUUSD M1)       |
//|                                              https://albforex.al |
//+------------------------------------------------------------------+
//| Opens directly in SCALPER PRO mode:                              |
//|  - entries on fresh M1 EMA 8/14 crosses and on pullbacks to the  |
//|    EMA band while the M1 trend lasts (max 3 per leg)             |
//|  - only with the M5 trend, solid momentum candle, enough         |
//|    volatility for the spread, no news spikes                     |
//|  - stop behind the last 5 candles, 1R target, break-even at      |
//|    +0.6R, exit on a close through the slow EMA, stale-trade exit |
//|  - cooldown after a loss, pause after 3 losses in a row          |
//|  - 0.5% risk per trade, 2% daily loss guard, unlimited trades    |
//| Own magic number (81420262): can run next to the baseline EA.    |
//| All logic lives in ALB_FOREX_EMA_CORE.mqh (keep it next to this  |
//| file to compile). NOT validated for live trading.                |
//+------------------------------------------------------------------+
#property copyright   "ALB FOREX"
#property link        "https://albforex.al"
#property version     "1.21"
#property description "ALB FOREX Scalper Pro - XAUUSD M1 EMA 8/14 scalper with M5 trend filter."
#property description "Crosses + trend continuations, fast exits, loss-streak pause, 2% daily guard."
#property description "Experimental research EA - NOT validated for live trading."

#define AFX_EA_NAME            "ALB_FOREX_SCALPER_PRO"
#define AFX_DASH_TITLE         "ALB FOREX | SCALPER PRO"
#define AFX_DEF_ENTRY_MODE     AFX_ENTRY_SCALPER
#define AFX_DEF_MAGIC          81420262
#define AFX_DEF_MAX_TRADES     0
#define AFX_DEF_RR             1.0
#define AFX_DEF_FLAT_FILTER    true
#define AFX_DEF_COMMENT        "ALBFX_SCP"

#include "ALB_FOREX_EMA_CORE.mqh"
//+------------------------------------------------------------------+
