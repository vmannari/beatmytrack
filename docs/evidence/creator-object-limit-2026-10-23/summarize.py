"""Index completed capacity probes and keep the analysis tables exact."""
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
data = {name: json.loads((HERE / f"results-{name}.json").read_text())
        for name in ("headless", "boundary", "mobile")}
for name, expected in (("headless", 38), ("boundary", 5), ("mobile", 13)):
    assert data[name]["checks"] == expected and data[name]["failures"] == 0, name
    assert data[name]["rows"][-1]["stage"] == "complete", name
higher_dir = HERE.parent / "creator-object-limit-higher-2026-10-23"
if (higher_dir / "results-higher.json").exists():
    data["higher"] = json.loads((higher_dir / "results-higher.json").read_text())
    assert data["higher"]["checks"] == 40 and data["higher"]["failures"] == 0
    assert data["higher"]["rows"][-1]["stage"] == "complete"

def row(stage, count, **fields):
    return next(r for r in data["headless"]["rows"] if r["stage"] == stage
                and r.get("count") == count and all(r[k] == v for k, v in fields.items()))

doc_path = ROOT / "docs/CREATOR_OBJECT_LIMIT_2026_10_23.md"
doc = doc_path.read_text(encoding="utf-8")
for kind, count, label in (("tyre_stack", 96, "96 single-stack objects"),
                           ("tyre_stack", 960, "960 single-stack objects"),
                           ("tyre_wall", 96, "96 six-stack walls"),
                           ("tyre_wall", 480, "480 six-stack walls")):
    r = row("tyre_impact", count, kind=kind)
    doc = re.sub(rf"^\| {label} \| [\d,]+ \| [\d.]+ ms \|$",
                 f"| {label} | {r['bodies']:,} | {r['ticks']['median_ms']:.3f} ms |", doc, flags=re.M)
for r in data["boundary"]["rows"]:
    if r["stage"] != "tyre_solver_boundary":
        continue
    label = f"{r['wall_objects']} six-stack walls, boundary probe"
    doc = re.sub(rf"^\| {label} \| [\d,]+ \| [\d.]+ ms \|$",
                 f"| {label} | {r['bodies']:,} | {r['ticks']['median_ms']:.3f} ms |", doc, flags=re.M)
for scenario, count, label in (("trees", 96, "96 trees"), ("trees", 960, "960 trees"),
                                ("barriers", 960, "960 concrete barriers"),
                                ("mixed", 960, "960 mixed nature/barrier props"),
                                ("winter_castles", 96, "96 snow castles"),
                                ("winter_castles", 288, "288 snow castles")):
    r = row("editor_props", count, scenario=scenario)
    doc = re.sub(rf"^\| {label} \| .*? \|$",
                 f"| {label} | {r['static_allocation_delta']/1048576:.1f} MiB | "
                 f"{r['initial_build_ms']:,.0f} ms | {r['move_one_ms']:.1f} ms |", doc, flags=re.M)
stacks = row("editor_props", 960, scenario="tyre_stacks")
walls = row("editor_props", 960, scenario="tyre_walls")
doc = re.sub(r"Tyres share geometry.*?Those figures do not include roads, ground, the complete app, GPU allocations or driver compilation\.",
             f"Tyres share geometry and are cheap to construct in the editor: 960 single-stack objects add about "
             f"{stacks['static_allocation_delta']/1048576:.2f} MiB of Godot static allocation, with a "
             f"{stacks['initial_build_ms']:.1f} ms initial build and a {stacks['move_one_ms']:.1f} ms single-object update "
             f"in the headless component probe. 960 walls add about {walls['static_allocation_delta']/1048576:.2f} MiB, "
             f"with a {walls['initial_build_ms']:.1f} ms build and a {walls['move_one_ms']:.1f} ms update. "
             "Those figures do not include roads, ground, the complete app, GPU allocations or driver compilation.", doc)
oil = row("prop_physics", 960, kind="oil")["warm_ticks"]["median_ms"]
trees = row("prop_physics", 960, kind="tree")["warm_ticks"]["median_ms"]
doc = re.sub(r"960 oil entries take about [\d.]+ ms", f"960 oil entries take about {oil:.2f} ms", doc)
doc = re.sub(r"960 static tree entries take about [\d.]+ ms", f"960 static tree entries take about {trees:.2f} ms", doc)
large = row("document", 960)
small = row("document", 96)
doc = re.sub(r"Validation is about .*? Both counts expand", f"Validation has a median of "
             f"{large['validation']['median_ms']:.2f} ms; the final full compile median is "
             f"{large['compile']['median_ms']:.0f} ms versus {small['compile']['median_ms']:.0f} ms for 96 objects. Both counts expand", doc)
