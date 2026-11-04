"""Verify the enabled studio's native receipts and packaged photo provenance."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
cases = {"production": "report.json", "persistent-seed": "seed.json", "persistent-reuse": "reuse.json",
         "warm-scheduling": "report.json", "deferred-app": "report.json", "first-entry": "report.json"}
summary = {"decision": "dedicated carousel studio enabled; full live Garage retained",
           "native_checks": 3, "native_failures": 0, "runs": {}}
for label, report_name in cases.items():
    report = json.loads((evidence/label/report_name).read_text())
    receipt = json.loads((evidence/(label+"-receipt.json")).read_text())
    assert receipt["exit_code"] == report["failures"] == 0, label
    summary["native_checks"] += report["checks"]
    summary["runs"][label] = {"checks": report["checks"], "failures": report["failures"],
                              "changed_sources": receipt["changed_sources"]}
for label in ["pipeline", "bake-final", "import-assets"]:
    receipt = json.loads((evidence/(label+"-receipt.json")).read_text())
    assert receipt["exit_code"] == 0
    summary["runs"][label] = {"exit_code": 0, "changed_sources": receipt["changed_sources"]}
assert "3/3 passed" in (evidence/"pipeline.log").read_text()
seed = json.loads((evidence/"persistent-seed/seed.json").read_text())
reuse = json.loads((evidence/"persistent-reuse/reuse.json").read_text())
assert seed["pixel_hashes"] == reuse["pixel_hashes"]
assert seed["renders"] == 5 and reuse["renders"] == 0
summary["persistent_reuse"] = {"pixel_exact": True, "seed_renders": 5, "reuse_renders": 0,
                               "reuse_ms": reuse["ready_ms"]}
result = subprocess.run([sys.executable, str(root/"scripts/check_garage_previews.py")],
                        cwd=root, capture_output=True, text=True)
summary["bundled_preview_check"] = {"exit_code": result.returncode, "output": result.stdout+result.stderr}
assert result.returncode == 0, result.stderr
provenance = json.loads((root/"game/assets/garage/previews_v1/provenance.json").read_text())
assert "Dedicated thumbnail studio" in provenance["source"]
summary["bundled_images"] = provenance["hashes"]
summary["captures"] = [str(path.relative_to(evidence)).replace("\\", "/")
                       for label in cases for path in (evidence/label).glob("*.png")]
summary["production_source_sha256"] = {
    path: hashlib.sha256((root/path).read_bytes()).hexdigest()
    for path in ["game/ui/garage_thumbnail_studio.gd", "game/ui/garage_thumbnail_shadow.gdshader",
                 "game/ui/garage_preview_cache.gd", "game/ui/garage_preloaded_studio.gd",
                 "game/ui/garage_preloader.gd", "game/ui/garage_page.gd", "scripts/bake_garage_previews.gd",
                 "scripts/build_identity.ps1"]}
summary["runtime_log_errors"] = {}
for label in summary["runs"]:
    lines = (evidence/(label+".log")).read_text(encoding="utf-8", errors="replace").splitlines()
    errors = [line for line in lines if any(word in line for word in ("ERROR:", "FAIL:", "TIMEOUT"))]
    summary["runtime_log_errors"][label] = errors
    assert all("Failed to read the root certificate store" in line for line in errors), (label, errors)
(evidence/"summary.json").write_text(json.dumps(summary, indent=2)+"\n")
print(summary["native_checks"], "native checks; zero failures;", len(summary["captures"]), "captures; five current bundled pictures.")
