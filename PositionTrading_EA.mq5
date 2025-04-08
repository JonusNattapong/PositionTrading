//+------------------------------------------------------------------+
//|                                             PositionTrading_EA.mq5 |
//|                                Copyright 2025, Your Company Name    |
//|                                       www.yourcompanywebsite.com    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "www.yourcompanywebsite.com"
#property version   "1.00"
#property description "Position Trading EA based on EMA200 and Ichimoku Cloud"
#property strict

// Input Parameters
input ENUM_TIMEFRAMES TimeframeMain = PERIOD_D1;          // Main Timeframe for Entry/Exit
input ENUM_TIMEFRAMES TimeframeTrend = PERIOD_W1;         // Timeframe for Major Trend Analysis
input int EMA_Period = 200;                               // EMA Period
input int Ichimoku_Tenkan = 9;                            // Ichimoku Tenkan-sen Period
input int Ichimoku_Kijun = 26;                            // Ichimoku Kijun-sen Period
input int Ichimoku_Senkou = 52;                           // Ichimoku Senkou Span B Period
input int ATR_Period = 14;                                // ATR Period for Stop Loss Calculation
input double ATR_Multiplier = 2.0;                        // ATR Multiplier for Stop Loss
input double RiskPercentage = 1.0;                        // Risk % per trade (1-2% recommended)
input bool EnableTrailingStop = true;                     // Enable Trailing Stop Loss
input bool UseBreakEven = true;                           // Move SL to Breakeven after profit
input double BreakEvenPips = 50.0;                        // Pips in profit to move to breakeven
input double TrailingStopDistance = 0.0;                  // Fixed Trailing Stop (0 for ATR-based)
input bool UsePartialClose = false;                       // Enable Partial Profit Taking
input double PartialClosePercent = 50.0;                  // Percentage to close at first target
input double TakeProfitFactor = 3.0;                      // TP distance as multiple of SL distance
input bool UseIchimokuFilters = true;                     // Use Ichimoku Cloud as filter
input bool RequireChikouConfirmation = false;             // Require Chikou Span confirmation
input bool CheckWeeklyTrend = true;                       // Check Weekly timeframe for major trend
input bool EnableNewsFilter = false;                       // Filter entries near major news events
input int MaxSpread = 50;                                 // Maximum allowed spread in points
input int MagicNumber = 20250408;                         // Magic Number for this EA