doc_path.write_text(doc, encoding="utf-8", newline="\n")

sources = ["godot-version.txt", "game/tests/profile_creator_object_limit.gd",
           "game/tests/profile_creator_object_limit_higher.gd",
           "game/tests/profile_creator_object_limit_bootstrap.gd", "game/editor/track_document.gd",
           "game/editor/placed_object_batches.gd", "game/editor/editor_detail.gd", "game/editor/track_compiler.gd",
           "game/editor/editor_history.gd", "game/editor/creator_catalog.gd", "game/editor/road_pieces.gd",
           "game/editor/object_population.gd", "game/editor/editor_canvas.gd", "game/core/app.gd",
           "game/track/native_track_visual.gd", "game/vehicle/loose_tyres.gd", "game/vehicle/tyre_contacts.gd",
           "game/race/rewind_history.gd", "game/backend/runner.gd", "backend/bmt_backend/verifier.py",
           "native/track_geometry/tyre_contacts.hpp", "game/platform/track_geometry/track_geometry.gdextension",
           "docs/schemas/creator-track-v5.schema.json", "docs/CREATOR_OBJECT_LIMIT_2026_10_23.md"]
extension = (ROOT / "game/platform/track_geometry/track_geometry.gdextension").read_text()
for library in set(re.findall(r'"res://([^"\n]+\.dll)"', extension)):
    sources.append("game/" + library)

def fingerprint(path):
    raw = path.read_bytes()
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}

report = {
    "task": "Creator object count capacity analysis", "date": "2026-10-23",
    "requirements": {"COL-A01": "Count/contract trace", "COL-A02": "Component capacity probes",
                     "COL-A03": "Recommendation and limits", "COL-A04": "Higher counts without a tenfold ceiling"},
    "recommendation": {"target_authored_objects": 4096, "subsequent_target": 8192, "shipping_limit_unchanged": 96,
                       "native_tyre_body_ceiling": 4096, "wall_body_cost": 6,
                       "conditions": ["spatial tyre rendering", "native fallback boundary handling",
                                      "complex prop active-memory/geometry policy", "incremental editor/object history",
                                      "filtered hazard scans", "document byte allowance for higher target", "matching client/backend guards",
                                      "reference-device acceptance"]},
    "final_checks": {k: {"checks": v["checks"], "failures": v["failures"]} for k, v in data.items()},
    "commands": [{"command": "powershell -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_creator_object_limit.gd -CommandTimeoutSeconds 240",
                  "outcome": "exit 1: existing certificate-store error gate"},
                 {"command": "powershell -ExecutionPolicy Bypass -File docs/evidence/creator-object-limit-2026-10-23/run.ps1 -Mode All",
                  "outcome": "baseline 38/5/13 assertions; logs indexed below"},
                 {"command": "powershell -ExecutionPolicy Bypass -File docs/evidence/creator-object-limit-2026-10-23/run.ps1 -Mode Higher",
                  "outcome": "40 additional assertions; no full baseline rerun in the follow-up"}],
    "scope": "Windows desktop synthetic components, native body threshold and isolated RTX 3090 Mobile-renderer counters; not full app/device/FPS certification",
    "probe_isolation": "copied project settings without autoloads; source/asset junctions; original Desert PNG resource bound before NativeTrackVisual loads; no production asset or capacity-policy edit",
    "initial_corrections": ["strict String key versus dot-created StringName", "PrimitiveMesh array API",
                            "unrelated compressed Desert static sampler in full-app autoload; original failure retained",
                            "bootstrap alone runs after autoload; final probe project omits autoloads",
                            "ignore PowerShell exception wrapper, preserve actual runtime error gate"],
    "remaining": ["phone/touch/cold/thermal/long-session/PSS acceptance", "full expanded-editor/race workflows",
                  "matching expanded-track publication/backend release", "production compressed Desert sampler remains outside scope"],
    "not_performed": ["phone attachment check", "device test", "APK", "live backend/account mutation", "deployment"],
    "sources": {p: fingerprint(ROOT/p) for p in sources},
    "artifacts": {p.name: fingerprint(p) for p in HERE.iterdir() if p.is_file() and p.name != "report.json"},
}
if "higher" in data:
    report["higher_count_evidence"] = str(higher_dir.relative_to(ROOT)).replace("\\", "/")
    report["higher_count_artifacts"] = {p.name: fingerprint(p) for p in higher_dir.iterdir() if p.is_file()}
if (HERE/"checkpoint.json").exists():
    report["checkpoint"] = json.loads((HERE/"checkpoint.json").read_text())
(HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(json.dumps(report["final_checks"]))
