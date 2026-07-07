from __future__ import annotations

import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

from .models import RiskDecision, Signal


class SignalLedger:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(path)
        self.connection.execute(
            """
            CREATE TABLE IF NOT EXISTS signals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                key TEXT NOT NULL,
                instrument TEXT NOT NULL,
                timeframe TEXT NOT NULL,
                direction TEXT NOT NULL,
                strategy TEXT NOT NULL,
                regime TEXT NOT NULL,
                confidence INTEGER NOT NULL,
                entry REAL NOT NULL,
                stop_loss REAL NOT NULL,
                take_profit REAL NOT NULL,
                reward_risk REAL NOT NULL,
                accepted INTEGER NOT NULL,
                decision_reasons TEXT NOT NULL,
                signal_reasons TEXT NOT NULL
            )
            """
        )
        self.connection.execute("CREATE INDEX IF NOT EXISTS idx_signals_key_created ON signals(key, created_at)")
        self.connection.commit()

    def is_duplicate(self, signal: Signal, cooldown_minutes: int) -> bool:
        threshold = (datetime.now(timezone.utc) - timedelta(minutes=cooldown_minutes)).isoformat()
        row = self.connection.execute(
            "SELECT 1 FROM signals WHERE key = ? AND created_at >= ? AND accepted = 1 LIMIT 1",
            (signal.idempotency_key, threshold),
        ).fetchone()
        return row is not None

    def alerts_today(self) -> int:
        today = datetime.now(timezone.utc).date().isoformat()
        row = self.connection.execute(
            "SELECT COUNT(*) FROM signals WHERE accepted = 1 AND created_at >= ?",
            (f"{today}T00:00:00+00:00",),
        ).fetchone()
        return int(row[0]) if row else 0

    def record(self, signal: Signal, decision: RiskDecision) -> None:
        self.connection.execute(
            """
            INSERT INTO signals (
                created_at, key, instrument, timeframe, direction, strategy, regime,
                confidence, entry, stop_loss, take_profit, reward_risk, accepted,
                decision_reasons, signal_reasons
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                signal.created_at.isoformat(),
                signal.idempotency_key,
                signal.instrument,
                signal.timeframe,
                signal.direction.value,
                signal.strategy,
                signal.regime,
                signal.confidence,
                signal.entry,
                signal.stop_loss,
                signal.take_profit,
                signal.reward_risk,
                int(decision.accepted),
                " | ".join(decision.reasons),
                " | ".join(signal.reasons),
            ),
        )
        self.connection.commit()

    def close(self) -> None:
        self.connection.close()
