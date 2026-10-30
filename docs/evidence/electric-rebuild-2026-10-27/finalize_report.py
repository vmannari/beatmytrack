"""Record completed native runs and audit only the electric rebuild's assets."""
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
    owned = {"game/vehicle/electric_coachwork.gd", "game/vehicle/electric_car_model.gd"}
    old = read(HERE / "before-hashes.json")
    rows = [{"path": n, "before_sha256": h, "after_sha256": sha(ROOT / n), "unchanged": sha(ROOT / n) == h} for n, h in old.items()]
    controls = [r for r in rows if r["path"].startswith(("game/vehicle/", "game/ui/", "game/resources/", "game/tests/"))]
    concurrent = [r["path"] for r in controls if not r["unchanged"] and r["path"] not in owned]
    retained_names = {"test_electric_car_ui.gd", "test_electric_model.gd", "test_electric_quality.gd", "test_electric_convex_hood.gd", "test_electric_clean_bonnet.gd", "test_electric_hood.gd", "test_electric_hood_fairing.gd", "test_electric_design_pass.gd", "test_electric_surface_finish.gd", "test_electric_rounded_front.gd", "test_electric_smooth_nose.gd", "test_electric_sporty_corners.gd"}
    retained = [r for r in controls if Path(r["path"]).name in retained_names]
    assert len(retained) == len(retained_names) and all(r["unchanged"] for r in retained)
    concurrent_dir = HERE / "concurrent-final"
    for n in concurrent:
        target = concurrent_dir / n
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / n, target)
    save("source-comparison.json", {"owned_runtime_sources": sorted(owned), "concurrent_changes_preserved_excluded": concurrent, "original_shape_and_functional_fixture_files_byte_exact": len(retained), "task_did_not_edit_existing_fixtures": True, "concurrent_note": "Electric19 braking/configuration and its handling fixtures changed independently during this pass; preserved and excluded. No whole-tree freeze is claimed.", "snapshots": rows})

    historic = read(HERE / "before-assets.json")
    assert all(sha(ROOT / n) == h for n, h in historic.items())
    asset_root = ROOT / "game/assets/vehicles/electric_coachwork_v14"
    manifest = read(asset_root / "manifest.json")
    assert manifest["source_sha256"] == sha(ROOT / "game/vehicle/electric_coachwork.gd")
    assert manifest["model_sha256"] == sha(ROOT / "game/vehicle/electric_car_model.gd")
    resources = list(asset_root.glob("*.res"))
    assert len(resources) == len(manifest["meshes"]) == 403
    assert {f.name for f in resources} == {m["file"] for m in manifest["meshes"]}
    shadow_path = "game/assets/vehicles/racing_simple_v1/manifest.json"
    before_shadow, shadow = read(HERE / "before" / shadow_path), read(ROOT / shadow_path)
    assert {k: v for k, v in before_shadow["cars"].items() if k != "electric"} == {k: v for k, v in shadow["cars"].items() if k != "electric"}
    shadows = int(sum(m["triangles"] for m in shadow["cars"]["electric"]))
    assert len(shadow["cars"]["electric"]) == 5 and shadows == 3500
    photo_path = "game/assets/garage/previews_v1/provenance.json"
    before_photo, photo = read(HERE / "before" / photo_path), read(ROOT / photo_path)
    assert {k: v for k, v in before_photo["hashes"].items() if k != "electric"} == {k: v for k, v in photo["hashes"].items() if k != "electric"}
    provenance_changes = [n for n, h in photo["sources"].items() if before_photo["sources"].get(n) != h]
    assert set(provenance_changes) == owned
    assert photo["hashes"]["electric"] == sha(ROOT / "game/assets/garage/previews_v1/electric.png")
    photos = [r for r in rows if r["path"].endswith(".png")]
    assert len(photos) == 53 and all(not r["unchanged"] for r in photos)
    for r in photos:
        r["dimensions"] = list(struct.unpack(">II", (ROOT / r["path"]).read_bytes()[16:24]))
        assert r["dimensions"] == list(struct.unpack(">II", (HERE / "before" / r["path"]).read_bytes()[16:24]))
    asset_audit = {"version": 14, "prepared_resources": len(resources), "historical_v13_files_byte_exact": len(historic),
                   "source_sha256": manifest["source_sha256"], "assembly_sha256": manifest["model_sha256"],
                   "shadow_frames": 5, "shadow_triangles": shadows, "non_electric_shadow_entries_exact": True,
                   "non_electric_garage_picture_hashes_exact": True, "garage_provenance_changed_sources": provenance_changes,
                   "garage_template_sha256": sha(ROOT / "game/assets/garage/cars_v1/electric.scn"),
                   "photos": photos, "prepared_hashes": {f.name: sha(f) for f in sorted(resources)}}
    save("asset-verification.json", asset_audit)

    captures = {}
    for renderer in ["native", "desktop-mobile"]:
        capture = read(HERE / renderer / "capture-report.json")
        before = read(HERE / ("before-" + renderer) / "capture-report.json")
        assert capture["source_sha256"] == manifest["source_sha256"] and capture["model_sha256"] == manifest["model_sha256"]
        assert before["source_sha256"] == old["game/vehicle/electric_coachwork.gd"] and before["model_sha256"] == old["game/vehicle/electric_car_model.gd"]
        assert len(capture["captures"]) == len(before["captures"]) == 22 and capture["failures"] == before["failures"] == 0
        captures[renderer] = {"captures": 22, "save_failures": 0, "source_sha256": capture["source_sha256"], "assembly_sha256": capture["model_sha256"], "before_source_matches_task_start": True, "geometry": capture["geometry"]}

    start = (HERE / "before-hashes.json").stat().st_mtime
    logs = [(p, p.read_text(encoding="utf-8", errors="replace")) for p in (ROOT / "build/logs").glob("*/*.log") if p.stat().st_mtime >= start]
    logs.sort(key=lambda r: r[0].stat().st_mtime)
    log_dir = HERE / "command-logs"
    log_dir.mkdir(exist_ok=True)
    commands = []

    def command(script, marker, count, folder=None, renderer=None, extra=None):
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
        args = list(extra or [])
        if folder:
            args.append("--evidence-root=res://../docs/evidence/electric-rebuild-2026-10-27/" + folder)
        if args:
            argv += ["-TestArgument"] + args
        commands.append({"argv": argv, "checks": count, "failures": 0, "log": target.relative_to(HERE).as_posix(), "completed": True})
        return {"checks": count, "failures": 0, "log": target.relative_to(HERE).as_posix(), "renderer": renderer}

    tests = {}
    construction = read(HERE / "construction/construction.json")
    baseline = read(HERE / "construction/before/construction.json")
    assert construction["checks"] == 33 and construction["failures"] == 0
    assert baseline["checks"] == 33 and baseline["failures"] == 9
    tests["construction"] = command("test_electric_rebuild", "ELECTRIC_REBUILD:", 33)
    tests["bonnet"] = command("test_electric_convex_hood", "ELECTRIC_CONVEX_HOOD:", 40, "hood-final")
    for renderer, suffix in [("gl_compatibility", "native"), ("mobile", "mobile")]:
        model = read(HERE / ("model-" + suffix) / "report.json")
        assert model["checks"] == 34 and model["failures"] == 0
        tests["model_" + suffix] = command("test_electric_model", "ELECTRIC_MODEL:", 34, "model-" + suffix, renderer)
        tests["actual_app_" + suffix] = command("test_electric_car_ui", "ELECTRIC_UI:", 70, "app-" + suffix, renderer)
    tests["racing_electric"] = command("test_racing_car_models", "RACING_MODEL_TESTS", 23, extra=["--vehicle=electric"])
    bake_candidates = [(p, t) for p, t in logs if "ELECTRIC_BAKE: 403 authored full/simple mesh resources" in t]
    assert bake_candidates
    p, _ = bake_candidates[-1]
    shutil.copyfile(p, log_dir / (p.parent.name + "-" + p.name))
    commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/bake_electric_model.gd", "-CommandTimeoutSeconds", "300"], "resources": 403, "exit_code": 0, "log": "command-logs/" + p.parent.name + "-" + p.name, "completed": True})
    commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/test_electric_rebuild.gd", "-TestArgument", "--before"], "checks": 33, "failures": 9, "expected_failure": True, "evidence": "construction/before/construction.json", "note": "Exact retained source loaded only in isolated process memory; no production rollback", "completed": True})
    parser_candidates = [(p, t) for p, t in logs if "SCRIPT_PARSE:" in t and "0 failures" in t]
    assert parser_candidates
    p, content = parser_candidates[-1]
    summary = next(line for line in content.splitlines() if "SCRIPT_PARSE:" in line)
    shutil.copyfile(p, log_dir / (p.parent.name + "-" + p.name))
    parser = {"summary": summary, "log": "command-logs/" + p.parent.name + "-" + p.name, "completed": True}
    commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/test_script_parse.gd"], **parser})
    for renderer, folder in [("gl_compatibility", "native"), ("mobile", "desktop-mobile")]:
        candidates = [(p, t) for p, t in logs if "ELECTRIC_DESIGN_REVIEW: 22 captures, 0 save failures" in t and ("Compatibility" if renderer == "gl_compatibility" else "Forward Mobile") in t]
        assert candidates
        p, _ = candidates[-1]
        shutil.copyfile(p, log_dir / (p.parent.name + "-" + p.name))
        commands.append({"argv": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", "TestScript", "-ScriptPath", "res://tests/review_electric_design.gd", "-Graphical", "-RenderingMethod", renderer, "-TestArgument", "--evidence-root=res://../docs/evidence/electric-rebuild-2026-10-27/" + folder], "captures": 22, "save_failures": 0, "log": "command-logs/" + p.parent.name + "-" + p.name, "completed": True})
    failures = []
    for p, content in logs:
        if re.search(r"ELECTRIC_.*[1-9][0-9]* failures", content) or "at: doors (res://vehicle/electric_coachwork.gd:289)" in content:
            target = log_dir / (p.parent.name + "-" + p.name)
            shutil.copyfile(p, target)
            failures.append(target.relative_to(HERE).as_posix())
    save("commands.json", {"completed_checks_and_captures": commands, "retained_failure_logs": failures, "derived_asset_actual_argv_and_outputs": "derivative-commands.json", "note": "Pinned scripts/dev.ps1 engine wrapper; no planned-as-passed runs. Native capture saves are separate from construction checks."})

    board = (HERE / "before-after.html").read_text(encoding="utf-8")
    views = re.findall(r'<option value="([^"]+)"[^>]*>[^<]+</option>', board.split('<select id="view">')[1].split('</select>')[0])
    dynamic = [HERE / (prefix + renderer) / (detail + "-" + view + ".png") for prefix in ["", "before-"] for renderer in ["native", "desktop-mobile"] for detail in ["full", "simple"] for view in views]
    assert len(dynamic) == 88 and all(f.is_file() for f in dynamic)
    static = [HERE / n for n in re.findall(r'(?:src|href)="([^"]+)"', board) if not n.startswith(("http", "#"))]
    assert all(f.is_file() for f in static if f.name != "report.json")
    save("board-validation.json", {"dynamic_images": 88, "all_dynamic_images_present": True, "static_links": len(static), "all_static_links_present": True, "initial_view": "front-quarter", "before_version": 13, "after_version": 14, "browser_javascript_execution": False})

    reductions = {detail: 100 * (1 - captures["native"]["geometry"][detail]["triangles"] / baseline["metrics"][detail]["visible_triangles"]) for detail in ["full", "simple"]}
    report = {
        "date": "2026-10-27", "request": "Rebuild the whole electric car from scratch, targeting AAA quality while keeping it simple enough.",
        "requirements": {"ERB01": "Replace body and exterior assembly construction", "ERB02": "Coherent sporting form, rounded low nose, convex bonnet and flowing canopy", "ERB03": "Fitted optical/pocket/glazing/wheel/panel/mirror details", "ERB04": "Full/racing budgets and five prepared shadows", "ERB05": "Refresh actual Garage template and all electric pictures", "R01": "Retain canonical physical/config/input/camera/save systems and unrelated work", "Q01": "Native proof, actual runs, retained findings, hashes and isolated Git checkpoint"},
        "implementation": {"runtime_sources": sorted(owned), "prepared_root": "electric_coachwork_v14", "new_construction": "Direct shared body sections, convex bonnet, continuous arched canopy, formed end caps, inset optical/plate assemblies and new aero wheel assembly", "reused_foundations": ["shared finish and tyre construction", "existing opaque glass shader", "physical wheel configuration and game systems"], "old_front_deformation_chain_used": False, "per_frame_vertex_deformation": False},
        "tests": tests, "parser": parser, "construction_metrics": construction["metrics"],
        "baseline": {"checks": 33, "failures": 9, "metrics": baseline["metrics"], "note": "Exact task-start sources loaded only in isolated test memory. Failures include budgets/component count and new named pocket requirements; baseline canopy is sampled using its original screen names, not assumed missing."},
        "native_views": captures, "geometry_reduction_percent": reductions,
        "geometry": {"full_visible_triangles": 115686, "racing_visible_triangles": 36952, "full_budget": 120000, "racing_budget": 45000, "prepared_meshes": 403, "previous_prepared_meshes": 864, "unbatched_instances": 372, "previous_unbatched_instances": 823, "shadows": {"frames": 5, "triangles": shadows}, "wheelbase_world_metres": 2.46, "wheel_diameter_world_metres": 0.6512, "arch_clearance_model_metres": construction["metrics"]["full"]["arch_clearance_model_metres"], "arch_clearance_world_metres": construction["metrics"]["full"]["arch_clearance_model_metres"] * 0.88},
        "assets": {"historical_v13_files_exact": len(historic), "pictures_refreshed": len(photos), "other_cars_shadow_and_garage_picture_entries_exact": True, "coachwork_sha256": manifest["source_sha256"], "assembly_sha256": manifest["model_sha256"]},
        "visual_review": "Matched front/side/rear/roof and detail views show a continuous canopy, controlled shoulder roll, convex tapered bonnet, integrated light signatures, recessed plate and simpler new wheel forms. Actual Garage and gameplay views are included for owner review.",
        "old_shape_fixture_applicability": "Original fixtures remain byte-exact and parse. Old named panels, local-control topology and historical wheel/body allocation ratios describe the replaced construction; these shape-specific fixtures were not rerun as acceptance for the new model. The unchanged bonnet and functional model/App/racing checks were run, alongside the new whole-car geometry check.",
        "retained_findings": ["Initial typed-array door outline error", "First complete draft bonnet has eight near-cowl shelf failures; original threshold retained and cowl grade corrected", "Initial baseline test misses original screen aliases and serializes NaN as null; corrected test retains all assertions and samples both constructions; final exact baseline33/9", "Native drafts expose end-section/shoulder and closed-normal/plate/panel-edge issues; successive source snapshots and native images remain", "Superseded draft resources archived outside the shipping v14 root", "Initial final audit assumes all prior tests are byte-exact; independent Electric19 braking/configuration and handling-fixture changes are identified, retained in concurrent-final, and excluded; all12 original shape/functional fixtures remain exact", "Native App logs retain desktop frame hitches; no physical-device or frame-rate claim"],
        "scope": {"concurrent_sources_preserved_excluded": concurrent, "task_did_not_edit_existing_fixtures": True, "original_shape_and_functional_fixture_files_exact": len(retained), "canonical_config_note": "Concurrent Electric18-to-19 braking tune is preserved/excluded; this visual pass changes no canonical source or handling configuration. Native commands retain their individual build identities.", "source_audit": "source-comparison.json", "asset_audit": "asset-verification.json"},
        "quality_acceptance": "AAA is the requested art target, not a certification. Owner appearance/motion and physical-device appearance/cost acceptance remain.",
        "remaining": ["Reload/rebuild the existing editor/game", "Owner visual review", "Physical-device appearance/cost acceptance"],
        "not_performed": ["physical-device attachment query/test", "APK", "real authentication/purchase", "owner-save/live mutation", "deployment", "owner-process restart", "main-index staging/commit/merge/reset"],
        "checkpoint": "checkpoint.json / task-only.patch: isolated git apply check, application and byte-exact comparison; shared index unchanged",
        "evidence": ["before-after.html", "commands.json", "derivative-commands.json", "source-comparison.json", "asset-verification.json", "board-validation.json", "checkpoint.json"]}
    save("report.json", report)
    print(json.dumps({"tests": len(tests), "parser": summary, "historical_files_exact": len(historic), "prepared_meshes": len(resources), "photos": len(photos), "shadows": shadows, "reductions_percent": reductions, "concurrent": concurrent}))


if __name__ == "__main__":
    main()
