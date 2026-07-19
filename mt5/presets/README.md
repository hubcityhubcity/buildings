# Fortress FX MT5 Presets

These `.set` files are Strategy Tester input presets for the MT5 Expert Advisor.

## Presets

- `v0.5_A_both_directions.set` — buys and sells enabled with ADX/DI filter.
- `v0.5_B_short_only.set` — buys disabled, sells enabled with ADX/DI filter.
- `v0.5_C_long_only.set` — buys enabled, sells disabled with ADX/DI filter.

## Standard backtest setup

Use the same setup for each comparison run:

- Expert: `FortressFX\FortressFX.ex5`
- Symbol: `EURUSD`
- Timeframe: `M15`
- Date: `Last year`
- Initial Deposit: `100000`
- Forward: `No`
- Risk: `0.10%`

## Phone/VPS workflow

1. Download the `.set` file inside the VPS.
2. In MT5 Strategy Tester, open the `Inputs` tab.
3. Press `Load`.
4. Select the `.set` file.
5. Confirm `EXECUTION_ENABLED=true` is only being used inside Strategy Tester.
6. Run the test and capture the Backtest results.

Do not enable live chart trading until backtests and demo forward tests prove stability.