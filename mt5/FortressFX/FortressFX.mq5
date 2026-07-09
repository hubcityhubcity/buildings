//+------------------------------------------------------------------+
//| Fortress FX - MT5 Expert Advisor Skeleton                         |
//| Demo-first automation scaffold with FTMO-style guardrails.        |
//+------------------------------------------------------------------+
#property copyright "Hub City"
#property version   "0.1"
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

input int    EMA_FAST_PERIOD                = 20;
input int    EMA_SLOW_PERIOD                = 50;
input int    RSI_PERIOD                     = 14;
input int    ATR_PERIOD                     = 14;
input double MIN_REWARD_RISK                = 1.50;

string       g_symbol;
datetime     g_day_start_time = 0;
double       g_day_start_equity = 0.0;
double       g_initial_balance = 0.0;
datetime     g_last_trade_time = 0;
bool         g_locked = false;
string       g_lock_reason = "";

//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = _Symbol;
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ResetDailyAnchor();
   Print("Fortress FX initialized on ", g_symbol, ". EXECUTION_ENABLED=", EXECUTION_ENABLED);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshDailyAnchorIfNeeded();
   if(!AccountGuardAllowsTrading())
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
      Print("Signal found but execution disabled: ", signal.direction, " entry=", signal.entry, " sl=", signal.stop_loss, " tp=", signal.take_profit);
      return;
   }

   ExecuteSignal(signal);
}

//+------------------------------------------------------------------+
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
   // Placeholder strategy: guarded EMA/RSI trend-pullback prototype.
   // This intentionally returns false until indicator-copy and entry rules are finalized.
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
      Print("Order sent: ", signal.direction, " lots=", signal.lots, " sl=", signal.stop_loss, " tp=", signal.take_profit);
   }
   else
   {
      Print("Order rejected: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}
