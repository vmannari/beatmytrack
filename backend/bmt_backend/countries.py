"""Offline allowlist shared with the native country picker."""
import hashlib
import json
from pathlib import Path

COUNTRIES = json.loads(Path(__file__).with_name("countries.json").read_text(encoding="utf-8"))
COUNTRY_CODES = frozenset(row["code"] for row in COUNTRIES)
TEST_COUNTRIES = ("FI", "SE", "GB", "DE", "FR", "IT", "ES", "US", "CA", "BR", "JP", "AU", "NL", "NO")


def test_country(player_id: str) -> str:
    """Fictional profile metadata; never infer real players' nationality."""
    return TEST_COUNTRIES[int(hashlib.sha256(player_id.encode()).hexdigest()[:8], 16) % len(TEST_COUNTRIES)]
