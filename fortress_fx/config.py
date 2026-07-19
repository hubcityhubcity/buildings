from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


def _csv(name: str, default: str) -> tuple[str, ...]:
    return tuple(item.strip().upper() for item in os.getenv(name, default).split(",") if item.strip())


def _bool(name: str, default: bool) -> bool:
    raw = os.getenv(name, str(default)).strip().lower()
    return raw in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    signal_only: bool
    db_path: Path
    log_level: str
    oanda_environment: str
    oanda_token: str
    oanda_account_id: str
    oanda_rest_url: str
    alert_channel: str
    email_smtp_host: str
    email_smtp_port: int
    email_username: str
    email_app_password: str
    email_from: str
    email_to: str
    telegram_bot_token: str
    telegram_chat_id: str
    instruments: tuple[str, ...]
    granularities: tuple[str, ...]
    candle_count: int
    scan_interval_seconds: int
    min_confidence: int
    max_spread_pips: float
    min_reward_risk: float
    max_alerts_per_day: int
    alert_dedup_minutes: int
    backtest_spread_pips: float
    backtest_slippage_pips: float

    @classmethod
    def from_env(cls) -> "Settings":
        load_dotenv()
        env = os.getenv("OANDA_ENV", "practice").strip().lower()
        default_rest = (
            "https://api-fxtrade.oanda.com"
            if env == "live"
            else "https://api-fxpractice.oanda.com"
        )
        email_username = os.getenv("EMAIL_USERNAME", "").strip()
        return cls(
            signal_only=_bool("SIGNAL_ONLY", True),
            db_path=Path(os.getenv("DB_PATH", "data/fortress_fx.sqlite3")),
            log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
            oanda_environment=env,
            oanda_token=os.getenv("OANDA_TOKEN", "").strip(),
            oanda_account_id=os.getenv("OANDA_ACCOUNT_ID", "").strip(),
            oanda_rest_url=os.getenv("OANDA_REST_URL", default_rest).rstrip("/"),
            alert_channel=os.getenv("ALERT_CHANNEL", "email").strip().lower(),
            email_smtp_host=os.getenv("EMAIL_SMTP_HOST", "smtp.gmail.com").strip(),
            email_smtp_port=int(os.getenv("EMAIL_SMTP_PORT", "587")),
            email_username=email_username,
            email_app_password=os.getenv("EMAIL_APP_PASSWORD", "").strip(),
            email_from=os.getenv("EMAIL_FROM", email_username).strip(),
            email_to=os.getenv("EMAIL_TO", "").strip(),
            telegram_bot_token=os.getenv("TELEGRAM_BOT_TOKEN", "").strip(),
            telegram_chat_id=os.getenv("TELEGRAM_CHAT_ID", "").strip(),
            instruments=_csv("INSTRUMENTS", "EUR_USD,GBP_USD,USD_JPY"),
            granularities=_csv("GRANULARITIES", "M15,H1"),
            candle_count=int(os.getenv("CANDLE_COUNT", "300")),
            scan_interval_seconds=int(os.getenv("SCAN_INTERVAL_SECONDS", "60")),
            min_confidence=int(os.getenv("MIN_CONFIDENCE", "70")),
            max_spread_pips=float(os.getenv("MAX_SPREAD_PIPS", "2.0")),
            min_reward_risk=float(os.getenv("MIN_REWARD_RISK", "1.5")),
            max_alerts_per_day=int(os.getenv("MAX_ALERTS_PER_DAY", "8")),
            alert_dedup_minutes=int(os.getenv("ALERT_DEDUP_MINUTES", "120")),
            backtest_spread_pips=float(os.getenv("BACKTEST_SPREAD_PIPS", "1.2")),
            backtest_slippage_pips=float(os.getenv("BACKTEST_SLIPPAGE_PIPS", "0.2")),
        )

    def validate_runtime(self) -> None:
        missing = []
        if not self.oanda_token:
            missing.append("OANDA_TOKEN")
        if not self.oanda_account_id:
            missing.append("OANDA_ACCOUNT_ID")
        if self.alert_channel not in {"email", "telegram"}:
            raise RuntimeError("ALERT_CHANNEL must be either 'email' or 'telegram'.")
        if self.alert_channel == "email":
            for name, value in (
                ("EMAIL_USERNAME", self.email_username),
                ("EMAIL_APP_PASSWORD", self.email_app_password),
                ("EMAIL_FROM", self.email_from),
                ("EMAIL_TO", self.email_to),
            ):
                if not value:
                    missing.append(name)
        else:
            if not self.telegram_bot_token:
                missing.append("TELEGRAM_BOT_TOKEN")
            if not self.telegram_chat_id:
                missing.append("TELEGRAM_CHAT_ID")
        if missing:
            raise RuntimeError("Missing required environment variables: " + ", ".join(missing))
        if self.candle_count < 80:
            raise RuntimeError("CANDLE_COUNT must be at least 80.")
        if self.min_reward_risk <= 1:
            raise RuntimeError("MIN_REWARD_RISK must be greater than 1.")
