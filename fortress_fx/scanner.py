from __future__ import annotations

import logging
from dataclasses import dataclass

from .config import Settings
from .ledger import SignalLedger
from .oanda import OandaClient
from .risk import RiskGate
from .strategies import evaluate_strategies
from .telegram import TelegramNotifier


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
        self.notifier = TelegramNotifier(settings.telegram_bot_token, settings.telegram_chat_id)
        self.logger = logging.getLogger(__name__)

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
        return ScanOutcome(instrument, timeframe, "ALERT_SENT", f"{signal.direction.value} {signal.strategy}")

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
