"""Read-only integrity checks for the electric refinement's captured result."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent


def verify() -> None:
    report = json.loads((EVIDENCE / "report.json").read_text(encoding="utf-8"))
    checked = 0
    for name, expected in report["files_sha256"].items():
        path = ROOT / name
        assert path.is_file(), f"Missing artifact: {name}"
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, f"Changed artifact: {name}"
        checked += 1
    one_pedal = json.loads((EVIDENCE / "one-pedal.json").read_text())
    assert one_pedal["failures"] == 0 and one_pedal["checks"] == 63
    assert one_pedal["metrics"]["stop_72_kph_seconds"] <= 1.8
    assert one_pedal["metrics"]["first_tick_deceleration"] >= 11
    assert json.loads((EVIDENCE / "handling.json").read_text())["failures"] == 0
    for renderer in ("model", "mobile-model"):
        geometry = json.loads((EVIDENCE / renderer / "report.json").read_text())
        assert geometry["checks"] == 28 and geometry["failures"] == 0
        assert geometry["triangles"] == {"full": 160628, "simple": 57288}
    cache = ROOT / "game/assets/vehicles/electric_coachwork_v2"
    manifest = json.loads((cache / "manifest.json").read_text())
    assert len(manifest["meshes"]) == 470
    assert {item["file"] for item in manifest["meshes"]} == {p.name for p in cache.glob("*.res")}
    for key, path in (("source_sha256", "electric_coachwork.gd"), ("model_sha256", "electric_car_model.gd")):
        assert manifest[key] == hashlib.sha256((ROOT / "game/vehicle" / path).read_bytes()).hexdigest()
    assert not (ROOT / "game/assets/vehicles/electric_coachwork_v1").exists()
    photos = list((ROOT / "game/assets/liveries/previews_v2/electric").glob("*.png"))
    assert len(photos) == 49
    for photo in photos:
        raw = photo.read_bytes()
        assert raw[:8] == b"\x89PNG\r\n\x1a\n"
        assert struct.unpack(">II", raw[16:24]) == (320, 200)
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())["expected_manifest"]
    assert fixture["rules_key"] == "standing-5-road-gates-v22"
    assert fixture["physics_version"] == "arcade-planar-0.68"
    assert fixture["vehicles"]["electric"] == {
        "config_hash": "ae59641c3b5acf909296ac4f6719505e9bed1d0731d8a95213831e963e261e6e",
        "handling_version": "electric-2",
    }
    print(f"ELECTRIC_REFINEMENT_ARTIFACTS: {checked} hashes, 470 meshes, 49 photos; all checks pass")


if __name__ == "__main__":
    verify()
