from __future__ import annotations

from typing import Sequence

from .market_math import atr, bollinger, ema, rsi
from .models import Candle, Direction, Signal


def detect_regime(candles: Sequence[Candle]) -> str:
    closes = [candle.close for candle in candles]
    fast = ema(closes, 20)
    slow = ema(closes, 50)
    current_atr = atr(candles, 14)
    separation = abs(fast - slow) / current_atr if current_atr else 0.0
    recent_span = max(candle.high for candle in candles[-20:]) - min(candle.low for candle in candles[-20:])
    span_in_atr = recent_span / current_atr if current_atr else 0.0
    if separation >= 0.55:
        return "TRENDING"
    if span_in_atr <= 4.0:
        return "RANGING"
    return "TRANSITIONAL"


def trend_pullback(candles: Sequence[Candle], instrument: str, timeframe: str, regime: str) -> Signal | None:
    closes = [candle.close for candle in candles]
    fast, slow = ema(closes, 20), ema(closes, 50)
    current_rsi, current_atr = rsi(closes, 14), atr(candles, 14)
    last, previous = candles[-1], candles[-2]

    if fast > slow and last.close > fast and 45 <= current_rsi <= 68 and last.close > previous.high:
        stop = min(candle.low for candle in candles[-6:]) - (0.25 * current_atr)
        risk = last.close - stop
        return Signal(
            instrument, timeframe, Direction.LONG, "trend_pullback", regime, last.close, stop,
            last.close + (risk * 2.0), min(92, round(65 + (fast - slow) / current_atr * 18)),
            ("20 EMA above 50 EMA", "price reclaimed the fast EMA", "RSI supports upside continuation"),
        )
    if fast < slow and last.close < fast and 32 <= current_rsi <= 55 and last.close < previous.low:
        stop = max(candle.high for candle in candles[-6:]) + (0.25 * current_atr)
        risk = stop - last.close
        return Signal(
            instrument, timeframe, Direction.SHORT, "trend_pullback", regime, last.close, stop,
            last.close - (risk * 2.0), min(92, round(65 + (slow - fast) / current_atr * 18)),
            ("20 EMA below 50 EMA", "price rejected the fast EMA", "RSI supports downside continuation"),
        )
    return None


def momentum_breakout(candles: Sequence[Candle], instrument: str, timeframe: str, regime: str) -> Signal | None:
    closes = [candle.close for candle in candles]
    fast, slow = ema(closes, 20), ema(closes, 50)
    current_rsi, current_atr = rsi(closes, 14), atr(candles, 14)
    last = candles[-1]
    previous_window = candles[-21:-1]
    breakout_high = max(candle.high for candle in previous_window)
    breakout_low = min(candle.low for candle in previous_window)

    if last.close > breakout_high and fast > slow and current_rsi >= 57:
        stop = last.close - (1.25 * current_atr)
        risk = last.close - stop
        return Signal(
            instrument, timeframe, Direction.LONG, "momentum_breakout", regime, last.close, stop,
            last.close + (risk * 2.2), min(94, round(68 + (current_rsi - 55))),
            ("20-bar upside breakout", "EMA trend agrees", "RSI confirms momentum"),
        )
    if last.close < breakout_low and fast < slow and current_rsi <= 43:
        stop = last.close + (1.25 * current_atr)
        risk = stop - last.close
        return Signal(
            instrument, timeframe, Direction.SHORT, "momentum_breakout", regime, last.close, stop,
            last.close - (risk * 2.2), min(94, round(68 + (45 - current_rsi))),
            ("20-bar downside breakout", "EMA trend agrees", "RSI confirms momentum"),
        )
    return None


def mean_reversion(candles: Sequence[Candle], instrument: str, timeframe: str, regime: str) -> Signal | None:
    closes = [candle.close for candle in candles]
    middle, upper, lower = bollinger(closes, 20, 2.0)
    current_rsi, current_atr = rsi(closes, 14), atr(candles, 14)
    last = candles[-1]

    if last.close < lower and current_rsi <= 27:
        stop = last.low - (0.8 * current_atr)
        risk = last.close - stop
        if middle - last.close >= risk * 1.5:
            return Signal(
                instrument, timeframe, Direction.LONG, "mean_reversion", regime, last.close, stop, middle,
                min(88, round(66 + (30 - current_rsi))),
                ("close below lower Bollinger Band", "RSI shows downside exhaustion", "target is the statistical mean"),
            )
    if last.close > upper and current_rsi >= 73:
        stop = last.high + (0.8 * current_atr)
        risk = stop - last.close
        if last.close - middle >= risk * 1.5:
            return Signal(
                instrument, timeframe, Direction.SHORT, "mean_reversion", regime, last.close, stop, middle,
                min(88, round(66 + (current_rsi - 70))),
                ("close above upper Bollinger Band", "RSI shows upside exhaustion", "target is the statistical mean"),
            )
    return None


def evaluate_strategies(candles: Sequence[Candle], instrument: str, timeframe: str) -> list[Signal]:
    if len(candles) < 80:
        return []
    regime = detect_regime(candles)
    candidates: list[Signal | None]
    if regime == "TRENDING":
        candidates = [trend_pullback(candles, instrument, timeframe, regime), momentum_breakout(candles, instrument, timeframe, regime)]
    elif regime == "RANGING":
        candidates = [mean_reversion(candles, instrument, timeframe, regime)]
    else:
        candidates = [trend_pullback(candles, instrument, timeframe, regime), momentum_breakout(candles, instrument, timeframe, regime), mean_reversion(candles, instrument, timeframe, regime)]
    return sorted((candidate for candidate in candidates if candidate), key=lambda item: item.confidence, reverse=True)
