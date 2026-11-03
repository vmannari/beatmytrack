"""Reconcile completed native checks, reviewed views and exact shipping artefacts."""
from pathlib import Path
import hashlib
import json
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def read(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    results = {}
    for name, prefix in [("options-final", "FORKLIFT_KITS"), ("original-final", "FORKLIFT_ORIGINAL_CABIN"), ("construction-edge-final", "FORKLIFT_KIT_CONSTRUCTION"), ("prepared", "MODULAR_CAR_ASSETS"), ("garage-gl", "FORKLIFT_GARAGE"), ("garage-mobile", "FORKLIFT_GARAGE"), ("retained-model", "FORKLIFT_MODEL_FINISH")]:
        text = read(OUT / (name + ".log"))
        match = re.search(prefix + r": (\d+) checks, (\d+) failures", text)
        assert match and int(match[2]) == 0, name
        assert "SCRIPT ERROR" not in text and "FAIL:" not in text, name
        results[name] = {"checks": int(match[1]), "failures": int(match[2])}
    shots = {}
    for folder in ["before-review-gl", "review-edge-final", "garage-gl", "garage-mobile"]:
        paths = sorted((OUT / folder).glob("*.png"))
        assert len(paths) == 56, (folder, len(paths))
        shots[folder] = {p.name: sha(p) for p in paths}
    for name in ["review-before.log", "review-edge-final.log"]:
        text = read(OUT / name)
        assert "FORKLIFT_KIT_REVIEW: 56 captures" in text and "SCRIPT ERROR" not in text and "FAIL:" not in text
    backend = read(OUT / "backend.log")
    assert "60 passed" in backend and "failed" not in backend
    catalogue = "backend/bmt_backend/vehicle_appearance_catalog.json"
    assert (OUT / "before" / catalogue).read_bytes() == (ROOT / catalogue).read_bytes()
    construction = json.loads((OUT / "construction.json").read_text(encoding="utf-8"))
    assert construction["failures"] == 0
    sources = ["game/vehicle/forklift_model.gd", "game/vehicle/forklift_kits.gd", "game/vehicle/forklift_kit_surface.gd", "game/vehicle/vehicle_customisation.gd", "game/tests/test_forklift_kits.gd", "game/tests/test_forklift_original_cabin.gd", "game/tests/test_forklift_kit_construction.gd", "game/tests/capture_forklift_kit_refinement.gd", "scripts/update_forklift_cabin_catalog.py", "game/resources/cars/forklift.tres"]
    assets = sorted((ROOT / "game/assets/vehicles/modular_kits_v1/forklift").rglob("*.scn"))
    assert len(assets) == 104
    assets += sorted((ROOT / "game/assets/vehicles/modular_car_bases_v1").glob("forklift_*.scn"))
    assets.append(ROOT / "game/assets/garage/cars_v1/forklift.scn")
    report = {
        "requirements": ["FKR01", "FKR02", "FKR03", "FKR04", "FKR05", "R01", "Q01"],
        "scope": "Review and rebuild all 52 non-stock forklift kits; retain 14 choices in each of four categories",
        "engine": "4.7.2.stable.official.ed1daf0bf", "checks": results,
        "backend": "60 passed, 4 PostgreSQL cases deselected; complete server catalogue unchanged",
        "construction_triangle_maximum": max(v["triangles"] for v in construction["assemblies"].values()),
        "sources_sha256": {name: sha(ROOT / name) for name in sources},
        "assets_sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in assets},
        "screenshots_sha256": shots,
        "review": "All options inspected in four contact sheets and selected full-size views; final matched gallery includes every option. Owner appearance acceptance remains.",
        "retained_findings": ["Initial conditional typed-array construction error corrected", "First construction audit: 7,684 checks / 28 failures; panel boundary sampling, wheel seam precision and geometry budget repaired", "Recessed wheel-centre audit: 8,564 / 68; exact zero-width aperture tips repaired", "First cast-edge bevel audit: 8,564 / 80; tip-face normals corrected", "First close-up camera offsets were in world space; matched final views use car-local offsets", "Earlier high wheel covers were replaced by properly recessed wheel centres", "First successful bake preceded final aperture-edge refinement; repeated after the final change, earlier logs retained"],
        "limits": ["Owner appearance and touch acceptance remain", "No phone/device test, APK or device performance measurement", "No owner save/process changes", "No live purchase/sync mutation or deployment", "English display fallback retained", "Generated shared build identity excluded from task-only patch; regenerate with dev.ps1"],
        "visual_references": ["https://www.toyotaforklift.com/lifts/internal-combustion-forklifts-cushion-tire/core-ic-cushion-forklift", "https://www.linde-mh.co.uk/en_uk/Landingpage/Diesel-forklifts/"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": results, "assets": len(assets), "final_captures": sum(len(v) for v in shots.values()), "max_triangles": report["construction_triangle_maximum"]}, indent=2))

if __name__ == "__main__": main()
