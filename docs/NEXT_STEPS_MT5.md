# Next Steps: MT5 Execution Build

## Current decision

- FTMO platform target: MT5
- Paid FTMO challenge: not purchased yet
- Required next milestone: demo-capable MT5 Expert Advisor

## What was added

`mt5/FortressFX/FortressFX.mq5` is the first Expert Advisor scaffold. It does not trade by default. `EXECUTION_ENABLED=false` is the default safety switch.

The first scaffold includes:

- FTMO-style account-size inputs
- daily and total loss soft stops
- official-limit danger lock
- max open trade limit
- spread limit
- cooldown between trades
- mandatory stop-loss/take-profit validation
- lot sizing from stop distance and risk percentage
- order send/rejection logging

The strategy function intentionally returns `false` for now. The next code task is to implement and test the first strategy module after the account guard exists.

## Required next user setup

Because MT5 is a Windows desktop trading platform, the next practical setup is:

1. Choose a Windows VPS.
2. Install MT5 on the VPS.
3. Log into an MT5 demo account.
4. Copy the `FortressFX.mq5` EA into the MT5 `Experts` folder.
5. Compile it in MetaEditor.
6. Attach it to one demo chart.
7. Keep `EXECUTION_ENABLED=false` until compile, logs, and guard behavior are confirmed.

## Recommended first demo symbol

Start with one symbol only, for example EURUSD, on M15 or H1. Do not start with multiple pairs until the guardrail logs are clean.

## Development order

1. Compile skeleton EA.
2. Confirm account guard logs.
3. Add indicator handles and signal rules.
4. Run MT5 Strategy Tester with execution disabled.
5. Enable demo-only execution.
6. Test guardrail failures.
7. Forward test for several active sessions.
8. Review report before paying for FTMO.
