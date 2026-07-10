//+------------------------------------------------------------------+
//| Fortress FX - MT5 Expert Advisor                                  |
//| Demo-first automation scaffold with FTMO-style guardrails.        |
//+------------------------------------------------------------------+
#property copyright "Hub City"
#property version   "0.4"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

input bool   EXECUTION_ENABLED              = false;
input bool   FTMO_MODE                      = true;
input double FTMO_ACCOUNT_SIZE              = 100000.0;
input double FTMO_PROFIT_TARGET_PCT         = 10.0;
input double FTMO_DAILY_LOSS_LIMIT_PCT      = 5.0;
input double FTMO_MAX_LOSS_LIMIT_PCT        = 10.0;
input double FTMO_SOFT_DAILY_STOP_PCT       = 3.5;
input double FTMO_SOFT_TOTAL_STOP_PCT       = 7.5;
input double MAX_RISK_PER_TRADE_PCT         = 0.25;
input int    MAX_OPEN_TRADES                = 1;
input int    MAGIC_NUMBER                   = 20260709;
input int    MAX_SPREAD_POINTS              = 25;
input int    MIN_SECONDS_BETWEEN_TRADES     = 900;
input bool   WEEKEND_FLAT                   = true;

input bool   ENABLE_SIGNALS                 = true;
input bool   TRADE_ON_NEW_BAR_ONLY          = true;
input bool   USE_SESSION_FILTER             = true;
input int    SESSION_START_HOUR             = 7;
input int    SESSION_END_HOUR               = 17;
input int    MAX_SIGNALS_PER_DAY            = 3;
input int    EMA_FAST_PERIOD                = 20;
input int    EMA_SLOW_PERIOD                = 50;
input int    RSI_PERIOD                     = 14;
input int    ATR_PERIOD                     = 14;
input double ATR_STOP_MULTIPLIER            = 1.50;
input double ATR_TAKE_PROFIT_MULTIPLIER     = 2.50;
input double MIN_REWARD_RISK                = 1.50;
input int    MIN_ATR_POINTS                 = 50;
input int    MIN_EMA_SEPARATION_POINTS      = 25;
input int    MIN_CANDLE_BODY_POINTS         = 20;
input bool   REQUIRE_CANDLE_DIRECTION       = true;
input double RSI_BUY_MIN                    = 52.0;
input double RSI_BUY_MAX                    = 70.0;
input double RSI_SELL_MIN                   = 30.0;
input double RSI_SELL_MAX                   = 48.0;

struct TradeSignal
{
   string direction;
   double entry;
   double stop_loss;
   double take_profit;
   double risk_points;
   double reward_points;
   double lots;
};

