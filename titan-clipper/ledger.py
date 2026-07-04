import json
from pathlib import Path


def load_ledger(path: str) -> dict:
    file = Path(path)
    return json.loads(file.read_text()) if file.exists() else {"leads": [], "actions": [], "outcomes": []}
