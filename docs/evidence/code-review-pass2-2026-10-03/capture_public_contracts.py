"""Read-only local public endpoints, recording no player data or credentials."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

ORIGIN = "http://127.0.0.1:18181"
FIELDS = ("engine_version", "verifier_version", "physics_version", "rules_key",
          "compiler_version", "track_schema", "replay_schema", "tick_rate", "laps")


def public_get(path):
    try:
        with urlopen(ORIGIN + path, timeout=3) as response:
            return response.status, json.load(response)
    except HTTPError as error:
        return error.code, {}
    except (URLError, TimeoutError, OSError, ValueError):
        return None, {}


def main():
    result = {"observed_at_utc": datetime.now(timezone.utc).isoformat(),
              "origin": ORIGIN, "authenticated_requests": False}
    for path in ("/healthz", "/readyz", "/v1/manifest"):
        status, body = public_get(path)
        result[path] = {"http_status": status,
                        "contract": {key: body[key] for key in FIELDS if key in body}}
    status, catalog = public_get("/v1/tracks?limit=1")
    items = catalog.get("items", [])
    result["catalog_sample"] = {"http_status": status, "returned_entries": len(items)}
    if items:
        version_id = str(items[0].get("version_id", ""))
        if len(version_id) == 36 and all(c in "0123456789abcdef-" for c in version_id):
            status, board = public_get(f"/v1/track-versions/{version_id}/leaderboard?limit=1")
            manifest = board.get("manifest", {})
            result["sample_board"] = {"http_status": status,
                "contract": {key: manifest[key] for key in FIELDS if key in manifest}}
    destination = Path(__file__).with_name("live-public-contracts.json")
    destination.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
