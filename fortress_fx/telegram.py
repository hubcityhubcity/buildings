from __future__ import annotations

from html import escape

import requests

from .models import Quote, Signal


class TelegramNotifier:
    def __init__(self, token: str, chat_id: str) -> None:
        self.token = token
        self.chat_id = chat_id

    def send_signal(self, signal: Signal, quote: Quote) -> None:
        reasons = "\n".join(f"• {escape(reason)}" for reason in signal.reasons)
        message = (
            f"<b>FORTRESS FX — {signal.direction.value} SIGNAL</b>\n"
            f"<b>{escape(signal.instrument)} · {escape(signal.timeframe)}</b>\n\n"
            f"Strategy: <b>{escape(signal.strategy.replace('_', ' ').title())}</b>\n"
            f"Regime: <b>{escape(signal.regime.title())}</b>\n"
            f"Confidence: <b>{signal.confidence}/100</b>\n\n"
            f"Entry reference: <code>{signal.entry:.5f}</code>\n"
            f"Live midpoint: <code>{quote.mid:.5f}</code>\n"
            f"Stop: <code>{signal.stop_loss:.5f}</code>\n"
            f"Target: <code>{signal.take_profit:.5f}</code>\n"
            f"Estimated R:R: <b>{signal.reward_risk:.2f}</b>\n\n"
            f"<b>Why now</b>\n{reasons}\n\n"
            f"<i>Signal-only. Confirm current conditions before acting.</i>"
        )
        response = requests.post(
            f"https://api.telegram.org/bot{self.token}/sendMessage",
            json={
                "chat_id": self.chat_id,
                "text": message,
                "parse_mode": "HTML",
                "disable_web_page_preview": True,
            },
            timeout=(5, 20),
        )
        response.raise_for_status()
        payload = response.json()
        if not payload.get("ok"):
            raise RuntimeError(f"Telegram rejected notification: {payload}")
