# Fortress FX — Signal Intelligence Engine

A multi-regime forex signal system built for **live data, Android alerts, research, and disciplined verification**.

> **Default behavior: signal-only.** The project does not send broker orders. It fails closed until an execution adapter is deliberately designed, independently tested, and explicitly enabled.

## What the first release does

- Pulls current/complete candles from OANDA v20 pricing APIs
- Scans configurable instruments and timeframes
- Scores three complementary strategy families:
  - **Trend pullback** — EMA alignment + RSI recovery
  - **Momentum breakout** — Donchian break + trend confirmation
  - **Mean reversion** — Bollinger extension + RSI exhaustion
- Uses a market-regime selector so strategies are not treated as universally valid
- Rejects weak setups using a hard **risk gate**:
  - stale candle data
  - spread too wide
  - invalid stop distance
  - insufficient reward/risk
  - duplicate alerts
  - daily alert cap
- Sends structured alerts to your phone by **email**; Telegram remains an optional fallback
- Stores every accepted/rejected signal in SQLite for review
- Includes a backtest module designed to use next-bar entries and configurable spread/slippage assumptions rather than perfect fills

## Non-negotiable operating rules

1. **No guaranteed outcome claims.** Every signal is a probability estimate, not a promise.
2. **No live execution at launch.** The bot starts in `SIGNAL_ONLY=true` mode.
3. **No secrets in Git.** Put credentials in `.env` or host-level secret storage.
4. **A strategy earns promotion through out-of-sample testing, paper tracking, and forward performance.**
5. **Risk rules override signals.** A setup that fails a gate is not sent.

## Architecture

```text
OANDA candles/prices
       |
       v
Market data client ---> indicators ---> regime detector
                                      |
                                      v
                 strategy ensemble / signal scoring
                                      |
                                      v
           risk gate + duplicate protection + SQLite ledger
                                      |
                                      v
                       Email push alert to phone
```

## Phone alerts — email first

The default notification path is authenticated SMTP email. Gmail notifications on Android can therefore surface accepted setups directly on your phone.

Configure the sender and destination in private environment secrets:

```bash
ALERT_CHANNEL=email
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your-sending-address@example.com
EMAIL_APP_PASSWORD=your-email-app-password
EMAIL_FROM=your-sending-address@example.com
EMAIL_TO=the-address-you-read-on-your-phone@example.com
```

`EMAIL_APP_PASSWORD` is secret. Do not commit, screenshot, paste, or send it in chat.

Telegram remains available later by changing `ALERT_CHANNEL=telegram` and adding the Telegram credentials.

Alerts include instrument/timeframe, long/short direction, regime/strategy, entry zone, stop, target, estimated reward/risk, confidence score, reasoning, and risk-gate status.

## OANDA setup

Create a practice account/token first. Add these values to `.env`:

```bash
OANDA_ENV=practice
OANDA_TOKEN=...
OANDA_ACCOUNT_ID=...
```

The OANDA REST v20 API exposes account-scoped current pricing, price streams, and candle history by instrument/granularity.

## Local quick start

```bash
git clone https://github.com/hubcityhubcity/buildings.git
cd buildings
git checkout fortress-fx

python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Add practice OANDA and email-alert values to .env

python -m fortress_fx.main --once
```

For continuous scanning:

```bash
python -m fortress_fx.main --loop
```

## Backtest command

```bash
python -m fortress_fx.backtest --instrument EUR_USD --granularity M15 --count 3000
```

The initial backtest is deliberately conservative: complete candles only, next-bar entry assumption, estimated spread/slippage, one open trade at a time, and forced stop/target evaluation on future bars.

## Configuration highlights

```bash
INSTRUMENTS=EUR_USD,GBP_USD,USD_JPY
GRANULARITIES=M15,H1
SCAN_INTERVAL_SECONDS=60
MIN_CONFIDENCE=70
MAX_SPREAD_PIPS=2.0
MAX_ALERTS_PER_DAY=8
SIGNAL_ONLY=true
ALERT_CHANNEL=email
```

## Roadmap

### Phase 1 — Signal foundation
- [x] Repository and technical specification
- [x] Live-data adapter interface
- [x] Email notification adapter
- [x] Optional Telegram notification adapter
- [x] Strategy ensemble and risk gate
- [x] Signal ledger
- [x] Backtest baseline

### Phase 2 — Evidence engine
- [ ] Walk-forward validation
- [ ] Parameter stability testing
- [ ] Monte Carlo trade-sequence stress tests
- [ ] Performance dashboard
- [ ] News/session filters

### Phase 3 — Controlled execution
- [ ] Broker-specific execution adapter
- [ ] Practice-account-only order simulation
- [ ] Independent kill switch
- [ ] Position reconciliation
- [ ] Explicit human approval mode before automation

## Security

Never commit OANDA tokens, email app passwords, Telegram bot tokens, broker passwords, or account IDs linked to real funds. Rotate a credential immediately if it is exposed.

## License

Private personal project — all rights reserved.
