from __future__ import annotations

from datetime import datetime, timedelta, timezone
from math import sqrt
from typing import Sequence

from .models import Candle


def pip_size(instrument: str) -> float:
    return 0.01 if instrument.endswith("_JPY") else 0.0001


def granularity_delta(granularity: str) -> timedelta:
    mapping = {
        "S5": 5, "S10": 10, "S15": 15, "S30": 30,
        "M1": 60, "M2": 120, "M4": 240, "M5": 300,
        "M10": 600, "M15": 900, "M30": 1800,
        "H1": 3600, "H2": 7200, "H3": 10800, "H4": 14400,
        "H6": 21600, "H8": 28800, "H12": 43200,
        "D": 86400, "W": 604800,
    }
    if granularity not in mapping:
        raise ValueError(f"Unsupported granularity: {granularity}")
    return timedelta(seconds=mapping[granularity])


def candle_is_fresh(candle: Candle, granularity: str, now: datetime | None = None) -> bool:
    now = now or datetime.now(timezone.utc)
    completed_at = candle.timestamp + granularity_delta(granularity)
    return now - completed_at <= granularity_delta(granularity) * 1.5


def ema(values: Sequence[float], period: int) -> float:
    if len(values) < period:
        raise ValueError(f"Need {period} values for EMA.")
    value = sum(values[:period]) / period
    alpha = 2 / (period + 1)
    for current in values[period:]:
        value = (current * alpha) + (value * (1 - alpha))
    return value


def rsi(values: Sequence[float], period: int = 14) -> float:
    if len(values) < period + 1:
        raise ValueError(f"Need {period + 1} values for RSI.")
    changes = [values[index] - values[index - 1] for index in range(1, len(values))]
    seed = changes[:period]
    avg_gain = sum(max(change, 0.0) for change in seed) / period
    avg_loss = sum(abs(min(change, 0.0)) for change in seed) / period
    for change in changes[period:]:
        avg_gain = ((avg_gain * (period - 1)) + max(change, 0.0)) / period
        avg_loss = ((avg_loss * (period - 1)) + abs(min(change, 0.0))) / period
    if avg_loss == 0:
        return 100.0
    relative_strength = avg_gain / avg_loss
    return 100 - (100 / (1 + relative_strength))


def atr(candles: Sequence[Candle], period: int = 14) -> float:
    if len(candles) < period + 1:
        raise ValueError(f"Need {period + 1} candles for ATR.")
    true_ranges = []
    for index in range(1, len(candles)):
        candle = candles[index]
        previous_close = candles[index - 1].close
        true_ranges.append(max(
            candle.high - candle.low,
            abs(candle.high - previous_close),
            abs(candle.low - previous_close),
        ))
    value = sum(true_ranges[:period]) / period
    for current in true_ranges[period:]:
        value = ((value * (period - 1)) + current) / period
    return value


def bollinger(values: Sequence[float], period: int = 20, deviations: float = 2.0) -> tuple[float, float, float]:
    if len(values) < period:
        raise ValueError(f"Need {period} values for Bollinger Bands.")
    window = values[-period:]
    middle = sum(window) / period
    variance = sum((value - middle) ** 2 for value in window) / period
    spread = sqrt(variance) * deviations
    return middle, middle + spread, middle - spread
