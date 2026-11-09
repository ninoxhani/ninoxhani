//+------------------------------------------------------------------+
//|                                     ALB_FOREX_EMA_SCALPER_EA.mq5 |
//|                       ALB FOREX - EMA 8/14 pullback scalper (MT5) |
//|                                              https://albforex.al |
//+------------------------------------------------------------------+
//| Experimental research Expert Advisor for XAUUSD.                 |
//|  Trend : EMA 8/14 on the latest CLOSED trend-TF candle (M5).     |
//|  Entry : completed entry-TF candle (M1) touching the EMA 8/14    |
//|          band and confirming in the trend direction.             |
//|  Exit  : structural swing stop-loss, fixed R:R take-profit.      |
//|  Risk  : equity % per trade, daily equity loss guard, max        |
//|          entries per day, one position per symbol.               |
//|                                                                  |
//| Independent project. Shares no code or state with any other      |
//| ALB FOREX Expert Advisor.                                        |
//| NOT validated for live trading. Read STATUS.md before use.       |
//+------------------------------------------------------------------+
#property copyright   "ALB FOREX"
#property link        "https://albforex.al"
#property version     "1.10"
#property description "ALB FOREX EMA 8/14 Scalper - M1 EMA-band pullback entries or EMA crossover scalping."
#property description "Structural swing SL, fixed R:R TP, equity-based sizing, daily loss guard."
#property description "Experimental research EA - NOT validated for live trading."

#define AFX_EA_NAME              "ALB_FOREX_EMA_SCALPER_EA"
#define AFX_EA_VERSION           "1.10"
#define AFX_OBJ_PREFIX           "AFXES_"
#define AFX_MAX_RISK_PERCENT     5.0
#define AFX_MAX_DAILY_LOSS_PCT   20.0
#define AFX_RR_TOLERANCE         0.01
#define AFX_FILL_VERIFY_SECONDS  30

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_AFX_TRADING_MODE
  {
   AFX_FULL_AUTO  = 0,   // FULL_AUTO - open and manage trades
   AFX_ALERT_ONLY = 1    // ALERT_ONLY - detect and alert, never send orders
  };

enum ENUM_AFX_CONFIRM_MODE
  {
   AFX_CONFIRM_SAME_CANDLE = 0,   // A: SAME_CANDLE - one candle touches and confirms
   AFX_CONFIRM_NEXT_CANDLE = 1    // B: NEXT_CANDLE - touch, next candle confirms (experimental)
  };

enum ENUM_AFX_ENTRY_MODE
  {
   AFX_ENTRY_PULLBACK  = 0,   // PULLBACK - M5 trend + M1 EMA-band pullback (baseline)
   AFX_ENTRY_CROSSOVER = 1    // CROSSOVER - every M1 EMA 8/14 cross (scalper)
  };

enum ENUM_AFX_NEWS_LEVEL
  {
   AFX_NEWS_HIGH_ONLY   = 0,   // High impact only
   AFX_NEWS_MEDIUM_HIGH = 1    // Medium and high impact
  };

