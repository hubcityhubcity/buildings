from __future__ import annotations

from datetime import datetime
from typing import Any

import requests

from .config import Settings
from .models import Candle, Quote


class OandaClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {settings.oanda_token}",
                "Content-Type": "application/json",
                "Accept-Datetime-Format": "RFC3339",
            }
        )

    @staticmethod
    def _timestamp(raw: str) -> datetime:
        return datetime.fromisoformat(raw.replace("Z", "+00:00"))

    def _get(self, path: str, params: dict[str, Any]) -> dict[str, Any]:
        response = self.session.get(
            f"{self.settings.oanda_rest_url}{path}",
            params=params,
            timeout=(5, 20),
        )
        response.raise_for_status()
        return response.json()

    def candles(self, instrument: str, granularity: str, count: int) -> list[Candle]:
        payload = self._get(
            f"/v3/accounts/{self.settings.oanda_account_id}/instruments/{instrument}/candles",
            {"price": "M", "granularity": granularity, "count": count, "smooth": "false"},
        )
        candles: list[Candle] = []
        for item in payload.get("candles", []):
            if not item.get("complete") or "mid" not in item:
                continue
            mid = item["mid"]
            candles.append(
                Candle(
                    timestamp=self._timestamp(item["time"]),
                    open=float(mid["o"]),
                    high=float(mid["h"]),
                    low=float(mid["l"]),
                    close=float(mid["c"]),
                    volume=int(item.get("volume", 0)),
                )
            )
        if not candles:
            raise RuntimeError(f"OANDA returned no completed candles for {instrument} {granularity}.")
        return candles

    def quote(self, instrument: str) -> Quote:
        payload = self._get(
            f"/v3/accounts/{self.settings.oanda_account_id}/pricing",
            {"instruments": instrument, "includeHomeConversions": "false"},
        )
        prices = payload.get("prices", [])
        if not prices:
            raise RuntimeError(f"OANDA returned no quote for {instrument}.")
        price = prices[0]
        return Quote(
            instrument=instrument,
            bid=float(price["bids"][0]["price"]),
            ask=float(price["asks"][0]["price"]),
            timestamp=self._timestamp(price["time"]),
        )
