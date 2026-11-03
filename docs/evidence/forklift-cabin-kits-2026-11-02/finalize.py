"""Record completed checks and exact forklift artefacts, without owner data."""
from pathlib import Path
import hashlib
import json
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def read(path):
    data = path.read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    results = {}
    for file, prefix in [("kits-final.log", "FORKLIFT_KITS"), ("original-corrected.log", "FORKLIFT_ORIGINAL_CABIN"), ("prepared.log", "MODULAR_CAR_ASSETS"), ("garage-gl-final.log", "FORKLIFT_GARAGE"), ("garage-mobile-final.log", "FORKLIFT_GARAGE"), ("retained-model.log", "FORKLIFT_MODEL_FINISH")]:
        match = re.search(prefix+r": (\d+) checks, (\d+) failures", read(OUT / file))
        assert match, file
        results[file] = {"checks": int(match[1]), "failures": int(match[2])}
        assert int(match[2]) == 0, file
    shots = {}
    for name in ["garage-gl-final", "garage-mobile-final"]:
        paths = sorted((OUT / name).glob("*.png"))
        assert len(paths) == 56, (name, len(paths))
        shots[name] = {p.name: sha(p) for p in paths}
    sources = ["game/vehicle/forklift_model.gd", "game/vehicle/forklift_kits.gd", "game/vehicle/vehicle_customisation.gd", "game/ui/garage_customisation_camera.gd", "game/ui/garage_part_indicator.gd", "backend/bmt_backend/vehicle_appearance_catalog.json", "backend/tests/test_forklift_kits.py", "game/tests/test_forklift_kits.gd", "game/tests/test_forklift_garage.gd", "game/tests/test_forklift_original_cabin.gd", "game/tests/test_forklift_prepared_kits.gd", "game/resources/cars/forklift.tres"]
    assets = sorted((ROOT / "game/assets/vehicles/modular_kits_v1/forklift").rglob("*.scn"))
    assert len(assets) == 104
    assets += sorted((ROOT / "game/assets/vehicles/modular_car_bases_v1").glob("forklift_*.scn"))
    assets.append(ROOT / "game/assets/garage/cars_v1/forklift.scn")
    before = json.loads((OUT / "before/backend/bmt_backend/vehicle_appearance_catalog.json").read_text())
    after = json.loads((ROOT / "backend/bmt_backend/vehicle_appearance_catalog.json").read_text())
    for category, ids in after["forklift_parts"].items():
        assert ids[:4] == before["forklift_parts"][category] and len(ids) == 14
    before.pop("forklift_parts"); after.pop("forklift_parts")
    assert before == after
    backend = read(OUT / "backend-sqlite.log")
    assert "171 passed" in backend and "failed" not in backend
    report = {
        "requirements": ["FKC01", "FKC02", "FKC03", "FKC04", "R01", "Q01"],
        "options_per_category": 14, "new_options_per_category": 10,
        "old_ids_and_unrelated_server_catalogue_retained": True,
        "godot": "4.7.2.stable.official.ed1daf0bf", "checks": results,
        "backend": {"focused": "171 passed, 6 deselected", "retained": "40 passed, 1 skipped, 1 pre-existing sticker-catalogue failure, 35 deselected", "postgresql": "Unavailable localhost service; initial 3 connection errors retained, final runs explicitly exclude PostgreSQL"},
        "sources_sha256": {n: sha(ROOT / n) for n in sources},
        "assets_sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in assets},
        "screenshots_sha256": shots,
        "initial_findings": ["Sandbox denied normal user log directory; isolated test APPDATA then used", "Sandbox denied Windows certificate-store read; offline native checks ran with normal Windows access", "Initial assertion assumed duplicate mesh names were retained: 741 checks / 2 failures; corrected presence assertion gives 741 / 0", "Initial Original comparison mixed batched and unbatched construction: 6 / 5; both raw builders give 6 / 0 with exactly zero normal difference", "Initial native captures sampled unfinished kit animations; retained separately, final captures wait for animation and camera completion", "Initial backend invocation lacked PYTHONPATH; corrected", "Retained sticker list mismatch is identical in task-start and final catalogue: 25 server entries versus 13 native"],
        "limits": ["No phone/device test or APK", "No owner-save or owner-process changes", "No live purchases, sync writes or deployment", "Matching backend catalogue rollout required for new online items", "Forklift category and option display copy continues the existing English fallback", "Owner appearance/touch acceptance and device performance remain", "dev.ps1 regenerated shared build identity; excluded from task-only patch; regenerate through dev.ps1 after applying"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": results, "assets": len(assets), "final_native_captures": sum(len(v) for v in shots.values())}, indent=2))

if __name__ == "__main__": main()
