//+------------------------------------------------------------------+
//|                                     ALB_FOREX_EMA_SCALPER_EA.mq5 |
//|                    ALB FOREX - EMA 8/14 EA, baseline defaults     |
//|                                              https://albforex.al |
//+------------------------------------------------------------------+
//| Opens in PULLBACK mode (M5 trend + M1 EMA-band pullback, max 5   |
//| entries/day, 1.5R). CROSSOVER and SCALPER PRO are available via  |
//| the EntryMode input. For the scalper use ALB_FOREX_SCALPER_PRO.  |
//| All logic lives in ALB_FOREX_EMA_CORE.mqh (keep it next to this  |
//| file to compile). NOT validated for live trading.                |
//+------------------------------------------------------------------+
#property copyright   "ALB FOREX"
#property link        "https://albforex.al"
#property version     "1.30"
#property description "ALB FOREX EMA 8/14 EA - baseline: M5 trend, M1 EMA-band pullback, 1.5R."
#property description "Also contains CROSSOVER and SCALPER PRO modes (EntryMode input)."
#property description "Experimental research EA - NOT validated for live trading."

#define AFX_EA_NAME     "ALB_FOREX_EMA_SCALPER_EA"
#define AFX_DASH_TITLE  "ALB FOREX | EMA 8/14 PULLBACK"

#include "ALB_FOREX_EMA_CORE.mqh"
//+------------------------------------------------------------------+
