"""Reconcile the final production snapshot without discarding rejected attempts."""
import hashlib
import json
from pathlib import Path
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-simplification-2026-11-13"
required = ["piece-bake-scoped", "direct-final-pieces", "prepared-pieces", "final-metrics",
            "modules-compact", "modules-kart", "modules-forklift", "modules-electric", "modules-hovercraft",
            "app-compat", "app-mobile", "steering-compat", "steering-mobile", "hover-lod-compat", "hover-lod-mobile",
            "final-views-compat", "final-views-mobile", "contact", "cockpit", "clearance", "driving", "ghosts",
            "wash-final", "wash-surfaces", "parser-final", "prepared-preflight", "garage-pictures", "factory-art-final"]
receipts = {}
for label in required:
    receipt = json.loads((OUT / (label + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0 and not receipt["errors"], label
    receipts[label] = receipt
module_checks = 0
for car in ["compact", "kart", "forklift", "electric", "hovercraft"]:
    text = (OUT / ("modules-" + car + ".log")).read_text(encoding="utf-8", errors="replace")
    match = re.search(r"MODULAR_CAR_ASSETS: (\d+) checks, 0 failures", text)
    assert match, car
    module_checks += int(match[1])
assert module_checks == 7557
assert "468 resources; 1925 checks, 0 failures" in (OUT / "prepared-preflight.log").read_text()
assert "5 exact native images" in (OUT / "picture-preflight.log").read_text()
refresh = json.loads((OUT / "refresh-source-receipt.json").read_text())
assert refresh["changed"] == []
before = json.loads((OUT / "refresh-source-before.json").read_text())
current = runpy.run_path(str(ROOT / "scripts/refresh_car_simplification.py"))["sources"]()
drift = sorted(p for p in before.keys() | current.keys() if before.get(p) != current.get(p))
assert not drift, drift
start = json.loads((OUT / "start.json").read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(ROOT / ".git/index") == start[".git/index"]
controls = {p: sha(ROOT / p) == digest for p, digest in start.items()
            if p.startswith("game/resources/cars/") or p in ["game/vehicle/kart_steering.gd", "game/vehicle/kart_model.gd",
            "game/vehicle/forklift_model.gd", "game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res",
            "game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res"]}
assert all(controls.values()), controls
old = json.loads((OUT / "baseline-metrics/headless.json").read_text())
new = json.loads((OUT / "current-metrics/headless.json").read_text())
metrics = []
for row in new["rows"]:
    if row["case"] != 0:
        continue
    prior = next(r for r in old["rows"] if r["id"] == row["id"] and r["case"] == 0)
    assert row["base_hits"] == 1
    assert row["surfaces"] == prior["surfaces"]
    metrics.append({"vehicle": row["id"], "before_triangles": prior["triangles"], "triangles": row["triangles"],
                    "triangle_reduction_percent": 100 * (prior["triangles"] - row["triangles"]) / prior["triangles"],
                    "before_buffer_bytes": prior["buffer_bytes"], "buffer_bytes": row["buffer_bytes"],
                    "buffer_change_percent": 100 * (row["buffer_bytes"] - prior["buffer_bytes"]) / prior["buffer_bytes"],
                    "visible_surfaces": row["surfaces"], "base_hits": row["base_hits"]})
imports = json.loads((OUT / "image-import-receipt.json").read_text())
assert imports["verified_images"] == 260 and not imports["editor_diagnostics"]
protected = {p: {"before": digest, "after": sha(ROOT / p)} for p, digest in start.items()
             if ("challenger_hellcat_v1/" in p or p.endswith("super_rally_model.gd"))
             and (ROOT / p).is_file() and sha(ROOT / p) != digest}
summary = {"module_checks": module_checks, "prepared_resources": 468, "prepared_checks": 1925,
           "main_index_exact": True, "controls": controls, "current_input_count": len(current), "current_source_drift": drift,
           "stock_metrics": metrics, "receipts": receipts, "concurrent_protected_inputs": protected,
           "limits": ["Challenger assets and cache publication excluded; concurrent edits preserved.",
                      "Raw active-assembly payload is not total RAM, measured VRAM, package size or FPS.",
                      "Volt and Hover distance data increase active buffer payload.",
                      "Owner art acceptance and physical-device qualification remain."]}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps({"module_checks": module_checks, "prepared_checks": 1925, "source_drift": drift,
                  "main_index_exact": True, "stock_metrics": metrics}))
