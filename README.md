# Position Trading EA for MetaTrader 5

## Overview

This repository contains an Expert Advisor (EA) for MetaTrader 5 that implements a Position Trading strategy. Position Trading is a long-term trading approach that aims to capture major market trends that can last from several weeks to several months.

The EA uses a combination of technical indicators (EMA 200 and Ichimoku Cloud) to identify major trends and appropriate entry/exit points. It implements proper risk management with position sizing based on account risk percentage and ATR-based stop loss calculation.

## Strategy Details

### Position Trading Concept

Position Trading focuses on:
- Capturing major market trends (lasting weeks to months)
- Lower trading frequency with longer holding periods
- Using larger stop losses to withstand normal market fluctuations
- Letting profitable trades run while using trailing stops to protect gains

### Technical Indicators Used

The EA implements the following technical indicators:
- **EMA 200**: Primary trend identification indicator
- **Ichimoku Cloud**: Multi-faceted indicator providing trend direction, momentum, and support/resistance levels
- **ATR (Average True Range)**: Used for calculating appropriate stop loss distances

### Entry Conditions

For Buy (Long) trades:
- Price is above EMA 200 on Daily and Weekly timeframes
- Price is above the Ichimoku Cloud (Senkou Span A & B)
- Tenkan-sen is above Kijun-sen (bullish momentum)
- Optional: Chikou Span is above price (additional confirmation)

For Sell (Short) trades:
- Price is below EMA 200 on Daily and Weekly timeframes
- Price is below the Ichimoku Cloud (Senkou Span A & B)
- Tenkan-sen is below Kijun-sen (bearish momentum)
- Optional: Chikou Span is below price (additional confirmation)

### Exit Strategy

The EA implements multiple exit mechanisms:
- Fixed Take Profit (based on Risk:Reward ratio)
- Stop Loss based on ATR (Average True Range)
- Trailing Stop Loss (ATR-based or fixed distance)
- Breakeven stop after achieving specified profit
- Optional partial profit taking at predefined levels

## Installation

1. Clone or download this repository to your local machine
2. Copy the `PositionTrading_EA.mq5` file to your MetaTrader 5 Experts folder:
   - Navigate to `File > Open Data Folder > MQL5 > Experts` in MetaTrader 5
   - Paste the file into this folder
3. Restart MetaTrader 5 or refresh the Navigator panel
4. Compile the EA in MetaEditor (right-click the file and select "Compile")
5. Attach the EA to a chart by dragging it from the Navigator panel

## Configuration

The EA features numerous customizable parameters:

### Timeframe Settings
- `TimeframeMain`: Main timeframe for entry/exit signals (default: D1)
- `TimeframeTrend`: Timeframe for major trend confirmation (default: W1)

### Indicator Parameters
- `EMA_Period`: Period for the EMA indicator (default: 200)
- `Ichimoku_Tenkan`: Tenkan-sen period (default: 9)
- `Ichimoku_Kijun`: Kijun-sen period (default: 26)
- `Ichimoku_Senkou`: Senkou Span B period (default: 52)
- `ATR_Period`: Period for ATR calculation (default: 14)

### Risk Management
- `RiskPercentage`: Percentage of account to risk per trade (default: 1%)
- `ATR_Multiplier`: Multiplier for ATR-based stop loss (default: 2.0)
- `TakeProfitFactor`: TP distance as multiple of SL distance (default: 3.0)

### Trade Management
- `EnableTrailingStop`: Enable/disable trailing stop (default: true)
- `TrailingStopDistance`: Fixed trailing stop distance in pips (0 for ATR-based)
- `UseBreakEven`: Enable/disable breakeven stop (default: true)
- `BreakEvenPips`: Pips in profit to move SL to breakeven (default: 50.0)
- `UsePartialClose`: Enable/disable partial profit taking (default: false)
- `PartialClosePercent`: Percentage to close at first target (default: 50%)

### Additional Filters
- `UseIchimokuFilters`: Use Ichimoku Cloud as filter (default: true)
- `RequireChikouConfirmation`: Require Chikou Span confirmation (default: false)
- `CheckWeeklyTrend`: Check Weekly timeframe for major trend (default: true)
- `EnableNewsFilter`: Filter entries near major news events (default: false)
- `MaxSpread`: Maximum allowed spread in points (default: 50)

## Best Practices

For optimal results with this Position Trading EA:

1. **Suitable Instruments**: Apply to major forex pairs, stock indices, or liquid commodities with clear trending behavior
2. **Timeframe**: The EA is designed for D1 and W1 timeframes, not suitable for lower timeframes
3. **Backtesting**: Always backtest the EA over multiple years of data before live trading
4. **Risk Management**: Keep the risk per trade low (1-2% maximum) due to the wider stop losses
5. **Expectations**: Position trading generates fewer trades but potentially larger moves; patience is required
6. **Market Conditions**: The strategy performs best in trending markets, may struggle in ranging markets

## Disclaimer

This EA is provided for educational and informational purposes only. Past performance is not indicative of future results. Trading financial markets carries significant risk of loss. Always test thoroughly on demo accounts and consult with a licensed financial advisor before trading real funds.

## Version History

- **1.0.0** (April 8, 2025) - Initial release

## License

This project is licensed under the MIT License - see the LICENSE file for details.