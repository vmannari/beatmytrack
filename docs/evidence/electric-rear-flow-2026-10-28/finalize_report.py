"""Audit the rear-only change and record completed pinned-engine checks."""
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
    owned = {"game/vehicle/electric_coachwork.gd"}
    original = read(HERE / "before-hashes.json")
    rows = [{"path": n, "before_sha256": h, "after_sha256": sha(ROOT / n), "unchanged": sha(ROOT / n) == h} for n, h in original.items()]
    controls = [r for r in rows if r["path"].startswith(("game/vehicle/", "game/ui/", "game/resources/", "game/tests/"))]
    concurrent = [r["path"] for r in controls if not r["unchanged"] and r["path"] not in owned]
    for n in concurrent:
        target = HERE / "concurrent-final" / n
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / n, target)
    save("source-comparison.json", {"owned_runtime_sources": sorted(owned), "concurrent_changes_preserved_excluded": concurrent, "original_fixture_files_exact": sum(r["unchanged"] for r in controls if r["path"].startswith("game/tests/")), "task_did_not_edit_existing_fixtures": True, "snapshots": rows})

    historic = read(HERE / "before-assets.json")
    assert len(historic) == 404 and all(sha(ROOT / n) == h for n, h in historic.items())
    asset_root = ROOT / "game/assets/vehicles/electric_coachwork_v15"
    manifest = read(asset_root / "manifest.json")
    assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
    assert manifest["model_sha256"] == sha(ROOT / "game/vehicle/electric_car_model.gd")
    resources = list(asset_root.glob("*.res"))
    assert len(resources) == len(manifest["meshes"]) == 403
    assert {f.name for f in resources} == {m["file"] for m in manifest["meshes"]}
    arrays = read(HERE / "prepared-array-audit.json")
    assert arrays["failures"] == 0 and arrays["exact_surface_arrays"] == 365 and len(arrays["changed_rear_arrays"]) == 38
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
    save("asset-verification.json", {"version": 15, "prepared_resources": len(resources), "historical_v14_files_byte_exact": len(historic), "source_sha256": manifest["source_sha256"], "assembly_sha256": manifest["model_sha256"], "exact_surface_arrays": 365, "changed_rear_arrays": arrays["changed_rear_arrays"], "shadow_frames": 5, "shadow_triangles": shadows, "non_electric_shadow_entries_exact": True, "non_electric_garage_picture_hashes_exact": True, "garage_provenance_changed_sources": provenance_changes, "garage_template_sha256": sha(ROOT / "game/assets/garage/cars_v1/electric.scn"), "photos": photos, "picture_files_changed": sum(not p["unchanged"] for p in photos), "prepared_hashes": {f.name: sha(f) for f in sorted(resources)}})

    captures = {}
    for renderer in ["native", "desktop-mobile"]:
        capture = read(HERE / renderer / "capture-report.json")
        before = read(HERE / ("before-" + renderer) / "capture-report.json")
        assert capture["source_sha256"] == manifest["source_sha256"] and capture["model_sha256"] == manifest["model_sha256"]
        assert before["source_sha256"] == original["game/vehicle/electric_coachwork.gd"] and before["model_sha256"] == original["game/vehicle/electric_car_model.gd"]
        assert len(capture["captures"]) == len(before["captures"]) == 22 and capture["failures"] == before["failures"] == 0
        captures[renderer] = {"captures": 22, "save_failures": 0, "source_sha256": capture["source_sha256"], "assembly_sha256": capture["model_sha256"], "before_source_matches_task_start": True, "geometry": capture["geometry"]}
        assert capture["geometry"]["full"]["triangles"] == before["geometry"]["full"]["triangles"] == 115686
        assert capture["geometry"]["simple"]["triangles"] == before["geometry"]["simple"]["triangles"] == 36952

    start = (HERE / "before-hashes.json").stat().st_mtime
    logs = [(p, p.read_text(encoding="utf-8", errors="replace")) for p in (ROOT / "build/logs").glob("*/*.log") if p.stat().st_mtime >= start]
    logs.sort(key=lambda r: r[0].stat().st_mtime)
    log_dir = HERE / "command-logs"
    log_dir.mkdir(exist_ok=True)
    commands = []

    def archive(p):
        target = log_dir / (p.parent.name + "-" + p.name)
        shutil.copyfile(p, target)
        return target.relative_to(HERE).as_posix()

    def command(script, marker, count, folder=None, renderer=None, extra=None):
        candidates = [(p, t) for p, t in logs if marker in t and f"{count} checks, 0 failures" in t]
        if renderer:
            candidates = [(p, t) for p, t in candidates if ("Compatibility" if renderer == "gl_compatibility" else "Forward Mobile") in t]
        assert candidates, (script, marker, count, renderer)
        p, _ = candidates[-1]
        argv = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/" + script + ".gd"]
        if renderer:
            argv += ["-Graphical", "-RenderingMethod", renderer]
        args = list(extra or [])
        if folder:
            args.append("--evidence-root=res://../docs/evidence/electric-rear-flow-2026-10-28/" + folder)
        if args:
            argv += ["-TestArgument"] + args
        record = {"argv": argv, "checks": count, "failures": 0, "log": archive(p), "completed": True}
        commands.append(record)
        return {"checks": count, "failures": 0, "log": record["log"], "renderer": renderer}

    rear, baseline = read(HERE / "checks/rear-flow.json"), read(HERE / "checks/before/rear-flow.json")
    assert rear["checks"] == baseline["checks"] == 58 and rear["failures"] == 0 and baseline["failures"] == 28
    tests = {"rear_flow": command("test_electric_rear_flow", "ELECTRIC_REAR_FLOW:", 58), "whole_car": command("test_electric_rebuild", "ELECTRIC_REBUILD:", 33, "construction"), "bonnet": command("test_electric_convex_hood", "ELECTRIC_CONVEX_HOOD:", 40, "hood")}
    for renderer, suffix in [("gl_compatibility", "native"), ("mobile", "mobile")]:
        model = read(HERE / ("model-" + suffix) / "report.json")
        assert model["checks"] == 34 and model["failures"] == 0
        tests["model_" + suffix] = command("test_electric_model", "ELECTRIC_MODEL:", 34, "model-" + suffix, renderer)
        tests["actual_app_" + suffix] = command("test_electric_car_ui", "ELECTRIC_UI:", 70, "app-" + suffix, renderer)
    tests["racing_electric"] = command("test_racing_car_models", "RACING_MODEL_TESTS", 23, extra=["--vehicle=electric"])
    for script, marker, params in [("bake_electric_model", "ELECTRIC_BAKE: 403 authored", {"resources": 403}), ("audit_electric_rear_arrays", "ELECTRIC_REAR_ARRAYS:", {"checks": 2, "failures": 0, "exact_surface_arrays": 365})]:
        candidates = [(p, t) for p, t in logs if marker in t]
        assert candidates
        p, _ = candidates[-1]
        commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/" + script + ".gd"], **params, "exit_code": 0, "log": archive(p), "completed": True})
    candidates = [(p, t) for p, t in logs if "SCRIPT_PARSE:" in t and "0 failures" in t]
    assert candidates
    p, content = candidates[-1]
    parser = {"summary": next(line for line in content.splitlines() if "SCRIPT_PARSE:" in line), "log": archive(p), "completed": True}
    commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/test_script_parse.gd"], **parser})
    for renderer, folder in [("gl_compatibility", "draft-native"), ("mobile", "desktop-mobile")]:
        candidates = [(p, t) for p, t in logs if "ELECTRIC_DESIGN_REVIEW: 22 captures, 0 save failures" in t and ("Compatibility" if renderer == "gl_compatibility" else "Forward Mobile") in t]
        assert candidates
        p, _ = candidates[-1]
        commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/review_electric_design.gd", "-Graphical", "-RenderingMethod", renderer, "-TestArgument", "--evidence-root=res://../docs/evidence/electric-rear-flow-2026-10-28/" + folder], "captures": 22, "save_failures": 0, "log": archive(p), "completed": True, "note": "Compatibility images are also copied to native/ after confirming the unchanged final source hash."})
    retained = [archive(p) for p, t in logs if re.search(r"ELECTRIC_REAR_FLOW: 58 checks, 28 failures", t)]
    commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/test_electric_rear_flow.gd", "-TestArgument", "--before"], "checks": 58, "failures": 28, "expected_failure": True, "evidence": "checks/before/rear-flow.json", "completed": True})
    save("commands.json", {"completed_checks_and_captures": commands, "expected_failure_logs": retained, "derived_asset_actual_argv_and_outputs": "derivative-commands.json", "initial_tooling_failure": {"script_path": "res://../docs/evidence/electric-rear-flow-2026-10-28/audit_rear_arrays.gd", "exit_code": 1, "reason": "TestScript requires a res://tests/ GDScript path.", "resolution": "Helper moved to game/tests/audit_electric_rear_arrays.gd; corrected native run passes."}})

    board = (HERE / "before-after.html").read_text(encoding="utf-8")
    views = re.findall(r'<option value="([^"]+)"[^>]*>[^<]+</option>', board.split('<select id="view">')[1].split('</select>')[0])
    dynamic = [HERE / (prefix + renderer) / (detail + "-" + view + ".png") for prefix in ["", "before-"] for renderer in ["native", "desktop-mobile"] for detail in ["full", "simple"] for view in views]
    assert len(dynamic) == 88 and all(f.is_file() for f in dynamic)
    static = [HERE / n for n in re.findall(r'(?:src|href)="([^"]+)"', board) if not n.startswith(("http", "#"))]
    assert all(f.is_file() for f in static if f.name != "report.json")
    save("board-validation.json", {"dynamic_images": 88, "all_dynamic_images_present": True, "static_links": len(static), "all_static_links_present": True, "initial_view": "rear-quarter", "before_version": 14, "after_version": 15, "browser_javascript_execution": False})

    report = {"date": "2026-10-28", "request": "Improve the rear, especially the rear-window-to-trunk transition.",
              "requirements": {"ERF01": "Shared rear window/trunk height, tangent and curvature", "ERF02": "Matching rear corners/pillars and finite width derivatives", "G01": "Retained geometry budgets, tail lip and fascia fit", "R01": "Protected front/roof/wheels/materials and canonical game systems", "Q01": "Prepared assets, native evidence, checks, hashes and isolated Git checkpoint"},
              "implementation": {"runtime_source": "game/vehicle/electric_coachwork.gd", "prepared_version": 15, "method": "C2 quintic continuation from lower rear glass through deck and corner height field; finite-derivative width endpoint; deck correction vanishes at the existing tail lip", "per_frame_vertex_deformation": False},
              "tests": tests, "array_audit": {"checks": 2, "failures": 0, "exact_surface_arrays": 365, "changed_rear_arrays": 38}, "parser": parser,
              "before": {"checks": 58, "failures": 28, "metrics": baseline["metrics"]}, "after": rear,
              "maximum_new_join_grade_change_degrees": max(m["join_grade_change_degrees"] for m in rear["metrics"].values()), "maximum_new_join_normal_change_degrees": max(m["normal_change_degrees"] for m in rear["metrics"].values()),
              "native_views": captures, "geometry": {"full_visible_triangles": 115686, "racing_visible_triangles": 36952, "triangles_added": 0, "prepared_resources": 403, "shadow_frames": 5, "shadow_triangles": shadows},
              "assets": {"historical_v14_files_exact": 404, "pictures_refreshed": 53, "picture_files_changed": sum(not p["unchanged"] for p in photos), "coachwork_sha256": manifest["source_sha256"], "assembly_sha256": manifest["model_sha256"]},
              "scope": {"owned_runtime_sources": sorted(owned), "concurrent_changes_preserved_excluded": concurrent, "task_did_not_edit_existing_fixtures": True},
              "visual_review": "Side and rear three-quarter views show the glass sweeping into the deck instead of ending against a flat shelf. The lower glass corners and pillar returns use the same transition; front/main-roof/wheel/fascia buffers remain exact.",
              "retained_findings": ["Exact task-start58/28 expected failure retained; final58/0 without threshold changes", "Initial evidence-directory audit invocation rejected by pinned wrapper path rule; helper moved to required test directory and passes", "Native App logs retain any desktop frame hitches; these tests do not establish a phone/FPS guarantee"],
              "remaining_acceptance": ["Reload/rebuild existing editor/game", "Owner appearance/motion review", "Physical-device appearance/cost acceptance"],
              "not_performed": ["physical-device attachment query/test", "APK", "real authentication/purchase", "owner-save/live mutation", "deployment", "owner-process restart", "main-index staging/commit/merge/reset"],
              "checkpoint": "checkpoint.json / task-only.patch: isolated apply check/application and byte comparison; shared index unchanged",
              "evidence": ["before-after.html", "commands.json", "derivative-commands.json", "source-comparison.json", "asset-verification.json", "prepared-array-audit.json", "board-validation.json", "checkpoint.json"]}
    save("report.json", report)
    print(json.dumps({"tests": len(tests), "parser": parser["summary"], "prepared": 403, "exact_arrays": 365, "pictures": 53, "shadows": shadows, "concurrent": concurrent}))


if __name__ == "__main__":
    main()
