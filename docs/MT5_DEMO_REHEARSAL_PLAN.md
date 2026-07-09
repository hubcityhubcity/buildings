# MT5 Demo Rehearsal Plan

## Decision

The target execution platform is MT5. Fortress FX must not be used on a paid FTMO challenge until it passes an MT5 demo rehearsal with FTMO-style limits.

## Why this gate exists

A paid challenge should not be the first time the bot places real platform orders. The demo rehearsal proves these things first:

- MT5 can stay online continuously on the chosen VPS.
- The Expert Advisor opens, modifies, and closes trades correctly.
- Every order has a stop loss and take profit at entry.
- Lot sizing matches configured risk.
- The daily drawdown lockout works.
- The total drawdown lockout works.
- Email alerts work for entries, exits, rejections, errors, and lockouts.
- The strategy behaves acceptably in live market conditions, not only in historical tests.

## Required rehearsal stages

### Stage 1 — MT5 Strategy Tester
- Compile the Expert Advisor.
- Run historical backtests on the same symbols and timeframes planned for FTMO.
- Use conservative spread and slippage assumptions.
- Reject parameter sets that only work on one narrow date range.

### Stage 2 — Demo forward test
- Run the EA on an MT5 demo account for at least several active trading sessions.
- Use FTMO-style account size, profit target, daily loss limit, max loss limit, and leverage assumptions.
- Keep the bot fully automated, including while the trader is asleep or at work.
- Record all decisions and fills.

### Stage 3 — Guardrail failure test
Deliberately test the protection system in a controlled demo environment:

- Force spread too wide -> trade must be rejected.
- Force max open trades reached -> new trade must be rejected.
- Force daily soft loss reached -> new trades must stop.
- Force total soft loss reached -> bot must lock down.
- Restart MT5/VPS -> bot must recover without duplicate trades.

### Stage 4 — Paid challenge readiness review
Before buying FTMO, produce a readiness report:

- total trades
- win rate
- average R
- max drawdown
- daily loss worst case
- errors/rejections
- uptime
- whether any rule breach would have occurred

## Pass/fail gate

The paid FTMO challenge is blocked until all of these are true:

- Zero drawdown-rule breaches in demo.
- Zero trades without stop loss.
- Zero uncontrolled duplicate entries.
- Bot survives restart/reconnect test.
- Email alerts work.
- Forward-test results are acceptable for the selected risk profile.

## Next implementation step

Build the MT5 Expert Advisor skeleton first:

- account guard module
- position sizing module
- strategy signal module
- execution module
- event logger
- email/webhook alert module

The first EA version should support demo-only execution and include an `EXECUTION_ENABLED` switch that defaults to false.
