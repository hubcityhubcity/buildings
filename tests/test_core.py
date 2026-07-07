from fortress_fx.market_math import pip_size
from fortress_fx.models import Direction, Signal


def test_jpy_pip_size() -> None:
    assert pip_size("USD_JPY") == 0.01
    assert pip_size("EUR_USD") == 0.0001


def test_signal_reward_risk() -> None:
    signal = Signal(
        instrument="EUR_USD",
        timeframe="M15",
        direction=Direction.LONG,
        strategy="test",
        regime="TRENDING",
        entry=1.1000,
        stop_loss=1.0990,
        take_profit=1.1020,
        confidence=80,
        reasons=("test",),
    )
    assert round(signal.reward_risk, 2) == 2.0
    assert len(signal.idempotency_key) == 24
