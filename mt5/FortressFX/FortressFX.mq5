//+------------------------------------------------------------------+
//| Fortress FX - MT5 Expert Advisor                                  |
//| Demo-first automation scaffold with FTMO-style guardrails.        |
//+------------------------------------------------------------------+
#property copyright "Hub City"
#property version   "0.7"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

enum StrategyModule
{
   STRATEGY_TREND_PULLBACK = 0,
   STRATEGY_OPENING_RANGE_BREAKOUT = 1,
   STRATEGY_DONCHIAN_BREAKOUT = 2
};

input bool           EXECUTION_ENABLED              = false;
input bool           FTMO_MODE                      = true;
input double         FTMO_ACCOUNT_SIZE              = 100000.0;
input double         FTMO_PROFIT_TARGET_PCT         = 10.0;
input double         FTMO_DAILY_LOSS_LIMIT_PCT      = 5.0;
input double         FTMO_MAX_LOSS_LIMIT_PCT        = 10.0;
input double         FTMO_SOFT_DAILY_STOP_PCT       = 3.5;
input double         FTMO_SOFT_TOTAL_STOP_PCT       = 7.5;
input double         MAX_RISK_PER_TRADE_PCT         = 0.25;
input int            MAX_OPEN_TRADES                = 1;
input int            MAGIC_NUMBER                   = 20260709;
input int            MAX_SPREAD_POINTS              = 25;
input int            MIN_SECONDS_BETWEEN_TRADES     = 900;
input bool           WEEKEND_FLAT                   = true;

input bool           ENABLE_SIGNALS                 = true;
input bool           ENABLE_BUY_SIGNALS             = true;
input bool           ENABLE_SELL_SIGNALS            = true;
input StrategyModule STRATEGY_MODULE                = STRATEGY_TREND_PULLBACK;
input bool           TRADE_ON_NEW_BAR_ONLY          = true;
input bool           USE_SESSION_FILTER             = true;
input int            SESSION_START_HOUR             = 7;
input int            SESSION_END_HOUR               = 17;
input int            MAX_SIGNALS_PER_DAY            = 3;

input int            EMA_FAST_PERIOD                = 20;
input int            EMA_SLOW_PERIOD                = 50;
input int            RSI_PERIOD                     = 14;
input int            ATR_PERIOD                     = 14;
input double         ATR_STOP_MULTIPLIER            = 1.50;
input double         ATR_TAKE_PROFIT_MULTIPLIER     = 2.50;
input double         MIN_REWARD_RISK                = 1.50;
input int            MIN_ATR_POINTS                 = 50;

input bool           USE_ADX_FILTER                 = false;
input int            ADX_PERIOD                     = 14;
input double         MIN_ADX_VALUE                  = 18.0;
input bool           REQUIRE_DI_ALIGNMENT           = true;

input int            MIN_BUY_EMA_SEPARATION_POINTS  = 35;
input int            MIN_SELL_EMA_SEPARATION_POINTS = 25;
input int            MIN_BUY_CANDLE_BODY_POINTS     = 25;
input int            MIN_SELL_CANDLE_BODY_POINTS    = 20;
input bool           REQUIRE_CANDLE_DIRECTION       = true;
input double         RSI_BUY_MIN                    = 55.0;
input double         RSI_BUY_MAX                    = 68.0;
input double         RSI_SELL_MIN                   = 30.0;
input double         RSI_SELL_MAX                   = 48.0;

input int            OR_START_HOUR                  = 7;
input int            OR_START_MINUTE                = 0;
input int            OR_END_HOUR                    = 8;
input int            OR_END_MINUTE                  = 0;
input int            OR_TRADE_END_HOUR              = 17;
input int            OR_TRADE_END_MINUTE            = 0;
input int            OR_BREAKOUT_BUFFER_POINTS      = 5;
input int            OR_MIN_RANGE_POINTS            = 40;
input int            OR_MAX_RANGE_POINTS            = 250;
input bool           OR_ONE_TRADE_PER_DAY           = true;

input int            DONCHIAN_LOOKBACK_BARS         = 20;
input int            DONCHIAN_BREAKOUT_BUFFER_POINTS= 5;
input bool           DONCHIAN_REQUIRE_EMA_BIAS      = true;

