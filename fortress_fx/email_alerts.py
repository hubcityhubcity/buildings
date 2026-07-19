from __future__ import annotations

import smtplib
import ssl
from email.message import EmailMessage

from .models import Quote, Signal


class EmailNotifier:
    """Send a plaintext trade signal by authenticated SMTP with STARTTLS."""

    def __init__(
        self,
        smtp_host: str,
        smtp_port: int,
        username: str,
        app_password: str,
        sender: str,
        recipient: str,
    ) -> None:
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.username = username
        self.app_password = app_password
        self.sender = sender
        self.recipient = recipient

    def send_signal(self, signal: Signal, quote: Quote) -> None:
        message = EmailMessage()
        message["From"] = self.sender
        message["To"] = self.recipient
        message["Subject"] = (
            f"Fortress FX {signal.direction.value}: {signal.instrument} "
            f"{signal.timeframe} [{signal.confidence}/100]"
        )
        message.set_content(
            "\n".join(
                (
                    f"FORTRESS FX — {signal.direction.value} SIGNAL",
                    "",
                    f"Instrument: {signal.instrument}",
                    f"Timeframe: {signal.timeframe}",
                    f"Strategy: {signal.strategy.replace('_', ' ').title()}",
                    f"Regime: {signal.regime.title()}",
                    f"Confidence: {signal.confidence}/100",
                    "",
                    f"Entry reference: {signal.entry:.5f}",
                    f"Live midpoint: {quote.mid:.5f}",
                    f"Stop: {signal.stop_loss:.5f}",
                    f"Target: {signal.take_profit:.5f}",
                    f"Estimated R:R: {signal.reward_risk:.2f}",
                    "",
                    "Why now:",
                    *(f"- {reason}" for reason in signal.reasons),
                    "",
                    "Signal-only. Confirm current conditions before acting.",
                )
            )
        )

        context = ssl.create_default_context()
        with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=20) as smtp:
            smtp.ehlo()
            smtp.starttls(context=context)
            smtp.ehlo()
            smtp.login(self.username, self.app_password)
            smtp.send_message(message)
