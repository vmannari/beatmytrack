"""Read-only native backend validation; no service/account writes."""
import json
import sys
from pathlib import Path
from types import SimpleNamespace

repo = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(repo / "backend"))
from bmt_backend.verifier import GodotVerifier  # noqa: E402

schema = json.loads((repo / "docs/schemas/creator-track-v5.schema.json").read_text(encoding="utf-8"))
objects = schema["properties"]["objects"]["items"]
assert objects["properties"]["length"]["minimum"] == 0.01
assert objects["properties"]["length"]["maximum"] == 18
assert set(objects["allOf"][0]["then"]["properties"]["kind"]["enum"]) == {
    "barrier", "fence", "guardrail", "wire_fence"
}
document = json.loads((repo / "build/continuous-barriers-native-document.json").read_text(encoding="utf-8"))
settings = SimpleNamespace(
    godot_bin="C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe",
    game_project=repo / "game", verifier_timeout_seconds=60,
)
verifier = GodotVerifier(settings)
try:
    first = verifier.validate_track(document)
    second = verifier.validate_track(document)
    assert first["track_content_hash"] == second["track_content_hash"]
    assert all("length" in obj for obj in document["objects"])
    result = f"NATIVE_BARRIER_VALIDATION: 5 checks, 0 failures; sections={len(document['objects'])}; hash={first['track_content_hash']}"
    print(result)
    (Path(__file__).parent / "logs/native-validation.log").write_text(result + "\n", encoding="utf-8")
finally:
    verifier.close()
