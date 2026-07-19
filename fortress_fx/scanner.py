from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol

from .config import Settings
from .email_alerts import EmailNotifier
from .ledger import SignalLedger
from .models import Quote, Signal
from .oanda import OandaClient
from .risk import RiskGate
from .strategies import evaluate_strategies
from .telegram import TelegramNotifier


class Notifier(Protocol):
    def send_signal(self, signal: Signal, quote: Quote) -> None: ...


@dataclass(frozen=True)
class ScanOutcome:
    instrument: str
    timeframe: str
    status: str
    detail: str


class Scanner:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.market = OandaClient(settings)
        self.ledger = SignalLedger(settings.db_path)
        self.risk_gate = RiskGate(settings)
        self.notifier: Notifier = self._build_notifier()
        self.logger = logging.getLogger(__name__)

    def _build_notifier(self) -> Notifier:
        if self.settings.alert_channel == "email":
            return EmailNotifier(
                smtp_host=self.settings.email_smtp_host,
                smtp_port=self.settings.email_smtp_port,
                username=self.settings.email_username,
                app_password=self.settings.email_app_password,
                sender=self.settings.email_from,
                recipient=self.settings.email_to,
            )
        return TelegramNotifier(self.settings.telegram_bot_token, self.settings.telegram_chat_id)

    def scan_pair(self, instrument: str, timeframe: str) -> ScanOutcome:
        candles = self.market.candles(instrument, timeframe, self.settings.candle_count)
        candidates = evaluate_strategies(candles, instrument, timeframe)
        if not candidates:
            return ScanOutcome(instrument, timeframe, "NO_SETUP", "No strategy met its entry conditions.")

        signal = candidates[0]
        quote = self.market.quote(instrument)
        decision = self.risk_gate.evaluate(
            signal=signal,
            quote=quote,
            latest_candle=candles[-1],
            alerts_today=self.ledger.alerts_today(),
            is_duplicate=self.ledger.is_duplicate(signal, self.settings.alert_dedup_minutes),
        )
        self.ledger.record(signal, decision)

        if not decision.accepted:
            return ScanOutcome(instrument, timeframe, "VETOED", "; ".join(decision.reasons))

        self.notifier.send_signal(signal, quote)
        return ScanOutcome(
            instrument,
            timeframe,
            "ALERT_SENT",
            f"{signal.direction.value} {signal.strategy} via {self.settings.alert_channel}",
        )

    def scan_all(self) -> list[ScanOutcome]:
        outcomes: list[ScanOutcome] = []
        for instrument in self.settings.instruments:
            for timeframe in self.settings.granularities:
                try:
                    outcomes.append(self.scan_pair(instrument, timeframe))
                except Exception as exc:  # Keep scanning the other markets even when one fails.
                    self.logger.exception("Scan failed for %s %s", instrument, timeframe)
                    outcomes.append(ScanOutcome(instrument, timeframe, "ERROR", str(exc)))
        return outcomes

    def close(self) -> None:
        self.ledger.close()
