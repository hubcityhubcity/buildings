# Fortress FX FTMO Automation Requirements

## Mission change

Fortress FX is no longer only a signal-and-alert engine. The target product is a fully automated trading system that can operate while the trader is sleeping or working, with a specific challenge profile for a one-step FTMO account.

This document defines the next architecture phase. It does not claim guaranteed passing, and it does not attempt to bypass FTMO rules. The bot must trade only inside the rules of the account actually purchased.

## Key architectural correction

OANDA can remain useful for early market-data experiments, but an FTMO challenge account is not executed through the OANDA practice API. FTMO automation must run through the actual trading platform assigned to the challenge account, most likely MetaTrader or another FTMO-supported platform.

The execution layer therefore becomes platform-specific:

- MT5: Expert Advisor or Python-to-terminal bridge
- MT4: Expert Advisor bridge
- cTrader: cBot / Open API path if available
- DXtrade: only if an approved automation path is available

The project must not be deployed as live execution until the exact FTMO platform, account type, symbols, leverage, and trading rules are confirmed.

## Target operating modes

### 1. Research mode
- No orders
- Pulls data
- Generates signals
- Runs backtests and walk-forward validation

### 2. Paper execution mode
- Simulated order placement
- Tracks realistic spread, slippage, commission, and rejections
- Verifies that account-level drawdown locks work

### 3. Practice execution mode
- Places trades only on demo/practice accounts
- Uses the same execution adapter planned for the FTMO account
- Sends every trade and account event by email alert

### 4. FTMO challenge mode
- Fully automated trading enabled
- Hard daily loss and max loss guardrails
- Kill switch before the platform rule is breached
- No martingale, no grid recovery, no revenge sizing
- No overnight/weekend behavior unless explicitly allowed and configured

## Required FTMO guardrails

These values must be configurable from environment variables or a protected settings file because the challenge terms can differ by product and can change over time.

- `FTMO_MODE=true`
- `FTMO_ACCOUNT_SIZE`
- `FTMO_PROFIT_TARGET_PCT`
- `FTMO_DAILY_LOSS_LIMIT_PCT`
- `FTMO_MAX_LOSS_LIMIT_PCT`
- `FTMO_SOFT_DAILY_STOP_PCT`
- `FTMO_SOFT_TOTAL_STOP_PCT`
- `FTMO_MAX_OPEN_TRADES`
- `FTMO_MAX_RISK_PER_TRADE_PCT`
- `FTMO_MAX_CORRELATED_RISK_PCT`
- `FTMO_NEWS_BLACKOUT_MINUTES_BEFORE`
- `FTMO_NEWS_BLACKOUT_MINUTES_AFTER`
- `FTMO_WEEKEND_FLAT=true/false`
- `EXECUTION_ENABLED=true/false`

The soft stops must be stricter than the official FTMO limits so the bot shuts itself down before a rule breach.

## Execution safety rules

1. Every trade must have a stop loss before or immediately at order entry.
2. Position size must be calculated from the stop distance and configured risk percentage.
3. The bot must check account equity before every order.
4. The bot must recalculate daily drawdown using the account's day boundary.
5. The bot must stop opening trades once soft daily loss is hit.
6. The bot must close or reduce risk if total loss approaches the max loss guardrail.
7. The bot must reject trades during spread spikes, stale data, disabled markets, and blackout windows.
8. The bot must log every decision, order request, fill, modification, rejection, and shutdown event.

## Strategy requirements for FTMO mode

The goal is not maximum trade count. The goal is controlled progress toward the target without violating drawdown rules.

FTMO mode should prefer:

- high-confidence sessions only
- London/New York overlap filters
- limited symbols at launch
- risk-per-trade below normal retail bot levels
- automatic cooldown after losses
- correlation limits across USD pairs
- trailing protection after partial progress
- no averaging down

## Implementation roadmap

### Phase A — Platform decision
- Confirm the exact FTMO platform the trader will use.
- Prefer MT5 if available because it has strong automation support.
- Determine whether the bot will run as a native Expert Advisor or as a Python signal server plus EA executor.

### Phase B — Account protection engine
- Implement account-equity polling.
- Implement daily and total loss calculations.
- Implement soft-stop lockout.
- Implement per-symbol and correlated-risk limits.

### Phase C — Execution adapter
- Add order placement, modification, and closing.
- Add fill/rejection handling.
- Add broker/platform reconnection handling.
- Add email alerts for every execution event.

### Phase D — FTMO rehearsal
- Run the same bot on a demo account with FTMO-style limits.
- Require enough forward sample size before a paid challenge.
- Produce a daily report: equity, drawdown, R-multiple, mistakes avoided, and next-session status.

## Next required user decision

The next decision is the trading platform for the FTMO challenge. The execution build depends on it.

Recommended default: MT5, if FTMO offers it for the selected one-step challenge and it is available to the trader.
