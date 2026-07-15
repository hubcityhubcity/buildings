# Fortress FX Phone Builds

These files are made for phone-only VPS testing.

They avoid preset confusion by hard-locking the strategy into the EA file itself.

## Donchian locked test

File:

```text
mt5/phone_builds/FortressFX_DONCHIAN_LOCKED.mq5
```

Purpose:

```text
Backtest-only Donchian Breakout test.
No preset required.
No STRATEGY_MODULE input required.
No accidental Trend Pullback rerun.
```

Expected MetaEditor version line:

```mql5
#property version   "0.7D-DONCHIAN-LOCKED"
```

Expected Experts log line:

```text
FORTRESS FX DONCHIAN LOCKED TEST initialized
Strategy=DONCHIAN_ONLY
```

Phone workflow:

1. Download `FortressFX_DONCHIAN_LOCKED.mq5`.
2. Put it in the MT5 Experts folder.
3. Open it in MetaEditor.
4. Confirm the top says `0.7D-DONCHIAN-LOCKED`.
5. Compile.
6. In Strategy Tester, select `FortressFX_DONCHIAN_LOCKED`.
7. Run the same EURUSD M15 one-year test.
8. Send Backtest screenshots.

Important:

This is a test build with `EXECUTION_ENABLED=true` by default so MT5 Strategy Tester places simulated trades. Use it for Strategy Tester/backtesting only unless you intentionally want demo execution.