//--- every reason an evaluated bar can fail to become a trade
enum ENUM_AFX_REJECT
  {
   RJ_NONE = 0,
   RJ_DATA_NOT_READY,
   RJ_TREND_NOT_SYNCED,
   RJ_STALE_SIGNAL,
   RJ_NO_TREND,
   RJ_NO_TOUCH,
   RJ_CANDLE_DIRECTION,
   RJ_CLOSE_VS_EMA8,
   RJ_SETUP_INVALIDATED,
   RJ_M1_ALIGNMENT,
   RJ_FLAT_SEPARATION,
   RJ_FLAT_SLOPE,
   RJ_SESSION_FILTER,
   RJ_MARKET_CLOSED,
   RJ_DIRECTION_NOT_ALLOWED,
   RJ_NEWS_BLOCK,
   RJ_NEWS_UNVERIFIED,
   RJ_DAILY_LOSS_HALT,
   RJ_DAILY_RISK_BUDGET,
   RJ_MAX_TRADES_DAY,
   RJ_FILL_UNRECONCILED,
   RJ_POSITION_OPEN,
   RJ_MAX_OPEN_POSITIONS,
   RJ_FOREIGN_NETTING_POSITION,
   RJ_PENDING_ORDER_EXISTS,
   RJ_DUPLICATE_SIGNAL,
   RJ_TRADING_NOT_PERMITTED,
   RJ_QUOTE_INVALID,
   RJ_QUOTE_STALE,
   RJ_NO_SWING,
   RJ_SL_WRONG_SIDE,
   RJ_SL_TOO_CLOSE,
   RJ_SL_TOO_FAR,
   RJ_SPREAD_ABSOLUTE,
   RJ_SPREAD_TO_STOP,
   RJ_ENTRY_DRIFT,
   RJ_RR_AFTER_NORMALIZATION,
   RJ_STOPS_LEVEL,
   RJ_RISK_CALC_FAILED,
   RJ_MIN_LOT_EXCEEDS_RISK,
   RJ_MARGIN,
   RJ_ORDER_CHECK,
   RJ_SEND_FAILED,
   RJ_NO_CROSS,
   RJ_TREND_MISMATCH,
   RJ_COUNT
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== General ==="
input ENUM_AFX_TRADING_MODE InpTradingMode        = AFX_FULL_AUTO;  // TradingMode
input string                InpTradingSymbol      = "";             // TradingSymbol (empty = chart symbol)
input ulong                 InpMagicNumber        = 81420261;       // MagicNumber (unique per EA instance)
input bool                  InpEnableLiveTrading  = false;          // EnableLiveTrading (required on REAL-money accounts)
input string                InpOrderComment       = "ALBFX_EMA";    // Order comment prefix

input group "=== Strategy ==="
input int                   InpFastEMA            = 8;              // FastEMA (period)
input int                   InpSlowEMA            = 14;             // SlowEMA (period)
input ENUM_TIMEFRAMES       InpTrendTF            = PERIOD_M5;      // TrendTF
input ENUM_TIMEFRAMES       InpEntryTF            = PERIOD_M1;      // EntryTF
input ENUM_AFX_ENTRY_MODE   InpEntryMode          = AFX_ENTRY_PULLBACK; // EntryMode (PULLBACK baseline / CROSSOVER scalper)
input ENUM_AFX_CONFIRM_MODE InpConfirmationMode   = AFX_CONFIRM_SAME_CANDLE; // ConfirmationMode (PULLBACK only)
input bool                  InpRequireM1EMAAlignment = false;       // RequireM1EMAAlignment (entry-TF EMA8 vs EMA14 in trade direction)
input bool                  InpModeBInvalidateOnCloseThrough = true; // Mode B: discard touch candle that closes through the far side of the band
input int                   InpATRPeriod          = 14;             // ATR period (entry TF and trend TF)
input bool                  InpRejectAfterBarGap  = true;           // Reject signal candles that are not contiguous (market gap)
input int                   InpMaxSignalDelaySeconds = 30;          // Max seconds after bar open to act on a closed-candle signal
input bool                  InpCrossUseTrendFilter = false;         // CROSSOVER: only trade crosses in the M5 trend direction
input double                InpCrossSLATR          = 1.5;           // CROSSOVER: stop distance (x entry-TF ATR) from the trigger price
input bool                  InpCrossCloseOnOpposite = true;         // CROSSOVER: close an open position when the EMAs cross the other way

input group "=== Market Filters ==="
input bool                  InpEnableFlatEMAFilter      = false;    // EnableFlatEMAFilter (OFF = baseline; ON = research variant C)
input bool                  InpUseSeparationCheck       = true;     // Flat filter: use EMA separation check
input double                InpMinimumEMASeparationATR  = 0.10;     // MinimumEMASeparationATR (|EMA8-EMA14| / ATR, trend TF)
input bool                  InpUseSlopeCheck            = true;     // Flat filter: use EMA slope check
input int                   InpSlopeBars                = 3;        // Slope lookback (closed trend-TF bars)
input double                InpMinimumEMASlopeATR       = 0.10;     // MinimumEMASlopeATR (EMA14 change over lookback / ATR, trend TF)
input bool                  InpEnableSpreadFilter       = true;     // EnableSpreadFilter
input double                InpMaxSpreadToStopRatio     = 0.15;     // MaxSpreadToStopRatio (spread / SL distance)
input int                   InpMaxSpreadPoints          = 0;        // MaxSpreadPoints (0 = disabled until calibrated)
input int                   InpMaxQuoteAgeSeconds       = 15;       // Max quote age in seconds (0 = disabled)
input bool                  InpEnableEntryDriftFilter   = true;     // EnableEntryDriftFilter
input double                InpMaxEntryDriftATR         = 0.20;     // MaxEntryDriftATR (|price - signal close| / entry-TF ATR)
input bool                  InpDriftExcludesSpread      = true;     // Drift on Bid basis (price move only; spread has its own filter)
input bool                  InpEnableNewsFilter         = true;     // EnableNewsFilter (fails CLOSED when data unavailable)
input int                   InpNewsBlockBeforeMinutes   = 15;       // NewsBlockBeforeMinutes
input int                   InpNewsBlockAfterMinutes    = 15;       // NewsBlockAfterMinutes
input string                InpNewsCurrencies           = "USD";    // News currencies (comma separated)
input ENUM_AFX_NEWS_LEVEL   InpNewsImportance           = AFX_NEWS_HIGH_ONLY; // News importance
input string                InpNewsCsvFile              = "ALBFX_news_events.csv"; // News CSV (Common\Files) used by the Strategy Tester
input int                   InpNewsExportDays           = 0;        // Live/demo only: export N days of calendar history to the CSV (0 = off)
input bool                  InpEnableSessionFilter      = false;    // EnableSessionFilter (broker server time)
input string                InpSessionStart             = "00:00";  // Session start HH:MM (server time, inclusive)
input string                InpSessionEnd               = "23:59";  // Session end HH:MM (server time, exclusive)

input group "=== Stop Loss / Take Profit ==="
input int                   InpSwingLookback      = 20;             // SwingLookback (completed entry-TF bars searched)
input int                   InpSwingLeftBars      = 2;              // SwingLeftBars (older bars)
input int                   InpSwingRightBars     = 2;              // SwingRightBars (newer bars)
input bool                  InpSwingRequireUnbroken = true;         // Use only swings not violated by later candles
input int                   InpStopBufferPoints   = 0;              // StopBufferPoints (fixed part, symbol points)
input double                InpStopBufferATR      = 0.10;           // Stop buffer, ATR part (x entry-TF ATR)
input bool                  InpAddSpreadToSellStop = true;          // Add current spread to SELL stops (SELL SL triggers on Ask)
input double                InpMinStopATR         = 0.25;           // Minimum SL distance (x entry-TF ATR)
input int                   InpMinStopPoints      = 0;              // Minimum SL distance (points, 0 = off)
input double                InpMaxStopATR         = 3.0;            // Maximum SL distance (x entry-TF ATR, 0 = off)
input double                InpRewardRisk         = 1.5;            // RewardRisk (TP = entry +/- RR x risk)
input bool                  InpReanchorTPToFill   = true;           // After fill, re-anchor TP to RR x (fill - SL)
input bool                  InpEnableBreakEven    = false;          // EnableBreakEven (research variant D)
input double                InpBreakEvenTriggerR  = 1.0;            // Break-even trigger (R)
input int                   InpBreakEvenOffsetPoints = 0;           // Break-even lock offset (points)
input bool                  InpEnableTrailingStop = false;          // EnableTrailingStop
input double                InpTrailStartR        = 1.0;            // Trailing start (R)
input double                InpTrailDistanceATR   = 1.0;            // Trailing distance (x entry-TF ATR)
input bool                  InpEnableTimeExit     = false;          // EnableTimeExit
input int                   InpMaxHoldMinutes     = 30;             // Time exit after N minutes

input group "=== Risk ==="
input double                InpRiskPercent        = 0.5;            // RiskPercent (% of equity per trade)
input double                InpMaxDailyLossPercent = 2.0;           // MaxDailyLossPercent (% of daily equity baseline)
input int                   InpMaxTradesPerDay    = 5;              // MaxTradesPerDay (executed entries per broker day, 0 = unlimited)
input int                   InpMaxOpenPositions   = 1;              // MaxOpenPositions (all symbols, this magic number)
input double                InpEstimatedCommissionPerLot = 7.0;     // EstimatedCommissionPerLot (round trip, account currency)
input int                   InpEstimatedSlippagePoints   = 10;      // EstimatedSlippagePoints (per side, points)
input bool                  InpEmergencyCloseOnDailyLimit = false;  // EmergencyCloseOnDailyLimit (close EA positions at the floor)
input bool                  InpCheckDailyBudgetBeforeEntry = true;  // Skip entries whose full SL loss would breach the daily limit
input double                InpMaxMarginUsagePercent = 50.0;        // Max margin of one entry (% of free margin)
input double                InpMaxLots            = 0.0;            // Hard lot cap (0 = broker maximum only)
input int                   InpDayResetHour       = 0;              // Daily reset hour (broker server time, 0 = midnight)
input int                   InpMaxDeviationPoints = 30;             // Max deviation for market orders (points)
input int                   InpMaxSendRetries     = 1;              // Retries after requote/price change (0-3)

input group "=== Diagnostics ==="
input bool                  InpEnableDetailedLogs   = true;         // EnableDetailedLogs
input bool                  InpLogNoSetupBars       = false;        // Also log bars without trend/touch (verbose)
input bool                  InpEnableChartDashboard = true;         // EnableChartDashboard
input bool                  InpEnableAlerts         = true;         // EnableAlerts
input bool                  InpEnablePushNotifications = false;     // Push notifications (live only)
input bool                  InpWriteJournalCsv      = true;         // Write signal journal CSV (Common\Files)
input bool                  InpWriteTesterReport    = true;         // Write extended report at the end of a backtest
input bool                  InpRunSelfTests         = false;        // Run built-in logic self-tests on start

//+------------------------------------------------------------------+
//| Data structures                                                  |
//+------------------------------------------------------------------+
struct AfxSignal
  {
   datetime          evalTime;
   datetime          signalBarTime;
   datetime          touchBarTime;
   datetime          trendBarTime;
   int               dir;
   bool              isSetup;
   bool              patternOk;
   double            sigOpen;
   double            sigHigh;
   double            sigLow;
   double            sigClose;
   double            emaFastM1;
   double            emaSlowM1;
   double            bandLow;
   double            bandHigh;
   double            emaFastTrend;
   double            emaSlowTrend;
   double            atrTrend;
   double            sepATR;
   double            slopeATR;
   double            atrEntry;
   double            bid;
   double            ask;
   double            spreadPts;
   double            swingPrice;
   int               swingShift;
   double            entry;
   double            sl;
   double            tp;
   double            slDist;
   double            rrActual;
   double            driftATR;
   double            volume;
   double            riskBudget;
   double            lossPerLot;
   double            plannedLoss;
   double            margin;
   int               reject;
   string            detail;
   string            decision;
  };

struct AfxPosRecord
  {
   ulong             posId;
   int               dir;
   datetime          openTime;
   double            openPrice;
   double            initialSL;
   double            riskMoney;
   datetime          signalBar;
  };

struct AfxDaily
  {
   datetime          dayStart;
   double            baseEquity;
   datetime          baseTime;
   bool              cfInclusive;
   double            cashFlow;
   bool              halted;
   string            haltReason;
   int               entries;
   int               alerts;
   string            source;
   double            lossPct;
  };

struct AfxTradeStat
  {
   ulong             pid;
   int               dir;
   datetime          tin;
   datetime          tout;
   double            net;
   double            cost;
   double            risk;
  };

//+------------------------------------------------------------------+
//| Global state                                                     |
//+------------------------------------------------------------------+
string   g_sym          = "";
int      g_digits       = 0;
double   g_point        = 0.0;
double   g_tick         = 0.0;
double   g_volMin       = 0.0;
double   g_volMax       = 0.0;
double   g_volStep      = 0.0;
int      g_volDigits    = 2;

bool     g_initOk       = false;
bool     g_isTester     = false;
bool     g_isVisual     = false;
bool     g_isOptim      = false;
bool     g_isHedging    = false;
bool     g_isReal       = false;
bool     g_persist      = false;
bool     g_execAllowed  = false;
string   g_execStatus   = "";
ENUM_ORDER_TYPE_FILLING g_filling = ORDER_FILLING_FOK;
int      g_sessStartMin = 0;
int      g_sessEndMin   = 0;

int      g_hFastT = INVALID_HANDLE;
int      g_hSlowT = INVALID_HANDLE;
int      g_hFastE = INVALID_HANDLE;
int      g_hSlowE = INVALID_HANDLE;
int      g_hAtrE  = INVALID_HANDLE;
int      g_hAtrT  = INVALID_HANDLE;

datetime g_lastBarTime         = 0;     // open time of the newest entry-TF bar seen
bool     g_evalPending         = false;
datetime g_evalBarTime         = 0;
datetime g_lastTradedSignalBar = 0;     // last signal candle that produced an order/alert
int      g_lastTrendDir        = 0;
string   g_lastEvalText        = "waiting for the first closed candle";

//--- order reconciliation
bool      g_pendVerify = false;
datetime  g_pendTime   = 0;
ulong     g_pendOrder  = 0;
ulong     g_pendDeal   = 0;
AfxSignal g_pendSig;

//--- daily state
AfxDaily g_day;
ulong    g_dayPosIds[];
datetime g_lastHistRefresh = 0;
bool     g_histDirty       = true;
datetime g_lastEmergencyTry = 0;
datetime g_sessionStart     = 0;      // EA start time: fills after it are new entries
datetime g_lastModifyTry    = 0;

//--- news
bool     g_newsOk          = false;
string   g_newsStatus      = "OFF";
string   g_newsBaseStatus  = "";
string   g_newsCurr[];
datetime g_newsTimes[];
string   g_newsTitles[];
datetime g_newsLastRefresh = 0;
datetime g_newsCovFrom     = 0;
datetime g_newsCovTo       = 0;
ulong    g_evtIds[];
int      g_evtImp[];
int      g_evtMode[];
string   g_evtName[];

//--- statistics
AfxPosRecord g_posRec[];
int      g_rejects[];
int      g_evaluations     = 0;
int      g_setups          = 0;
int      g_patternSignals  = 0;
int      g_validSignals    = 0;
int      g_rejectedSignals = 0;
int      g_ordersSent      = 0;
int      g_ordersFilled    = 0;
int      g_alertsEmitted   = 0;
int      g_dailyLimitActivations = 0;
int      g_emergencyCloses = 0;
string   g_dailyLimitDates = "";

//--- io
int      g_journal   = INVALID_HANDLE;
ulong    g_lastDashMs = 0;

//+------------------------------------------------------------------+
//| Small helpers                                                    |
//+------------------------------------------------------------------+
int    IMax(const int a, const int b) { return (a > b) ? a : b; }
int    IMin(const int a, const int b) { return (a < b) ? a : b; }
string BoolStr(const bool b) { return b ? "true" : "false"; }
string DirName(const int d) { return (d > 0) ? "BUY" : ((d < 0) ? "SELL" : "NONE"); }
bool   ValidValue(const double v) { return (v != EMPTY_VALUE && MathIsValidNumber(v) && v > 0.0); }

datetime AfxNow()
  {
   return g_isTester ? TimeCurrent() : TimeTradeServer();
  }

void LogInfo(const string m)
  {
   if(InpEnableDetailedLogs && !g_isOptim)
      PrintFormat("[AFX-EMA] %s", m);
  }

void LogWarn(const string m)
  {
   if(!g_isOptim)
      PrintFormat("[AFX-EMA][WARN] %s", m);
  }

void LogErr(const string m)
  {
   PrintFormat("[AFX-EMA][ERROR] %s", m);
  }

string Px(const double v)
  {
   return DoubleToString(v, g_digits);
  }

string RejectName(const int code)
  {
   switch(code)
     {
      case RJ_NONE:                     return "NONE";
      case RJ_DATA_NOT_READY:           return "DATA_NOT_READY";
      case RJ_TREND_NOT_SYNCED:         return "TREND_TF_NOT_SYNCED";
      case RJ_STALE_SIGNAL:             return "STALE_SIGNAL";
      case RJ_NO_TREND:                 return "NO_TREND";
      case RJ_NO_TOUCH:                 return "NO_BAND_TOUCH";
      case RJ_CANDLE_DIRECTION:         return "CANDLE_DIRECTION";
      case RJ_CLOSE_VS_EMA8:            return "CLOSE_VS_EMA8";
      case RJ_SETUP_INVALIDATED:        return "SETUP_INVALIDATED";
      case RJ_M1_ALIGNMENT:             return "ENTRY_TF_EMA_ALIGNMENT";
      case RJ_FLAT_SEPARATION:          return "FLAT_EMA_SEPARATION";
      case RJ_FLAT_SLOPE:               return "FLAT_EMA_SLOPE";
      case RJ_SESSION_FILTER:           return "SESSION_FILTER";
      case RJ_MARKET_CLOSED:            return "MARKET_CLOSED";
      case RJ_DIRECTION_NOT_ALLOWED:    return "DIRECTION_NOT_ALLOWED";
      case RJ_NEWS_BLOCK:               return "NEWS_WINDOW";
      case RJ_NEWS_UNVERIFIED:          return "NEWS_DATA_UNVERIFIED";
      case RJ_DAILY_LOSS_HALT:          return "DAILY_LOSS_HALT";
      case RJ_DAILY_RISK_BUDGET:        return "DAILY_RISK_BUDGET";
      case RJ_MAX_TRADES_DAY:           return "MAX_TRADES_PER_DAY";
      case RJ_FILL_UNRECONCILED:        return "PREVIOUS_ORDER_UNRECONCILED";
      case RJ_POSITION_OPEN:            return "POSITION_ALREADY_OPEN";
      case RJ_MAX_OPEN_POSITIONS:       return "MAX_OPEN_POSITIONS";
      case RJ_FOREIGN_NETTING_POSITION: return "FOREIGN_NETTING_POSITION";
      case RJ_PENDING_ORDER_EXISTS:     return "PENDING_ORDER_EXISTS";
      case RJ_DUPLICATE_SIGNAL:         return "DUPLICATE_SIGNAL";
      case RJ_TRADING_NOT_PERMITTED:    return "TRADING_NOT_PERMITTED";
      case RJ_QUOTE_INVALID:            return "QUOTE_INVALID";
      case RJ_QUOTE_STALE:              return "QUOTE_STALE";
      case RJ_NO_SWING:                 return "NO_STRUCTURAL_SWING";
      case RJ_SL_WRONG_SIDE:            return "SL_WRONG_SIDE";
      case RJ_SL_TOO_CLOSE:             return "SL_TOO_CLOSE";
      case RJ_SL_TOO_FAR:               return "SL_TOO_FAR";
      case RJ_SPREAD_ABSOLUTE:          return "SPREAD_ABSOLUTE";
      case RJ_SPREAD_TO_STOP:           return "SPREAD_TO_STOP_RATIO";
      case RJ_ENTRY_DRIFT:              return "ENTRY_DRIFT";
      case RJ_RR_AFTER_NORMALIZATION:   return "RR_AFTER_NORMALIZATION";
      case RJ_STOPS_LEVEL:              return "BROKER_STOPS_LEVEL";
      case RJ_RISK_CALC_FAILED:         return "RISK_CALC_FAILED";
      case RJ_MIN_LOT_EXCEEDS_RISK:     return "MIN_LOT_EXCEEDS_RISK";
      case RJ_MARGIN:                   return "MARGIN";
      case RJ_ORDER_CHECK:              return "ORDER_CHECK_FAILED";
      case RJ_SEND_FAILED:              return "ORDER_SEND_FAILED";
      case RJ_NO_CROSS:                 return "NO_EMA_CROSS";
      case RJ_TREND_MISMATCH:           return "CROSS_AGAINST_TREND";
     }
   return "UNKNOWN";
  }

bool IsNoSetup(const int code)
  {
   return (code == RJ_NO_TREND || code == RJ_NO_TOUCH || code == RJ_NO_CROSS);
  }

int Rej(AfxSignal &s, const int code, const string detail)
  {
   s.reject = code;
   s.detail = detail;
   return code;
  }

//+------------------------------------------------------------------+
//| PURE LOGIC (no terminal side effects) - covered by self-tests    |
//+------------------------------------------------------------------+
//--- +1 when fast EMA is above slow EMA, -1 below, 0 when equal
int AfxTrendDir(const double emaFast, const double emaSlow)
  {
   if(emaFast > emaSlow)
      return 1;
   if(emaFast < emaSlow)
      return -1;
   return 0;
  }

//--- EMA cross on closed bars: +1 fast crossed above slow on bar 1, -1 below, 0 none.
//--- "Now" = latest closed bar (shift 1), "Prev" = the bar before it (shift 2).
int AfxCrossDirection(const double fastNow, const double slowNow, const double fastPrev, const double slowPrev)
  {
   if(fastPrev <= slowPrev && fastNow > slowNow)
      return 1;
   if(fastPrev >= slowPrev && fastNow < slowNow)
      return -1;
   return 0;
  }

//--- candle range [low, high] intersects the EMA band (wick contact counts)
bool AfxBandTouch(const double low, const double high, const double ema1, const double ema2)
  {
   double bandLow  = MathMin(ema1, ema2);
   double bandHigh = MathMax(ema1, ema2);
   return (low <= bandHigh && high >= bandLow);
  }

//--- Candle pattern on series-indexed arrays (index 1 = latest CLOSED candle).
//--- Mode A: candle 1 touches the band and confirms.
//--- Mode B: candle 2 touches the band, candle 1 (the next one) confirms.
//--- Returns RJ_NONE when the pattern is confirmed for 'dir'.
int AfxEvaluatePattern(const int mode, const int dir,
                       const double &o[], const double &h[], const double &l[], const double &c[],
                       const double &emaF[], const double &emaS[],
                       const bool invalidateCloseThrough, const bool requireAlignment)
  {
   if(dir == 0)
      return RJ_NO_TREND;
   int touchIdx = (mode == AFX_CONFIRM_NEXT_CANDLE) ? 2 : 1;
   if(ArraySize(o) <= touchIdx || ArraySize(h) <= touchIdx || ArraySize(l) <= touchIdx ||
      ArraySize(c) <= touchIdx || ArraySize(emaF) <= touchIdx || ArraySize(emaS) <= touchIdx)
      return RJ_DATA_NOT_READY;

   if(!AfxBandTouch(l[touchIdx], h[touchIdx], emaF[touchIdx], emaS[touchIdx]))
      return RJ_NO_TOUCH;

   if(touchIdx == 2 && invalidateCloseThrough)
     {
      double bLow  = MathMin(emaF[2], emaS[2]);
      double bHigh = MathMax(emaF[2], emaS[2]);
      if(dir > 0 && c[2] < bLow)
         return RJ_SETUP_INVALIDATED;
      if(dir < 0 && c[2] > bHigh)
         return RJ_SETUP_INVALIDATED;
     }

   if(dir > 0)
     {
      if(!(c[1] > o[1]))
         return RJ_CANDLE_DIRECTION;
      if(!(c[1] > emaF[1]))
         return RJ_CLOSE_VS_EMA8;
      if(requireAlignment && !(emaF[1] > emaS[1]))
         return RJ_M1_ALIGNMENT;
     }
   else
     {
      if(!(c[1] < o[1]))
         return RJ_CANDLE_DIRECTION;
      if(!(c[1] < emaF[1]))
         return RJ_CLOSE_VS_EMA8;
      if(requireAlignment && !(emaF[1] < emaS[1]))
         return RJ_M1_ALIGNMENT;
     }
   return RJ_NONE;
  }

//--- Flat-EMA filter on the trend timeframe. Separation and slope are ATR-normalised.
//--- slope = (EMA_slow[closed] - EMA_slow[closed + SlopeBars]) / ATR, signed in trade direction.
int AfxFlatFilter(const int dir, const double emaFast, const double emaSlow,
                  const double emaSlowNow, const double emaSlowPast, const double atr,
                  const bool useSep, const double minSep, const bool useSlope, const double minSlope,
                  double &sepATR, double &slopeATR)
  {
   sepATR   = 0.0;
   slopeATR = 0.0;
   if(atr <= 0.0)
      return RJ_DATA_NOT_READY;
   sepATR   = MathAbs(emaFast - emaSlow) / atr;
   slopeATR = (emaSlowNow - emaSlowPast) / atr;
   if(useSep && sepATR < minSep)
      return RJ_FLAT_SEPARATION;
   if(useSlope)
     {
      double directional = (dir > 0) ? slopeATR : -slopeATR;
      if(directional < minSlope)
         return RJ_FLAT_SLOPE;
     }
   return RJ_NONE;
  }

//--- Latest confirmed swing on series-indexed arrays (index 0 = forming bar, never used).
//--- A pivot at shift i needs 'left' older and 'right' newer COMPLETED bars and must be a
//--- strict extremum. With requireUnbroken, no newer completed bar may exceed the pivot.
//--- Returns the pivot shift or -1.
int AfxFindSwing(const double &h[], const double &l[], const int total, const bool findLow,
                 const int left, const int right, const int lookback, const bool requireUnbroken,
                 double &price)
  {
   price = 0.0;
   if(left < 1 || right < 1 || lookback < 1)
      return -1;
   int n = IMin(total, IMin(ArraySize(h), ArraySize(l)));
   int first = right + 1;
   int last  = IMin(lookback, n - 1 - left);
   for(int i = first; i <= last; i++)
     {
      double v  = findLow ? l[i] : h[i];
      bool   ok = true;
      for(int k = 1; k <= left && ok; k++)
        {
         double w = findLow ? l[i + k] : h[i + k];
         if(findLow ? !(v < w) : !(v > w))
            ok = false;
        }
      for(int k = 1; k <= right && ok; k++)
        {
         double w = findLow ? l[i - k] : h[i - k];
         if(findLow ? !(v < w) : !(v > w))
            ok = false;
        }
      if(!ok)
         continue;
      if(requireUnbroken)
        {
         for(int j = 1; j < i && ok; j++)
           {
            double w = findLow ? l[j] : h[j];
            if(findLow ? (w < v) : (w > v))
               ok = false;
           }
         if(!ok)
            continue;
        }
      price = v;
      return i;
     }
   return -1;
  }

//--- price normalisation to the symbol tick grid (not merely digits)
double AfxRoundDown(const double price, const double tick, const int digits)
  {
   if(tick <= 0.0)
      return NormalizeDouble(price, digits);
   return NormalizeDouble(MathFloor(price / tick + 1e-8) * tick, digits);
  }

double AfxRoundUp(const double price, const double tick, const int digits)
  {
   if(tick <= 0.0)
      return NormalizeDouble(price, digits);
   return NormalizeDouble(MathCeil(price / tick - 1e-8) * tick, digits);
  }

double AfxTakeProfit(const int dir, const double entry, const double sl, const double rr)
  {
   if(dir > 0)
      return entry + rr * (entry - sl);
   return entry - rr * (sl - entry);
  }

//--- Largest volume on the step grid whose loss does not exceed the budget. 0 = cannot trade.
double AfxVolumeForRisk(const double budget, const double lossPerLot, const double step,
                        const double vmin, const double vmax)
  {
   if(budget <= 0.0 || lossPerLot <= 0.0 || step <= 0.0 || vmax <= 0.0)
      return 0.0;
   double raw = budget / lossPerLot;
   double v   = MathFloor(raw / step + 1e-7) * step;
   double cap = MathFloor(vmax / step + 1e-7) * step;
   if(v > cap)
      v = cap;
   while(v > 0.0 && v * lossPerLot > budget * (1.0 + 1e-9))
      v -= step;
   if(v < vmin - 1e-12 || v <= 0.0)
      return 0.0;
   return v;
  }

//--- distance between a price and the signal close in ATR units
double AfxDriftATR(const double price, const double signalClose, const double atr)
  {
   if(atr <= 0.0)
      return 0.0;
   return MathAbs(price - signalClose) / atr;
  }

bool AfxSpreadOk(const double spreadPrice, const double slDistance, const double maxRatio)
  {
   if(slDistance <= 0.0)
      return false;
   return (spreadPrice <= maxRatio * slDistance + 1e-12);
  }

datetime AfxDayStart(const datetime t, const int resetHour)
  {
   long off = (long)resetHour * 3600;
   long x   = (long)t - off;
   long d   = (x / 86400) * 86400;
   return (datetime)(d + off);
  }

bool AfxParseHHMM(const string text, int &minutes)
  {
   string s = text;
   StringTrimLeft(s);
   StringTrimRight(s);
   string parts[];
   if(StringSplit(s, ':', parts) != 2)
      return false;
   if(StringLen(parts[0]) < 1 || StringLen(parts[1]) < 1)
      return false;
   for(int p = 0; p < 2; p++)
      for(int i = 0; i < StringLen(parts[p]); i++)
        {
         ushort ch = StringGetCharacter(parts[p], i);
         if(ch < '0' || ch > '9')
            return false;
        }
   int hh = (int)StringToInteger(parts[0]);
   int mm = (int)StringToInteger(parts[1]);
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return false;
   minutes = hh * 60 + mm;
   return true;
  }

//--- [start, end) window in minutes of day, supports wrap past midnight; start == end -> always
bool AfxInWindow(const int nowMin, const int startMin, const int endMin)
  {
   if(startMin == endMin)
      return true;
   if(startMin < endMin)
      return (nowMin >= startMin && nowMin < endMin);
   return (nowMin >= startMin || nowMin < endMin);
  }

//--- news CSV line: "YYYY.MM.DD HH:MM,CUR,IMPORTANCE[,title]" (';' also accepted)
//--- importance: HIGH/3, MEDIUM/MODERATE/2, LOW/1
bool AfxParseNewsLine(const string rawLine, datetime &t, string &cur, int &imp, string &title)
  {
   string line = rawLine;
   StringTrimLeft(line);
   StringTrimRight(line);
   if(StringLen(line) == 0 || StringGetCharacter(line, 0) == '#')
      return false;
   StringReplace(line, ";", ",");
   string f[];
   int n = StringSplit(line, ',', f);
   if(n < 3)
      return false;
   for(int i = 0; i < n; i++)
     {
      StringTrimLeft(f[i]);
      StringTrimRight(f[i]);
     }
   if(StringLen(f[0]) < 16)
      return false;
   t = StringToTime(f[0]);
   if(t < D'2000.01.01 00:00')
      return false;
   cur = f[1];
   StringToUpper(cur);
   if(StringLen(cur) != 3)
      return false;
   string im = f[2];
   StringToUpper(im);
   if(im == "HIGH" || im == "3")
      imp = 3;
   else
      if(im == "MEDIUM" || im == "MODERATE" || im == "2")
         imp = 2;
      else
         if(im == "LOW" || im == "1")
            imp = 1;
         else
            return false;
   title = "";
   for(int i = 3; i < n; i++)
      title += (i > 3 ? " " : "") + f[i];
   return true;
  }

bool AfxNewsWindowHit(const datetime now, const datetime evt, const int beforeMin, const int afterMin)
  {
   long a = (long)evt - (long)beforeMin * 60;
   long b = (long)evt + (long)afterMin * 60;
   return ((long)now >= a && (long)now <= b);
  }

//+------------------------------------------------------------------+
//| Built-in self-tests for the pure logic above                     |
//+------------------------------------------------------------------+
int g_stPass = 0;
int g_stFail = 0;

void ST(const bool cond, const string name)
  {
   if(cond)
      g_stPass++;
   else
     {
      g_stFail++;
      PrintFormat("[AFX-EMA][SELFTEST][FAIL] %s", name);
     }
  }

bool StEq(const double a, const double b)
  {
   return (MathAbs(a - b) <= 1e-9);
  }

void StCandle(double &o[], double &h[], double &l[], double &c[], const int i,
              const double vo, const double vh, const double vl, const double vc)
  {
   o[i] = vo;
   h[i] = vh;
   l[i] = vl;
   c[i] = vc;
  }

int RunSelfTests()
  {
   g_stPass = 0;
   g_stFail = 0;
   double o[3], h[3], l[3], c[3], ef[3], es[3];
   ArrayInitialize(o, 0.0); ArrayInitialize(h, 0.0); ArrayInitialize(l, 0.0);
   ArrayInitialize(c, 0.0); ArrayInitialize(ef, 0.0); ArrayInitialize(es, 0.0);

//--- trend direction
   ST(AfxTrendDir(2.0, 1.0) == 1, "trend up");
   ST(AfxTrendDir(1.0, 2.0) == -1, "trend down");
   ST(AfxTrendDir(1.0, 1.0) == 0, "trend equal -> none");

//--- EMA crossover
   ST(AfxCrossDirection(2001.0, 2000.0, 1999.0, 2000.0) == 1, "cross up");
   ST(AfxCrossDirection(1999.0, 2000.0, 2001.0, 2000.0) == -1, "cross down");
   ST(AfxCrossDirection(2001.0, 2000.0, 2002.0, 2000.0) == 0, "no cross while above");
   ST(AfxCrossDirection(1999.0, 2000.0, 1998.0, 2000.0) == 0, "no cross while below");
   ST(AfxCrossDirection(2001.0, 2000.0, 2000.0, 2000.0) == 1, "cross up from equal");
   ST(AfxCrossDirection(2000.0, 2000.0, 1999.0, 2000.0) == 0, "touch to equal is not a cross yet");

//--- band touch
   ST(AfxBandTouch(1998.8, 2001.0, 2000.0, 1999.0), "touch: wick through band");
   ST(AfxBandTouch(2000.0, 2002.0, 2000.0, 1999.0), "touch: low exactly at band high");
   ST(!AfxBandTouch(2000.5, 2002.0, 2000.0, 1999.0), "no touch: candle above band");
   ST(!AfxBandTouch(1996.0, 1998.9, 2000.0, 1999.0), "no touch: candle below band");

//--- Mode A BUY
   ef[1] = 2000.0; es[1] = 1999.0;
   StCandle(o, h, l, c, 1, 1999.5, 2001.0, 1998.8, 2000.5);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_NONE, "A buy valid");
   StCandle(o, h, l, c, 1, 2000.6, 2001.0, 1998.8, 2000.2);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_CANDLE_DIRECTION, "A buy bearish candle rejected");
   StCandle(o, h, l, c, 1, 1999.2, 2000.5, 1998.8, 1999.8);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_CLOSE_VS_EMA8, "A buy close below EMA8 rejected");
   StCandle(o, h, l, c, 1, 2000.6, 2002.0, 2000.5, 2001.5);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_NO_TOUCH, "A buy no touch rejected");
   StCandle(o, h, l, c, 1, 1999.5, 2001.0, 1998.8, 2000.5);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 0, o, h, l, c, ef, es, true, false) == RJ_NO_TREND, "no trend rejected");

