import pandas as pd
import pandas_ta as ta
import numpy as np

def load_data(filepath):
    """
    Loads historical price data from a CSV file.
    Expects columns: 'Date', 'Open', 'High', 'Low', 'Close', 'Volume'
    """
    try:
        df = pd.read_csv(filepath, parse_dates=['Date'], index_col='Date')
        # Ensure standard column names (adjust if your CSV uses different names)
        df.rename(columns={
            'open': 'Open', 'high': 'High', 'low': 'Low', 'close': 'Close', 'volume': 'Volume'
        }, inplace=True, errors='ignore') # Use errors='ignore' in case columns are already correct
        df.sort_index(inplace=True)
        print(f"Data loaded successfully from {filepath}")
        print(f"Data range: {df.index.min()} to {df.index.max()}")
        print(f"Columns: {df.columns.tolist()}")
        return df
    except FileNotFoundError:
        print(f"Error: Data file not found at {filepath}")
        print("Please provide a CSV file with OHLCV data.")
        return None
    except Exception as e:
        print(f"Error loading data: {e}")
        return None

def calculate_indicators(df):
    """
    Calculates technical indicators based on the Trading Plan.
    """
    if df is None or df.empty:
        return None

    print("Calculating indicators...")
    # EMA 200 (Section 2, 3)
    df['EMA200'] = ta.ema(df['Close'], length=200)

    # Ichimoku Cloud (Section 2, 3)
    # pandas_ta uses standard Ichimoku parameters (9, 26, 52)
    # Adjust parameters here if needed based on specific plan details (not explicitly mentioned)
    ichimoku_df = ta.ichimoku(df['High'], df['Low'], df['Close'])
    # Rename columns for clarity based on TradingPlan.md references
    df['TENKAN'] = ichimoku_df.iloc[:, 0] # Tenkan-sen
    df['KIJUN'] = ichimoku_df.iloc[:, 1]  # Kijun-sen
    df['SENKOU_A'] = ichimoku_df.iloc[:, 2] # Senkou Span A
    df['SENKOU_B'] = ichimoku_df.iloc[:, 3] # Senkou Span B
    df['CHIKOU'] = ichimoku_df.iloc[:, 4]  # Chikou Span (Lagging Span)

    # Add other optional indicators if needed (e.g., ATR for SL - Section 5)
    df['ATR'] = ta.atr(df['High'], df['Low'], df['Close'], length=14) # Common ATR length

    print("Indicators calculated.")
    df.dropna(inplace=True) # Remove rows with NaN values generated by indicators
    return df

def apply_strategy(df):
    """
    Applies the trading strategy rules to generate signals.
    Returns a DataFrame with 'Signal' column (1 for Buy, -1 for Sell, 0 for Hold).
    """
    if df is None or df.empty:
        return None

    print("Applying strategy rules...")
    df['Signal'] = 0 # Default to Hold

    # --- Entry Criteria (Section 4) ---

    # Buy Conditions (Long Entry)
    buy_condition_1 = (df['Close'] > df['EMA200']) & (df['Close'] > df['SENKOU_A']) & (df['Close'] > df['SENKOU_B']) # Trend Up (Price > EMA200 & Price > Kumo)
    buy_condition_2 = (df['TENKAN'] > df['KIJUN']) # Tenkan > Kijun (Ichimoku confirmation)
    # Add Breakout/Pullback logic here - Requires more complex state tracking or pattern recognition
    # For simplicity, we'll start with the indicator conditions
    # buy_condition_3 = (df['CHIKOU'] > df['Close'].shift(26)) # Chikou Span confirmation (optional, using standard 26 period shift)

    # Combine Buy Conditions (Simplified for now)
    df.loc[buy_condition_1 & buy_condition_2, 'Signal'] = 1

    # Sell Conditions (Short Entry)
    sell_condition_1 = (df['Close'] < df['EMA200']) & (df['Close'] < df['SENKOU_A']) & (df['Close'] < df['SENKOU_B']) # Trend Down (Price < EMA200 & Price < Kumo)
    sell_condition_2 = (df['TENKAN'] < df['KIJUN']) # Tenkan < Kijun (Ichimoku confirmation)
    # Add Breakout/Pullback logic here
    # sell_condition_3 = (df['CHIKOU'] < df['Close'].shift(26)) # Chikou Span confirmation (optional)

    # Combine Sell Conditions (Simplified for now)
    df.loc[sell_condition_1 & sell_condition_2, 'Signal'] = -1

    # --- Exit Criteria (Section 5) ---
    # Stop Loss and Take Profit logic will be handled during the backtest simulation loop
    # as they depend on the entry price and ongoing price action.

    # Prevent conflicting signals on the same bar (optional, depends on handling)
    # Example: If both buy and sell conditions are met, prioritize one or set to Hold (0)
    # This simple version might generate buy/sell on the same bar if conditions overlap briefly.

    print("Strategy signals generated.")
    return df