input bool           USE_LOSS_STREAK_COOLDOWN       = true;
input int            MAX_CONSECUTIVE_LOSSES         = 3;
input int            LOSS_COOLDOWN_MINUTES          = 240;

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
int          g_consecutive_losses = 0;
datetime     g_loss_cooldown_until = 0;
datetime     g_orb_trade_day = 0;
bool         g_locked = false;
string       g_lock_reason = "";
int          g_ema_fast_handle = INVALID_HANDLE;
int          g_ema_slow_handle = INVALID_HANDLE;
int          g_rsi_handle = INVALID_HANDLE;
int          g_atr_handle = INVALID_HANDLE;
int          g_adx_handle = INVALID_HANDLE;

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
   g_adx_handle = iADX(g_symbol, PERIOD_CURRENT, ADX_PERIOD);

   if(g_ema_fast_handle == INVALID_HANDLE || g_ema_slow_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE || g_adx_handle == INVALID_HANDLE)
   {
      Print("Fortress FX failed to create indicator handles.");
      return(INIT_FAILED);
   }

   Print("Fortress FX initialized on ", g_symbol, ". v0.7 strategy module pack active. Module=", (int)STRATEGY_MODULE, ", EXECUTION_ENABLED=", EXECUTION_ENABLED);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(g_ema_fast_handle);
   if(g_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(g_ema_slow_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong deal_ticket = trans.deal;
   if(deal_ticket == 0)
      return;

   if(!HistoryDealSelect(deal_ticket))
      return;

   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != g_symbol)
      return;

   if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != MAGIC_NUMBER)
      return;

   ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT && deal_entry != DEAL_ENTRY_OUT_BY)
      return;

   double net_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                     + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                     + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

   if(net_profit < 0.0)
   {
      g_consecutive_losses++;
      Print("Closed losing trade. Consecutive losses=", g_consecutive_losses, ", net=", DoubleToString(net_profit, 2));

      if(USE_LOSS_STREAK_COOLDOWN && MAX_CONSECUTIVE_LOSSES > 0 && g_consecutive_losses >= MAX_CONSECUTIVE_LOSSES)
      {
         g_loss_cooldown_until = TimeCurrent() + (LOSS_COOLDOWN_MINUTES * 60);
         Print("Loss-streak cooldown active until ", TimeToString(g_loss_cooldown_until, TIME_DATE|TIME_MINUTES), ".");
      }
   }
   else if(net_profit > 0.0)
   {
      if(g_consecutive_losses > 0)
         Print("Closed winning trade. Consecutive loss counter reset.");
      g_consecutive_losses = 0;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshDailyAnchorIfNeeded();
   if(!AccountGuardAllowsTrading())
      return;

   if(LossCooldownActive())
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
bool LossCooldownActive()
{
   if(!USE_LOSS_STREAK_COOLDOWN)
      return false;

   if(g_loss_cooldown_until <= 0)
      return false;

   if(TimeCurrent() >= g_loss_cooldown_until)
   {
      g_loss_cooldown_until = 0;
      g_consecutive_losses = 0;
      Print("Loss-streak cooldown cleared.");
      return false;
   }

   return true;
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

   ResetSignal(signal);

   double ema_fast[1];
   double ema_slow[1];
   double rsi[1];
   double atr[1];
   double adx[1];
   double plus_di[1];
   double minus_di[1];

   if(CopyBuffer(g_ema_fast_handle, 0, 1, 1, ema_fast) != 1) return false;
   if(CopyBuffer(g_ema_slow_handle, 0, 1, 1, ema_slow) != 1) return false;
   if(CopyBuffer(g_rsi_handle, 0, 1, 1, rsi) != 1) return false;
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr) != 1) return false;

   if(USE_ADX_FILTER)
   {
      if(CopyBuffer(g_adx_handle, 0, 1, 1, adx) != 1) return false;
      if(CopyBuffer(g_adx_handle, 1, 1, 1, plus_di) != 1) return false;
      if(CopyBuffer(g_adx_handle, 2, 1, 1, minus_di) != 1) return false;
      if(adx[0] < MIN_ADX_VALUE)
         return false;
   }

   double open_price = iOpen(g_symbol, PERIOD_CURRENT, 1);
   double close_price = iClose(g_symbol, PERIOD_CURRENT, 1);
   double high_price = iHigh(g_symbol, PERIOD_CURRENT, 1);
   double low_price = iLow(g_symbol, PERIOD_CURRENT, 1);

   if(open_price <= 0.0 || close_price <= 0.0 || high_price <= 0.0 || low_price <= 0.0)
      return false;

   double atr_points = atr[0] / _Point;
   if(atr_points < MIN_ATR_POINTS)
      return false;

   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   bool built = false;

   if(STRATEGY_MODULE == STRATEGY_TREND_PULLBACK)
      built = BuildTrendPullback(signal, ema_fast[0], ema_slow[0], rsi[0], atr[0], open_price, close_price, ask, bid);
   else if(STRATEGY_MODULE == STRATEGY_OPENING_RANGE_BREAKOUT)
      built = BuildOpeningRangeBreakout(signal, atr[0], close_price, ask, bid);
   else if(STRATEGY_MODULE == STRATEGY_DONCHIAN_BREAKOUT)
      built = BuildDonchianBreakout(signal, ema_fast[0], ema_slow[0], atr[0], close_price, ask, bid);

   if(!built)
      return false;

   if(USE_ADX_FILTER && REQUIRE_DI_ALIGNMENT)
   {
      if(signal.direction == "BUY" && plus_di[0] <= minus_di[0])
         return false;
      if(signal.direction == "SELL" && minus_di[0] <= plus_di[0])
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
void ResetSignal(TradeSignal &signal)
{
   signal.direction = "";
   signal.entry = 0.0;
   signal.stop_loss = 0.0;
   signal.take_profit = 0.0;
   signal.risk_points = 0.0;
   signal.reward_points = 0.0;
   signal.lots = 0.0;
}

//+------------------------------------------------------------------+
bool BuildTrendPullback(TradeSignal &signal, double ema_fast, double ema_slow, double rsi, double atr, double open_price, double close_price, double ask, double bid)
{
   double candle_body_points = MathAbs(close_price - open_price) / _Point;
   double ema_separation_points = MathAbs(ema_fast - ema_slow) / _Point;
   bool bullish_close = close_price > open_price;
   bool bearish_close = close_price < open_price;

   bool buy_setup = ENABLE_BUY_SIGNALS && ema_fast > ema_slow && close_price > ema_fast && rsi >= RSI_BUY_MIN && rsi <= RSI_BUY_MAX;
   bool sell_setup = ENABLE_SELL_SIGNALS && ema_fast < ema_slow && close_price < ema_fast && rsi >= RSI_SELL_MIN && rsi <= RSI_SELL_MAX;

   buy_setup = buy_setup && ema_separation_points >= MIN_BUY_EMA_SEPARATION_POINTS && candle_body_points >= MIN_BUY_CANDLE_BODY_POINTS;
   sell_setup = sell_setup && ema_separation_points >= MIN_SELL_EMA_SEPARATION_POINTS && candle_body_points >= MIN_SELL_CANDLE_BODY_POINTS;

   if(REQUIRE_CANDLE_DIRECTION)
   {
      buy_setup = buy_setup && bullish_close;
      sell_setup = sell_setup && bearish_close;
   }

   if(buy_setup)
      return SetAtrSignal(signal, "BUY", ask, atr);

   if(sell_setup)
      return SetAtrSignal(signal, "SELL", bid, atr);

   return false;
}

//+------------------------------------------------------------------+
bool BuildOpeningRangeBreakout(TradeSignal &signal, double atr, double close_price, double ask, double bid)
{
   datetime range_start = TodayAt(OR_START_HOUR, OR_START_MINUTE);
   datetime range_end = TodayAt(OR_END_HOUR, OR_END_MINUTE);
   datetime trade_end = TodayAt(OR_TRADE_END_HOUR, OR_TRADE_END_MINUTE);
   datetime now = TimeCurrent();

   if(now < range_end || now >= trade_end)
      return false;

   if(OR_ONE_TRADE_PER_DAY && g_orb_trade_day == g_day_start_time)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   if(!CalculateOpeningRange(range_start, range_end, range_high, range_low))
      return false;

   double range_points = (range_high - range_low) / _Point;
   if(range_points < OR_MIN_RANGE_POINTS || range_points > OR_MAX_RANGE_POINTS)
      return false;

   double buy_trigger = range_high + (OR_BREAKOUT_BUFFER_POINTS * _Point);
   double sell_trigger = range_low - (OR_BREAKOUT_BUFFER_POINTS * _Point);

   if(ENABLE_BUY_SIGNALS && close_price > buy_trigger)
      return SetAtrSignal(signal, "BUY", ask, atr);

   if(ENABLE_SELL_SIGNALS && close_price < sell_trigger)
      return SetAtrSignal(signal, "SELL", bid, atr);

   return false;
}

//+------------------------------------------------------------------+
bool CalculateOpeningRange(datetime range_start, datetime range_end, double &range_high, double &range_low)
{
   MqlRates rates[];
   int copied = CopyRates(g_symbol, PERIOD_CURRENT, range_start, range_end, rates);
   if(copied <= 0)
      return false;

   range_high = -1.0e100;
   range_low = 1.0e100;

   for(int i = 0; i < copied; i++)
   {
      if(rates[i].time >= range_start && rates[i].time < range_end)
      {
         if(rates[i].high > range_high) range_high = rates[i].high;
         if(rates[i].low < range_low) range_low = rates[i].low;
      }
   }

   return (range_high > range_low && range_high > 0.0 && range_low > 0.0);
}

//+------------------------------------------------------------------+
bool BuildDonchianBreakout(TradeSignal &signal, double ema_fast, double ema_slow, double atr, double close_price, double ask, double bid)
{
   if(DONCHIAN_LOOKBACK_BARS < 5)
      return false;

   double highest_high = HighestHigh(DONCHIAN_LOOKBACK_BARS, 2);
   double lowest_low = LowestLow(DONCHIAN_LOOKBACK_BARS, 2);
   if(highest_high <= 0.0 || lowest_low <= 0.0 || highest_high <= lowest_low)
      return false;

   double buy_trigger = highest_high + (DONCHIAN_BREAKOUT_BUFFER_POINTS * _Point);
   double sell_trigger = lowest_low - (DONCHIAN_BREAKOUT_BUFFER_POINTS * _Point);

   bool buy_setup = ENABLE_BUY_SIGNALS && close_price > buy_trigger;
   bool sell_setup = ENABLE_SELL_SIGNALS && close_price < sell_trigger;

   if(DONCHIAN_REQUIRE_EMA_BIAS)
   {
      buy_setup = buy_setup && ema_fast > ema_slow;
      sell_setup = sell_setup && ema_fast < ema_slow;
   }

   if(buy_setup)
      return SetAtrSignal(signal, "BUY", ask, atr);

   if(sell_setup)
      return SetAtrSignal(signal, "SELL", bid, atr);

   return false;
}

//+------------------------------------------------------------------+
double HighestHigh(int lookback, int start_shift)
{
   double result = -1.0e100;
   for(int i = start_shift; i < start_shift + lookback; i++)
   {
      double high = iHigh(g_symbol, PERIOD_CURRENT, i);
      if(high <= 0.0)
         return 0.0;
      if(high > result)
         result = high;
   }
   return result;
}

//+------------------------------------------------------------------+
double LowestLow(int lookback, int start_shift)
{
   double result = 1.0e100;
   for(int i = start_shift; i < start_shift + lookback; i++)
   {
      double low = iLow(g_symbol, PERIOD_CURRENT, i);
      if(low <= 0.0)
         return 0.0;
      if(low < result)
         result = low;
   }
   return result;
}

//+------------------------------------------------------------------+
bool SetAtrSignal(TradeSignal &signal, string direction, double entry, double atr)
{
   signal.direction = direction;
   signal.entry = entry;

   if(direction == "BUY")
   {
      signal.stop_loss = NormalizeDouble(entry - (atr * ATR_STOP_MULTIPLIER), _Digits);
      signal.take_profit = NormalizeDouble(entry + (atr * ATR_TAKE_PROFIT_MULTIPLIER), _Digits);
      return true;
   }

   if(direction == "SELL")
   {
      signal.stop_loss = NormalizeDouble(entry + (atr * ATR_STOP_MULTIPLIER), _Digits);
      signal.take_profit = NormalizeDouble(entry - (atr * ATR_TAKE_PROFIT_MULTIPLIER), _Digits);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
datetime TodayAt(int hour, int minute)
{
   MqlDateTime current;
   TimeToStruct(g_day_start_time, current);
   current.hour = hour;
   current.min = minute;
   current.sec = 0;
   return StructToTime(current);
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
      if(STRATEGY_MODULE == STRATEGY_OPENING_RANGE_BREAKOUT)
         g_orb_trade_day = g_day_start_time;
      Print("Order sent: ", signal.direction, " lots=", signal.lots, " sl=", signal.stop_loss, " tp=", signal.take_profit, " dailySignals=", g_day_signal_count, " module=", (int)STRATEGY_MODULE);
   }
   else
   {
      Print("Order rejected: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}
