"""Reconcile final five-car receipts and preserve all nonpassing attempts."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-model-refinement-2026-11-12"
required = ["modules-compact", "modules-kart", "modules-forklift", "modules-electric", "modules-hovercraft",
            "live-direct-corrected", "live-prepared-qualified", "live-contact", "live-cockpit", "live-clearance",
            "app-kart-compat", "app-kart-mobile", "steering-prepared-compat", "steering-prepared-mobile",
            "wash-compat-ready", "wash-surfaces", "retained-ghosts", "driving", "runtime-parser",
            "prepared-preflight", "garage-pictures", "final-metrics-qualified", "final-views-compat", "final-views-mobile"]
receipts = {}
for name in required:
    receipt = json.loads((OUT / (name + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0 and not receipt["errors"], name
    receipts[name] = receipt
assert json.loads((OUT / "refresh-source-receipt.json").read_text())["changed"] == []
before = json.loads((OUT / "task-start-hashes.json").read_text())
index_matches_start = hashlib.sha256((ROOT / ".git/index").read_bytes()).hexdigest() == before[".git/index"]
module_checks = 0
for name in required[:5]:
    content = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
    match = re.search(r"MODULAR_CAR_ASSETS: (\d+) checks, 0 failures", content)
    assert match, name
    module_checks += int(match[1])
assert module_checks == 7557
assert "GARAGE_PREVIEWS: 5 exact native images" in (OUT / "picture-preflight.log").read_text()
assert "468 resources; 1925 checks, 0 failures" in (OUT / "prepared-preflight.log").read_text()
old = json.loads((ROOT / "docs/evidence/car-model-review-2026-11-12/headless.json").read_text())
new = json.loads((OUT / "current-metrics/headless.json").read_text())
baseline = {row["id"]: row for row in old["rows"] if row["case"] == 0}
metrics = []
for row in new["rows"]:
    if row["case"] != 0:
        continue
    original = baseline[row["id"]]["buffer_bytes"]
    metrics.append({"id": row["id"], "triangles": row["triangles"], "visible_surfaces": row["surfaces"],
                    "before_buffer_bytes": original, "after_buffer_bytes": row["buffer_bytes"],
                    "saved_bytes": original-row["buffer_bytes"],
                    "saved_percent": 100*(original-row["buffer_bytes"])/original})
protected_changes = [name for name, sha in before.items()
                     if ("challenger_hellcat_v1" in name or name.endswith("super_rally_model.gd"))
                     and (ROOT / name).is_file() and hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != sha]
summary = {"module_checks": module_checks, "prepared_resources": 468, "prepared_checks": 1925,
           "checked_picture_count": 5, "static_helmet_morph_bytes_removed": 495720,
           "main_index_equals_task_start_at_handoff": index_matches_start,
           "stock_metrics": metrics, "final_receipts": receipts,
           "concurrent_protected_input_changes": protected_changes,
           "limitations": ["Challenger model/picture authoring excluded; concurrent changes preserved.",
                           "Full six-car release readiness and original Challenger pixel identity are not claimed.",
                           "Kart final counts include concurrent cloth authoring.",
                           "No physical-device test or FPS claim."]}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
manifest = {p.relative_to(OUT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in OUT.rglob("*") if p.is_file() and p.name not in ["artifact-hashes.json", "source-only.patch"]}
(OUT / "artifact-hashes.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(json.dumps({"module_checks": module_checks, "prepared_checks": 1925, "pictures": 5,
                  "main_index_equals_task_start_at_handoff": index_matches_start, "stock_metrics": metrics}))
