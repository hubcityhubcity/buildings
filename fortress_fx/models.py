from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from hashlib import sha256
from typing import Any


class Direction(str, Enum):
    LONG = "LONG"
    SHORT = "SHORT"


@dataclass(frozen=True)
class Candle:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: int = 0


@dataclass(frozen=True)
class Quote:
    instrument: str
    bid: float
    ask: float
    timestamp: datetime

    @property
    def mid(self) -> float:
        return (self.bid + self.ask) / 2


@dataclass(frozen=True)
class Signal:
    instrument: str
    timeframe: str
    direction: Direction
    strategy: str
    regime: str
    entry: float
    stop_loss: float
    take_profit: float
    confidence: int
    reasons: tuple[str, ...]
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def risk_distance(self) -> float:
        return abs(self.entry - self.stop_loss)

    @property
    def reward_distance(self) -> float:
        return abs(self.take_profit - self.entry)

    @property
    def reward_risk(self) -> float:
        return self.reward_distance / self.risk_distance if self.risk_distance else 0.0

    @property
    def idempotency_key(self) -> str:
        raw = "|".join(
            (
                self.instrument,
                self.timeframe,
                self.direction.value,
                self.strategy,
                self.regime,
                f"{self.entry:.6f}",
                f"{self.stop_loss:.6f}",
                f"{self.take_profit:.6f}",
            )
        )
        return sha256(raw.encode("utf-8")).hexdigest()[:24]


@dataclass(frozen=True)
class RiskDecision:
    accepted: bool
    reasons: tuple[str, ...]
