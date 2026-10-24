"""Add optional negotiated download fields without replacing concurrent contracts."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
for name in ["backend/schemas/discovery-query-v3.schema.json", "backend/schemas/discovery-page-v3.schema.json"]:
    path = ROOT / name
    before = HERE / "before" / name
    if not before.exists():
        before.parent.mkdir(parents=True, exist_ok=True)
        before.write_bytes(path.read_bytes())
    value = json.loads(path.read_text())
    if "query" in name:
        value["properties"].update({"preview_cache": {"type": "boolean", "default": False},
            "known_previews": {"type": "array", "maxItems": 32,
                "items": {"type": "string", "pattern": "^[0-9a-f]{64}$"}}})
    else:
        item = value["properties"]["items"]["items"]
        item["required"].remove("points") if "points" in item["required"] else None
        item["properties"]["preview_hash"] = {"type": "string", "pattern": "^[0-9a-f]{64}$"}
        item["anyOf"] = [{"required": ["points"]}, {"required": ["preview_hash"]}]
    path.write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")