//--- Mode A SELL
   ef[1] = 2000.0; es[1] = 2001.0;
   StCandle(o, h, l, c, 1, 2000.8, 2001.5, 1999.2, 1999.6);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, -1, o, h, l, c, ef, es, true, false) == RJ_NONE, "A sell valid");
   StCandle(o, h, l, c, 1, 1999.6, 2001.5, 1999.2, 2000.8);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, -1, o, h, l, c, ef, es, true, false) == RJ_CANDLE_DIRECTION, "A sell bullish candle rejected");
   StCandle(o, h, l, c, 1, 2000.9, 2001.5, 1999.2, 2000.3);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, -1, o, h, l, c, ef, es, true, false) == RJ_CLOSE_VS_EMA8, "A sell close above EMA8 rejected");

//--- entry-TF alignment option
   ef[1] = 1999.0; es[1] = 2000.0;
   StCandle(o, h, l, c, 1, 1999.5, 2001.0, 1998.9, 2000.5);
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_NONE, "alignment off: buy valid with EMA8<EMA14");
   ST(AfxEvaluatePattern(AFX_CONFIRM_SAME_CANDLE, 1, o, h, l, c, ef, es, true, true) == RJ_M1_ALIGNMENT, "alignment on: buy rejected with EMA8<EMA14");

//--- Mode B BUY
   ef[2] = 2000.0; es[2] = 1999.0;
   StCandle(o, h, l, c, 2, 2000.4, 2000.8, 1999.5, 1999.8);
   ef[1] = 2000.1; es[1] = 1999.2;
   StCandle(o, h, l, c, 1, 1999.9, 2000.9, 1999.8, 2000.6);
   ST(AfxEvaluatePattern(AFX_CONFIRM_NEXT_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_NONE, "B buy valid");
   StCandle(o, h, l, c, 2, 2000.4, 2000.8, 1998.0, 1998.5);
   ST(AfxEvaluatePattern(AFX_CONFIRM_NEXT_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_SETUP_INVALIDATED, "B buy touch candle closed through band");
   ST(AfxEvaluatePattern(AFX_CONFIRM_NEXT_CANDLE, 1, o, h, l, c, ef, es, false, false) == RJ_NONE, "B buy close-through allowed when option off");
   StCandle(o, h, l, c, 2, 2001.0, 2002.0, 2000.5, 2001.5);
   ST(AfxEvaluatePattern(AFX_CONFIRM_NEXT_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_NO_TOUCH, "B buy without touch on previous candle");
   StCandle(o, h, l, c, 2, 2000.4, 2000.8, 1999.5, 1999.8);
   StCandle(o, h, l, c, 1, 2000.6, 2000.9, 1999.8, 2000.3);
   ST(AfxEvaluatePattern(AFX_CONFIRM_NEXT_CANDLE, 1, o, h, l, c, ef, es, true, false) == RJ_CANDLE_DIRECTION, "B buy bearish confirmation rejected");

//--- swing detection
   double sh[25], sl[25];
   ArrayInitialize(sh, 100.0);
   ArrayInitialize(sl, 100.0);
   double sp = 0.0;
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, true, sp) == -1, "swing: flat lows -> none");
   sl[8] = 94.0; sl[9] = 94.0;
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, false, sp) == -1, "swing: equal lows are not strict pivots");
   sl[8] = 100.0; sl[9] = 100.0;
   sl[5] = 95.0;
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, true, sp) == 5 && StEq(sp, 95.0), "swing low at shift 5");
   sl[2] = 80.0;
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, false, sp) == 5, "swing: shift 2 lacks two closed right bars");
   sl[2] = 100.0;
   sl[1] = 94.0;
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, false, sp) == 5, "swing: broken pivot accepted when rule off");
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, true, sp) == -1, "swing: broken pivot rejected, none older");
   sl[12] = 90.0;
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 20, true, sp) == 12 && StEq(sp, 90.0), "swing: falls back to older unbroken pivot");
   ST(AfxFindSwing(sh, sl, 25, true, 2, 2, 10, true, sp) == -1, "swing: lookback limit respected");
   sh[4] = 105.0;
   ST(AfxFindSwing(sh, sl, 25, false, 2, 2, 20, true, sp) == 4 && StEq(sp, 105.0), "swing high at shift 4");
   sh[1] = 106.0;
   ST(AfxFindSwing(sh, sl, 25, false, 2, 2, 20, true, sp) == -1, "swing high broken by newer bar (unbroken rule)");
   ST(AfxFindSwing(sh, sl, 25, false, 2, 2, 20, false, sp) == 4, "swing high kept when unbroken rule off");

//--- price normalisation
   ST(StEq(AfxRoundDown(2000.127, 0.01, 2), 2000.12), "round down 0.01");
   ST(StEq(AfxRoundUp(2000.121, 0.01, 2), 2000.13), "round up 0.01");
   ST(StEq(AfxRoundDown(2000.123, 0.05, 2), 2000.10), "round down 0.05 tick");
   ST(StEq(AfxRoundUp(2000.123, 0.05, 2), 2000.15), "round up 0.05 tick");
   ST(StEq(AfxRoundUp(2000.10, 0.05, 2), 2000.10), "round up keeps on-grid price");

//--- take profit
   ST(StEq(AfxTakeProfit(1, 2000.0, 1998.0, 1.5), 2003.0), "TP buy 1.5R");
   ST(StEq(AfxTakeProfit(-1, 2000.0, 2002.0, 1.5), 1997.0), "TP sell 1.5R");

//--- volume sizing
   ST(StEq(AfxVolumeForRisk(50.0, 200.0, 0.01, 0.01, 100.0), 0.25), "volume 0.25");
   ST(StEq(AfxVolumeForRisk(1.0, 200.0, 0.01, 0.01, 100.0), 0.0), "min lot exceeds risk -> 0");
   ST(StEq(AfxVolumeForRisk(50.0, 200.0, 0.01, 0.01, 0.10), 0.10), "volume capped at max");
   ST(StEq(AfxVolumeForRisk(10.0, 3.0, 0.1, 0.1, 100.0), 3.3), "volume floors to step 0.1");
   ST(AfxVolumeForRisk(50.0, 333.33, 0.01, 0.01, 100.0) * 333.33 <= 50.0 + 1e-9, "volume never exceeds budget");

//--- spread / stop ratio
   ST(AfxSpreadOk(0.15, 1.00, 0.15), "spread 15 pts vs SL 100 pts ok");
   ST(!AfxSpreadOk(0.16, 1.00, 0.15), "spread 16 pts vs SL 100 pts rejected");

//--- entry drift: Bid basis is spread-neutral; an Ask with 0.20 spread alone breaks a 0.20 ATR limit
   ST(MathAbs(AfxDriftATR(2000.10, 2000.00, 1.0) - 0.10) < 1e-9, "drift 0.10 ATR on bid basis");
   ST(AfxDriftATR(2000.00 + 0.21, 2000.00, 1.0) > 0.20, "spread-inclusive ask exceeds 0.20 ATR without any price move");

//--- flat filter
   double sep = 0.0, slope = 0.0;
   ST(AfxFlatFilter(1, 2001.0, 2000.0, 2000.0, 1999.5, 2.0, true, 0.1, true, 0.1, sep, slope) == RJ_NONE && StEq(sep, 0.5) && StEq(slope, 0.25), "flat filter pass");
   ST(AfxFlatFilter(1, 2000.1, 2000.0, 2000.0, 1999.5, 2.0, true, 0.1, true, 0.1, sep, slope) == RJ_FLAT_SEPARATION, "flat filter separation");
   ST(AfxFlatFilter(1, 2001.0, 2000.0, 2000.0, 1999.5, 2.0, true, 0.1, true, 0.3, sep, slope) == RJ_FLAT_SLOPE, "flat filter slope");
   ST(AfxFlatFilter(-1, 1999.0, 2000.0, 2000.0, 1999.5, 2.0, true, 0.1, true, 0.1, sep, slope) == RJ_FLAT_SLOPE, "flat filter slope against sell");
   ST(AfxFlatFilter(1, 2000.1, 2000.0, 2000.0, 1999.5, 2.0, false, 0.1, true, 0.1, sep, slope) == RJ_NONE, "flat filter separation disabled");

//--- day boundary
   ST(AfxDayStart(D'2026.11.08 15:30', 0) == D'2026.11.08 00:00', "day start midnight");
   ST(AfxDayStart(D'2026.11.08 01:00', 2) == D'2026.11.07 02:00', "day start reset hour 2, before");
   ST(AfxDayStart(D'2026.11.08 02:00', 2) == D'2026.11.08 02:00', "day start reset hour 2, at");

//--- session parsing / window
   int mins = -1;
   ST(AfxParseHHMM("09:30", mins) && mins == 570, "parse 09:30");
   ST(!AfxParseHHMM("24:00", mins), "reject 24:00");
   ST(!AfxParseHHMM("ab:cd", mins), "reject non-numeric");
   ST(AfxInWindow(23 * 60, 22 * 60, 2 * 60), "wrap window 23:00");
   ST(AfxInWindow(60, 22 * 60, 2 * 60), "wrap window 01:00");
   ST(!AfxInWindow(12 * 60, 22 * 60, 2 * 60), "wrap window excludes 12:00");
   ST(AfxInWindow(600, 480, 1020), "window 10:00 in 08-17");
   ST(!AfxInWindow(1020, 480, 1020), "window end exclusive");
   ST(AfxInWindow(5, 0, 0), "start==end -> always");

//--- news parsing / window
   datetime nt = 0;
   string   ncur = "", ntitle = "";
   int      nimp = 0;
   ST(AfxParseNewsLine("2026.10.02 15:30,USD,HIGH,Non-Farm Payrolls", nt, ncur, nimp, ntitle) &&
      nt == D'2026.10.02 15:30' && ncur == "USD" && nimp == 3 && ntitle == "Non-Farm Payrolls", "news line parse");
   ST(AfxParseNewsLine("2026.10.02 15:30;eur;2;CPI", nt, ncur, nimp, ntitle) && ncur == "EUR" && nimp == 2, "news line semicolon");
   ST(!AfxParseNewsLine("# comment", nt, ncur, nimp, ntitle), "news comment ignored");
   ST(!AfxParseNewsLine("garbage", nt, ncur, nimp, ntitle), "news garbage ignored");
   ST(AfxNewsWindowHit(D'2026.10.02 15:15', D'2026.10.02 15:30', 15, 15), "news window start");
   ST(!AfxNewsWindowHit(D'2026.10.02 15:14', D'2026.10.02 15:30', 15, 15), "news window before");
   ST(AfxNewsWindowHit(D'2026.10.02 15:45', D'2026.10.02 15:30', 15, 15), "news window end");
   ST(!AfxNewsWindowHit(D'2026.10.02 15:46', D'2026.10.02 15:30', 15, 15), "news window after");

   PrintFormat("[AFX-EMA][SELFTEST] %d passed, %d failed", g_stPass, g_stFail);
   return g_stFail;
  }

//+------------------------------------------------------------------+
//| Symbol / account helpers                                         |
//+------------------------------------------------------------------+
bool LoadSymbolProperties()
  {
   g_digits  = (int)SymbolInfoInteger(g_sym, SYMBOL_DIGITS);
   g_point   = SymbolInfoDouble(g_sym, SYMBOL_POINT);
   g_tick    = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_SIZE);
   g_volMin  = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MIN);
   g_volMax  = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MAX);
   g_volStep = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_STEP);
   if(g_point <= 0.0 || g_volStep <= 0.0 || g_volMin <= 0.0 || g_volMax <= 0.0)
      return false;
   if(g_tick <= 0.0)
      g_tick = g_point;
   g_volDigits = (int)MathMax(0.0, MathCeil(-MathLog10(g_volStep) - 1e-9));
   return true;
  }

ENUM_ORDER_TYPE_FILLING SelectFilling()
  {
   long fm = SymbolInfoInteger(g_sym, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((fm & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

string FillingName(const ENUM_ORDER_TYPE_FILLING f)
  {
   if(f == ORDER_FILLING_FOK)
      return "FOK";
   if(f == ORDER_FILLING_IOC)
      return "IOC";
   return "RETURN";
  }

bool TradingPermitted(string &why)
  {
   if(g_isTester)
      return true;
   if(TerminalInfoInteger(TERMINAL_CONNECTED) == 0)
     {
      why = "terminal is disconnected from the trade server";
      return false;
     }
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
     {
      why = "Algo Trading is switched OFF in the terminal toolbar";
      return false;
     }
   if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
     {
      why = "'Allow Algo Trading' is unchecked in the EA properties";
      return false;
     }
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
     {
      why = "trading is not allowed for this account (investor login?)";
      return false;
     }
   if(AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0)
     {
      why = "the broker disabled expert trading for this account";
      return false;
     }
   return true;
  }

bool DirectionAllowed(const int dir, string &why)
  {
   ENUM_SYMBOL_TRADE_MODE m = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(g_sym, SYMBOL_TRADE_MODE);
   if(m == SYMBOL_TRADE_MODE_DISABLED)
     {
      why = "symbol trading disabled";
      return false;
     }
   if(m == SYMBOL_TRADE_MODE_CLOSEONLY)
     {
      why = "symbol is close-only";
      return false;
     }
   if(m == SYMBOL_TRADE_MODE_LONGONLY && dir < 0)
     {
      why = "symbol is long-only";
      return false;
     }
   if(m == SYMBOL_TRADE_MODE_SHORTONLY && dir > 0)
     {
      why = "symbol is short-only";
      return false;
     }
   return true;
  }

//--- true when 'now' (server time) is inside one of the symbol's trade sessions.
//--- If the broker defines no sessions for the day the check does not block; the
//--- server return code (MARKET_CLOSED) still protects the order.
bool IsSymbolSessionOpen(const datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   long secs = (long)dt.hour * 3600 + (long)dt.min * 60 + (long)dt.sec;
   datetime from = 0, to = 0;
   bool any = false;
   for(uint i = 0; i < 16; i++)
     {
      if(!SymbolInfoSessionTrade(g_sym, dow, i, from, to))
         break;
      any = true;
      long f = (long)from % 86400;
      long t = (long)to;
      if(t > 86400)
         t = t % 86400;
      if(t == 0 && (long)to > 0)
         t = 86400;
      if(secs >= f && secs < t)
         return true;
     }
   return !any;
  }

bool SessionFilterAllows(const datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   return AfxInWindow(dt.hour * 60 + dt.min, g_sessStartMin, g_sessEndMin);
  }

//+------------------------------------------------------------------+
//| Position / order ownership                                       |
//+------------------------------------------------------------------+
int OwnPositionsOnSymbol(ulong &ticket)
  {
   int n = 0;
   ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_sym)
         continue;
      n++;
      ticket = t;
     }
   return n;
  }

int OwnPositionsAllSymbols()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         n++;
     }
   return n;
  }

bool ForeignPositionOnSymbol()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_sym)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         return true;
     }
   return false;
  }

int OwnPendingOrdersOnSymbol()
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != g_sym)
         continue;
      n++;
     }
   return n;
  }

int FindPosRecord(const ulong posId)
  {
   for(int i = ArraySize(g_posRec) - 1; i >= 0; i--)
      if(g_posRec[i].posId == posId)
         return i;
   return -1;
  }

//--- Registers an executed entry of today. Entries opened while this EA instance runs are
//--- counted +1; entries found in history from before the start only raise the count to the
//--- number of known positions (they may already be included in the persisted counter).
void AddDayPosId(const ulong posId, const datetime openedAt)
  {
   int n = ArraySize(g_dayPosIds);
   for(int i = 0; i < n; i++)
      if(g_dayPosIds[i] == posId)
         return;
   ArrayResize(g_dayPosIds, n + 1);
   g_dayPosIds[n] = posId;
   if(openedAt >= g_sessionStart)
      g_day.entries++;
   else
      if(g_day.entries < n + 1)
         g_day.entries = n + 1;
  }

//+------------------------------------------------------------------+
//| Persistence (terminal global variables, disabled in the tester)  |
//+------------------------------------------------------------------+
string GVKey(const string key)
  {
   string symPart = StringSubstr(g_sym, 0, 12);
   return StringFormat("AFXES_%I64d_%I64u_%s_%s", AccountInfoInteger(ACCOUNT_LOGIN), InpMagicNumber, symPart, key);
  }

void GVSet(const string key, const double value)
  {
   if(!g_persist)
      return;
   GlobalVariableSet(GVKey(key), value);
  }

bool GVGet(const string key, double &value)
  {
   if(!g_persist)
      return false;
   string n = GVKey(key);
   if(!GlobalVariableCheck(n))
      return false;
   value = GlobalVariableGet(n);
   return true;
  }

void PersistState()
  {
   if(!g_persist)
      return;
   GVSet("DAY", (double)g_day.dayStart);
   GVSet("EQ0", g_day.baseEquity);
   GVSet("T0", (double)g_day.baseTime);
   GVSet("CFI", g_day.cfInclusive ? 1.0 : 0.0);
   GVSet("HALT", g_day.halted ? 1.0 : 0.0);
   GVSet("CNT", (double)g_day.entries);
   GVSet("ALR", (double)g_day.alerts);
   GVSet("LTRD", (double)g_lastTradedSignalBar);
   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
//| Daily equity protection                                          |
//+------------------------------------------------------------------+
bool IsExternalCashFlow(const ENUM_DEAL_TYPE ty)
  {
   return (ty == DEAL_TYPE_BALANCE || ty == DEAL_TYPE_CREDIT || ty == DEAL_TYPE_BONUS);
  }

double DailyBaseline()
  {
   return g_day.baseEquity + g_day.cashFlow;
  }

void ResetDayFields(const datetime ds)
  {
   g_day.dayStart    = ds;
   g_day.baseEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_day.baseTime    = AfxNow();
   g_day.cfInclusive = false;
   g_day.cashFlow    = 0.0;
   g_day.halted      = false;
   g_day.haltReason  = "";
   g_day.entries     = 0;
   g_day.alerts      = 0;
   g_day.source      = "SNAPSHOT";
   g_day.lossPct     = 0.0;
   ArrayResize(g_dayPosIds, 0);
  }

//--- First start on a broker day without persisted state: rebuild a defensible baseline.
//--- Candidate A: current equity (snapshot now).
//--- Candidate B: balance + credit - today's realised trading P/L (equity before today's
//---              closed trades, ignoring floating P/L that existed at the day boundary).
//--- The HIGHER candidate is used so that losses already realised today are not forgotten.
void ReconstructBaseline(const datetime now, const datetime ds)
  {
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double credit = AccountInfoDouble(ACCOUNT_CREDIT);
   double tradePnL = 0.0, cf = 0.0;
   bool   histOk = (!g_isTester && HistorySelect(ds, now + 3600));
   if(histOk)
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d == 0)
            continue;
         ENUM_DEAL_TYPE ty = (ENUM_DEAL_TYPE)HistoryDealGetInteger(d, DEAL_TYPE);
         double v = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION) +
                    HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_FEE);
         if(IsExternalCashFlow(ty))
            cf += HistoryDealGetDouble(d, DEAL_PROFIT);
         else
            tradePnL += v;
        }
     }
   double candB = bal + credit - tradePnL;
   if(g_isTester || !histOk || candB <= eq)
     {
      g_day.baseEquity  = eq;
      g_day.baseTime    = now;
      g_day.cfInclusive = false;
      g_day.source      = g_isTester ? "TESTER_START_EQUITY" : "SNAPSHOT_AT_START";
     }
   else
     {
      g_day.baseEquity  = candB - cf;
      g_day.baseTime    = ds;
      g_day.cfInclusive = true;
      g_day.source      = "RECONSTRUCTED_FROM_HISTORY";
     }
  }

