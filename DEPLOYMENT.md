# Fortress FX deployment guide

## Before deployment

Use a **practice OANDA account** first. This version sends signals only; it has no order-placement code.

You need four secrets:

- `OANDA_TOKEN`
- `OANDA_ACCOUNT_ID`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

Keep them in the deployment platform's secret/environment-variable settings. Do not paste them into GitHub files, commits, issues, or screenshots.

## Telegram setup from Android

1. In Telegram, open **@BotFather**.
2. Send `/newbot`, name it, and copy the token it gives you.
3. Open your new bot and press **Start** or send it any message.
4. In a browser, open:

   ```text
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```

5. Find `chat.id` in the response. That number is your `TELEGRAM_CHAT_ID`.
6. Store the token and chat ID as deployment secrets.

## Container deployment

This repository includes a `Dockerfile`. Any host that can run a Docker service can run Fortress FX continuously.

Set the command to:

```text
python -m fortress_fx.main --loop
```

Set these minimum environment variables:

```text
SIGNAL_ONLY=true
OANDA_ENV=practice
OANDA_TOKEN=...
OANDA_ACCOUNT_ID=...
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
INSTRUMENTS=EUR_USD,GBP_USD,USD_JPY
GRANULARITIES=M15,H1
SCAN_INTERVAL_SECONDS=60
```

For a persistent signal ledger, point `DB_PATH` at host-provided persistent storage, for example:

```text
DB_PATH=/data/fortress_fx.sqlite3
```

## First test

Run a one-time scan before enabling continuous mode:

```bash
python -m fortress_fx.main --once
```

Expected outcomes:

- `NO_SETUP`: market data worked; no qualifying opportunity exists right now.
- `VETOED`: a strategy saw a setup, but the risk gate blocked it.
- `ALERT_SENT`: a qualifying setup passed every gate and was sent to Telegram.
- `ERROR`: check the platform logs, token, account ID, instrument availability, and network access.

## Safe operating sequence

1. Practice OANDA data + Telegram alerts.
2. Verify alert quality manually for at least several weeks across different market conditions.
3. Run out-of-sample and walk-forward tests before changing thresholds.
4. Add dashboard reporting and a kill switch.
5. Consider any execution adapter only after the research evidence is strong and stable.
