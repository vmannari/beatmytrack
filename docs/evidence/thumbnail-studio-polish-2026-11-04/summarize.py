"""Verify the enabled studio's native receipts and packaged photo provenance."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
cases = {"production-final": "report.json", "appearance": "report.json",
         "persistent-final-seed": "seed.json", "persistent-final-reuse": "reuse.json",
         "deferred-app": "report.json", "gallery-accepted": "report.json"}
summary = {"decision": "seamless background, reflected turntable; interim blue lines removed",
           "native_checks": 3, "native_failures": 0, "runs": {}}
for label, report_name in cases.items():
    report = json.loads((evidence/label/report_name).read_text(encoding="utf-8"))
    receipt = json.loads((evidence/(label+"-receipt.json")).read_text(encoding="utf-8"))
    assert receipt["exit_code"] == report["failures"] == 0, label
    summary["native_checks"] += report["checks"]
    summary["runs"][label] = {"checks": report["checks"], "failures": report["failures"],
                              "changed_sources": receipt["changed_sources"]}
for label in ["pipeline", "bake-final", "import-assets"]:
    receipt = json.loads((evidence/(label+"-receipt.json")).read_text(encoding="utf-8"))
    assert receipt["exit_code"] == 0
    summary["runs"][label] = {"exit_code": 0, "changed_sources": receipt["changed_sources"]}
assert "3/3 passed" in (evidence/"pipeline.log").read_text(encoding="utf-8")
seed = json.loads((evidence/"persistent-final-seed/seed.json").read_text(encoding="utf-8"))
reuse = json.loads((evidence/"persistent-final-reuse/reuse.json").read_text(encoding="utf-8"))
assert seed["pixel_hashes"] == reuse["pixel_hashes"]
assert seed["renders"] == 5 and reuse["renders"] == 0
summary["persistent_reuse"] = {"pixel_exact": True, "seed_renders": 5, "reuse_renders": 0,
                               "reuse_ms": reuse["ready_ms"]}
result = subprocess.run([sys.executable, str(root/"scripts/check_garage_previews.py")],
                        cwd=root, capture_output=True, text=True)
summary["bundled_preview_check"] = {"exit_code": result.returncode, "output": result.stdout+result.stderr}
assert result.returncode == 0, result.stderr
provenance = json.loads((root/"game/assets/garage/previews_v1/provenance.json").read_text(encoding="utf-8"))
assert "Dedicated thumbnail studio" in provenance["source"]
assert "soft seamless backdrop" in provenance["source"]
summary["bundled_images"] = provenance["hashes"]
import statistics
baseline = json.loads((evidence/"baseline/report.json").read_text(encoding="utf-8"))
final = json.loads((evidence/"production-final/report.json").read_text(encoding="utf-8"))
summary["timings"] = {}
for field in ("picture_ms", "persisted_ms"):
    old = statistics.median(row[field] for row in baseline["rows"][1:])
    new = statistics.median(row[field] for row in final["rows"][1:])
    summary["timings"][field] = {"baseline_first": baseline["rows"][0][field], "final_first": final["rows"][0][field],
                                "baseline_later_median": old, "final_later_median": new, "later_percent_change": 100*(new/old-1)}
appearance = json.loads((evidence/"appearance/report.json").read_text(encoding="utf-8"))
summary["reflection_pixel_proof"] = appearance["rows"]
assert all(row["reflection"]["pixels"]>row["control"]["pixels"]+100 for row in appearance["rows"])
summary["captures"] = [str(path.relative_to(evidence)).replace("\\", "/")
                       for label in cases for path in (evidence/label).glob("*.png")]
summary["production_source_sha256"] = {
    path: hashlib.sha256((root/path).read_bytes()).hexdigest()
    for path in ["game/ui/garage_thumbnail_studio.gd", "game/ui/garage_thumbnail_reflections.gd",
                 "game/ui/garage_thumbnail_backdrop.gdshader", "game/ui/garage_thumbnail_deck.gdshader",
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