void DailyInit()
  {
   datetime now = AfxNow();
   datetime ds  = AfxDayStart(now, InpDayResetHour);
   ResetDayFields(ds);
   bool restored = false;
   double v = 0.0;
   if(GVGet("DAY", v) && (datetime)(long)v == ds)
     {
      double eq0 = 0.0, t0 = 0.0, cfi = 0.0, halt = 0.0, cnt = 0.0, alr = 0.0;
      if(GVGet("EQ0", eq0) && GVGet("T0", t0) && eq0 > 0.0)
        {
         g_day.baseEquity  = eq0;
         g_day.baseTime    = (datetime)(long)t0;
         g_day.cfInclusive = (GVGet("CFI", cfi) && cfi > 0.5);
         g_day.halted      = (GVGet("HALT", halt) && halt > 0.5);
         g_day.entries     = GVGet("CNT", cnt) ? (int)cnt : 0;
         g_day.alerts      = GVGet("ALR", alr) ? (int)alr : 0;
         g_day.source      = "RESTORED_FROM_PERSISTED_STATE";
         if(g_day.halted)
            g_day.haltReason = "daily-loss halt restored from persisted state";
         restored = true;
        }
     }
   if(GVGet("LTRD", v))
      g_lastTradedSignalBar = (datetime)(long)v;
   if(!restored)
      ReconstructBaseline(now, ds);
   g_histDirty = true;
   RefreshHistoryAggregates(true);
   PersistState();
   LogInfo(StringFormat("Daily baseline: %.2f (%s) day start %s, entries today %d, halted %s",
                        DailyBaseline(), g_day.source, TimeToString(ds, TIME_DATE | TIME_MINUTES),
                        g_day.entries, BoolStr(g_day.halted)));
  }

void CheckDayRollover()
  {
   datetime now = AfxNow();
   datetime ds  = AfxDayStart(now, InpDayResetHour);
   if(ds == g_day.dayStart)
      return;
   LogInfo(StringFormat("Broker day closed: entries %d, alerts %d, loss %.2f%%, halted %s",
                        g_day.entries, g_day.alerts, g_day.lossPct, BoolStr(g_day.halted)));
   ResetDayFields(ds);
   g_day.source = "DAY_ROLLOVER_EQUITY";
   g_histDirty = true;
   RefreshHistoryAggregates(true);
   PersistState();
   LogInfo(StringFormat("New broker day %s: baseline equity %.2f", TimeToString(ds, TIME_DATE), g_day.baseEquity));
  }

//--- Rebuild today's external cash flow and executed entry count from deal history.
void RefreshHistoryAggregates(const bool force)
  {
   datetime now = AfxNow();
   if(!force && !g_histDirty && (long)(now - g_lastHistRefresh) < 60)
      return;
   g_lastHistRefresh = now;
   if(!HistorySelect(g_day.dayStart, now + 3600))
     {
      LogWarn("HistorySelect failed - daily counters keep their last known values");
      return;
     }
   double cf = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      datetime dt = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      ENUM_DEAL_TYPE ty = (ENUM_DEAL_TYPE)HistoryDealGetInteger(d, DEAL_TYPE);
      if(IsExternalCashFlow(ty))
        {
         bool inc = g_day.cfInclusive ? (dt >= g_day.baseTime) : (dt > g_day.baseTime);
         if(inc)
            cf += HistoryDealGetDouble(d, DEAL_PROFIT);
         continue;
        }
      if(HistoryDealGetString(d, DEAL_SYMBOL) != g_sym)
         continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagicNumber)
         continue;
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
      if(en != DEAL_ENTRY_IN)
         continue;
      if(dt < g_day.dayStart)
         continue;
      AddDayPosId((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID), dt);
     }
   if(MathAbs(cf - g_day.cashFlow) > 0.005)
      LogInfo(StringFormat("External cash flow today: %.2f -> daily baseline adjusted to %.2f", cf, g_day.baseEquity + cf));
   g_day.cashFlow = cf;
   g_histDirty = false;
  }

void CheckDailyLoss()
  {
   CheckDayRollover();
   RefreshHistoryAggregates(false);
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double base = DailyBaseline();
   if(base <= 0.0)
      return;
   g_day.lossPct = (base - eq) / base * 100.0;
   if(!g_day.halted && g_day.lossPct >= InpMaxDailyLossPercent)
     {
      g_day.halted     = true;
      g_day.haltReason = StringFormat("daily loss %.2f%% >= limit %.2f%% (baseline %.2f, equity %.2f)",
                                      g_day.lossPct, InpMaxDailyLossPercent, base, eq);
      g_dailyLimitActivations++;
      if(StringLen(g_dailyLimitDates) < 2000)
         g_dailyLimitDates += TimeToString(g_day.dayStart, TIME_DATE) + " ";
      LogWarn("DAILY LOSS LIMIT REACHED: " + g_day.haltReason + " -> new entries disabled until the next broker day. Existing SL/TP stay in place.");
      if(InpEnableAlerts && !g_isOptim)
         Alert(AFX_EA_NAME, " ", g_sym, ": daily loss limit reached - new entries disabled");
      PersistState();
     }
   if(g_day.halted && InpEmergencyCloseOnDailyLimit && g_day.lossPct >= InpMaxDailyLossPercent)
      EmergencyCloseOwnPositions();
  }

//+------------------------------------------------------------------+
//| News filter                                                      |
//+------------------------------------------------------------------+
int NewsMinImportance()
  {
   return (InpNewsImportance == AFX_NEWS_HIGH_ONLY) ? 3 : 2;
  }

bool NewsCurrencyWanted(const string cur)
  {
   for(int i = 0; i < ArraySize(g_newsCurr); i++)
      if(g_newsCurr[i] == cur)
         return true;
   return false;
  }

void NewsAdd(const datetime t, const string title)
  {
   int n = ArraySize(g_newsTimes);
   ArrayResize(g_newsTimes, n + 1);
   ArrayResize(g_newsTitles, n + 1);
   g_newsTimes[n]  = t;
   g_newsTitles[n] = title;
  }

void NewsClear()
  {
   ArrayResize(g_newsTimes, 0);
   ArrayResize(g_newsTitles, 0);
  }

void NewsSetStatus(const bool ok, const string status)
  {
   if(status != g_newsStatus || ok != g_newsOk)
     {
      if(ok)
         LogInfo("News filter: " + status);
      else
         LogWarn("News filter: " + status);
     }
   g_newsOk     = ok;
   g_newsStatus = status;
  }

int ImportanceRank(const ENUM_CALENDAR_EVENT_IMPORTANCE i)
  {
   if(i == CALENDAR_IMPORTANCE_HIGH)
      return 3;
   if(i == CALENDAR_IMPORTANCE_MODERATE)
      return 2;
   if(i == CALENDAR_IMPORTANCE_LOW)
      return 1;
   return 0;
  }

bool CalendarEventInfo(const ulong eventId, int &imp, int &tmode, string &name)
  {
   int n = ArraySize(g_evtIds);
   for(int i = 0; i < n; i++)
      if(g_evtIds[i] == eventId)
        {
         imp   = g_evtImp[i];
         tmode = g_evtMode[i];
         name  = g_evtName[i];
         return true;
        }
   MqlCalendarEvent ev;
   if(!CalendarEventById(eventId, ev))
      return false;
   imp   = ImportanceRank(ev.importance);
   tmode = (int)ev.time_mode;
   name  = ev.name;
   ArrayResize(g_evtIds, n + 1);
   ArrayResize(g_evtImp, n + 1);
   ArrayResize(g_evtMode, n + 1);
   ArrayResize(g_evtName, n + 1);
   g_evtIds[n]  = eventId;
   g_evtImp[n]  = imp;
   g_evtMode[n] = tmode;
   g_evtName[n] = name;
   return true;
  }

bool RefreshNewsLive(const bool force)
  {
   datetime now = AfxNow();
   long interval = g_newsOk ? 600 : 60;
   if(!force && (long)(now - g_newsLastRefresh) < interval)
      return g_newsOk;
   g_newsLastRefresh = now;
   if(ArraySize(g_newsCurr) == 0)
     {
      NewsSetStatus(false, "no news currencies configured -> entries blocked");
      return false;
     }
//--- verify that the calendar database is populated around 'now'
   MqlCalendarValue chk[];
   ResetLastError();
   if(!CalendarValueHistory(chk, now - 7 * 86400, now + 7 * 86400, NULL, g_newsCurr[0]))
     {
      NewsSetStatus(false, StringFormat("calendar query failed (err %d) -> entries blocked", GetLastError()));
      return false;
     }
   bool future = false;
   for(int i = 0; i < ArraySize(chk); i++)
      if(chk[i].time > now)
        {
         future = true;
         break;
        }
   if(ArraySize(chk) == 0 || !future)
     {
      NewsSetStatus(false, "calendar data empty or stale (no upcoming " + g_newsCurr[0] + " events) -> entries blocked");
      return false;
     }
//--- collect relevant events
   NewsClear();
   int minImp = NewsMinImportance();
   datetime from = now - (InpNewsBlockAfterMinutes + 60) * 60;
   datetime to   = now + 2 * 86400;
   for(int c = 0; c < ArraySize(g_newsCurr); c++)
     {
      MqlCalendarValue vals[];
      ResetLastError();
      if(!CalendarValueHistory(vals, from, to, NULL, g_newsCurr[c]))
        {
         NewsSetStatus(false, StringFormat("calendar query for %s failed (err %d) -> entries blocked", g_newsCurr[c], GetLastError()));
         return false;
        }
      for(int i = 0; i < ArraySize(vals); i++)
        {
         int imp = 0, tmode = 0;
         string name = "";
         if(!CalendarEventInfo(vals[i].event_id, imp, tmode, name))
            continue;
         if(imp < minImp || tmode != (int)CALENDAR_TIMEMODE_DATETIME)
            continue;
         NewsAdd(vals[i].time, g_newsCurr[c] + " " + name);
        }
     }
   NewsSetStatus(true, StringFormat("LIVE calendar OK, %d relevant events in window", ArraySize(g_newsTimes)));
   return true;
  }

bool LoadNewsCsv()
  {
   NewsClear();
   g_newsCovFrom = 0;
   g_newsCovTo   = 0;
   ResetLastError();
   int h = FileOpen(InpNewsCsvFile, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      NewsSetStatus(false, "TESTER: news CSV '" + InpNewsCsvFile + "' not found in Common\\Files -> ALL entries blocked. " +
                    "Provide the dataset, or set EnableNewsFilter=false and report that limitation.");
      return false;
     }
   int minImp = NewsMinImportance();
   datetime minT = 0, maxT = 0;
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(StringFind(line, "# coverage_from=") == 0)
        {
         g_newsCovFrom = StringToTime(StringSubstr(line, 16));
         continue;
        }
      if(StringFind(line, "# coverage_to=") == 0)
        {
         g_newsCovTo = StringToTime(StringSubstr(line, 14));
         continue;
        }
      datetime t = 0;
      string cur = "", title = "";
      int imp = 0;
      if(!AfxParseNewsLine(line, t, cur, imp, title))
         continue;
      if(!NewsCurrencyWanted(cur) || imp < minImp)
         continue;
      NewsAdd(t, cur + " " + title);
      if(minT == 0 || t < minT)
         minT = t;
      if(t > maxT)
         maxT = t;
     }
   FileClose(h);
   if(g_newsCovFrom == 0 || g_newsCovTo == 0)
     {
      if(ArraySize(g_newsTimes) == 0)
        {
         NewsSetStatus(false, "TESTER: news CSV has no matching events and no coverage header -> ALL entries blocked");
         return false;
        }
      g_newsCovFrom = minT - 3 * 86400;
      g_newsCovTo   = maxT + 3 * 86400;
     }
   NewsSetStatus(true, StringFormat("TESTER CSV OK: %d events, coverage %s - %s", ArraySize(g_newsTimes),
                                    TimeToString(g_newsCovFrom, TIME_DATE), TimeToString(g_newsCovTo, TIME_DATE)));
   g_newsBaseStatus = g_newsStatus;
   return true;
  }

void ExportNewsCsv(const int days)
  {
   datetime now  = AfxNow();
   datetime from = now - days * 86400;
   datetime to   = now + 7 * 86400;
   int h = FileOpen(InpNewsCsvFile, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      LogWarn(StringFormat("News export: cannot create '%s' (err %d)", InpNewsCsvFile, GetLastError()));
      return;
     }
   FileWriteString(h, "# ALB FOREX EMA Scalper news dataset - times are broker SERVER time\r\n");
   FileWriteString(h, "# exported " + TimeToString(now, TIME_DATE | TIME_MINUTES) + " from the MT5 economic calendar\r\n");
   FileWriteString(h, "# coverage_from=" + TimeToString(from, TIME_DATE | TIME_MINUTES) + "\r\n");
   FileWriteString(h, "# coverage_to=" + TimeToString(to, TIME_DATE | TIME_MINUTES) + "\r\n");
   FileWriteString(h, "# time,currency,importance,title\r\n");
   int written = 0;
   for(int c = 0; c < ArraySize(g_newsCurr); c++)
     {
      MqlCalendarValue vals[];
      if(!CalendarValueHistory(vals, from, to, NULL, g_newsCurr[c]))
        {
         LogWarn(StringFormat("News export: calendar query for %s failed (err %d)", g_newsCurr[c], GetLastError()));
         continue;
        }
      for(int i = 0; i < ArraySize(vals); i++)
        {
         int imp = 0, tmode = 0;
         string name = "";
         if(!CalendarEventInfo(vals[i].event_id, imp, tmode, name))
            continue;
         if(imp < 2 || tmode != (int)CALENDAR_TIMEMODE_DATETIME)
            continue;
         StringReplace(name, ",", " ");
         StringReplace(name, ";", " ");
         FileWriteString(h, TimeToString(vals[i].time, TIME_DATE | TIME_MINUTES) + "," + g_newsCurr[c] + "," +
                         (imp >= 3 ? "HIGH" : "MEDIUM") + "," + name + "\r\n");
         written++;
        }
     }
   FileClose(h);
   LogInfo(StringFormat("News export: %d medium/high events written to Common\\Files\\%s", written, InpNewsCsvFile));
  }

bool NewsInit()
  {
   ArrayResize(g_newsCurr, 0);
   string parts[];
   int n = StringSplit(InpNewsCurrencies, ',', parts);
   for(int i = 0; i < n; i++)
     {
      string c = parts[i];
      StringTrimLeft(c);
      StringTrimRight(c);
      StringToUpper(c);
      if(StringLen(c) != 3)
         continue;
      int k = ArraySize(g_newsCurr);
      ArrayResize(g_newsCurr, k + 1);
      g_newsCurr[k] = c;
     }
   if(!g_isTester && InpNewsExportDays > 0 && ArraySize(g_newsCurr) > 0)
      ExportNewsCsv(InpNewsExportDays);
   if(!InpEnableNewsFilter)
     {
      g_newsOk     = false;
      g_newsStatus = "DISABLED by input";
      return true;
     }
   if(ArraySize(g_newsCurr) == 0)
     {
      NewsSetStatus(false, "no valid news currencies configured -> entries blocked");
      return false;
     }
   if(g_isTester)
      return LoadNewsCsv();
   return RefreshNewsLive(true);
  }

//--- false = data not verified (caller must fail closed)
bool NewsCheck(const datetime now, bool &blocked, string &evt)
  {
   blocked = false;
   evt     = "";
   if(!g_isTester)
      RefreshNewsLive(false);
   if(!g_newsOk)
      return false;
   if(g_isTester)
     {
      if(now < g_newsCovFrom || now > g_newsCovTo)
        {
         g_newsStatus = "TESTER CSV does not cover " + TimeToString(now, TIME_DATE) + " -> entries blocked";
         return false;
        }
      g_newsStatus = g_newsBaseStatus;
     }
   for(int i = 0; i < ArraySize(g_newsTimes); i++)
      if(AfxNewsWindowHit(now, g_newsTimes[i], InpNewsBlockBeforeMinutes, InpNewsBlockAfterMinutes))
        {
         blocked = true;
         evt = g_newsTitles[i] + " @ " + TimeToString(g_newsTimes[i], TIME_DATE | TIME_MINUTES);
         return true;
        }
   return true;
  }

//+------------------------------------------------------------------+
//| Market data helpers                                              |
//+------------------------------------------------------------------+
bool IndicatorsReady(string &why)
  {
   int bE = Bars(g_sym, InpEntryTF);
   int bT = Bars(g_sym, InpTrendTF);
   int needE = IMax(IMax(InpSwingLookback + InpSwingLeftBars + 3, InpSlowEMA * 5), IMax(InpATRPeriod * 3, 60));
   int needT = IMax(InpSlowEMA * 5 + InpSlopeBars, IMax(InpATRPeriod * 3, 60));
   if(bE < needE || bT < needT)
     {
      why = StringFormat("insufficient history: entry TF %d/%d bars, trend TF %d/%d bars", bE, needE, bT, needT);
      return false;
     }
   int hs[6];
   hs[0] = g_hFastE; hs[1] = g_hSlowE; hs[2] = g_hAtrE;
   hs[3] = g_hFastT; hs[4] = g_hSlowT; hs[5] = g_hAtrT;
   for(int i = 0; i < 6; i++)
     {
      int bars = (i < 3) ? bE : bT;
      int bc = BarsCalculated(hs[i]);
      if(bc < bars)
        {
         why = StringFormat("indicator %d not calculated yet (%d/%d)", i, bc, bars);
         return false;
        }
     }
   return true;
  }

