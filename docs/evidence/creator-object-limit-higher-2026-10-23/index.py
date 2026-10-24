"""Index the higher-count follow-up without replacing the baseline evidence."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
data = json.loads((HERE/"results-higher.json").read_text())
assert data["checks"] == 40 and data["failures"] == 0
assert data["rows"][-1]["stage"] == "complete"
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
sources = ["game/tests/profile_creator_object_limit_higher.gd",
           "game/tests/profile_creator_object_limit.gd",
           "game/tests/profile_creator_object_limit_bootstrap.gd",
           "docs/evidence/creator-object-limit-2026-10-23/run.ps1",
           "game/editor/track_document.gd", "game/editor/placed_object_batches.gd",
           "game/editor/editor_history.gd", "game/vehicle/tyre_contacts.gd",
           "game/vehicle/loose_tyres.gd", "native/track_geometry/tyre_contacts.hpp"]
report = {
    "date": "2026-10-23", "requirement": "COL-A04",
    "intent": "Owner's tenfold guess is not a capacity ceiling; measure higher counts",
    "recommendation": {"next_engineering_target": 4096, "subsequent_target": 8192,
                       "arbitrary_mix_device_certified": False, "shipping_limit_unchanged": 96},
    "command": "powershell -ExecutionPolicy Bypass -File docs/evidence/creator-object-limit-2026-10-23/run.ps1 -Mode Higher",
    "exit_code": 0, "checks": data["checks"], "failures": data["failures"],
    "document_counts": [960, 2048, 4096, 8192, 16384],
    "body_counts": [960, 2048, 4096, 4097, 8192],
    "visual_counts": [2048, 4096, 8192],
    "current_byte_limit": 524288, "native_body_ceiling": 4096,
    "scope": "Headless isolated desktop component probe; count-only in-memory validator; no runtime policy edit; oversized fractional documents compile-skipped and visual components explicitly marked",
    "remaining": ["incremental editor updates", "per-object history sharing", "spatial tyre batches",
                  "native fallback boundary", "filtered hazard work", "higher document contract",
                  "matching backend/client acceptance", "device cold/thermal/touch/PSS acceptance"],
    "not_performed": ["phone attachment check", "physical device test", "APK", "live account/backend mutation", "deployment"],
    "source_sha256": {name: sha(ROOT/name) for name in sources},
    "artifacts": {p.name: sha(p) for p in HERE.iterdir() if p.is_file() and p.name != "report.json"},
    "baseline": "baseline-report.json retains the original 960-target report and its original checkpoint",
}
(HERE/"report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print("Higher-count report: 40 assertions passed; next target 4096, subsequent target 8192.")
