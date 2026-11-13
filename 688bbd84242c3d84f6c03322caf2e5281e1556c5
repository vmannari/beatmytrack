"""Audit this pass against its retained snapshots and record completed runs."""
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
    before = read(HERE / "before-hashes.json")
    sources = [{"path": n, "before_sha256": h, "after_sha256": sha(ROOT / n),
                "unchanged": h == sha(ROOT / n)} for n, h in before.items()]
    controls = [s for s in sources if s["path"].startswith(("game/vehicle/", "game/ui/", "game/resources/", "game/tests/"))]
    expected_changed = {"game/vehicle/electric_coachwork.gd", "game/ui/garage_preloader.gd", "game/vehicle/compact_detail.gd"}
    assert {s["path"] for s in controls if not s["unchanged"]} == expected_changed
    assert all(s["unchanged"] for s in controls if s["path"].startswith("game/tests/"))
    save("source-comparison.json", {
        "runtime_scope": ["game/vehicle/electric_coachwork.gd"],
        "concurrent_changes_preserved_and_excluded": ["game/ui/garage_preloader.gd", "game/vehicle/compact_detail.gd"],
        "concurrent_detail_note": "Only cache generation/invalidation changes in CompactDetail; tyre and finish construction remain unchanged.",
        "original_test_fixtures_exact": True, "snapshots": sources})

    historical = read(HERE / "before-assets.json")
    assert all((ROOT / n).is_file() and sha(ROOT / n) == h for n, h in historical.items())
    asset_root = ROOT / "game/assets/vehicles/electric_coachwork_v13"
    manifest = read(asset_root / "manifest.json")
    assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
    assert manifest["model_sha256"] == sha(ROOT / "game/vehicle/electric_car_model.gd")
    prepared = list(asset_root.glob("*.res"))
    assert len(prepared) == len(manifest["meshes"]) == 864
    assert {f.name for f in prepared} == {m["file"] for m in manifest["meshes"]}
    previous_root = ROOT / "game/assets/vehicles/electric_coachwork_v12"
    exact_resources = sum(sha(f) == sha(previous_root / f.name) for f in prepared)

    shadow_path = "game/assets/vehicles/racing_simple_v1/manifest.json"
    old_shadows, new_shadows = read(HERE / "before" / shadow_path), read(ROOT / shadow_path)
    assert {k: v for k, v in old_shadows["cars"].items() if k != "electric"} == {k: v for k, v in new_shadows["cars"].items() if k != "electric"}
    shadow_triangles = int(sum(s["triangles"] for s in new_shadows["cars"]["electric"]))
    assert shadow_triangles == 7694
    provenance_path = "game/assets/garage/previews_v1/provenance.json"
    old_provenance, provenance = read(HERE / "before" / provenance_path), read(ROOT / provenance_path)
    assert {k: v for k, v in old_provenance["hashes"].items() if k != "electric"} == {k: v for k, v in provenance["hashes"].items() if k != "electric"}
    changed_provenance = [k for k, v in provenance["sources"].items() if old_provenance["sources"].get(k) != v]
    assert changed_provenance == ["game/vehicle/electric_coachwork.gd"]
    assert provenance["hashes"]["electric"] == sha(ROOT / "game/assets/garage/previews_v1/electric.png")
    photos = [s for s in sources if s["path"].endswith(".png")]
    assert len(photos) == 53 and all(not s["unchanged"] for s in photos)
    dimensions = {}
    for item in photos:
        n = item["path"]
        dims = struct.unpack(">II", (ROOT / n).read_bytes()[16:24])
        assert dims == struct.unpack(">II", (HERE / "before" / n).read_bytes()[16:24])
        dimensions[n] = list(dims)
    captures = {}
    for renderer in ["native", "desktop-mobile"]:
        data = read(HERE / renderer / "capture-report.json")
        assert data["source_sha256"] == manifest["source_sha256"] and data["model_sha256"] == manifest["model_sha256"]
        assert len(data["captures"]) == 22 and data["failures"] == 0
        captures[renderer] = data
    assets = {"version": 13, "prepared_resources": len(prepared), "unchanged_v12_resource_bytes": exact_resources,
              "resource_byte_note": "Versioned serialized paths change resource bytes; this count does not measure unchanged vertex arrays.",
              "historical_v12_files_exact": len(historical), "source_sha256": manifest["source_sha256"],
              "assembly_sha256": manifest["model_sha256"], "electric_photos_refreshed": len(photos),
              "photo_dimensions_unchanged": dimensions, "garage_template_sha256": sha(ROOT / "game/assets/garage/cars_v1/electric.scn"),
              "non_electric_shadow_entries_exact": True, "non_electric_garage_photo_hashes_exact": True,
              "garage_provenance_changed_source_entries": changed_provenance,
              "visible_triangles": {k: v["triangles"] for k, v in captures["native"]["geometry"].items()},
              "shadow_triangles": shadow_triangles,
              "prepared_hashes": {f.name: sha(f) for f in sorted(prepared)}}
    save("asset-verification.json", assets)

    logs = []
    start = (HERE / "before-hashes.json").stat().st_mtime
    for f in (ROOT / "build/logs").glob("*/*.log"):
        if f.stat().st_mtime < start:
            continue
        content = f.read_text(encoding="utf-8", errors="replace")
        logs.append((f, content))
    logs.sort(key=lambda r: r[0].stat().st_mtime)
    commands = []
    log_dir = HERE / "command-logs"
    log_dir.mkdir(exist_ok=True)

    def command(script, marker, count, folder=None, renderer=None, args=None):
        candidates = [(p, t) for p, t in logs if marker in t and f"{count} checks, 0 failures" in t]
        if renderer:
            candidates = [(p, t) for p, t in candidates if ("Compatibility" if renderer == "gl_compatibility" else "Forward Mobile") in t]
        assert candidates, (script, marker, count, renderer)
        p, content = candidates[-1]
        target = log_dir / (p.parent.name + "-" + p.name)
        shutil.copyfile(p, target)
        argv = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/" + script + ".gd"]
        if renderer:
            argv += ["-Graphical", "-RenderingMethod", renderer]
        arguments = list(args or [])
        if folder:
            arguments.append("--evidence-root=res://../docs/evidence/electric-convex-hood-2026-10-27/" + folder)
        if arguments:
            argv += ["-TestArgument"] + arguments
        commands.append({"argv": argv, "checks": count, "failures": 0, "log": target.relative_to(HERE).as_posix(), "completed": True})

    suites = [("convex_hood", "CONVEX_HOOD", 40, "final-convex", "convex-hood"),
              ("smooth_nose", "SMOOTH_NOSE", 22, "final-nose", "smooth-nose"),
              ("hood_fairing", "HOOD_FAIRING", 28, "final-fairing", "hood-fairing"),
              ("hood", "HOOD", 28, "final-hood", "hood"),
              ("sporty_corners", "SPORTY_CORNERS", 30, "final-corners", "sporty-corners"),
              ("clean_bonnet", "CLEAN_BONNET", 34, "final-bonnet", "clean-bonnet"),
              ("surface_finish", "SURFACE_FINISH", 34, "final-surface", "surface-finish"),
              ("design_pass", "DESIGN_PASS", 54, "final-design", "design-pass"),
              ("rounded_front", "ROUNDED_FRONT", 8, "final-round", "rounded-front")]
    outcomes = []
    for script, marker, count, folder, data_name in suites:
        data = read(HERE / folder / (data_name + ".json"))
        assert data["checks"] == count and data["failures"] == 0
        command("test_electric_" + script, "ELECTRIC_" + marker + ":", count, folder)
        outcomes.append({"suite": script, "checks": count, "failures": 0, "evidence": folder + "/" + data_name + ".json"})
    for renderer, suffix in [("gl_compatibility", "native"), ("mobile", "mobile")]:
        for script, marker, count, name in [("model", "MODEL", 34, "report"), ("quality", "QUALITY", 60, "quality")]:
            folder = script + "-" + suffix
            data = read(HERE / folder / (name + ".json"))
            assert data["checks"] == count and data["failures"] == 0
            command("test_electric_" + script, "ELECTRIC_" + marker + ":", count, folder, renderer)
            outcomes.append({"suite": script, "renderer": renderer, "checks": count, "failures": 0})
        command("test_electric_car_ui", "ELECTRIC_UI:", 70, "app-" + suffix, renderer)
        outcomes.append({"suite": "actual_app", "renderer": renderer, "checks": 70, "failures": 0})
    command("test_racing_car_models", "RACING_MODEL_TESTS", 23, args=["--vehicle=electric"])
    outcomes.append({"suite": "racing_model_electric", "checks": 23, "failures": 0})

    for renderer, folder in [("gl_compatibility", "native"), ("mobile", "desktop-mobile")]:
        candidates = [(p, t) for p, t in logs if "ELECTRIC_DESIGN_REVIEW: 22 captures, 0 save failures" in t and ("Compatibility" if renderer == "gl_compatibility" else "Forward Mobile") in t]
        assert candidates
        p, _ = candidates[-1]
        shutil.copyfile(p, log_dir / (p.parent.name + "-" + p.name))
        commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/review_electric_design.gd", "-Graphical", "-RenderingMethod", renderer, "-TestArgument", "--evidence-root=res://../docs/evidence/electric-convex-hood-2026-10-27/" + folder], "log": "command-logs/" + p.parent.name + "-" + p.name, "captures": 22, "save_failures": 0, "completed": True})
    for job, script, marker in [("prepared_geometry", "bake_electric_model.gd", "ELECTRIC_BAKE: 864 authored"), ("class_cache_refresh", None, None)]:
        candidates = [(p, t) for p, t in logs if marker in t] if marker else [(p, t) for p, t in logs if p.parent.name == "Import-38780"]
        assert candidates
        p, content = candidates[-1]
        assert "SCRIPT ERROR" not in content
        shutil.copyfile(p, log_dir / (p.parent.name + "-" + p.name))
        argv = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript" if script else "Import"]
        if script:
            argv += ["-ScriptPath", "res://tests/" + script]
        commands.append({"job": job, "argv": argv, "log": "command-logs/" + p.parent.name + "-" + p.name, "exit_code": 0, "completed": True})

    parser_candidates = [(p, t) for p, t in logs if "SCRIPT_PARSE_TESTS" in t or "SCRIPT_PARSE:" in t or "SCRIPT_PARSE_TEST:" in t]
    assert parser_candidates, "Locate completed parser log"
    p, content = parser_candidates[-1]
    assert "0 failures" in content
    shutil.copyfile(p, log_dir / (p.parent.name + "-" + p.name))
    commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/test_script_parse.gd"], "log": "command-logs/" + p.parent.name + "-" + p.name, "summary": content.strip().splitlines()[-1], "completed": True})

    retained = []
    for p, content in logs:
        if ("failures" in content and re.search(r"[1-9][0-9]* failures", content) and "ELECTRIC_" in content) or (p.parent.name in ["Import-38428", "TestScript-2012", "TestScript-23800", "CheckScript-36152"]):
            target = log_dir / (p.parent.name + "-" + p.name)
            shutil.copyfile(p, target)
            retained.append(target.relative_to(HERE).as_posix())
    save("commands.json", {"completed_checks": commands, "derivative_commands": "derivative-commands.json", "retained_failure_logs": retained, "note": "Commands use the pinned scripts/dev.ps1 engine wrapper; derivative receipts retain actual argv and output. Native capture saves are not counted as geometry assertions."})

    board = (HERE / "before-after.html").read_text(encoding="utf-8")
    views = re.findall(r'<option value="([^"]+)"[^>]*>[^<]+</option>', board.split('<select id="view">')[1].split('</select>')[0])
    dynamic = [HERE / (prefix + renderer) / (detail + "-" + view + ".png") for prefix in ["", "before-"] for renderer in ["native", "desktop-mobile"] for detail in ["full", "simple"] for view in views]
    assert len(dynamic) == 88 and all(f.is_file() for f in dynamic)
    static = [HERE / n for n in re.findall(r'(?:src|href)="([^"]+)"', board) if not n.startswith(("http", "#"))]
    # report.json is written below; all other links are ready now.
    assert all(f.is_file() for f in static if f.name != "report.json")
    save("board-validation.json", {"dynamic_images": len(dynamic), "all_dynamic_images_present": True, "static_links": len(static), "all_static_links_present": True, "initial_view": "side", "before_version": 12, "after_version": 13, "browser_javascript_execution": False, "note": "Local image/link validation and source review; no automated browser-execution claim."})

    convex = read(HERE / "final-convex/convex-hood.json")
    report = {
        "date": "2026-10-27", "request": "The hood should be mainly convex, rather than dropping and then plateauing.",
        "requirements": {"ECV01": "Continuous convex main bonnet without a horizontal shelf", "ECV02": "Keep inward taper, low front corners, fitted joins, crown and no-S-bend limits", "ECV03/Q01": "Refresh prepared model/derived assets and provide native/actual-App evidence and isolated checkpoint", "R01": "Retain canonical simulation/config, wheels, camera/input, finishes, rear/cabin and concurrent work"},
        "implementation": {"runtime_source": "game/vehicle/electric_coachwork.gd", "asset_root": "electric_coachwork_v13", "method": "Fixed-Z convex centre Bezier loft, broad upper-panel blending and a 1.5mm C2 leading fairing; analytic normal transport and matching surface queries", "prepared_not_per_frame": True, "original_thresholds_relaxed": False},
        "baseline": {"expanded_checks": 40, "failures": 24, "evidence": "checks/before/convex-hood.json", "initial_checks": 30, "initial_failures": 18, "initial_evidence": "baseline-30/convex-hood.json"},
        "convex_sections": convex["metrics"], "tests": outcomes,
        "parser": commands[-1],
        "native_views": {renderer: {"captures": len(data["captures"]), "save_failures": data["failures"], "coach_sha256": data["source_sha256"], "assembly_sha256": data["model_sha256"]} for renderer, data in captures.items()},
        "visual_review": "Side and three-quarter native views show one progressive curve into the nose instead of the former drop/flat transition. Taper and low fender silhouette remain; native specular and actual Garage/race captures are provided for owner review.",
        "geometry": {"full_triangles": 158270, "simple_visible_triangles": 78940, "triangles_added": 0, "simple_shadows": shadow_triangles, "shadow_frames": 5, "model_cap": 170000, "wheelbase_metres": 2.46, "wheel_diameter_metres": 0.6512, "front_arch_clearance_model_metres": 0.0329999375343323, "front_arch_clearance_world_metres": 0.0329999375343323 * 0.88, "outer_brow_model_metres": 0.862352132797241},
        "assets": {k: assets[k] for k in ["prepared_resources", "unchanged_v12_resource_bytes", "historical_v12_files_exact", "electric_photos_refreshed", "source_sha256", "assembly_sha256"]},
        "retained_findings": ["Exact task-start regression failures retained (30/18 and expanded40/24)", "First narrow draft passes longitudinal convexity but fails four original crown checks; original thresholds retained", "Broadened draft has two expanded outboard slope failures; source and native views retained; corrected by C2 fairing", "Initial import fails during concurrent RoadPieces.stamp_materials edits; later import succeeds without changing that source", "Initial App/racing/parser attempts fail during concurrent JumpProfiles class-cache changes; class-cache refresh and reruns succeed", "Actual App logs retain desktop frame hitches; these runs do not establish a frame-time or phone guarantee"],
        "scope": "One EV runtime source plus new regression and refreshed EV derived assets. Concurrent CompactDetail cache-generation and Garage preloader work is retained and excluded from the checkpoint.",
        "checkpoint": "checkpoint.json and task-only.patch: isolated git apply check/application and byte comparison; no shared index mutation",
        "remaining_acceptance": ["Reload/rebuild the existing editor/game", "Owner appearance and motion review", "Physical-device cost/appearance acceptance; no device check/test performed"],
        "not_performed": ["APK", "real authentication or purchase", "owner-save/live mutation", "deployment", "owner-process restart", "main-index staging/commit/merge/reset"],
        "evidence": ["before-after.html", "commands.json", "derivative-commands.json", "source-comparison.json", "asset-verification.json", "board-validation.json", "checkpoint.json"]}
    save("report.json", report)
    print(json.dumps({"outcomes": len(outcomes), "historical_files_exact": len(historical), "prepared_resources": len(prepared), "unchanged_resource_bytes": exact_resources, "photos": len(photos), "board_images": len(dynamic), "parser": report["parser"]["summary"]}))


if __name__ == "__main__":
    main()