//--- Shift of the latest trend-TF bar that is CLOSED at evalTime (start of the forming
//--- entry-TF bar). Fails when the trend-TF series has not rolled forward yet.
bool TrendClosedShift(const datetime evalTime, int &shift, string &why)
  {
   int per = PeriodSeconds(InpTrendTF);
   datetime t0 = iTime(g_sym, InpTrendTF, 0);
   if(t0 == 0)
     {
      why = "trend TF series empty";
      return false;
     }
   if((long)t0 + per <= (long)evalTime)
     {
      why = "trend TF series has not rolled to the current bar yet";
      return false;
     }
   int s = iBarShift(g_sym, InpTrendTF, evalTime - 1, false);
   if(s < 0)
     {
      why = "iBarShift(trend TF) failed";
      return false;
     }
   datetime ts = iTime(g_sym, InpTrendTF, s);
   if((long)ts + per > (long)evalTime)
      s++;
   if(s < 1)
     {
      why = "no closed trend TF bar available";
      return false;
     }
   shift = s;
   return true;
  }

double LatestClosedEntryATR()
  {
   double a[];
   ArraySetAsSeries(a, true);
   if(CopyBuffer(g_hAtrE, 0, 1, 1, a) != 1 || !ValidValue(a[0]))
      return 0.0;
   return a[0];
  }

//+------------------------------------------------------------------+
//| Signal construction                                              |
//+------------------------------------------------------------------+
int CheckGates(AfxSignal &s, const datetime now)
  {
   string why = "";
   if(InpEnableSessionFilter && !SessionFilterAllows(now))
      return Rej(s, RJ_SESSION_FILTER, "outside " + InpSessionStart + "-" + InpSessionEnd + " server time");
   if(!IsSymbolSessionOpen(now))
      return Rej(s, RJ_MARKET_CLOSED, "outside the symbol trade session");
   if(!DirectionAllowed(s.dir, why))
      return Rej(s, RJ_DIRECTION_NOT_ALLOWED, why);
   if(InpEnableNewsFilter)
     {
      bool   blocked = false;
      string evt     = "";
      if(!NewsCheck(now, blocked, evt))
         return Rej(s, RJ_NEWS_UNVERIFIED, g_newsStatus);
      if(blocked)
         return Rej(s, RJ_NEWS_BLOCK, evt);
     }
   if(g_day.halted)
      return Rej(s, RJ_DAILY_LOSS_HALT, g_day.haltReason);
   RefreshHistoryAggregates(true);
   int used = g_execAllowed ? g_day.entries : g_day.alerts;
   if(InpMaxTradesPerDay > 0 && used >= InpMaxTradesPerDay)
      return Rej(s, RJ_MAX_TRADES_DAY, StringFormat("%d of %d used today", used, InpMaxTradesPerDay));
   if(g_pendVerify)
      return Rej(s, RJ_FILL_UNRECONCILED, StringFormat("order #%I64u still being reconciled", g_pendOrder));
   ulong tk = 0;
   if(OwnPositionsOnSymbol(tk) > 0)
      return Rej(s, RJ_POSITION_OPEN, StringFormat("EA position #%I64u already open", tk));
   if(OwnPositionsAllSymbols() >= InpMaxOpenPositions)
      return Rej(s, RJ_MAX_OPEN_POSITIONS, StringFormat("%d EA positions open (max %d)", OwnPositionsAllSymbols(), InpMaxOpenPositions));
   if(!g_isHedging && ForeignPositionOnSymbol())
      return Rej(s, RJ_FOREIGN_NETTING_POSITION, "netting account: manual/other-EA position on this symbol - not interfering");
   if(OwnPendingOrdersOnSymbol() > 0)
      return Rej(s, RJ_PENDING_ORDER_EXISTS, "EA pending order exists on this symbol");
   if(s.signalBarTime <= g_lastTradedSignalBar)
      return Rej(s, RJ_DUPLICATE_SIGNAL, "signal candle " + TimeToString(s.signalBarTime, TIME_DATE | TIME_MINUTES) + " already acted on");
   if(g_execAllowed && !TradingPermitted(why))
      return Rej(s, RJ_TRADING_NOT_PERMITTED, why);
   return RJ_NONE;
  }

//--- position size from the structural stop. Includes estimated slippage (both sides)
//--- and round-trip commission. Never rounds volume up.
int CalcVolume(AfxSignal &s)
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   s.riskBudget = eq * InpRiskPercent / 100.0;
   ENUM_ORDER_TYPE ot = (s.dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double slip  = (double)InpEstimatedSlippagePoints * g_point;
   double eAdv  = (s.dir > 0) ? s.entry + slip : s.entry - slip;
   double slAdv = (s.dir > 0) ? s.sl - slip : s.sl + slip;
   double pnl   = 0.0;
   if(!OrderCalcProfit(ot, g_sym, 1.0, eAdv, slAdv, pnl) || pnl >= 0.0)
     {
      double tv = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tv <= 0.0)
         tv = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_VALUE);
      if(tv <= 0.0 || g_tick <= 0.0)
         return Rej(s, RJ_RISK_CALC_FAILED, StringFormat("OrderCalcProfit failed (err %d) and no tick value", GetLastError()));
      pnl = -(MathAbs(eAdv - slAdv) / g_tick) * tv;
      LogWarn("OrderCalcProfit unavailable - using tick-value fallback for risk calculation");
     }
   s.lossPerLot = MathAbs(pnl) + MathMax(0.0, InpEstimatedCommissionPerLot);
   double vmax = g_volMax;
   if(InpMaxLots > 0.0)
      vmax = MathMin(vmax, InpMaxLots);
   double vlimit = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_LIMIT);
   if(vlimit > 0.0)
      vmax = MathMin(vmax, vlimit);
   s.volume = AfxVolumeForRisk(s.riskBudget, s.lossPerLot, g_volStep, g_volMin, vmax);
   if(s.volume <= 0.0)
      return Rej(s, RJ_MIN_LOT_EXCEEDS_RISK, StringFormat("min lot %.2f would lose %.2f > budget %.2f (loss/lot %.2f)",
                 g_volMin, g_volMin * s.lossPerLot, s.riskBudget, s.lossPerLot));
   s.volume      = NormalizeDouble(s.volume, g_volDigits);
   s.plannedLoss = s.volume * s.lossPerLot;

   if(InpCheckDailyBudgetBeforeEntry)
     {
      double base     = DailyBaseline();
      double limitAmt = base * InpMaxDailyLossPercent / 100.0;
      double lossNow  = MathMax(0.0, base - eq);
      if(lossNow + s.plannedLoss > limitAmt + 1e-6)
         return Rej(s, RJ_DAILY_RISK_BUDGET, StringFormat("today's loss %.2f + planned %.2f > daily limit %.2f",
                    lossNow, s.plannedLoss, limitAmt));
     }

   double m = 0.0;
   if(!OrderCalcMargin(ot, g_sym, s.volume, s.entry, m))
      return Rej(s, RJ_MARGIN, StringFormat("OrderCalcMargin failed (err %d)", GetLastError()));
   s.margin = m;
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(m > fm * InpMaxMarginUsagePercent / 100.0)
      return Rej(s, RJ_MARGIN, StringFormat("margin %.2f > %.0f%% of free margin %.2f", m, InpMaxMarginUsagePercent, fm));
   return RJ_NONE;
  }

//--- quote-dependent part of the order: entry, SL, TP, spread, drift, volume.
//--- Re-run on every send attempt so a requote is validated from scratch.
int BuildOrderLevels(AfxSignal &s)
  {
   MqlTick tk;
   if(!SymbolInfoTick(g_sym, tk))
      return Rej(s, RJ_QUOTE_INVALID, StringFormat("SymbolInfoTick failed (err %d)", GetLastError()));
   if(tk.bid <= 0.0 || tk.ask <= 0.0 || tk.ask < tk.bid)
      return Rej(s, RJ_QUOTE_INVALID, StringFormat("invalid quote bid=%s ask=%s", Px(tk.bid), Px(tk.ask)));
   datetime now = AfxNow();
   if(InpMaxQuoteAgeSeconds > 0 && (long)(now - tk.time) > InpMaxQuoteAgeSeconds)
      return Rej(s, RJ_QUOTE_STALE, StringFormat("last quote is %I64d s old", (long)(now - tk.time)));

   s.bid = tk.bid;
   s.ask = tk.ask;
   double spread = tk.ask - tk.bid;
   s.spreadPts = spread / g_point;
   s.entry     = (s.dir > 0) ? tk.ask : tk.bid;

//--- stop: structural swing (PULLBACK) or ATR distance from the trigger price (CROSSOVER).
//--- The ATR stop is measured from Bid for BUY (BUY SL triggers on Bid) and from Ask for SELL,
//--- so BUY and SELL carry the same spread cost.
   bool   atrStop = (InpEntryMode == AFX_ENTRY_CROSSOVER);
   double buffer  = (double)InpStopBufferPoints * g_point + InpStopBufferATR * s.atrEntry;
   double slRaw   = 0.0;
   if(s.dir > 0)
     {
      slRaw = atrStop ? tk.bid - InpCrossSLATR * s.atrEntry : s.swingPrice - buffer;
      s.sl  = AfxRoundDown(slRaw, g_tick, g_digits);
      if(!(s.sl < tk.bid))
         return Rej(s, RJ_SL_WRONG_SIDE, StringFormat("BUY SL %s not below bid %s", Px(s.sl), Px(tk.bid)));
     }
   else
     {
      slRaw = atrStop ? tk.ask + InpCrossSLATR * s.atrEntry : s.swingPrice + buffer + (InpAddSpreadToSellStop ? spread : 0.0);
      s.sl  = AfxRoundUp(slRaw, g_tick, g_digits);
      if(!(s.sl > tk.ask))
         return Rej(s, RJ_SL_WRONG_SIDE, StringFormat("SELL SL %s not above ask %s", Px(s.sl), Px(tk.ask)));
     }
   s.slDist = MathAbs(s.entry - s.sl);
   double minDist = MathMax(InpMinStopATR * s.atrEntry, (double)InpMinStopPoints * g_point);
   if(s.slDist < minDist)
      return Rej(s, RJ_SL_TOO_CLOSE, StringFormat("SL distance %.0f pts < minimum %.0f pts", s.slDist / g_point, minDist / g_point));
   if(InpMaxStopATR > 0.0 && s.slDist > InpMaxStopATR * s.atrEntry)
      return Rej(s, RJ_SL_TOO_FAR, StringFormat("SL distance %.0f pts > maximum %.0f pts", s.slDist / g_point, InpMaxStopATR * s.atrEntry / g_point));

//--- spread filters
   if(InpEnableSpreadFilter)
     {
      if(InpMaxSpreadPoints > 0 && s.spreadPts > (double)InpMaxSpreadPoints)
         return Rej(s, RJ_SPREAD_ABSOLUTE, StringFormat("spread %.0f pts > max %d pts", s.spreadPts, InpMaxSpreadPoints));
      if(InpMaxSpreadToStopRatio > 0.0 && !AfxSpreadOk(spread, s.slDist, InpMaxSpreadToStopRatio))
         return Rej(s, RJ_SPREAD_TO_STOP, StringFormat("spread %.0f pts > %.2f x SL %.0f pts", s.spreadPts, InpMaxSpreadToStopRatio, s.slDist / g_point));
     }

//--- entry drift versus the confirmed signal close. Chart candles are Bid prices, so by
//--- default drift is measured on the Bid for BOTH directions: it then measures price
//--- movement only. Measuring a BUY on the Ask would add the spread to BUY drift only.
   double driftPx = InpDriftExcludesSpread ? tk.bid : s.entry;
   s.driftATR = AfxDriftATR(driftPx, s.sigClose, s.atrEntry);
   if(InpEnableEntryDriftFilter && s.driftATR > InpMaxEntryDriftATR)
      return Rej(s, RJ_ENTRY_DRIFT, StringFormat("%s %s vs signal close %s = %.2f ATR > %.2f ATR",
                 InpDriftExcludesSpread ? "bid" : "quote", Px(driftPx), Px(s.sigClose), s.driftATR, InpMaxEntryDriftATR));

//--- take profit (rounded away from entry so R:R is not reduced by normalisation)
   double tpRaw = AfxTakeProfit(s.dir, s.entry, s.sl, InpRewardRisk);
   s.tp = (s.dir > 0) ? AfxRoundUp(tpRaw, g_tick, g_digits) : AfxRoundDown(tpRaw, g_tick, g_digits);
   s.rrActual = (s.slDist > 0.0) ? MathAbs(s.tp - s.entry) / s.slDist : 0.0;
   if(s.rrActual < InpRewardRisk - AFX_RR_TOLERANCE)
      return Rej(s, RJ_RR_AFTER_NORMALIZATION, StringFormat("R:R %.3f after normalisation < %.2f", s.rrActual, InpRewardRisk));

//--- broker minimum stop distance (SL/TP are checked against the price that triggers them)
   double stopsLvl = (double)SymbolInfoInteger(g_sym, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   if(s.dir > 0)
     {
      if(tk.bid - s.sl < stopsLvl || s.tp - tk.bid < stopsLvl)
         return Rej(s, RJ_STOPS_LEVEL, StringFormat("stops level %.0f pts violated", stopsLvl / g_point));
     }
   else
     {
      if(s.sl - tk.ask < stopsLvl || tk.ask - s.tp < stopsLvl)
         return Rej(s, RJ_STOPS_LEVEL, StringFormat("stops level %.0f pts violated", stopsLvl / g_point));
     }

   return CalcVolume(s);
  }

int BuildSignal(const datetime evalTime, AfxSignal &s)
  {
   ZeroMemory(s);
   s.evalTime   = evalTime;
   s.reject     = RJ_NONE;
   s.swingShift = -1;
   datetime now = AfxNow();
   string   why = "";

   if(!IndicatorsReady(why))
      return Rej(s, RJ_DATA_NOT_READY, why);

   int need = IMax(InpSwingLookback + InpSwingLeftBars + 2, 4);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(g_sym, InpEntryTF, 0, need, r);
   if(got < need)
      return Rej(s, RJ_DATA_NOT_READY, StringFormat("CopyRates returned %d of %d bars (err %d)", got, need, GetLastError()));
   if(r[0].time != evalTime)
      return Rej(s, RJ_DATA_NOT_READY, "entry TF bar 0 does not match the evaluated bar");

   bool modeB = (InpConfirmationMode == AFX_CONFIRM_NEXT_CANDLE);
   long per   = (long)PeriodSeconds(InpEntryTF);
   s.signalBarTime = r[1].time;
   s.touchBarTime  = modeB ? r[2].time : r[1].time;
   s.sigOpen  = r[1].open;
   s.sigHigh  = r[1].high;
   s.sigLow   = r[1].low;
   s.sigClose = r[1].close;

   long delay = (long)(now - evalTime);
   if(delay > (long)InpMaxSignalDelaySeconds)
      return Rej(s, RJ_STALE_SIGNAL, StringFormat("evaluated %I64d s after bar open (max %d s)", delay, InpMaxSignalDelaySeconds));
   if(InpRejectAfterBarGap)
     {
      if((long)(r[0].time - r[1].time) != per)
         return Rej(s, RJ_STALE_SIGNAL, "signal candle not contiguous with the current bar (market gap)");
      if(modeB && (long)(r[1].time - r[2].time) != per)
         return Rej(s, RJ_STALE_SIGNAL, "touch and confirmation candles not contiguous (market gap)");
     }

//--- entry timeframe indicators (index 0 = forming bar, never used for decisions)
   double ef[], es[], ae[];
   ArraySetAsSeries(ef, true);
   ArraySetAsSeries(es, true);
   ArraySetAsSeries(ae, true);
   if(CopyBuffer(g_hFastE, 0, 0, 3, ef) != 3 || CopyBuffer(g_hSlowE, 0, 0, 3, es) != 3 || CopyBuffer(g_hAtrE, 0, 1, 1, ae) != 1)
      return Rej(s, RJ_DATA_NOT_READY, StringFormat("CopyBuffer (entry TF) failed (err %d)", GetLastError()));
   if(!ValidValue(ef[1]) || !ValidValue(es[1]) || !ValidValue(ef[2]) || !ValidValue(es[2]) || !ValidValue(ae[0]))
      return Rej(s, RJ_DATA_NOT_READY, "invalid entry TF indicator values");
   s.emaFastM1 = ef[1];
   s.emaSlowM1 = es[1];
   s.atrEntry  = ae[0];
   int bi = modeB ? 2 : 1;
   s.bandLow  = MathMin(ef[bi], es[bi]);
   s.bandHigh = MathMax(ef[bi], es[bi]);

//--- trend timeframe (latest CLOSED bar only)
   int tShift = 0;
   if(!TrendClosedShift(evalTime, tShift, why))
      return Rej(s, RJ_TREND_NOT_SYNCED, why);
   int nT = InpSlopeBars + 1;
   double tf[], ts[], at[];
   ArraySetAsSeries(tf, true);
   ArraySetAsSeries(ts, true);
   ArraySetAsSeries(at, true);
   if(CopyBuffer(g_hFastT, 0, tShift, 1, tf) != 1 || CopyBuffer(g_hSlowT, 0, tShift, nT, ts) != nT || CopyBuffer(g_hAtrT, 0, tShift, 1, at) != 1)
      return Rej(s, RJ_DATA_NOT_READY, StringFormat("CopyBuffer (trend TF) failed (err %d)", GetLastError()));
   if(!ValidValue(tf[0]) || !ValidValue(ts[0]) || !ValidValue(ts[nT - 1]) || !ValidValue(at[0]))
      return Rej(s, RJ_DATA_NOT_READY, "invalid trend TF indicator values");
   s.trendBarTime = iTime(g_sym, InpTrendTF, tShift);
   s.emaFastTrend = tf[0];
   s.emaSlowTrend = ts[0];
   s.atrTrend     = at[0];
   s.sepATR       = MathAbs(tf[0] - ts[0]) / at[0];
   s.slopeATR     = (ts[0] - ts[nT - 1]) / at[0];
   int trendDir   = AfxTrendDir(tf[0], ts[0]);
   g_lastTrendDir = trendDir;
   bool crossMode = (InpEntryMode == AFX_ENTRY_CROSSOVER);

//--- candle arrays (index = shift)
   double o[], h[], l[], c[];
   ArrayResize(o, need);
   ArrayResize(h, need);
   ArrayResize(l, need);
   ArrayResize(c, need);
   for(int i = 0; i < need; i++)
     {
      o[i] = r[i].open;
      h[i] = r[i].high;
      l[i] = r[i].low;
      c[i] = r[i].close;
     }
   if(crossMode)
     {
      //--- CROSSOVER: every closed-bar EMA fast/slow cross on the entry TF is a signal
      int cd = AfxCrossDirection(ef[1], es[1], ef[2], es[2]);
      if(cd == 0)
         return Rej(s, RJ_NO_CROSS, "no EMA cross on the last closed bar");
      s.dir     = cd;
      s.isSetup = true;
      //--- exit rule: the opposite cross closes an open position, whatever the entry filters say
      if(InpCrossCloseOnOpposite)
         CloseOppositeOnCross(cd);
      if(InpCrossUseTrendFilter && trendDir != cd)
         return Rej(s, RJ_TREND_MISMATCH, StringFormat("%s cross but %s trend is %s", DirName(cd), EnumToString(InpTrendTF), DirName(trendDir)));
      s.patternOk = true;
     }
   else
     {
   s.dir = trendDir;
   if(s.dir == 0)
      return Rej(s, RJ_NO_TREND, "trend TF EMA fast == EMA slow");
   int pr = AfxEvaluatePattern((int)InpConfirmationMode, s.dir, o, h, l, c, ef, es,
                               InpModeBInvalidateOnCloseThrough, InpRequireM1EMAAlignment);
   s.isSetup = (pr != RJ_NO_TOUCH);
   if(pr != RJ_NONE)
     {
      string d = "";
      if(pr == RJ_NO_TOUCH)
         d = StringFormat("candle [%s..%s] does not touch band [%s..%s]", Px(l[bi]), Px(h[bi]), Px(s.bandLow), Px(s.bandHigh));
      else
         if(pr == RJ_CANDLE_DIRECTION)
            d = StringFormat("confirmation candle O=%s C=%s not %s", Px(o[1]), Px(c[1]), s.dir > 0 ? "bullish" : "bearish");
         else
            if(pr == RJ_CLOSE_VS_EMA8)
               d = StringFormat("close %s not %s EMA%d %s", Px(c[1]), s.dir > 0 ? "above" : "below", InpFastEMA, Px(ef[1]));
            else
               if(pr == RJ_SETUP_INVALIDATED)
                  d = StringFormat("touch candle closed %s through the band", Px(c[2]));
               else
                  if(pr == RJ_M1_ALIGNMENT)
                     d = StringFormat("entry TF EMA%d %s vs EMA%d %s not aligned", InpFastEMA, Px(ef[1]), InpSlowEMA, Px(es[1]));
      return Rej(s, pr, d);
     }
   s.patternOk = true;
     }

//--- flat EMA filter (trend timeframe, ATR-normalised)
   if(InpEnableFlatEMAFilter)
     {
      double sep = 0.0, slope = 0.0;
      int fr = AfxFlatFilter(s.dir, tf[0], ts[0], ts[0], ts[nT - 1], at[0],
                             InpUseSeparationCheck, InpMinimumEMASeparationATR,
                             InpUseSlopeCheck, InpMinimumEMASlopeATR, sep, slope);
      if(fr != RJ_NONE)
         return Rej(s, fr, StringFormat("separation %.3f ATR (min %.3f), slope %.3f ATR (min %.3f)",
                                        sep, InpMinimumEMASeparationATR, slope, InpMinimumEMASlopeATR));
     }

//--- risk / state / environment gates
   int gr = CheckGates(s, now);
   if(gr != RJ_NONE)
      return gr;

//--- structural swing (PULLBACK only; CROSSOVER uses an ATR stop)
   if(!crossMode)
     {
      double sp = 0.0;
      int sh = AfxFindSwing(h, l, need, s.dir > 0, InpSwingLeftBars, InpSwingRightBars,
                            InpSwingLookback, InpSwingRequireUnbroken, sp);
      if(sh < 0)
         return Rej(s, RJ_NO_SWING, StringFormat("no confirmed %s in the last %d closed bars", s.dir > 0 ? "swing low" : "swing high", InpSwingLookback));
      s.swingShift = sh;
      s.swingPrice = sp;
     }

   return BuildOrderLevels(s);
  }

//+------------------------------------------------------------------+
//| Execution                                                        |
//+------------------------------------------------------------------+
//--- CROSSOVER exit rule: close this EA's position on this symbol that points against newDir.
void CloseOppositeOnCross(const int newDir)
  {
   if(!g_execAllowed)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != g_sym)
         continue;
      int pdir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(pdir == -newDir)
         ClosePositionByTicket(t, "OPPOSITE CROSS");
     }
  }

