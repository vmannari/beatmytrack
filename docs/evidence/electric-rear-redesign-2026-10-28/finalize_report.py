"""Audit the complete rear redesign and its native review evidence."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import struct

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def read(p):
    return json.loads(p.read_text(encoding="utf-8"))


def save(name, value):
    (HERE / name).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main():
    original = read(HERE / "before-hashes.json")
    owned = {"game/vehicle/electric_coachwork.gd"}
    rows = [{"path": n, "before_sha256": h, "after_sha256": sha(ROOT / n), "unchanged": sha(ROOT / n) == h} for n, h in original.items()]
    controls = [r for r in rows if r["path"].startswith(("game/vehicle/", "game/ui/", "game/resources/", "game/tests/"))]
    concurrent = [r["path"] for r in controls if not r["unchanged"] and r["path"] not in owned]
    for n in concurrent:
        target = HERE / "concurrent-final" / n
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / n, target)
    save("source-comparison.json", {"owned_runtime_sources": sorted(owned), "concurrent_changes_preserved_excluded": concurrent, "task_did_not_edit_existing_fixtures": True, "snapshots": rows})

    historic = read(HERE / "before-assets.json")
    assert len(historic) == 404 and all(sha(ROOT / n) == h for n, h in historic.items())
    asset_root = ROOT / "game/assets/vehicles/electric_coachwork_v16"
    manifest = read(asset_root / "manifest.json")
    assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
    assert manifest["model_sha256"] == sha(ROOT / "game/vehicle/electric_car_model.gd")
    resources = list(asset_root.glob("*.res"))
    assert len(resources) == len(manifest["meshes"]) == 409
    assert {p.name for p in resources} == {m["file"] for m in manifest["meshes"]}
    audit = read(HERE / "prepared-array-audit.json")
    assert audit["failures"] == 0 and not audit["unexpected_changes"] and audit["protected_front_side_vertices"] > 0
    shadow_path = "game/assets/vehicles/racing_simple_v1/manifest.json"
    before_shadow, shadow = read(HERE / "before" / shadow_path), read(ROOT / shadow_path)
    assert {k: v for k, v in before_shadow["cars"].items() if k != "electric"} == {k: v for k, v in shadow["cars"].items() if k != "electric"}
    shadows = int(sum(m["triangles"] for m in shadow["cars"]["electric"]))
    assert len(shadow["cars"]["electric"]) == 5
    photo_path = "game/assets/garage/previews_v1/provenance.json"
    before_photo, photo = read(HERE / "before" / photo_path), read(ROOT / photo_path)
    assert {k: v for k, v in before_photo["hashes"].items() if k != "electric"} == {k: v for k, v in photo["hashes"].items() if k != "electric"}
    provenance_changes = [n for n, h in photo["sources"].items() if before_photo["sources"].get(n) != h]
    assert set(provenance_changes) == owned
    assert photo["hashes"]["electric"] == sha(ROOT / "game/assets/garage/previews_v1/electric.png")
    photos = [r for r in rows if r["path"].endswith(".png")]
    assert len(photos) == 53
    for r in photos:
        r["dimensions"] = list(struct.unpack(">II", (ROOT / r["path"]).read_bytes()[16:24]))
        assert r["dimensions"] == list(struct.unpack(">II", (HERE / "before" / r["path"]).read_bytes()[16:24]))
    save("asset-verification.json", {"version": 16, "prepared_resources": len(resources), "historical_v15_files_byte_exact": len(historic), "source_sha256": manifest["source_sha256"], "assembly_sha256": manifest["model_sha256"], "buffer_audit": audit, "shadow_frames": 5, "shadow_triangles": shadows, "non_electric_shadow_entries_exact": True, "non_electric_garage_picture_hashes_exact": True, "garage_provenance_changed_sources": provenance_changes, "garage_template_sha256": sha(ROOT / "game/assets/garage/cars_v1/electric.scn"), "pictures": photos, "prepared_hashes": {p.name: sha(p) for p in sorted(resources)}})

    captures = {}
    for renderer in ["native", "desktop-mobile"]:
        current = read(HERE / renderer / "capture-report.json")
        before = read(HERE / ("before-" + renderer) / "capture-report.json")
        assert current["source_sha256"] == manifest["source_sha256"] and current["model_sha256"] == manifest["model_sha256"]
        assert before["before"] and before["source_sha256"] == original["game/vehicle/electric_coachwork.gd"]
        assert len(current["captures"]) == len(before["captures"]) == 26
        assert current["failures"] == before["failures"] == 0
        assert current["geometry"]["full"]["triangles"] == 117126 and current["geometry"]["simple"]["triangles"] == 37312
        assert before["geometry"]["full"]["triangles"] == 115686 and before["geometry"]["simple"]["triangles"] == 36952
        captures[renderer] = {"captures": 26, "save_failures": 0, "source_sha256": current["source_sha256"], "before_source_sha256": before["source_sha256"], "geometry": current["geometry"], "garage_note": "Actual read-only CarShowroom with synthetic condition; isolated baseline caches disabled; no owner saves read."}

    qa = read(HERE / "qa-commands.json")
    jobs = {r["job"]: r for r in qa if r["exit_code"] == 0}
    expected_jobs = {"arrays", "native", "mobile", "before-mobile", "construction", "model-native", "model-mobile", "rear-app-native", "rear-app-mobile", "racing", "hood", "retained-flow", "parser"}
    assert expected_jobs <= jobs.keys()
    assert all(jobs[n]["coachwork_sha256"] == manifest["source_sha256"] for n in expected_jobs)
    expected = {"construction": ("ELECTRIC_REBUILD", 33), "model-native": ("ELECTRIC_MODEL", 34), "model-mobile": ("ELECTRIC_MODEL", 34), "rear-app-native": ("ELECTRIC_REAR_APP", 58), "rear-app-mobile": ("ELECTRIC_REAR_APP", 58), "racing": ("RACING_MODEL_TESTS", 23), "hood": ("ELECTRIC_CONVEX_HOOD", 40), "retained-flow": ("ELECTRIC_REAR_FLOW", 58)}
    tests = {}
    for name, (marker, count) in expected.items():
        assert marker in jobs[name]["output"] and f"{count} checks, 0 failures" in jobs[name]["output"]
        tests[name] = {"checks": count, "failures": 0, "command_receipt": "qa-commands.json", "job": name}
    parser = next(line for line in jobs["parser"]["output"].splitlines() if "SCRIPT_PARSE:" in line)
    assert "0 failures" in parser
    shape, baseline = read(HERE / "shape/rear-shape.json"), read(HERE / "shape/before/rear-shape.json")
    assert shape["checks"] == baseline["checks"] == 24 and shape["failures"] == 0 and baseline["failures"] == 16
    tests["rear_shape"] = {"checks": 24, "failures": 0, "evidence": "shape/rear-shape.json"}
    tests["protected_arrays"] = {"checks": 2, "failures": 0, "evidence": "prepared-array-audit.json"}

    start = (HERE / "before-hashes.json").stat().st_mtime
    logs = [(p, p.read_text(encoding="utf-8", errors="replace")) for p in (ROOT / "build/logs").glob("*/*.log") if p.stat().st_mtime >= start]
    log_dir = HERE / "command-logs"
    log_dir.mkdir(exist_ok=True)
    retained_logs = []
    for p, content in logs:
        if "Invalid access to property or key 'position' on a base object of type 'Nil'" in content or "ELECTRIC_REAR_SHAPE:" in content or "ELECTRIC_BAKE:" in content or "ELECTRIC_REAR_REDESIGN_ARRAYS:" in content or ("ELECTRIC_DESIGN_REVIEW: 26" in content and "115686" in content):
            target = log_dir / (p.parent.name + "-" + p.name)
            shutil.copyfile(p, target)
            retained_logs.append(target.relative_to(HERE).as_posix())
    save("commands.json", {"final_native_checks_actual_argv_outputs": "qa-commands.json", "derived_assets_actual_argv_outputs": "derivative-commands.json", "retained_logs": retained_logs, "manual_commands": [{"script": "res://tests/bake_electric_model.gd", "action": "TestScript", "exit_code": 0, "resources": 409}, {"script": "res://tests/test_electric_rear_redesign.gd", "action": "TestScript", "checks": 24, "failures": 0}, {"script": "res://tests/test_electric_rear_redesign.gd", "args": ["--before"], "checks": 24, "failures": 16, "expected_failure": True}, {"script": "res://tests/review_electric_rear_redesign.gd", "renderer": "gl_compatibility", "args": ["--before", "--evidence-root=res://../docs/evidence/electric-rear-redesign-2026-10-28/before-native"], "captures": 26, "save_failures": 0}], "tooling_findings": ["Initial audit classifier omitted four intended TailOpticEnd rear arrays; corrected classification passes, with strict front/main-roof/wheel/front-side-vertex checks retained", "Initial nested PowerShell quoting attempt fails before execution; corrected pinned-wrapper invocation passes", "One concurrent project.godot build-metadata read lock rejects a wrapper startup; final checks run sequentially and pass", "Initial owned current-control fixture taps relative analog pedals without movement; correcting the fixture to drag from neutral retains all checks and produces58/0"], "retained_original_ui_failure": {"job": "app-native", "attempts": sum(1 for r in qa if r["job"] == "app-native" and r["exit_code"] != 0), "reason": "Unmodified existing UI test dereferences the removed D/R button at line261 after its actual Garage/race checks; Electric21 already uses gas/brake at task start", "current_control_proof": "New test_electric_rear_app.gd retains applicable Garage/racing/keyboard/controller checks and verifies real gas/brake touch/restart paths across all layouts"}, "engine_entry_point": "scripts/dev.ps1 (pinned Godot build)"})

    board = (HERE / "before-after.html").read_text(encoding="utf-8")
    views = re.findall(r'<option value="([^"]+)"[^>]*>[^<]+</option>', board.split('<select id="view">')[1].split('</select>')[0])
    dynamic = [HERE / (prefix + renderer) / (("" if view.startswith("garage-") else detail + "-") + view + ".png") for prefix in ["", "before-"] for renderer in ["native", "desktop-mobile"] for view in views for detail in ([""] if view.startswith("garage-") else ["full", "simple"])]
    assert len(dynamic) == 104 and all(p.is_file() for p in dynamic)
    static = [HERE / n for n in re.findall(r'(?:src|href)="([^"]+)"', board) if not n.startswith(("http", "#"))]
    assert all(p.is_file() for p in static if p.name != "report.json")
    save("board-validation.json", {"dynamic_images": 104, "all_dynamic_images_present": True, "static_links": len(static), "all_static_links_present": True, "initial_view": "garage-rear-clean", "before_version": 15, "after_version": 16, "browser_javascript_execution": False})

    report = {"date": "2026-10-28", "request": "Completely redesign the malformed trunk and rear window shown in the owner's Garage screenshot.", "requirements": {"ERR01": "Shallow consistently convex rear glass and clean outline", "ERR02": "Separate painted transition and stable rear pillars/shoulders", "ERR03": "Flatter trunk with fitted side opening seams", "G01": "Existing full/racing budgets and lighting/articulation", "R01": "Protected front/roof/wheels/materials and canonical game systems", "Q01": "Actual low Garage-angle review, regression/source/asset proof and isolated checkpoint"}, "implementation": {"runtime_source": "game/vehicle/electric_coachwork.gd", "prepared_version": 16, "previous_rear_height_field_removed": True, "separate_glass_apron_deck_sections": True, "per_frame_vertex_deformation": False}, "tests": tests, "parser": parser, "before": baseline, "after": shape, "native_views": captures, "geometry": {"full": 117126, "racing": 37312, "added_full": 1440, "added_racing": 360, "full_budget": 120000, "racing_budget": 45000, "prepared_resources": 409, "shadow_frames": 5, "shadow_triangles": shadows}, "buffer_scope": {"exact_surface_arrays": audit["exact_surface_arrays"], "protected_front_side_vertices": audit["protected_front_side_vertices"], "unexpected_changes": audit["unexpected_changes"]}, "assets": {"historic_v15_files_exact": 404, "pictures_refreshed": 53, "coachwork_sha256": manifest["source_sha256"], "assembly_sha256": manifest["model_sha256"]}, "source_scope": {"owned_runtime_sources": sorted(owned), "concurrent_changes_preserved_excluded": concurrent, "existing_fixtures_edited_by_task": False}, "visual_review": "Checked the new low rear studio and actual Garage views clean and with synthetic wear in both renderers. The lower glass remains shallow instead of curling, the painted apron carries the slope transition, and the trunk is gently crowned with side seams rather than an inset rectangular lid.", "retained_findings": ["The prior continuity-only58-check suite passes on the rejected shape; this illustrates its limited scope rather than proof of appearance", "New actual-shape test passes24/0 versus exact rejected-model24/16 without threshold relaxation", "Initial rear optical classification, PowerShell quoting and concurrent metadata-read lock are retained; corrected sequential runs pass", "Initial draft geometry and Garage views retained; rear badge subsequently fitted to the new rear surface", "Original UI fixture fails twice at its stale D/R-button assumption; current-control integration uses a new owned fixture, with original existing fixture preserved", "Native App desktop hitches remain in logs; no phone/FPS guarantee"], "remaining_acceptance": ["Reload/rebuild existing editor/game", "Owner appearance and motion review", "Physical-device appearance/cost acceptance"], "not_performed": ["physical-device attachment query/test", "APK", "real authentication/purchase", "owner-save/live mutation", "deployment", "owner-process restart", "main-index staging/commit/merge/reset"], "checkpoint": "checkpoint.json / task-only.patch: isolated apply check/application, byte comparison and unchanged shared index", "evidence": ["before-after.html", "commands.json", "qa-commands.json", "derivative-commands.json", "source-comparison.json", "asset-verification.json", "prepared-array-audit.json", "board-validation.json", "checkpoint.json"]}
    save("report.json", report)
    print(json.dumps({"tests": len(tests), "parser": parser, "resources": 409, "protected_arrays": audit["exact_surface_arrays"], "front_vertices": audit["protected_front_side_vertices"], "photos": 53, "shadows": shadows, "concurrent": concurrent}))


if __name__ == "__main__":
    main()
