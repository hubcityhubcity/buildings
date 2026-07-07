from __future__ import annotations

from datetime import datetime, timezone

from .config import Settings
from .market_math import candle_is_fresh, pip_size
from .models import Candle, Direction, Quote, RiskDecision, Signal


class RiskGate:
    """Veto layer. A strategy cannot override a failed gate."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def evaluate(
        self,
        signal: Signal,
        quote: Quote,
        latest_candle: Candle,
        alerts_today: int,
        is_duplicate: bool,
    ) -> RiskDecision:
        reasons: list[str] = []
        if signal.confidence < self.settings.min_confidence:
            reasons.append(f"confidence {signal.confidence} below minimum {self.settings.min_confidence}")
        if signal.reward_risk < self.settings.min_reward_risk:
            reasons.append(f"reward/risk {signal.reward_risk:.2f} below minimum {self.settings.min_reward_risk:.2f}")

        if signal.direction is Direction.LONG:
            if not (signal.stop_loss < signal.entry < signal.take_profit):
                reasons.append("invalid LONG price geometry")
        else:
            if not (signal.take_profit < signal.entry < signal.stop_loss):
                reasons.append("invalid SHORT price geometry")

        spread_pips = (quote.ask - quote.bid) / pip_size(signal.instrument)
        if spread_pips > self.settings.max_spread_pips:
            reasons.append(f"spread {spread_pips:.2f} pips exceeds {self.settings.max_spread_pips:.2f}")

        if not candle_is_fresh(latest_candle, signal.timeframe, datetime.now(timezone.utc)):
            reasons.append("latest completed candle is stale")
        if alerts_today >= self.settings.max_alerts_per_day:
            reasons.append("daily alert limit reached")
        if is_duplicate:
            reasons.append("duplicate setup inside alert cooldown")

        return RiskDecision(accepted=not reasons, reasons=tuple(reasons))