string ModeTag()
  {
   if(InpEntryMode == AFX_ENTRY_CROSSOVER)
      return "X";
   return (InpConfirmationMode == AFX_CONFIRM_NEXT_CANDLE) ? "B" : "A";
  }

string BuildComment(const AfxSignal &s)
  {
   string c = StringFormat("%s %s %s", InpOrderComment, s.dir > 0 ? "B" : "S",
                           "M" + ModeTag());
   return StringSubstr(c, 0, 31);
  }

bool ModifySLTP(const ulong ticket, const double sl, const double tp, const string why)
  {
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = g_sym;
   req.sl       = sl;
   req.tp       = tp;
   req.magic    = InpMagicNumber;
   ResetLastError();
   bool ok = OrderSend(req, res);
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_NO_CHANGES)
     {
      LogInfo(StringFormat("Position #%I64u modified (%s): SL=%s TP=%s", ticket, why, Px(sl), Px(tp)));
      return true;
     }
   LogWarn(StringFormat("Modify #%I64u (%s) failed: ok=%s retcode=%u %s err=%d", ticket, why, BoolStr(ok), res.retcode, res.comment, GetLastError()));
   return false;
  }

bool ClosePositionByTicket(const ulong ticket, const string why)
  {
   if(!PositionSelectByTicket(ticket))
      return false;
   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double vol = PositionGetDouble(POSITION_VOLUME);
   MqlTick tk;
   if(!SymbolInfoTick(g_sym, tk))
      return false;
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action       = TRADE_ACTION_DEAL;
   req.position     = ticket;
   req.symbol       = g_sym;
   req.volume       = vol;
   req.type         = (pt == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price        = (pt == POSITION_TYPE_BUY) ? tk.bid : tk.ask;
   req.deviation    = (ulong)IMax(0, InpMaxDeviationPoints);
   req.magic        = InpMagicNumber;
   req.type_filling = g_filling;
   req.type_time    = ORDER_TIME_GTC;
   req.comment      = StringSubstr("AFX " + why, 0, 31);
   ResetLastError();
   bool ok = OrderSend(req, res);
   if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL)
     {
      LogWarn(StringFormat("Position #%I64u closed (%s) at %s", ticket, why, Px(res.price)));
      return true;
     }
   LogErr(StringFormat("Close #%I64u (%s) failed: ok=%s retcode=%u %s err=%d", ticket, why, BoolStr(ok), res.retcode, res.comment, GetLastError()));
   return false;
  }

void CancelOwnPendingOrders(const string why)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber || OrderGetString(ORDER_SYMBOL) != g_sym)
         continue;
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_REMOVE;
      req.order  = t;
      if(OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE)
         LogWarn(StringFormat("Order #%I64u cancelled (%s)", t, why));
      else
         LogErr(StringFormat("Cancel order #%I64u failed retcode=%u", t, res.retcode));
     }
  }

void EmergencyCloseOwnPositions()
  {
   if(!g_execAllowed)
      return;
   datetime now = AfxNow();
   if((long)(now - g_lastEmergencyTry) < 2)
      return;
   g_lastEmergencyTry = now;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != g_sym)
         continue;
      if(ClosePositionByTicket(t, "DAILY LIMIT"))
         g_emergencyCloses++;
     }
  }

//--- True when SL/TP may be modified now (freeze level) and new levels respect stops level.
bool ModifyAllowed(const int dir, const double newSL, const double newTP, const double curSL, const double curTP, string &why)
  {
   MqlTick tk;
   if(!SymbolInfoTick(g_sym, tk))
     {
      why = "no quote";
      return false;
     }
   double stopsLvl = (double)SymbolInfoInteger(g_sym, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   double freeze   = (double)SymbolInfoInteger(g_sym, SYMBOL_TRADE_FREEZE_LEVEL) * g_point;
   double px = (dir > 0) ? tk.bid : tk.ask;
   if(freeze > 0.0)
     {
      if(curSL > 0.0 && MathAbs(px - curSL) <= freeze)
        {
         why = "SL inside freeze level";
         return false;
        }
      if(curTP > 0.0 && MathAbs(px - curTP) <= freeze)
        {
         why = "TP inside freeze level";
         return false;
        }
     }
   if(dir > 0)
     {
      if(newSL > 0.0 && (newSL >= px || px - newSL < stopsLvl))
        {
         why = "new SL violates stops level";
         return false;
        }
      if(newTP > 0.0 && (newTP <= px || newTP - px < stopsLvl))
        {
         why = "new TP violates stops level";
         return false;
        }
     }
   else
     {
      if(newSL > 0.0 && (newSL <= px || newSL - px < stopsLvl))
        {
         why = "new SL violates stops level";
         return false;
        }
      if(newTP > 0.0 && (newTP >= px || px - newTP < stopsLvl))
        {
         why = "new TP violates stops level";
         return false;
        }
     }
   return true;
  }

//--- Confirms the order produced a protected position and records its planned risk.
void VerifyPendingFill()
  {
   if(!g_pendVerify)
      return;
   ulong tk = 0;
   if(OwnPositionsOnSymbol(tk) > 0 && PositionSelectByTicket(tk))
     {
      ulong  posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      datetime ot  = (datetime)PositionGetInteger(POSITION_TIME);
      int dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      g_pendVerify = false;
      if(FindPosRecord(posId) >= 0)
         return;
      g_ordersFilled++;
      AddDayPosId(posId, ot);

      //--- never keep an unprotected position
      if(sl <= 0.0)
        {
         LogErr(StringFormat("Position #%I64u has NO stop-loss after fill - attempting to attach it", tk));
         if(!ModifySLTP(tk, g_pendSig.sl, g_pendSig.tp, "attach missing stops"))
           {
            LogErr("Could not attach stops - closing the unprotected position");
            ClosePositionByTicket(tk, "UNPROTECTED");
            PersistState();
            return;
           }
         sl = g_pendSig.sl;
         tp = g_pendSig.tp;
        }

      //--- re-anchor TP to the actual fill (SL is never moved or widened here)
      if(InpReanchorTPToFill && sl > 0.0)
        {
         double ideal = AfxTakeProfit(dir, open, sl, InpRewardRisk);
         ideal = (dir > 0) ? AfxRoundUp(ideal, g_tick, g_digits) : AfxRoundDown(ideal, g_tick, g_digits);
         if(MathAbs(ideal - tp) >= g_tick * 0.5)
           {
            string why = "";
            if(ModifyAllowed(dir, sl, ideal, sl, tp, why))
              {
               if(ModifySLTP(tk, sl, ideal, "re-anchor TP to fill"))
                  tp = ideal;
              }
            else
               LogWarn("TP re-anchor skipped: " + why);
           }
        }

      //--- actual risk at the stop from the real fill
      double pnl = 0.0, riskMoney = 0.0;
      ENUM_ORDER_TYPE ot2 = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OrderCalcProfit(ot2, g_sym, vol, open, sl, pnl))
         riskMoney = MathAbs(pnl);
      int k = ArraySize(g_posRec);
      ArrayResize(g_posRec, k + 1);
      g_posRec[k].posId     = posId;
      g_posRec[k].dir       = dir;
      g_posRec[k].openTime  = ot;
      g_posRec[k].openPrice = open;
      g_posRec[k].initialSL = sl;
      g_posRec[k].riskMoney = riskMoney;
      g_posRec[k].signalBar = g_pendSig.signalBarTime;

      double slipPts = (open - g_pendSig.entry) / g_point * dir;
      LogInfo(StringFormat("FILL VERIFIED #%I64u %s %.2f lots @ %s (planned %s, slippage %+.0f pts) SL=%s TP=%s risk@SL=%.2f budget=%.2f",
                           posId, DirName(dir), vol, Px(open), Px(g_pendSig.entry), slipPts, Px(sl), Px(tp), riskMoney, g_pendSig.riskBudget));
      if(vol < g_pendSig.volume - g_volStep * 0.5)
         LogWarn(StringFormat("PARTIAL FILL: %.2f of %.2f lots filled", vol, g_pendSig.volume));
      if(riskMoney + vol * InpEstimatedCommissionPerLot > g_pendSig.riskBudget * 1.10)
         LogWarn(StringFormat("RISK OVERSHOOT after fill: %.2f + est. commission vs budget %.2f (slippage). SL not widened.",
                              riskMoney, g_pendSig.riskBudget));
      PersistState();
      return;
     }
   if((long)(AfxNow() - g_pendTime) > AFX_FILL_VERIFY_SECONDS)
     {
      LogErr(StringFormat("FILL NOT RECONCILED: no EA position found %d s after order #%I64u (deal #%I64u). Check the terminal journal.",
                          AFX_FILL_VERIFY_SECONDS, g_pendOrder, g_pendDeal));
      g_pendVerify = false;
      g_histDirty  = true;
     }
  }

void BeginReconciliation(const AfxSignal &s, const ulong order, const ulong deal)
  {
   g_lastTradedSignalBar = s.signalBarTime;
   g_pendVerify = true;
   g_pendTime   = AfxNow();
   g_pendOrder  = order;
   g_pendDeal   = deal;
   g_pendSig    = s;
   PersistState();
  }