// Global variables
int handle_ema200_main;                                   // Handle for EMA 200 on main timeframe
int handle_ema200_trend;                                  // Handle for EMA 200 on trend timeframe
int handle_ichimoku_main;                                 // Handle for Ichimoku on main timeframe
int handle_ichimoku_trend;                                // Handle for Ichimoku on trend timeframe
int handle_atr;                                           // Handle for ATR indicator
double point;                                             // Symbol point value
int digits;                                               // Symbol digits
double pips_adj;                                          // Adjustment for 3/5 digit brokers
bool first_run = true;                                    // Flag for first run initialization
datetime last_bar_time;                                   // Time of the last processed bar
int partial_ticket = 0;                                   // Ticket of partially closed position

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicator handles
   handle_ema200_main = iMA(_Symbol, TimeframeMain, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema200_trend = iMA(_Symbol, TimeframeTrend, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   handle_ichimoku_main = iIchimoku(_Symbol, TimeframeMain, Ichimoku_Tenkan, Ichimoku_Kijun, Ichimoku_Senkou);
   handle_ichimoku_trend = iIchimoku(_Symbol, TimeframeTrend, Ichimoku_Tenkan, Ichimoku_Kijun, Ichimoku_Senkou);
   handle_atr = iATR(_Symbol, TimeframeMain, ATR_Period);
   
   // Check if indicators were created successfully
   if(handle_ema200_main == INVALID_HANDLE || handle_ichimoku_main == INVALID_HANDLE || 
      handle_atr == INVALID_HANDLE || handle_ema200_trend == INVALID_HANDLE || 
      handle_ichimoku_trend == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }
   
   // Calculate point value and adjustment for 3/5 digit brokers
   digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   pips_adj = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   
   // Reset state
   first_run = true;
   last_bar_time = 0;
   
   // Display EA information
   Print("Position Trading EA initialized on ", _Symbol);
   Print("Main Timeframe: ", EnumToString(TimeframeMain), ", Trend Timeframe: ", EnumToString(TimeframeTrend));
   Print("Risk per trade: ", RiskPercentage, "%, ATR Multiplier for SL: ", ATR_Multiplier);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handle_ema200_main != INVALID_HANDLE) IndicatorRelease(handle_ema200_main);
   if(handle_ema200_trend != INVALID_HANDLE) IndicatorRelease(handle_ema200_trend);
   if(handle_ichimoku_main != INVALID_HANDLE) IndicatorRelease(handle_ichimoku_main);
   if(handle_ichimoku_trend != INVALID_HANDLE) IndicatorRelease(handle_ichimoku_trend);
   if(handle_atr != INVALID_HANDLE) IndicatorRelease(handle_atr);
   
   Print("Position Trading EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if spread is not too high
   double current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread > MaxSpread)
   {
      // Comment("Spread too high: ", current_spread, " > ", MaxSpread);
      return;
   }
   
   // Check for new bar on the main timeframe
   datetime current_bar_time = iTime(_Symbol, TimeframeMain, 0);
   bool new_bar = (current_bar_time > last_bar_time);
   
   if(first_run || new_bar)
   {
      first_run = false;
      last_bar_time = current_bar_time;
      
      // Process open positions - trailing stop, breakeven, etc.
      ManageOpenPositions();
      
      // Only check for new entry signals on new bar
      if(new_bar)
      {
         // Check if we already have an open position
         bool has_position = HasOpenPosition();
         
         // Only look for new entry signals if no position is open
         if(!has_position)
         {
            CheckForEntrySignals();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for entry signals based on strategy rules                  |
//+------------------------------------------------------------------+
void CheckForEntrySignals()
{
   // Wait for indicators to be ready
   int bars_calculated = BarsCalculated(handle_ema200_main);
   if(bars_calculated < 200) 
   {
      Print("Not enough bars calculated for EMA200: ", bars_calculated);
      return;
   }
   
   // Get indicator values
   double ema200_main[], tenkan[], kijun[], senkou_a[], senkou_b[], chikou[];
   double ema200_trend[];
   double atr[];
   
   // Main timeframe indicators
   if(CopyBuffer(handle_ema200_main, 0, 0, 3, ema200_main) <= 0) return;
   if(CopyBuffer(handle_ichimoku_main, 0, 0, 3, tenkan) <= 0) return;      // Tenkan-sen
   if(CopyBuffer(handle_ichimoku_main, 1, 0, 3, kijun) <= 0) return;       // Kijun-sen
   if(CopyBuffer(handle_ichimoku_main, 2, 0, 3, senkou_a) <= 0) return;    // Senkou Span A
   if(CopyBuffer(handle_ichimoku_main, 3, 0, 3, senkou_b) <= 0) return;    // Senkou Span B
   if(CopyBuffer(handle_ichimoku_main, 4, 0, Ichimoku_Kijun + 3, chikou) <= 0) return; // Chikou Span
   
   // Trend timeframe indicators (Weekly)
   if(CheckWeeklyTrend)
   {
      if(CopyBuffer(handle_ema200_trend, 0, 0, 3, ema200_trend) <= 0) return;
   }
   
   // ATR for stop loss calculation
   if(CopyBuffer(handle_atr, 0, 0, 3, atr) <= 0) return;
   
   // Get price data
   MqlRates rates[];
   if(CopyRates(_Symbol, TimeframeMain, 0, 3, rates) <= 0) return;
   
   // Current values
   double current_close = rates[0].close;
   double current_open = rates[0].open;
   
   // Check for buy signals
   bool buy_signal = false;
   
   // 1. Price is above EMA 200 on main timeframe
   bool above_ema200_main = (current_close > ema200_main[0]);
   
   // 2. Price is above Kumo (Senkou A and B)
   bool above_kumo = (current_close > senkou_a[0] && current_close > senkou_b[0]);
   
   // 3. Tenkan is above Kijun (bullish Ichimoku confirmation)
   bool tenkan_above_kijun = (tenkan[0] > kijun[0]);
   
   // 4. Chikou Span confirmation (optional)
   bool chikou_confirmation = true;
   if(RequireChikouConfirmation)
   {
      // Check if Chikou (current price shifted back) is above the price at that point
      if(chikou[Ichimoku_Kijun] > rates[Ichimoku_Kijun].close)
         chikou_confirmation = true;
      else
         chikou_confirmation = false;
   }
   
   // 5. Check Weekly trend if enabled
   bool weekly_uptrend = true;
   if(CheckWeeklyTrend)
   {
      weekly_uptrend = (current_close > ema200_trend[0]);
   }
   
   // Combine all buy conditions
   buy_signal = above_ema200_main && above_kumo && tenkan_above_kijun && 
               chikou_confirmation && weekly_uptrend;
               
   // Check for sell signals
   bool sell_signal = false;
   
   // 1. Price is below EMA 200 on main timeframe
   bool below_ema200_main = (current_close < ema200_main[0]);
   
   // 2. Price is below Kumo (Senkou A and B)
   bool below_kumo = (current_close < senkou_a[0] && current_close < senkou_b[0]);
   
   // 3. Tenkan is below Kijun (bearish Ichimoku confirmation)
   bool tenkan_below_kijun = (tenkan[0] < kijun[0]);
   
   // 4. Chikou Span confirmation (optional)
   bool chikou_bear_confirmation = true;
   if(RequireChikouConfirmation)
   {
      // Check if Chikou (current price shifted back) is below the price at that point
      if(chikou[Ichimoku_Kijun] < rates[Ichimoku_Kijun].close)
         chikou_bear_confirmation = true;
      else
         chikou_bear_confirmation = false;
   }
   
   // 5. Check Weekly trend if enabled
   bool weekly_downtrend = true;
   if(CheckWeeklyTrend)
   {
      weekly_downtrend = (current_close < ema200_trend[0]);
   }
   
   // Combine all sell conditions
   sell_signal = below_ema200_main && below_kumo && tenkan_below_kijun && 
                chikou_bear_confirmation && weekly_downtrend;
   
   // Open trades if signals are triggered
   if(buy_signal)
   {
      // Calculate stop loss based on ATR
      double stop_loss = current_close - (atr[0] * ATR_Multiplier);
      double sl_distance = current_close - stop_loss;
      
      // Calculate position size based on risk percentage
      double position_size = CalculatePositionSize(POSITION_TYPE_BUY, current_close, stop_loss);
      
      // Calculate take profit based on risk-reward ratio
      double take_profit = current_close + (sl_distance * TakeProfitFactor);
      
      // Open buy position
      OpenPosition(POSITION_TYPE_BUY, position_size, stop_loss, take_profit);
   }
   else if(sell_signal)
   {
      // Calculate stop loss based on ATR
      double stop_loss = current_close + (atr[0] * ATR_Multiplier);
      double sl_distance = stop_loss - current_close;
      
      // Calculate position size based on risk percentage
      double position_size = CalculatePositionSize(POSITION_TYPE_SELL, current_close, stop_loss);
      
      // Calculate take profit based on risk-reward ratio
      double take_profit = current_close - (sl_distance * TakeProfitFactor);
      
      // Open sell position
      OpenPosition(POSITION_TYPE_SELL, position_size, stop_loss, take_profit);
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                 |
//+------------------------------------------------------------------+
double CalculatePositionSize(ENUM_POSITION_TYPE position_type, double entry_price, double stop_loss)
{
   // Calculate risk amount in account currency
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (RiskPercentage / 100.0);
   
   // Calculate stop loss distance in points
   double sl_distance = 0;
   if(position_type == POSITION_TYPE_BUY)
      sl_distance = entry_price - stop_loss;
   else
      sl_distance = stop_loss - entry_price;
      
   // Convert to points
   sl_distance = MathAbs(sl_distance) / point;
   
   // Calculate trade size
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double points_per_tick = tick_size / point;
   
   double value_per_point = tick_value / points_per_tick;
   
   // Calculate lot size
   double lot_size = 0;
   if(sl_distance > 0 && value_per_point > 0)
      lot_size = risk_amount / (sl_distance * value_per_point);
   
   // Adjust to allowed lot step
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   lot_size = MathMax(min_lot, MathMin(lot_size, max_lot));
   
   // Return calculated lot size
   return lot_size;
}

//+------------------------------------------------------------------+
//| Open a new position with specified parameters                    |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_POSITION_TYPE position_type, double lot_size, double stop_loss, double take_profit)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Prepare the request
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot_size;
   request.type = position_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(_Symbol, position_type == POSITION_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
   request.sl = stop_loss;
   request.tp = take_profit;
   request.deviation = 10; // Allow slippage
   request.type_filling = ORDER_FILLING_FOK;
   request.magic = MagicNumber;
   request.comment = "Position Trading EA";
   
   // Send the request
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError(), " - ", result.retcode);
      return;
   }
   
   // Log successful order
   string position_type_str = position_type == POSITION_TYPE_BUY ? "BUY" : "SELL";
   Print("Position opened: ", position_type_str, " ", lot_size, " lots at ", request.price, 
         ", SL: ", stop_loss, ", TP: ", take_profit);
}

//+------------------------------------------------------------------+
//| Check if there is an open position for this EA                   |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage existing open positions (trailing stop, breakeven)        |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // Select the position
      if(!PositionGetSymbol(i))
         continue;
      
      // Check if this position belongs to our EA
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      
      // Get position details
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double position_sl = PositionGetDouble(POSITION_SL);
      double position_tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double position_profit = PositionGetDouble(POSITION_PROFIT);
      double current_price = position_type == POSITION_TYPE_BUY ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Get ATR value for dynamic trailing
      double atr[];
      if(CopyBuffer(handle_atr, 0, 0, 1, atr) <= 0) return;
      
      // Calculate breakeven level (consider point adjustment for 3/5 digit brokers)
      double breakeven_trigger = BreakEvenPips * point * pips_adj;
      
      // Implement breakeven strategy
      if(UseBreakEven && position_sl != position_open_price)
      {
         if(position_type == POSITION_TYPE_BUY && current_price > position_open_price + breakeven_trigger)
         {
            ModifyPosition(ticket, position_open_price, position_tp);
            Print("Moved stop loss to breakeven for ticket #", ticket);
         }
         else if(position_type == POSITION_TYPE_SELL && current_price < position_open_price - breakeven_trigger)
         {
            ModifyPosition(ticket, position_open_price, position_tp);
            Print("Moved stop loss to breakeven for ticket #", ticket);
         }
      }
      
      // Implement trailing stop
      if(EnableTrailingStop)
      {
         // Calculate trailing stop level
         double new_sl = 0;
         
         if(TrailingStopDistance > 0)
         {
            // Fixed trailing stop
            double trailing_distance = TrailingStopDistance * point * pips_adj;
            
            if(position_type == POSITION_TYPE_BUY)
            {
               new_sl = current_price - trailing_distance;
               if(new_sl > position_sl && new_sl > position_open_price)
               {
                  ModifyPosition(ticket, new_sl, position_tp);
                  Print("Updated trailing stop to ", new_sl, " for ticket #", ticket);
               }
            }
            else if(position_type == POSITION_TYPE_SELL)
            {
               new_sl = current_price + trailing_distance;
               if((new_sl < position_sl || position_sl == 0) && new_sl < position_open_price)
               {
                  ModifyPosition(ticket, new_sl, position_tp);
                  Print("Updated trailing stop to ", new_sl, " for ticket #", ticket);
               }
            }
         }
         else
         {
            // ATR-based trailing stop
            double atr_trailing = atr[0] * ATR_Multiplier;
            
            if(position_type == POSITION_TYPE_BUY)
            {
               new_sl = current_price - atr_trailing;
               if(new_sl > position_sl && new_sl > position_open_price)
               {
                  ModifyPosition(ticket, new_sl, position_tp);
                  Print("Updated ATR trailing stop to ", new_sl, " for ticket #", ticket);
               }
            }
            else if(position_type == POSITION_TYPE_SELL)
            {
               new_sl = current_price + atr_trailing;
               if((new_sl < position_sl || position_sl == 0) && new_sl < position_open_price)
               {
                  ModifyPosition(ticket, new_sl, position_tp);
                  Print("Updated ATR trailing stop to ", new_sl, " for ticket #", ticket);
               }
            }
         }
      }
      
      // Implement partial close at first target
      if(UsePartialClose && partial_ticket != ticket)
      {
         double risk_distance = MathAbs(position_open_price - position_sl);
         double first_target = position_type == POSITION_TYPE_BUY ? 
                              position_open_price + risk_distance : 
                              position_open_price - risk_distance;
         
         // Check if price reached first target
         bool target_reached = (position_type == POSITION_TYPE_BUY && current_price >= first_target) ||
                              (position_type == POSITION_TYPE_SELL && current_price <= first_target);
         
         if(target_reached)
         {
            double position_volume = PositionGetDouble(POSITION_VOLUME);
            double close_volume = position_volume * (PartialClosePercent / 100.0);
            
            // Close partial position
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = close_volume;
            request.type = position_type == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = current_price;
            request.deviation = 10;
            request.magic = MagicNumber;
            request.comment = "Partial Close at first target";
            
            // Send the request
            if(OrderSend(request, result))
            {
               Print("Partial close executed for ticket #", ticket, ": ", close_volume, " lots");
               partial_ticket = ticket; // Mark this ticket as partially closed
            }
            else
            {
               Print("Failed to execute partial close: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify position's stop loss and take profit                      |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double new_sl, double new_tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   // Prepare the request
   request.action = TRADE_ACTION_MODIFY;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = new_sl;
   request.tp = new_tp;
   
   // Send the request
   if(!OrderSend(request, result))
   {
      Print("ModifyPosition error: ", GetLastError(), " - ", result.retcode);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
// Additional functions can be added here for more advanced features
// Examples:
// - News filter implementation
// - Breakout detection
// - Multi-timeframe signal confirmation
// - Trend strength analysis
// - Custom logging and statistics
//+------------------------------------------------------------------+