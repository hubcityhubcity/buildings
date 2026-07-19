from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Sequence

from .config import Settings
from .market_math import pip_size
from .models import Candle, Direction, Signal
from .oanda import OandaClient
from .strategies import evaluate_strategies


@dataclass(frozen=True)
class BacktestResult:
    trades: int
    wins: int
    losses: int
    net_r: float
    max_drawdown_r: float

    @property
    def win_rate(self) -> float:
        return (self.wins / self.trades * 100) if self.trades else 0.0


def run_backtest(
    candles: Sequence[Candle],
    instrument: str,
    timeframe: str,
    spread_pips: float,
    slippage_pips: float,
) -> BacktestResult:
    """Conservative bar-by-bar baseline, not a promise of future performance."""
    trades = wins = losses = 0
    net_r = peak_r = max_drawdown_r = 0.0
    last_exit_index = 0
    unit_cost = (spread_pips + slippage_pips) * pip_size(instrument)

    for index in range(80, len(candles) - 2):
        if index <= last_exit_index:
            continue
        candidates = evaluate_strategies(candles[: index + 1], instrument, timeframe)
        if not candidates:
            continue
        signal = candidates[0]
        if signal.risk_distance <= 0:
            continue

        next_bar = candles[index + 1]
        entry = next_bar.open + unit_cost if signal.direction is Direction.LONG else next_bar.open - unit_cost
        adjusted = Signal(
            instrument=signal.instrument,
            timeframe=signal.timeframe,
            direction=signal.direction,
            strategy=signal.strategy,
            regime=signal.regime,
            entry=entry,
            stop_loss=signal.stop_loss,
            take_profit=signal.take_profit,
            confidence=signal.confidence,
            reasons=signal.reasons,
            metadata=signal.metadata,
        )

        outcome_r: float | None = None
        for future_index in range(index + 1, min(len(candles), index + 97)):
            bar = candles[future_index]
            # If stop and target are touched in the same bar, assume the adverse fill first.
            if adjusted.direction is Direction.LONG:
                if bar.low <= adjusted.stop_loss:
                    outcome_r = -1.0
                elif bar.high >= adjusted.take_profit:
                    outcome_r = adjusted.reward_risk
            else:
                if bar.high >= adjusted.stop_loss:
                    outcome_r = -1.0
                elif bar.low <= adjusted.take_profit:
                    outcome_r = adjusted.reward_risk
            if outcome_r is not None:
                last_exit_index = future_index
                break

        if outcome_r is None:
            continue
        trades += 1
        net_r += outcome_r
        peak_r = max(peak_r, net_r)
        max_drawdown_r = max(max_drawdown_r, peak_r - net_r)
        if outcome_r > 0:
            wins += 1
        else:
            losses += 1

    return BacktestResult(trades, wins, losses, net_r, max_drawdown_r)


def main() -> int:
    parser = argparse.ArgumentParser(description="Fortress FX baseline backtest")
    parser.add_argument("--instrument", default="EUR_USD")
    parser.add_argument("--granularity", default="M15")
    parser.add_argument("--count", type=int, default=3000)
    args = parser.parse_args()

    settings = Settings.from_env()
    if not settings.oanda_token or not settings.oanda_account_id:
        raise RuntimeError("OANDA_TOKEN and OANDA_ACCOUNT_ID are required for historical candles.")
    candles = OandaClient(settings).candles(args.instrument.upper(), args.granularity.upper(), args.count)
    result = run_backtest(
        candles,
        args.instrument.upper(),
        args.granularity.upper(),
        settings.backtest_spread_pips,
        settings.backtest_slippage_pips,
    )
    print(
        f"Trades={result.trades} Wins={result.wins} Losses={result.losses} "
        f"WinRate={result.win_rate:.1f}% NetR={result.net_r:.2f} MaxDrawdownR={result.max_drawdown_r:.2f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