bool SendMarketEntry(AfxSignal &s)
  {
   int retries = IMax(0, IMin(3, InpMaxSendRetries));
   for(int attempt = 0; attempt <= retries; attempt++)
     {
      if(attempt > 0)
        {
         int rr = BuildOrderLevels(s);
         if(rr != RJ_NONE)
           {
            LogWarn("Retry aborted - order no longer valid: " + RejectName(rr) + " " + s.detail);
            return false;
           }
        }
      MqlTradeRequest     req;
      MqlTradeResult      res;
      MqlTradeCheckResult chk;
      ZeroMemory(req);
      ZeroMemory(res);
      ZeroMemory(chk);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = g_sym;
      req.volume       = s.volume;
      req.type         = (s.dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      req.price        = s.entry;
      req.sl           = s.sl;
      req.tp           = s.tp;
      req.deviation    = (ulong)IMax(0, InpMaxDeviationPoints);
      req.magic        = InpMagicNumber;
      req.comment      = BuildComment(s);
      req.type_filling = g_filling;
      req.type_time    = ORDER_TIME_GTC;

      if(!OrderCheck(req, chk) || (chk.retcode != 0 && chk.retcode != TRADE_RETCODE_DONE))
        {
         Rej(s, RJ_ORDER_CHECK, StringFormat("OrderCheck retcode=%u %s", chk.retcode, chk.comment));
         return false;
        }
      g_ordersSent++;
      ResetLastError();
      bool ok = OrderSend(req, res);
      uint rc = res.retcode;
      if(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED)
        {
         s.decision = "ORDER_ACCEPTED";
         LogInfo(StringFormat("ORDER ACCEPTED %s %.2f %s req=%s SL=%s TP=%s -> retcode=%u order=#%I64u deal=#%I64u price=%s vol=%.2f",
                              DirName(s.dir), s.volume, g_sym, Px(s.entry), Px(s.sl), Px(s.tp), rc,
                              res.order, res.deal, Px(res.price), res.volume));
         BeginReconciliation(s, res.order, res.deal);
         if(g_filling == ORDER_FILLING_RETURN && res.volume < s.volume - g_volStep * 0.5)
            CancelOwnPendingOrders("remainder of a partially filled market order");
         VerifyPendingFill();
         return true;
        }
      //--- outcome unknown: block duplicates and reconcile from positions
      if(rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION || (!ok && rc == 0))
        {
         s.decision = "ORDER_OUTCOME_UNKNOWN";
         Rej(s, RJ_SEND_FAILED, StringFormat("outcome unknown (retcode=%u err=%d) - reconciling, no resend", rc, GetLastError()));
         BeginReconciliation(s, res.order, res.deal);
         return false;
        }
      bool requote = (rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_PRICE_OFF);
      LogWarn(StringFormat("OrderSend attempt %d failed: retcode=%u %s err=%d", attempt + 1, rc, res.comment, GetLastError()));
      if(!requote || attempt >= retries)
        {
         Rej(s, RJ_SEND_FAILED, StringFormat("retcode=%u %s", rc, res.comment));
         return false;
        }
     }
   Rej(s, RJ_SEND_FAILED, "requote retries exhausted");
   return false;
  }

//+------------------------------------------------------------------+
//| Optional position management (all disabled by default)           |
//+------------------------------------------------------------------+
double InitialRiskDistance(const ulong posId, const double open, const double sl, const double tp)
  {
   int k = FindPosRecord(posId);
   if(k >= 0 && g_posRec[k].initialSL > 0.0)
      return MathAbs(open - g_posRec[k].initialSL);
   if(tp > 0.0 && InpRewardRisk > 0.0)
      return MathAbs(tp - open) / InpRewardRisk;
   if(sl > 0.0)
      return MathAbs(open - sl);
   return 0.0;
  }

void ManageOpenPositions()
  {
   if(!g_execAllowed)
      return;
   if(!InpEnableBreakEven && !InpEnableTrailingStop && !InpEnableTimeExit)
      return;
   ulong tk = 0;
   if(OwnPositionsOnSymbol(tk) == 0 || !PositionSelectByTicket(tk))
      return;
   datetime now = AfxNow();
   ulong  posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   datetime ot  = (datetime)PositionGetInteger(POSITION_TIME);
   int dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;

   if(InpEnableTimeExit && (long)(now - ot) >= (long)InpMaxHoldMinutes * 60)
     {
      if((long)(now - g_lastModifyTry) >= 2)
        {
         g_lastModifyTry = now;
         ClosePositionByTicket(tk, "TIME EXIT");
        }
      return;
     }
   double risk = InitialRiskDistance(posId, open, sl, tp);
   if(risk <= 0.0)
      return;
   MqlTick q;
   if(!SymbolInfoTick(g_sym, q))
      return;
   double px = (dir > 0) ? q.bid : q.ask;
   double progress = (dir > 0) ? px - open : open - px;
   double newSL = sl;

   if(InpEnableBreakEven && progress >= InpBreakEvenTriggerR * risk)
     {
      double off = (double)InpBreakEvenOffsetPoints * g_point;
      double be  = (dir > 0) ? AfxRoundDown(open + off, g_tick, g_digits) : AfxRoundUp(open - off, g_tick, g_digits);
      if(dir > 0 ? (be > newSL) : (newSL <= 0.0 || be < newSL))
         newSL = be;
     }
   if(InpEnableTrailingStop && progress >= InpTrailStartR * risk)
     {
      double atr = LatestClosedEntryATR();
      if(atr > 0.0)
        {
         double dist  = InpTrailDistanceATR * atr;
         double trail = (dir > 0) ? AfxRoundDown(px - dist, g_tick, g_digits) : AfxRoundUp(px + dist, g_tick, g_digits);
         if(dir > 0 ? (trail > newSL) : (newSL <= 0.0 || trail < newSL))
            newSL = trail;
        }
     }
   if(MathAbs(newSL - sl) < g_tick * 0.5)
      return;
   if((long)(now - g_lastModifyTry) < 2)
      return;
   g_lastModifyTry = now;
   string why = "";
   if(ModifyAllowed(dir, newSL, tp, sl, tp, why))
      ModifySLTP(tk, newSL, tp, "break-even/trailing");
   else
      LogInfo("SL management skipped: " + why);
  }

//+------------------------------------------------------------------+
//| Alerts, journal, dashboard                                       |
//+------------------------------------------------------------------+
void DrawSignalArrow(const AfxSignal &s)
  {
   if(!InpEnableChartDashboard || (g_isTester && !g_isVisual) || g_sym != _Symbol)
      return;
   string name = AFX_OBJ_PREFIX + "SIG_" + IntegerToString((long)s.signalBarTime);
   if(ObjectFind(0, name) >= 0)
      return;
   ENUM_OBJECT type = (s.dir > 0) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
   double price = (s.dir > 0) ? s.sigLow : s.sigHigh;
   if(ObjectCreate(0, name, type, 0, s.signalBarTime, price))
     {
      ObjectSetInteger(0, name, OBJPROP_COLOR, s.dir > 0 ? C'0,229,255' : C'176,96,255');
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }

void EmitSignalAlert(AfxSignal &s)
  {
   g_alertsEmitted++;
   g_day.alerts++;
   g_lastTradedSignalBar = s.signalBarTime;
   PersistState();
   string msg = StringFormat("%s %s %s signal [%s] entry~%s SL=%s TP=%s vol=%.2f risk=%.2f%s",
                             AFX_EA_NAME, g_sym, DirName(s.dir),
                             "Mode " + ModeTag(),
                             Px(s.entry), Px(s.sl), Px(s.tp), s.volume, s.plannedLoss,
                             (InpTradingMode == AFX_FULL_AUTO) ? " (LIVE EXECUTION LOCKED)" : "");
   if(InpEnableAlerts && !g_isOptim)
      Alert(msg);
   if(InpEnablePushNotifications && !g_isTester)
      SendNotification(msg);
   DrawSignalArrow(s);
  }

string CsvSafe(const string v)
  {
   string r = v;
   StringReplace(r, ",", ";");
   StringReplace(r, "\r", " ");
   StringReplace(r, "\n", " ");
   return r;
  }

string FileSafe(const string v)
  {
   string r = v;
   string bad = "\\/:*?\"<>|";
   for(int i = 0; i < StringLen(bad); i++)
      StringReplace(r, StringSubstr(bad, i, 1), "_");
   return r;
  }

void JournalOpen()
  {
   if(!InpWriteJournalCsv || g_isOptim)
      return;
   string fn = StringFormat("ALBFX_EMA_SCALPER_Journal_%s_%I64u_%s.csv", FileSafe(g_sym), InpMagicNumber, g_isTester ? "TESTER" : "LIVE");
   int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ;
   if(!g_isTester)
      flags |= FILE_READ;
   g_journal = FileOpen(fn, flags);
   if(g_journal == INVALID_HANDLE)
     {
      LogWarn(StringFormat("Journal: cannot open %s (err %d)", fn, GetLastError()));
      return;
     }
   if(!g_isTester)
      FileSeek(g_journal, 0, SEEK_END);
   if(FileSize(g_journal) == 0)
      FileWriteString(g_journal, "eval_time,signal_bar,mode,dir,decision,reason,detail,trend_bar,ema_fast_tf,ema_slow_tf,sep_atr,slope_atr," +
                      "ema_fast_entry,ema_slow_entry,open,high,low,close,atr_entry,bid,ask,spread_pts,swing,entry,sl,tp,sl_pts,rr,drift_atr,volume,risk_budget,planned_loss\r\n");
   LogInfo("Journal: Common\\Files\\" + fn);
  }

void JournalWrite(const AfxSignal &s)
  {
   if(g_journal == INVALID_HANDLE)
      return;
   if(IsNoSetup(s.reject) && !InpLogNoSetupBars)
      return;
   string line = StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.3f,%.3f,%s,%s,%s,%s,%s,%s,%s,%s,%s,%.1f,%s,%s,%s,%s,%.1f,%.3f,%.3f,%.2f,%.2f,%.2f\r\n",
                              TimeToString(s.evalTime, TIME_DATE | TIME_SECONDS),
                              TimeToString(s.signalBarTime, TIME_DATE | TIME_MINUTES),
                              ModeTag(),
                              DirName(s.dir), s.decision, RejectName(s.reject), CsvSafe(s.detail),
                              TimeToString(s.trendBarTime, TIME_DATE | TIME_MINUTES),
                              Px(s.emaFastTrend), Px(s.emaSlowTrend), s.sepATR, s.slopeATR,
                              Px(s.emaFastM1), Px(s.emaSlowM1), Px(s.sigOpen), Px(s.sigHigh), Px(s.sigLow), Px(s.sigClose),
                              Px(s.atrEntry), Px(s.bid), Px(s.ask), s.spreadPts, Px(s.swingPrice),
                              Px(s.entry), Px(s.sl), Px(s.tp), (g_point > 0.0 ? s.slDist / g_point : 0.0),
                              s.rrActual, s.driftATR, s.volume, s.riskBudget, s.plannedLoss);
   FileWriteString(g_journal, line);
   if(!g_isTester)
      FileFlush(g_journal);
  }

void DashLabel(const int idx, const string text, const color clr)
  {
   string name = AFX_OBJ_PREFIX + "DB_L" + IntegerToString(idx);
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 30 + idx * 17);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, idx == 0 ? 10 : 9);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void DashboardUpdate(const bool force)
  {
   if(!InpEnableChartDashboard || (g_isTester && !g_isVisual))
      return;
   ulong ms = GetTickCount64();
   if(!force && ms - g_lastDashMs < 1000)
      return;
   g_lastDashMs = ms;

   const color cTitle = C'0,229,255';
   const color cText  = C'205,215,240';
   const color cAccent = C'176,96,255';
   const color cGood  = C'0,220,150';
   const color cBad   = C'255,82,120';
   const int   lines  = 11;

   string bg = AFX_OBJ_PREFIX + "DB_BG";
   if(ObjectFind(0, bg) < 0)
     {
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 22);
      ObjectSetInteger(0, bg, OBJPROP_XSIZE, 540);
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, 18 + lines * 17);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'8,12,30');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_COLOR, C'0,150,255');
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, bg, OBJPROP_BACK, false);
     }

   MqlTick q;
   double spreadPts = 0.0;
   if(SymbolInfoTick(g_sym, q) && g_point > 0.0)
      spreadPts = (q.ask - q.bid) / g_point;
   string pos = "none";
   ulong tk = 0;
   if(OwnPositionsOnSymbol(tk) > 0 && PositionSelectByTicket(tk))
      pos = StringFormat("%s %.2f @ %s  SL %s  TP %s  P/L %.2f",
                         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL",
                         PositionGetDouble(POSITION_VOLUME), Px(PositionGetDouble(POSITION_PRICE_OPEN)),
                         Px(PositionGetDouble(POSITION_SL)), Px(PositionGetDouble(POSITION_TP)),
                         PositionGetDouble(POSITION_PROFIT));
   int used = g_execAllowed ? g_day.entries : g_day.alerts;

   DashLabel(0, "ALB FOREX | EMA 8/14 SCALPER  v" + AFX_EA_VERSION, cTitle);
   DashLabel(1, "Mode: " + (InpTradingMode == AFX_FULL_AUTO ? "FULL_AUTO" : "ALERT_ONLY") + "  |  " + g_execStatus,
             g_execAllowed ? cGood : cAccent);
   DashLabel(2, StringFormat("Symbol: %s   Spread: %.0f pts   Fill: %s   %s", g_sym, spreadPts, FillingName(g_filling),
                             g_isHedging ? "HEDGING" : "NETTING"), cText);
   if(InpEntryMode == AFX_ENTRY_CROSSOVER)
      DashLabel(3, StringFormat("Entry: CROSSOVER  trend filter %s  SL %.1f ATR  RR 1:%.2f",
                                InpCrossUseTrendFilter ? "ON" : "OFF", InpCrossSLATR, InpRewardRisk), cText);
   else
      DashLabel(3, StringFormat("Confirm: %s   Flat filter: %s   RR 1:%.2f",
                                InpConfirmationMode == AFX_CONFIRM_NEXT_CANDLE ? "B next candle" : "A same candle",
                                InpEnableFlatEMAFilter ? "ON" : "OFF", InpRewardRisk), cText);
   DashLabel(4, StringFormat("%s trend (closed bar): %s", EnumToString(InpTrendTF), DirName(g_lastTrendDir)),
             g_lastTrendDir > 0 ? cTitle : (g_lastTrendDir < 0 ? cAccent : cText));
   double dayPct = -g_day.lossPct;
   if(MathAbs(dayPct) < 0.005)
      dayPct = 0.0;
   DashLabel(5, StringFormat("Day P/L: %+.2f%%   Limit: -%.2f%%   %s", dayPct, InpMaxDailyLossPercent,
                             g_day.halted ? "HALTED" : "OK"), g_day.halted ? cBad : cGood);
   DashLabel(6, StringFormat("Entries today: %d / %s   Risk/trade: %.2f%%", used,
                             InpMaxTradesPerDay > 0 ? IntegerToString(InpMaxTradesPerDay) : "unlimited", InpRiskPercent), cText);
   DashLabel(7, "News: " + (InpEnableNewsFilter ? g_newsStatus : "DISABLED"),
             (!InpEnableNewsFilter || g_newsOk) ? cText : cBad);
   DashLabel(8, "Position: " + pos, cText);
   DashLabel(9, "Last: " + StringSubstr(g_lastEvalText, 0, 70), cText);
   DashLabel(10, "Telegram @Alb_Forex  |  albforex.al  |  research EA - not validated", cAccent);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Evaluation driver                                                |
//+------------------------------------------------------------------+
void FinalizeEvaluation(AfxSignal &s)
  {
   g_evaluations++;
   if(s.isSetup)
      g_setups++;
   if(s.patternOk)
      g_patternSignals++;
   if(s.reject == RJ_NONE)
     {
      g_validSignals++;
      if(g_execAllowed)
        {
         if(!SendMarketEntry(s) && s.decision == "")
            s.decision = "REJECTED";
        }
      else
        {
         EmitSignalAlert(s);
         s.decision = "ALERT";
        }
     }
   else
      s.decision = IsNoSetup(s.reject) ? "NO_SETUP" : "REJECTED";

   if(s.reject > RJ_NONE && s.reject < RJ_COUNT)
      g_rejects[s.reject]++;
   if(s.patternOk && s.reject != RJ_NONE)
      g_rejectedSignals++;

   string modeTxt = ModeTag();
   if(s.reject == RJ_NONE || s.decision == "ORDER_OUTCOME_UNKNOWN")
      g_lastEvalText = StringFormat("%s %s %s %s SL %s TP %s vol %.2f", TimeToString(s.signalBarTime, TIME_MINUTES),
                                    DirName(s.dir), s.decision, Px(s.entry), Px(s.sl), Px(s.tp), s.volume);
   else
      g_lastEvalText = StringFormat("%s %s %s", TimeToString(s.signalBarTime, TIME_MINUTES), DirName(s.dir), RejectName(s.reject));

   if(!IsNoSetup(s.reject) || InpLogNoSetupBars)
     {
      if(s.reject == RJ_NONE)
         LogInfo(StringFormat("SIGNAL %s mode %s bar %s -> %s | entry %s SL %s TP %s (RR %.2f, SL %.0f pts, spread %.0f pts, drift %.2f ATR) vol %.2f risk %.2f",
                              DirName(s.dir), modeTxt, TimeToString(s.signalBarTime, TIME_DATE | TIME_MINUTES), s.decision,
                              Px(s.entry), Px(s.sl), Px(s.tp), s.rrActual, s.slDist / g_point, s.spreadPts, s.driftATR,
                              s.volume, s.plannedLoss));
      else
         LogInfo(StringFormat("EVAL %s mode %s bar %s -> %s [%s] %s", DirName(s.dir), modeTxt,
                              TimeToString(s.signalBarTime, TIME_DATE | TIME_MINUTES), s.decision, RejectName(s.reject), s.detail));
     }
   JournalWrite(s);
   DashboardUpdate(true);
  }

void ProcessEntryTimeframe()
  {
   datetime t0 = iTime(g_sym, InpEntryTF, 0);
   if(t0 == 0)
      return;
   if(g_lastBarTime == 0)
     {
      //--- first observation: never act on a candle that closed before the EA was watching
      g_lastBarTime = t0;
      return;
     }
   if(t0 != g_lastBarTime)
     {
      g_lastBarTime = t0;
      g_evalPending = true;
      g_evalBarTime = t0;
     }
   if(!g_evalPending || g_evalBarTime != t0)
      return;

   AfxSignal s;
   int rc = BuildSignal(t0, s);
   bool retryable = (rc == RJ_DATA_NOT_READY || rc == RJ_TREND_NOT_SYNCED);
   if(retryable && (long)(AfxNow() - t0) <= (long)InpMaxSignalDelaySeconds)
      return;   // retry on the next tick of the same bar
   g_evalPending = false;
   FinalizeEvaluation(s);
  }

//+------------------------------------------------------------------+
//| Performance report (Strategy Tester)                             |
//+------------------------------------------------------------------+
void AddLine(string &out, const string line)
  {
   out += line + "\r\n";
  }

int FindStat(const AfxTradeStat &arr[], const int n, const ulong pid)
  {
   for(int i = n - 1; i >= 0; i--)
      if(arr[i].pid == pid)
         return i;
   return -1;
  }

double BuildPerformanceReport(string &out)
  {
   out = "";
   AddLine(out, "==================== ALB FOREX EMA 8/14 SCALPER - EXTENDED REPORT ====================");
   AddLine(out, StringFormat("EA %s v%s | symbol %s | magic %I64u", AFX_EA_NAME, AFX_EA_VERSION, g_sym, InpMagicNumber));
   AddLine(out, StringFormat("Config: ENTRY MODE=%s%s", InpEntryMode == AFX_ENTRY_CROSSOVER ? "CROSSOVER (every M1 EMA cross)" : "PULLBACK (baseline)",
                             InpEntryMode == AFX_ENTRY_CROSSOVER ? StringFormat(" trendFilter=%s SL=%.2fATR closeOnOpposite=%s",
                                   BoolStr(InpCrossUseTrendFilter), InpCrossSLATR, BoolStr(InpCrossCloseOnOpposite)) : ""));
   AddLine(out, StringFormat("Config: mode=%s confirm=%s flatFilter=%s(sep=%s %.2f, slope=%s %.2f/%d bars) M1align=%s",
                             InpTradingMode == AFX_FULL_AUTO ? "FULL_AUTO" : "ALERT_ONLY",
                             InpConfirmationMode == AFX_CONFIRM_NEXT_CANDLE ? "B_NEXT_CANDLE" : "A_SAME_CANDLE",
                             BoolStr(InpEnableFlatEMAFilter), BoolStr(InpUseSeparationCheck), InpMinimumEMASeparationATR,
                             BoolStr(InpUseSlopeCheck), InpMinimumEMASlopeATR, InpSlopeBars, BoolStr(InpRequireM1EMAAlignment)));
   AddLine(out, StringFormat("Config: risk=%.2f%% RR=%.2f dailyLoss=%.2f%% maxTrades=%d spreadRatio=%.2f drift=%.2fATR BE=%s trail=%s timeExit=%s",
                             InpRiskPercent, InpRewardRisk, InpMaxDailyLossPercent, InpMaxTradesPerDay, InpMaxSpreadToStopRatio,
                             InpMaxEntryDriftATR, BoolStr(InpEnableBreakEven), BoolStr(InpEnableTrailingStop), BoolStr(InpEnableTimeExit)));
   AddLine(out, "News filter: " + (InpEnableNewsFilter ? g_newsStatus : "DISABLED - backtest has NO news protection (limitation)"));

   if(!HistorySelect(0, TimeCurrent() + 86400))
     {
      AddLine(out, "HistorySelect failed - no trade statistics");
      return 0.0;
     }
   AfxTradeStat st[];
   int np = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetString(d, DEAL_SYMBOL) != g_sym)
         continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      ulong pid = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(FindStat(st, np, pid) >= 0)
         continue;
      ArrayResize(st, np + 1);
      st[np].pid  = pid;
      st[np].dir  = ((ENUM_DEAL_TYPE)HistoryDealGetInteger(d, DEAL_TYPE) == DEAL_TYPE_BUY) ? 1 : -1;
      st[np].tin  = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      st[np].tout = 0;
      st[np].net  = 0.0;
      st[np].cost = 0.0;
      int k = FindPosRecord(pid);
      st[np].risk = (k >= 0) ? g_posRec[k].riskMoney : 0.0;
      np++;
     }
   for(int i = 0; i < total; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      int k = FindStat(st, np, (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID));
      if(k < 0)
         continue;
      double comm = HistoryDealGetDouble(d, DEAL_COMMISSION);
      double swp  = HistoryDealGetDouble(d, DEAL_SWAP);
      double fee  = HistoryDealGetDouble(d, DEAL_FEE);
      st[k].net  += HistoryDealGetDouble(d, DEAL_PROFIT) + comm + swp + fee;
      st[k].cost += comm + swp + fee;
      ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
      if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
        {
         datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
         if(t > st[k].tout)
            st[k].tout = t;
        }
     }

   int n = 0, wins = 0, losses = 0, rCount = 0, consec = 0, maxConsec = 0;
   int bN = 0, bW = 0, sN = 0, sW = 0;
   double gp = 0.0, gl = 0.0, net = 0.0, costs = 0.0, sumR = 0.0, bNet = 0.0, sNet = 0.0;
   long durs[];
   string months[];
   double monthNet[];
   int    monthCnt[];
   for(int i = 0; i < np; i++)
     {
      if(st[i].tout == 0)
         continue;
      n++;
      net   += st[i].net;
      costs += st[i].cost;
      if(st[i].net > 0.0)
        {
         wins++;
         gp += st[i].net;
         consec = 0;
        }
      else
        {
         if(st[i].net < 0.0)
           {
            losses++;
            gl += st[i].net;
           }
         consec++;
         if(consec > maxConsec)
            maxConsec = consec;
        }
      if(st[i].risk > 0.0)
        {
         sumR += st[i].net / st[i].risk;
         rCount++;
        }
      if(st[i].dir > 0)
        {
         bN++;
         bNet += st[i].net;
         if(st[i].net > 0.0)
            bW++;
        }
      else
        {
         sN++;
         sNet += st[i].net;
         if(st[i].net > 0.0)
            sW++;
        }
      int dn = ArraySize(durs);
      ArrayResize(durs, dn + 1);
      durs[dn] = (long)(st[i].tout - st[i].tin);
      MqlDateTime mt;
      TimeToStruct(st[i].tout, mt);
      string key = StringFormat("%04d.%02d", mt.year, mt.mon);
      int mi = -1;
      for(int m = 0; m < ArraySize(months); m++)
         if(months[m] == key)
           {
            mi = m;
            break;
           }
      if(mi < 0)
        {
         mi = ArraySize(months);
         ArrayResize(months, mi + 1);
         ArrayResize(monthNet, mi + 1);
         ArrayResize(monthCnt, mi + 1);
         months[mi]   = key;
         monthNet[mi] = 0.0;
         monthCnt[mi] = 0;
        }
      monthNet[mi] += st[i].net;
      monthCnt[mi]++;
     }

   double avgR = (rCount > 0) ? sumR / rCount : 0.0;
   AddLine(out, "--------------------------------------------------------------------------------------");
   AddLine(out, StringFormat("1  Total closed trades       : %d", n));
   AddLine(out, StringFormat("2  Win rate                  : %.2f%% (%d W / %d L)", n > 0 ? 100.0 * wins / n : 0.0, wins, losses));
   AddLine(out, StringFormat("3  Net profit                : %.2f", net));
   AddLine(out, StringFormat("4  Profit factor             : %s", gl < 0.0 ? DoubleToString(gp / -gl, 3) : "n/a"));
   if(g_isTester)
      AddLine(out, StringFormat("5  Max equity drawdown       : %.2f (%.2f%%)", TesterStatistics(STAT_EQUITY_DD), TesterStatistics(STAT_EQUITYDD_PERCENT)));
   else
      AddLine(out, "5  Max equity drawdown       : see Strategy Tester report");
   AddLine(out, StringFormat("6  Average win               : %.2f", wins > 0 ? gp / wins : 0.0));
   AddLine(out, StringFormat("7  Average loss              : %.2f", losses > 0 ? gl / losses : 0.0));
   AddLine(out, StringFormat("8  Average realised R        : %.3f (over %d trades with recorded risk)", avgR, rCount));
   AddLine(out, StringFormat("9  Expectancy per trade      : %.2f (account currency)", n > 0 ? net / n : 0.0));
   double avgDur = 0.0, medDur = 0.0;
   int dn2 = ArraySize(durs);
   if(dn2 > 0)
     {
      long sum = 0;
      for(int i = 0; i < dn2; i++)
         sum += durs[i];
      avgDur = (double)sum / dn2 / 60.0;
      ArraySort(durs);
      medDur = (dn2 % 2 == 1) ? (double)durs[dn2 / 2] / 60.0 : (double)(durs[dn2 / 2 - 1] + durs[dn2 / 2]) / 120.0;
     }
   AddLine(out, StringFormat("10 Trade duration (minutes)  : average %.1f, median %.1f", avgDur, medDur));
   AddLine(out, StringFormat("11 Trading costs             : %.2f (commission + swap + fees)", costs));
   AddLine(out, "12 Results by month (exit month):");
   for(int m = 0; m < ArraySize(months); m++)
      AddLine(out, StringFormat("     %s : %4d trades, net %.2f", months[m], monthCnt[m], monthNet[m]));
   AddLine(out, StringFormat("13 Max consecutive losses    : %d", maxConsec));
   AddLine(out, StringFormat("14 BUY  : %d trades, win %.1f%%, net %.2f", bN, bN > 0 ? 100.0 * bW / bN : 0.0, bNet));
   AddLine(out, StringFormat("   SELL : %d trades, win %.1f%%, net %.2f", sN, sN > 0 ? 100.0 * sW / sN : 0.0, sNet));
   AddLine(out, StringFormat("15 Signal funnel: evaluated %d, setups (trend+touch) %d, confirmed patterns %d, passed all filters %d, rejected after pattern %d (%.1f%%)",
                             g_evaluations, g_setups, g_patternSignals, g_validSignals, g_rejectedSignals,
                             g_patternSignals > 0 ? 100.0 * g_rejectedSignals / g_patternSignals : 0.0));
   AddLine(out, StringFormat("   Orders sent %d, fills verified %d, alerts %d", g_ordersSent, g_ordersFilled, g_alertsEmitted));
   AddLine(out, "   Rejection reasons:");
   for(int i = 1; i < (int)RJ_COUNT; i++)
      if(g_rejects[i] > 0)
         AddLine(out, StringFormat("     %-30s %d", RejectName(i), g_rejects[i]));
   AddLine(out, StringFormat("16 Daily loss-limit activations: %d  %s", g_dailyLimitActivations, g_dailyLimitDates));
   AddLine(out, StringFormat("   Emergency closes: %d", g_emergencyCloses));
   AddLine(out, StringFormat("Break-even win rate at %.2fR before costs: %.1f%%", InpRewardRisk, 100.0 / (1.0 + InpRewardRisk)));
   AddLine(out, "No profitability claim is implied. Validate out-of-sample before any live use.");
   AddLine(out, "======================================================================================");
   return avgR;
  }

