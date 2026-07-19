from __future__ import annotations

import argparse
import logging
import time

from .config import Settings
from .scanner import Scanner


def run() -> int:
    parser = argparse.ArgumentParser(description="Fortress FX live signal scanner")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--once", action="store_true", help="Run one complete scan.")
    mode.add_argument("--loop", action="store_true", help="Scan continuously at the configured interval.")
    args = parser.parse_args()

    settings = Settings.from_env()
    settings.validate_runtime()
    logging.basicConfig(
        level=getattr(logging, settings.log_level, logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s - %(message)s",
    )

    scanner = Scanner(settings)
    try:
        while True:
            for outcome in scanner.scan_all():
                logging.info("%s %s: %s — %s", outcome.instrument, outcome.timeframe, outcome.status, outcome.detail)
            if args.once:
                return 0
            time.sleep(settings.scan_interval_seconds)
    finally:
        scanner.close()


if __name__ == "__main__":
    raise SystemExit(run())