string       g_symbol;
datetime     g_day_start_time = 0;
double       g_day_start_equity = 0.0;
double       g_initial_balance = 0.0;
datetime     g_last_trade_time = 0;
datetime     g_last_bar_time = 0;
int          g_day_signal_count = 0;
bool         g_locked = false;
string       g_lock_reason = "";
int          g_ema_fast_handle = INVALID_HANDLE;
int          g_ema_slow_handle = INVALID_HANDLE;
int          g_rsi_handle = INVALID_HANDLE;
int          g_atr_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = _Symbol;
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ResetDailyAnchor();

   g_ema_fast_handle = iMA(g_symbol, PERIOD_CURRENT, EMA_FAST_PERIOD, 0, MODE_EMA, PRICE_CLOSE);
   g_ema_slow_handle = iMA(g_symbol, PERIOD_CURRENT, EMA_SLOW_PERIOD, 0, MODE_EMA, PRICE_CLOSE);
   g_rsi_handle = iRSI(g_symbol, PERIOD_CURRENT, RSI_PERIOD, PRICE_CLOSE);
   g_atr_handle = iATR(g_symbol, PERIOD_CURRENT, ATR_PERIOD);

   if(g_ema_fast_handle == INVALID_HANDLE || g_ema_slow_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
   {
      Print("Fortress FX failed to create indicator handles.");
      return(INIT_FAILED);
   }

   Print("Fortress FX initialized on ", g_symbol, ". EXECUTION_ENABLED=", EXECUTION_ENABLED, ", ENABLE_SIGNALS=", ENABLE_SIGNALS, ", v0.4 filters active.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(g_ema_fast_handle);
   if(g_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(g_ema_slow_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshDailyAnchorIfNeeded();
   if(!AccountGuardAllowsTrading())
      return;

   if(TRADE_ON_NEW_BAR_ONLY && !IsNewBar())
      return;

   if(!SessionAllowed())
      return;

   if(MAX_SIGNALS_PER_DAY > 0 && g_day_signal_count >= MAX_SIGNALS_PER_DAY)
      return;

   if(CountOpenPositionsByMagic() >= MAX_OPEN_TRADES)
      return;

   if(TimeCurrent() - g_last_trade_time < MIN_SECONDS_BETWEEN_TRADES)
      return;

   if(!SpreadAllowed())
      return;

   TradeSignal signal;
   if(!BuildSignal(signal))
      return;

   if(!ValidateSignal(signal))
      return;

   if(!EXECUTION_ENABLED)
   {
      g_last_trade_time = TimeCurrent();
      g_day_signal_count++;
      Print("Signal found but execution disabled: ", signal.direction, " entry=", DoubleToString(signal.entry, _Digits), " sl=", DoubleToString(signal.stop_loss, _Digits), " tp=", DoubleToString(signal.take_profit, _Digits), " lots=", DoubleToString(signal.lots, 2), " dailySignals=", g_day_signal_count);
      return;
   }

   ExecuteSignal(signal);
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_bar_time = iTime(g_symbol, PERIOD_CURRENT, 0);
   if(current_bar_time == 0)
      return false;

   if(current_bar_time == g_last_bar_time)
      return false;

   g_last_bar_time = current_bar_time;
   return true;
}

//+------------------------------------------------------------------+
void ResetDailyAnchor()
{
   MqlDateTime current;
   TimeToStruct(TimeCurrent(), current);
   current.hour = 0;
   current.min = 0;
   current.sec = 0;
   g_day_start_time = StructToTime(current);
   g_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_day_signal_count = 0;
}

//+------------------------------------------------------------------+
void RefreshDailyAnchorIfNeeded()
{
   MqlDateTime current;
   TimeToStruct(TimeCurrent(), current);
   current.hour = 0;
   current.min = 0;
   current.sec = 0;
   datetime today = StructToTime(current);
   if(today != g_day_start_time)
      ResetDailyAnchor();
}

//+------------------------------------------------------------------+
bool AccountGuardAllowsTrading()
{
   if(g_locked)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double daily_loss_pct = 100.0 * MathMax(0.0, g_day_start_equity - equity) / FTMO_ACCOUNT_SIZE;
   double total_loss_pct = 100.0 * MathMax(0.0, FTMO_ACCOUNT_SIZE - equity) / FTMO_ACCOUNT_SIZE;

   if(daily_loss_pct >= FTMO_SOFT_DAILY_STOP_PCT)
   {
      LockBot("Soft daily loss stop reached");
      return false;
   }

   if(total_loss_pct >= FTMO_SOFT_TOTAL_STOP_PCT)
   {
      LockBot("Soft total loss stop reached");
      return false;
   }

   if(daily_loss_pct >= FTMO_DAILY_LOSS_LIMIT_PCT || total_loss_pct >= FTMO_MAX_LOSS_LIMIT_PCT)
   {
      LockBot("Official drawdown limit danger reached");
      return false;
   }

   if(WEEKEND_FLAT && IsWeekend())
      return false;

   return true;
}

//+------------------------------------------------------------------+
void LockBot(string reason)
{
   g_locked = true;
   g_lock_reason = reason;
   Print("FORTRESS FX LOCKED: ", reason);
}

//+------------------------------------------------------------------+
bool IsWeekend()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return (now.day_of_week == 0 || now.day_of_week == 6);
}

//+------------------------------------------------------------------+
bool SessionAllowed()
{
   if(!USE_SESSION_FILTER)
      return true;

   if(SESSION_START_HOUR == SESSION_END_HOUR)
      return true;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   int hour = now.hour;

   if(SESSION_START_HOUR < SESSION_END_HOUR)
      return (hour >= SESSION_START_HOUR && hour < SESSION_END_HOUR);

   return (hour >= SESSION_START_HOUR || hour < SESSION_END_HOUR);
}

//+------------------------------------------------------------------+
bool SpreadAllowed()
{
   long spread = SymbolInfoInteger(g_symbol, SYMBOL_SPREAD);
   return spread > 0 && spread <= MAX_SPREAD_POINTS;
}

//+------------------------------------------------------------------+
int CountOpenPositionsByMagic()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == g_symbol && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
bool BuildSignal(TradeSignal &signal)
{
   if(!ENABLE_SIGNALS)
      return false;

   signal.direction = "";
   signal.entry = 0.0;
   signal.stop_loss = 0.0;
   signal.take_profit = 0.0;
   signal.risk_points = 0.0;
   signal.reward_points = 0.0;
   signal.lots = 0.0;

   double ema_fast[1];
   double ema_slow[1];
   double rsi[1];
   double atr[1];

   if(CopyBuffer(g_ema_fast_handle, 0, 1, 1, ema_fast) != 1) return false;
   if(CopyBuffer(g_ema_slow_handle, 0, 1, 1, ema_slow) != 1) return false;
   if(CopyBuffer(g_rsi_handle, 0, 1, 1, rsi) != 1) return false;
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr) != 1) return false;

   double open_price = iOpen(g_symbol, PERIOD_CURRENT, 1);
   double close_price = iClose(g_symbol, PERIOD_CURRENT, 1);
   if(open_price <= 0.0 || close_price <= 0.0)
      return false;

   double candle_body_points = MathAbs(close_price - open_price) / _Point;
   if(candle_body_points < MIN_CANDLE_BODY_POINTS)
      return false;

   double ema_separation_points = MathAbs(ema_fast[0] - ema_slow[0]) / _Point;
   if(ema_separation_points < MIN_EMA_SEPARATION_POINTS)
      return false;

   double atr_points = atr[0] / _Point;
   if(atr_points < MIN_ATR_POINTS)
      return false;

   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   bool bullish_close = close_price > open_price;
   bool bearish_close = close_price < open_price;

   bool buy_setup = ema_fast[0] > ema_slow[0] && close_price > ema_fast[0] && rsi[0] >= RSI_BUY_MIN && rsi[0] <= RSI_BUY_MAX;
   bool sell_setup = ema_fast[0] < ema_slow[0] && close_price < ema_fast[0] && rsi[0] >= RSI_SELL_MIN && rsi[0] <= RSI_SELL_MAX;

   if(REQUIRE_CANDLE_DIRECTION)
   {
      buy_setup = buy_setup && bullish_close;
      sell_setup = sell_setup && bearish_close;
   }

   if(buy_setup)
   {
      signal.direction = "BUY";
      signal.entry = ask;
      signal.stop_loss = NormalizeDouble(signal.entry - (atr[0] * ATR_STOP_MULTIPLIER), _Digits);
      signal.take_profit = NormalizeDouble(signal.entry + (atr[0] * ATR_TAKE_PROFIT_MULTIPLIER), _Digits);
      return true;
   }

   if(sell_setup)
   {
      signal.direction = "SELL";
      signal.entry = bid;
      signal.stop_loss = NormalizeDouble(signal.entry + (atr[0] * ATR_STOP_MULTIPLIER), _Digits);
      signal.take_profit = NormalizeDouble(signal.entry - (atr[0] * ATR_TAKE_PROFIT_MULTIPLIER), _Digits);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
bool ValidateSignal(TradeSignal &signal)
{
   if(signal.stop_loss <= 0.0 || signal.take_profit <= 0.0)
      return false;

   if(signal.direction == "BUY")
   {
      if(!(signal.stop_loss < signal.entry && signal.entry < signal.take_profit))
         return false;
   }
   else if(signal.direction == "SELL")
   {
      if(!(signal.take_profit < signal.entry && signal.entry < signal.stop_loss))
         return false;
   }
   else
      return false;

   signal.risk_points = MathAbs(signal.entry - signal.stop_loss) / _Point;
   signal.reward_points = MathAbs(signal.take_profit - signal.entry) / _Point;
   if(signal.risk_points <= 0.0)
      return false;

   double reward_risk = signal.reward_points / signal.risk_points;
   if(reward_risk < MIN_REWARD_RISK)
      return false;

   signal.lots = CalculateLotsFromRisk(signal.risk_points);
   return signal.lots > 0.0;
}

//+------------------------------------------------------------------+
double CalculateLotsFromRisk(double risk_points)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double money_risk = equity * (MAX_RISK_PER_TRADE_PCT / 100.0);
   double tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   double volume_min = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

   if(risk_points <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0 || volume_step <= 0.0)
      return 0.0;

   double price_risk = risk_points * _Point;
   double risk_per_lot = (price_risk / tick_size) * tick_value;
   if(risk_per_lot <= 0.0)
      return 0.0;

   double lots = money_risk / risk_per_lot;
   lots = MathFloor(lots / volume_step) * volume_step;
   lots = MathMax(volume_min, MathMin(volume_max, lots));
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
void ExecuteSignal(TradeSignal &signal)
{
   bool sent = false;
   if(signal.direction == "BUY")
      sent = trade.Buy(signal.lots, g_symbol, 0.0, signal.stop_loss, signal.take_profit, "Fortress FX BUY");
   else if(signal.direction == "SELL")
      sent = trade.Sell(signal.lots, g_symbol, 0.0, signal.stop_loss, signal.take_profit, "Fortress FX SELL");

   if(sent)
   {
      g_last_trade_time = TimeCurrent();
      g_day_signal_count++;
      Print("Order sent: ", signal.direction, " lots=", signal.lots, " sl=", signal.stop_loss, " tp=", signal.take_profit, " dailySignals=", g_day_signal_count);
   }
   else
   {
      Print("Order rejected: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}