//+------------------------------------------------------------------+
//| Input validation                                                 |
//+------------------------------------------------------------------+
bool ValidateInputs(string &why)
  {
   if(InpMagicNumber == 0)
     { why = "MagicNumber must be non-zero (0 is used by manual trades)"; return false; }
   if(InpFastEMA < 1 || InpSlowEMA <= InpFastEMA)
     { why = "FastEMA must be >= 1 and smaller than SlowEMA"; return false; }
   if(PeriodSeconds(InpTrendTF) <= PeriodSeconds(InpEntryTF))
     { why = "TrendTF must be a higher timeframe than EntryTF"; return false; }
   if(InpATRPeriod < 1 || InpSlopeBars < 1)
     { why = "ATR period and slope bars must be >= 1"; return false; }
   if(InpSwingLeftBars < 1 || InpSwingRightBars < 1 || InpSwingLookback < InpSwingRightBars + 1)
     { why = "swing parameters invalid (left/right >= 1, lookback > right bars)"; return false; }
   if(InpRewardRisk <= 0.0)
     { why = "RewardRisk must be > 0"; return false; }
   if(InpRiskPercent <= 0.0 || InpRiskPercent > AFX_MAX_RISK_PERCENT)
     { why = StringFormat("RiskPercent must be in (0, %.1f]", AFX_MAX_RISK_PERCENT); return false; }
   if(InpMaxDailyLossPercent <= 0.0 || InpMaxDailyLossPercent > AFX_MAX_DAILY_LOSS_PCT)
     { why = StringFormat("MaxDailyLossPercent must be in (0, %.1f]", AFX_MAX_DAILY_LOSS_PCT); return false; }
   if(InpMaxTradesPerDay < 0 || InpMaxOpenPositions < 1)
     { why = "MaxTradesPerDay must be >= 0 (0 = unlimited) and MaxOpenPositions >= 1"; return false; }
   if(InpCrossSLATR <= 0.0)
     { why = "CROSSOVER stop distance must be > 0"; return false; }
   if(InpMaxSpreadToStopRatio < 0.0 || InpMaxSpreadPoints < 0 || InpMaxEntryDriftATR < 0.0 || InpMaxQuoteAgeSeconds < 0)
     { why = "spread / drift / quote-age thresholds cannot be negative"; return false; }
   if(InpStopBufferPoints < 0 || InpStopBufferATR < 0.0 || InpMinStopATR < 0.0 || InpMinStopPoints < 0 || InpMaxStopATR < 0.0)
     { why = "stop distance parameters cannot be negative"; return false; }
   if(InpMaxStopATR > 0.0 && InpMaxStopATR <= InpMinStopATR)
     { why = "Maximum SL distance must be larger than the minimum"; return false; }
   if(InpNewsBlockBeforeMinutes < 0 || InpNewsBlockAfterMinutes < 0 || InpNewsExportDays < 0 || InpNewsExportDays > 3650)
     { why = "news minutes cannot be negative; export days must be 0-3650"; return false; }
   if(InpDayResetHour < 0 || InpDayResetHour > 23)
     { why = "Daily reset hour must be 0-23"; return false; }
   if(InpMaxMarginUsagePercent <= 0.0 || InpMaxMarginUsagePercent > 100.0)
     { why = "Max margin usage must be in (0, 100]"; return false; }
   if(InpMaxSendRetries < 0 || InpMaxSendRetries > 3 || InpMaxDeviationPoints < 0)
     { why = "retries must be 0-3 and deviation >= 0"; return false; }
   if(InpEstimatedCommissionPerLot < 0.0 || InpEstimatedSlippagePoints < 0 || InpMaxLots < 0.0)
     { why = "commission, slippage and lot cap cannot be negative"; return false; }
   if(InpMaxSignalDelaySeconds < 1)
     { why = "Max signal delay must be >= 1 second"; return false; }
   if(InpBreakEvenTriggerR <= 0.0 || InpTrailStartR <= 0.0 || InpTrailDistanceATR <= 0.0 || InpMaxHoldMinutes < 1 || InpBreakEvenOffsetPoints < 0)
     { why = "break-even / trailing / time-exit parameters invalid"; return false; }
   if(!AfxParseHHMM(InpSessionStart, g_sessStartMin) || !AfxParseHHMM(InpSessionEnd, g_sessEndMin))
     { why = "session times must be HH:MM (00:00-23:59)"; return false; }
   return true;
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_initOk   = false;
   g_isTester = (MQLInfoInteger(MQL_TESTER) != 0);
   g_isVisual = (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
   g_isOptim  = (MQLInfoInteger(MQL_OPTIMIZATION) != 0);
   g_persist  = !g_isTester;
   g_sessionStart = (g_isTester ? TimeCurrent() : TimeTradeServer());
   ArrayResize(g_rejects, (int)RJ_COUNT);
   ArrayInitialize(g_rejects, 0);

   if(InpRunSelfTests)
     {
      int failed = RunSelfTests();
      if(failed > 0)
        {
         LogErr(StringFormat("Self-tests failed (%d) - EA will not start", failed));
         return INIT_FAILED;
        }
     }

   string why = "";
   if(!ValidateInputs(why))
     {
      LogErr("Invalid inputs: " + why);
      return INIT_PARAMETERS_INCORRECT;
     }

   g_sym = InpTradingSymbol;
   StringTrimLeft(g_sym);
   StringTrimRight(g_sym);
   if(g_sym == "")
      g_sym = _Symbol;
   if(!SymbolSelect(g_sym, true))
     {
      LogErr("Symbol not available: " + g_sym);
      return INIT_FAILED;
     }
   if(!LoadSymbolProperties())
     {
      LogErr("Cannot read symbol properties for " + g_sym);
      return INIT_FAILED;
     }
   string up = g_sym;
   StringToUpper(up);
   if(StringFind(up, "XAU") < 0)
      LogWarn("This EA is designed and documented for XAUUSD. " + g_sym + " is untested.");
   if(g_sym != _Symbol)
      LogWarn("TradingSymbol differs from the chart symbol: signals are evaluated on chart ticks only. Attach the EA to a " + g_sym + " chart.");

   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   g_isHedging = (mm == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   ENUM_ACCOUNT_TRADE_MODE am = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   g_isReal = (!g_isTester && am == ACCOUNT_TRADE_MODE_REAL);

   if(InpTradingMode == AFX_ALERT_ONLY)
     {
      g_execAllowed = false;
      g_execStatus  = "alerts only - no orders";
     }
   else
      if(g_isReal && !InpEnableLiveTrading)
        {
         g_execAllowed = false;
         g_execStatus  = "LOCKED: real account, EnableLiveTrading=false";
         LogWarn("REAL-MONEY account detected and EnableLiveTrading=false: running as ALERT_ONLY. No orders will be sent.");
         if(InpEnableAlerts)
            Alert(AFX_EA_NAME, ": real account detected - live execution LOCKED (EnableLiveTrading=false)");
        }
      else
        {
         g_execAllowed = true;
         g_execStatus  = g_isTester ? "executing (Strategy Tester)" : (g_isReal ? "EXECUTING ON REAL MONEY" : "executing (demo)");
         if(g_isReal)
            LogWarn("LIVE EXECUTION ENABLED ON A REAL-MONEY ACCOUNT (EnableLiveTrading=true). This strategy is NOT validated.");
        }

   g_hFastT = iMA(g_sym, InpTrendTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hSlowT = iMA(g_sym, InpTrendTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hFastE = iMA(g_sym, InpEntryTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hSlowE = iMA(g_sym, InpEntryTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hAtrE  = iATR(g_sym, InpEntryTF, InpATRPeriod);
   g_hAtrT  = iATR(g_sym, InpTrendTF, InpATRPeriod);
   if(g_hFastT == INVALID_HANDLE || g_hSlowT == INVALID_HANDLE || g_hFastE == INVALID_HANDLE ||
      g_hSlowE == INVALID_HANDLE || g_hAtrE == INVALID_HANDLE || g_hAtrT == INVALID_HANDLE)
     {
      LogErr(StringFormat("Indicator handle creation failed (err %d)", GetLastError()));
      ReleaseHandles();
      return INIT_FAILED;
     }

   g_filling = SelectFilling();
   ZeroMemory(g_pendSig);
   DailyInit();
   if(!NewsInit() && InpEnableNewsFilter)
      LogWarn("NEWS FILTER ENABLED BUT DATA NOT VERIFIED - new entries are BLOCKED until data is available. " + g_newsStatus);

   g_lastBarTime = iTime(g_sym, InpEntryTF, 0);
   g_evalPending = false;
   if(!g_isTester)
      EventSetTimer(1);
   JournalOpen();

   PrintFormat("[AFX-EMA] %s v%s started on %s | %s | %s | magic %I64u | filling %s | point %s tick %s | lots %.2f-%.2f step %.2f",
               AFX_EA_NAME, AFX_EA_VERSION, g_sym, InpTradingMode == AFX_FULL_AUTO ? "FULL_AUTO" : "ALERT_ONLY",
               g_execStatus, InpMagicNumber, FillingName(g_filling), DoubleToString(g_point, g_digits),
               DoubleToString(g_tick, g_digits), g_volMin, g_volMax, g_volStep);
   PrintFormat("[AFX-EMA] Strategy: trend %s EMA%d/%d (closed bar), entry %s, %s, flat filter %s, account %s, news %s",
               EnumToString(InpTrendTF), InpFastEMA, InpSlowEMA, EnumToString(InpEntryTF),
               InpEntryMode == AFX_ENTRY_CROSSOVER
               ? StringFormat("entry mode CROSSOVER (trend filter %s, SL %.2f ATR, RR %.2f, max trades/day %s)",
                              InpCrossUseTrendFilter ? "ON" : "OFF", InpCrossSLATR, InpRewardRisk,
                              InpMaxTradesPerDay > 0 ? IntegerToString(InpMaxTradesPerDay) : "unlimited")
               : (InpConfirmationMode == AFX_CONFIRM_NEXT_CANDLE ? "confirmation B (next candle, experimental)" : "confirmation A (same candle)"),
               InpEnableFlatEMAFilter ? "ON" : "OFF", g_isHedging ? "HEDGING" : "NETTING",
               InpEnableNewsFilter ? g_newsStatus : "DISABLED");
   g_initOk = true;
   DashboardUpdate(true);
   return INIT_SUCCEEDED;
  }

void ReleaseHandles()
  {
   if(g_hFastT != INVALID_HANDLE) { IndicatorRelease(g_hFastT); g_hFastT = INVALID_HANDLE; }
   if(g_hSlowT != INVALID_HANDLE) { IndicatorRelease(g_hSlowT); g_hSlowT = INVALID_HANDLE; }
   if(g_hFastE != INVALID_HANDLE) { IndicatorRelease(g_hFastE); g_hFastE = INVALID_HANDLE; }
   if(g_hSlowE != INVALID_HANDLE) { IndicatorRelease(g_hSlowE); g_hSlowE = INVALID_HANDLE; }
   if(g_hAtrE  != INVALID_HANDLE) { IndicatorRelease(g_hAtrE);  g_hAtrE  = INVALID_HANDLE; }
   if(g_hAtrT  != INVALID_HANDLE) { IndicatorRelease(g_hAtrT);  g_hAtrT  = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_initOk)
     {
      PersistState();
      PrintFormat("[AFX-EMA] Stopped (reason %d). Session: evaluated %d, setups %d, patterns %d, valid %d, orders %d, fills %d, alerts %d, daily-limit hits %d",
                  reason, g_evaluations, g_setups, g_patternSignals, g_validSignals, g_ordersSent, g_ordersFilled,
                  g_alertsEmitted, g_dailyLimitActivations);
     }
   ReleaseHandles();
   if(g_journal != INVALID_HANDLE)
     {
      FileClose(g_journal);
      g_journal = INVALID_HANDLE;
     }
   ObjectsDeleteAll(0, AFX_OBJ_PREFIX + "DB_");
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
      ObjectsDeleteAll(0, AFX_OBJ_PREFIX);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!g_initOk)
      return;
   CheckDailyLoss();                 // independent of new-bar evaluation
   if(g_pendVerify)
      VerifyPendingFill();
   ManageOpenPositions();
   ProcessEntryTimeframe();
   DashboardUpdate(false);
  }

//+------------------------------------------------------------------+
//| Timer (live only): equity guard without ticks, news refresh      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_initOk)
      return;
   CheckDailyLoss();
   if(g_pendVerify)
      VerifyPendingFill();
   if(InpEnableNewsFilter)
      RefreshNewsLive(false);
   DashboardUpdate(false);
  }

//+------------------------------------------------------------------+
//| Trade transactions: fills, closes, external cash flows           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!g_initOk || trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
     {
      g_histDirty = true;
      return;
     }
   ENUM_DEAL_TYPE ty = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(IsExternalCashFlow(ty))
     {
      g_histDirty = true;
      LogInfo(StringFormat("External cash flow deal #%I64u: %.2f - daily baseline will be adjusted", trans.deal,
                           HistoryDealGetDouble(trans.deal, DEAL_PROFIT)));
      return;
     }
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != g_sym)
      return;
   ulong pid = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   bool  own = ((ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == InpMagicNumber) || (FindPosRecord(pid) >= 0);
   if(!own)
      return;
   ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   g_histDirty = true;
   if(en == DEAL_ENTRY_IN)
     {
      if(g_pendVerify)
         VerifyPendingFill();
      return;
     }
   if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
     {
      double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_FEE);
      ENUM_DEAL_REASON rs = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
      int k = FindPosRecord(pid);
      string rTxt = (k >= 0 && g_posRec[k].riskMoney > 0.0) ? StringFormat("%.2fR", pnl / g_posRec[k].riskMoney) : "n/a";
      LogInfo(StringFormat("POSITION CLOSED #%I64u %s at %s: net %.2f (%s) reason %s", pid,
                           (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_SELL ? "BUY" : "SELL",
                           Px(HistoryDealGetDouble(trans.deal, DEAL_PRICE)), pnl, rTxt, EnumToString(rs)));
     }
  }

//+------------------------------------------------------------------+
//| Strategy Tester: extended report + custom criterion (avg R)      |
//+------------------------------------------------------------------+
double OnTester()
  {
   string rep = "";
   double avgR = BuildPerformanceReport(rep);
   if(InpWriteTesterReport && !g_isOptim)
     {
      string lines[];
      int n = StringSplit(rep, '\n', lines);
      for(int i = 0; i < n; i++)
        {
         string ln = lines[i];
         StringReplace(ln, "\r", "");
         if(StringLen(ln) > 0)
            Print(ln);
        }
      string fn = StringFormat("ALBFX_EMA_SCALPER_Report_%s_%s.txt", FileSafe(g_sym),
                               "Mode" + ModeTag());
      int h = FileOpen(fn, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, rep);
         FileClose(h);
         Print("[AFX-EMA] Extended report written to Common\\Files\\", fn);
        }
     }
   return avgR;
  }
//+------------------------------------------------------------------+
