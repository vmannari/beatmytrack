"""Summarize the four final native comparisons; exclude exploratory variants."""
import hashlib
import json
from pathlib import Path
from statistics import median

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
summary = {"decision": "restore original; dedicated studio not shipped", "checks": 0,
           "failures": 0, "renderers": {}, "source_changes_during_runs": {}}
for renderer in ("compat", "mobile"):
    runs = {}
    for strategy in ("original", "studio"):
        label = f"measure-{renderer}-{strategy}"
        report = json.loads((evidence/label/"report.json").read_text())
        receipt = json.loads((evidence/(label+"-receipt.json")).read_text())
        assert receipt["exit_code"] == report["failures"] == 0
        assert len(report["rows"]) == 3
        assert set(receipt["changed_sources"]) <= {"game/core/build_identity.gd"}
        summary["checks"] += report["checks"]
        summary["source_changes_during_runs"][label] = receipt["changed_sources"]
        rows = report["rows"]
        runs[strategy] = {
            "first": {key: rows[0][key] for key in ("picture_ms", "persisted_ms")},
            "later_median": {key: median(row[key] for row in rows[1:])
                             for key in ("picture_ms", "persisted_ms")},
            "rounds": [{key: row[key] for key in ("round", "picture_ms", "persisted_ms", "largest_frame_ms")}
                       for row in rows],
            "scene_estimates": {item["metrics"]["vehicle"]: {
                key: item["metrics"][key] for key in ("scene_bytes_estimate", "viewports", "viewport_pixels", "nodes", "meshes")}
                for item in rows[0]["deliveries"]},
        }
    runs["reduction_percent"] = {
        phase: {key: 100*(1-runs["studio"][phase][key]/runs["original"][phase][key])
                for key in ("picture_ms", "persisted_ms")}
        for phase in ("first", "later_median")}
    summary["renderers"][renderer] = runs

production = ["game/ui/garage_preview_cache.gd", "game/ui/garage_preview_renderer.gd",
              "game/ui/garage_page.gd", "game/ui/garage_preloaded_studio.gd",
              "scripts/bake_garage_previews.gd", "scripts/check_garage_previews.py", "scripts/build_identity.ps1"]
summary["production_matches_before"] = {}
for path in production:
    current = (root/path).read_bytes()
    assert current == (evidence/"before"/path).read_bytes(), path
    summary["production_matches_before"][path] = hashlib.sha256(current).hexdigest()
assert not (root/"game/ui/garage_thumbnail_studio.gd").exists()
assert not (root/"game/ui/garage_thumbnail_shadow.gdshader").exists()
summary["primary_native_pngs"] = sum(len(list((evidence/label).glob("*.png")))
    for label in summary["source_changes_during_runs"])
(evidence/"summary.json").write_text(json.dumps(summary, indent=2)+"\n")
print(json.dumps({key: summary[key] for key in ("decision", "checks", "failures", "primary_native_pngs")}))
for name, result in summary["renderers"].items():
    print(name, result["reduction_percent"])