def run_backtest(df, initial_capital=10000, risk_per_trade=0.01):
    """
    Runs the backtest simulation based on signals and strategy rules.
    Calculates performance metrics.
    """
    if df is None or df.empty or 'Signal' not in df.columns:
        print("Error: Cannot run backtest. Invalid data or signals.")
        return None

    print("Running backtest simulation...")
    capital = initial_capital
    position = 0 # 0: No position, 1: Long, -1: Short
    entry_price = 0
    stop_loss_price = 0
    trades = []
    equity_curve = [initial_capital]

    for i in range(1, len(df)):
        current_signal = df['Signal'].iloc[i]
        prev_signal = df['Signal'].iloc[i-1]
        current_close = df['Close'].iloc[i]
        current_low = df['Low'].iloc[i]
        current_high = df['High'].iloc[i]
        current_atr = df['ATR'].iloc[i] if 'ATR' in df.columns else 0 # Use ATR for SL if available

        # --- Check for Stop Loss ---
        if position == 1 and current_low <= stop_loss_price: # Long position stopped out
            exit_price = stop_loss_price
            profit = (exit_price - entry_price) * position_size
            capital += profit
            trades.append({
                'EntryDate': entry_date, 'ExitDate': df.index[i], 'Type': 'Long',
                'EntryPrice': entry_price, 'ExitPrice': exit_price,
                'StopLoss': stop_loss_price, 'Profit': profit, 'Reason': 'Stop Loss'
            })
            print(f"{df.index[i]} - STOP LOSS (Long): Exit at {exit_price:.2f}, Profit: {profit:.2f}, Capital: {capital:.2f}")
            position = 0
            entry_price = 0
        elif position == -1 and current_high >= stop_loss_price: # Short position stopped out
            exit_price = stop_loss_price
            profit = (entry_price - exit_price) * position_size # Note the order for short profit
            capital += profit
            trades.append({
                'EntryDate': entry_date, 'ExitDate': df.index[i], 'Type': 'Short',
                'EntryPrice': entry_price, 'ExitPrice': exit_price,
                'StopLoss': stop_loss_price, 'Profit': profit, 'Reason': 'Stop Loss'
            })
            print(f"{df.index[i]} - STOP LOSS (Short): Exit at {exit_price:.2f}, Profit: {profit:.2f}, Capital: {capital:.2f}")
            position = 0
            entry_price = 0

        # --- Check for Exit Signals (Simplified - e.g., opposite signal) ---
        # More complex exit logic (Section 5 - TP, Trailing SL, Reversals) needed here
        if position == 1 and current_signal == -1: # Exit Long on Sell signal
            exit_price = current_close
            profit = (exit_price - entry_price) * position_size
            capital += profit
            trades.append({
                'EntryDate': entry_date, 'ExitDate': df.index[i], 'Type': 'Long',
                'EntryPrice': entry_price, 'ExitPrice': exit_price,
                'StopLoss': stop_loss_price, 'Profit': profit, 'Reason': 'Opposite Signal'
            })
            print(f"{df.index[i]} - EXIT LONG: Exit at {exit_price:.2f}, Profit: {profit:.2f}, Capital: {capital:.2f}")
            position = 0
            entry_price = 0
        elif position == -1 and current_signal == 1: # Exit Short on Buy signal
            exit_price = current_close
            profit = (entry_price - exit_price) * position_size
            capital += profit
            trades.append({
                'EntryDate': entry_date, 'ExitDate': df.index[i], 'Type': 'Short',
                'EntryPrice': entry_price, 'ExitPrice': exit_price,
                'StopLoss': stop_loss_price, 'Profit': profit, 'Reason': 'Opposite Signal'
            })
            print(f"{df.index[i]} - EXIT SHORT: Exit at {exit_price:.2f}, Profit: {profit:.2f}, Capital: {capital:.2f}")
            position = 0
            entry_price = 0

        # --- Check for Entry Signals ---
        if position == 0: # Only enter if flat
            if current_signal == 1: # Enter Long
                entry_price = current_close
                entry_date = df.index[i]
                # Position Sizing (Section 6) - Simplified: Fixed fractional for now
                # Proper calculation needs Stop Loss distance first
                sl_distance_atr = current_atr * 2 # Example: SL based on 2x ATR (Section 5)
                stop_loss_price = entry_price - sl_distance_atr
                risk_amount = capital * risk_per_trade
                position_size = risk_amount / sl_distance_atr if sl_distance_atr > 0 else 1 # Avoid division by zero
                # Ensure position size is reasonable (e.g., handle minimum trade size if needed)
                position_size = max(position_size, 0.01) # Example minimum

                position = 1
                print(f"{entry_date} - ENTER LONG: Price={entry_price:.2f}, SL={stop_loss_price:.2f}, Size={position_size:.2f}")

            elif current_signal == -1: # Enter Short
                entry_price = current_close
                entry_date = df.index[i]
                sl_distance_atr = current_atr * 2 # Example: SL based on 2x ATR
                stop_loss_price = entry_price + sl_distance_atr
                risk_amount = capital * risk_per_trade
                position_size = risk_amount / sl_distance_atr if sl_distance_atr > 0 else 1
                position_size = max(position_size, 0.01)

                position = -1
                print(f"{entry_date} - ENTER SHORT: Price={entry_price:.2f}, SL={stop_loss_price:.2f}, Size={position_size:.2f}")

        equity_curve.append(capital + ( (current_close - entry_price) * position_size if position == 1 else (entry_price - current_close) * position_size if position == -1 else 0) )


    # --- Performance Calculation ---
    print("\nBacktest finished. Calculating performance...")
    total_return = ((capital / initial_capital) - 1) * 100
    trades_df = pd.DataFrame(trades)
    num_trades = len(trades_df)
    wins = trades_df[trades_df['Profit'] > 0]
    losses = trades_df[trades_df['Profit'] <= 0]
    win_rate = (len(wins) / num_trades) * 100 if num_trades > 0 else 0
    avg_win = wins['Profit'].mean() if len(wins) > 0 else 0
    avg_loss = losses['Profit'].mean() if len(losses) > 0 else 0
    risk_reward_ratio = abs(avg_win / avg_loss) if avg_loss != 0 else np.inf
    equity_curve_s = pd.Series(equity_curve, index=[df.index[0]] + df.index[1:].tolist()) # Align index
    max_drawdown = ((equity_curve_s / equity_curve_s.cummax()) - 1).min() * 100

    print("\n--- Backtest Results ---")
    print(f"Initial Capital: ${initial_capital:,.2f}")
    print(f"Final Capital:   ${capital:,.2f}")
    print(f"Total Return:    {total_return:.2f}%")
    print(f"Number of Trades:{num_trades}")
    print(f"Win Rate:        {win_rate:.2f}%")
    print(f"Average Win:     ${avg_win:.2f}")
    print(f"Average Loss:    ${avg_loss:.2f}")
    print(f"Risk/Reward Ratio:{risk_reward_ratio:.2f}")
    print(f"Max Drawdown:    {max_drawdown:.2f}%")
    print("------------------------")

    # Optional: Plot equity curve
    try:
        import matplotlib.pyplot as plt
        plt.figure(figsize=(12, 6))
        equity_curve_s.plot(title='Equity Curve')
        plt.xlabel('Date')
        plt.ylabel('Equity')
        plt.grid(True)
        plt.savefig('equity_curve.png') # Save the plot
        print("\nEquity curve plot saved to equity_curve.png")
        # plt.show() # Uncomment to display plot interactively
    except ImportError:
        print("\nInstall matplotlib to generate equity curve plots: pip install matplotlib")
    except Exception as e:
        print(f"\nCould not generate plot: {e}")


    return trades_df, equity_curve_s

# --- Main Execution ---
if __name__ == "__main__":
    DATA_FILEPATH = 'historical_data.csv' # <-- IMPORTANT: User needs to provide this file

    # 1. Load Data
    price_data = load_data(DATA_FILEPATH)

    if price_data is not None:
        # 2. Calculate Indicators (using Daily timeframe as per plan)
        # Note: The plan mentions W1 for major trend and D1 for entry/management.
        # This basic backtester uses a single timeframe (assumed D1 from data).
        # A more advanced version could incorporate multi-timeframe analysis.
        price_data_with_indicators = calculate_indicators(price_data.copy()) # Use copy to avoid modifying original

        if price_data_with_indicators is not None:
            # 3. Apply Strategy
            signal_data = apply_strategy(price_data_with_indicators.copy())

            if signal_data is not None:
                # 4. Run Backtest
                results, equity = run_backtest(signal_data)

                if results is not None:
                    # Optional: Save trade log
                    results.to_csv('trade_log.csv', index=False)
                    print("\nTrade log saved to trade_log.csv")
            else:
                print("Failed to generate signals.")
        else:
            print("Failed to calculate indicators.")
    else:
        print("Failed to load data. Exiting.")