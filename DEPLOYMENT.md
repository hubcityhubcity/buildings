# Fortress FX deployment guide

## Before deployment

Use a **practice OANDA account** first. This version sends signals only; it has no order-placement code.

The default email-alert path needs these private values:

- `OANDA_TOKEN`
- `OANDA_ACCOUNT_ID`
- `EMAIL_USERNAME`
- `EMAIL_APP_PASSWORD`
- `EMAIL_FROM`
- `EMAIL_TO`

Keep all of them in the deployment platform's secret/environment-variable settings. Do not paste them into GitHub files, commits, issues, screenshots, or chat.

## Email phone alerts

The bot sends an email only after a signal passes its strategy and risk gates. Configure a sender mailbox that supports authenticated SMTP with STARTTLS. The default configuration is for Gmail:

```text
ALERT_CHANNEL=email
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your-sending-address@example.com
EMAIL_APP_PASSWORD=your-app-password
EMAIL_FROM=your-sending-address@example.com
EMAIL_TO=the-address-you-read-on-your-phone@example.com
```

Use a dedicated app-specific password or provider credential for `EMAIL_APP_PASSWORD`; do not use your normal mailbox password. Confirm Gmail notifications are enabled on the Android device that receives `EMAIL_TO`.

Telegram remains optional. Only configure `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` if you later set `ALERT_CHANNEL=telegram`.

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
ALERT_CHANNEL=email
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=...
EMAIL_APP_PASSWORD=...
EMAIL_FROM=...
EMAIL_TO=...
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
- `ALERT_SENT`: a qualifying setup passed every gate and was sent by the configured alert channel.
- `ERROR`: check the platform logs, OANDA credentials, email credentials, instrument availability, and network access.

## Safe operating sequence

1. Practice OANDA data + email alerts.
2. Verify alert quality manually for at least several weeks across different market conditions.
3. Run out-of-sample and walk-forward tests before changing thresholds.
4. Add dashboard reporting and a kill switch.
5. Consider any execution adapter only after the research evidence is strong and stable.
