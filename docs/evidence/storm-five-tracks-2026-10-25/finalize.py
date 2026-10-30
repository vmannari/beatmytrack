"""Package the five current creator files and make a task-only review patch.

Run from the repository root after the native tests and captures finish.
Never stages files, changes Git metadata, publishes, or writes owner save data.
"""
from __future__ import annotations

import difflib
import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
IDS = ["storm_freight", "storm_switchyard", "storm_timber", "storm_quarry", "storm_floodgate"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text(path: Path) -> str:
    return path.read_bytes().decode("utf-8")


def main() -> None:
    runtime = json.loads((OUT / "runtime.json").read_text())
    assert runtime["checks"] == 165 and runtime["failures"] == 0
    geometry = json.loads((OUT / "runtime-geometry.json").read_text())
    assert geometry["checks"] == 50 and geometry["failures"] == 0
    assert {t["id"] for t in runtime["tracks"]} == set(IDS)
    assert all(len(t["cars"]) == 7 for t in runtime["tracks"])
    assert all(c["finished"] and len(c["laps"]) == 5 and c["contacts"] == 0 for t in runtime["tracks"] for c in t["cars"])
    sources = [ROOT / "game/resources/storm_tracks" / (id + ".json") for id in IDS]
    documents = [json.loads(p.read_text()) for p in sources]
    manifest = json.loads((ROOT / "game/resources/builtin_tracks.json").read_text())
    assert [e["id"] for e in manifest["entries"]] == ["ellipse"] + IDS
    for source, document in zip(sources, documents):
        native = json.loads((ROOT / "game/resources/tracks" / source.name).read_text())
        assert native["creator_document"] == document
        assert native["provenance"]["source_sha256"] == sha(source)
    (OUT / "publish-documents.json").write_text(json.dumps(documents, indent=2) + "\n", encoding="utf-8")
    with zipfile.ZipFile(OUT / "storm-tracks.zip", "w") as archive:
        for source in sources:
            item = zipfile.ZipInfo(source.name, (2026, 10, 25, 12, 0, 0))
            item.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(item, source.read_bytes())
        item = zipfile.ZipInfo("TRACK-GUIDE.txt", (2026, 10, 25, 12, 0, 0))
        item.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(item, "Five original Storm circuits for Beat my track.\nImport individual creator-track-v5 JSON files through Create.\n\n" + "\n".join(d["id"] + ".json - " + d["name"] for d in documents) + "\n\nOrdinary five laps, existing wet grip, explicitly placed scenery.\nNot published to the online catalogue.\n")

    patterns = {
        "all-car-final": "STORM_TRACK_TESTS: 165 checks, 0 failures",
        "geometry-final": "STORM_TRACK_TESTS: 50 checks, 0 failures",
        "catalog-headless": "STORM_TRACK_CATALOG: 33 checks, 0 failures",
        "tutorial": "First-play tutorial: 168 checks, 0 failures",
        "retirement": "EDITOR_RETIREMENT_TESTS: 31 checks, 0 failures",
        "parser": "SCRIPT_PARSE: 1204 scripts, 0 failures",
    }
    logs = list((ROOT / "build/logs").glob("TestScript-*/test-script.log"))
    captured_logs = {}
    for label, pattern in patterns.items():
        matches = [p for p in logs if pattern in p.read_text(encoding="utf-8", errors="replace")]
        assert matches, label
        source = max(matches, key=lambda p: p.stat().st_mtime)
        target = OUT / "logs" / (label + ".log")
        shutil.copy2(source, target)
        captured_logs[label] = str(source.relative_to(ROOT)).replace("\\", "/")
    for method in ["gl_compatibility", "mobile"]:
        for label, marker in [("catalog", "STORM_TRACK_CATALOG: 34 checks, 0 failures"), ("capture", "STORM_TRACK_CAPTURES: 5 tracks")]:
            matches = [p for p in logs if marker in p.read_text(encoding="utf-8", errors="replace") and (("OpenGL API" if method == "gl_compatibility" else "Forward Mobile") in p.read_text(encoding="utf-8", errors="replace"))]
            assert matches, method + label
            source = max(matches, key=lambda p: p.stat().st_mtime)
            shutil.copy2(source, OUT / "logs" / (method + "-" + label + ".log"))
            captured_logs[method + "-" + label] = str(source.relative_to(ROOT)).replace("\\", "/")
        expected = [id + suffix + ".png" for id in IDS for suffix in ["-map", "-drive", "-detail"]] + ["contact-sheet.png", "local-catalog.png"]
        assert all((OUT / method / name).exists() for name in expected)

    new_files = [
        "scripts/build_storm_tracks.py", "game/tests/test_storm_tracks.gd",
        "game/tests/test_storm_track_catalog.gd", "game/tests/capture_storm_tracks.gd",
        "game/tests/probe_storm_tracks.gd", "docs/STORM_FIVE_TRACKS_2026_10_25.md",
        "docs/evidence/storm-five-tracks-2026-10-25/finalize.py",
    ] + ["game/resources/" + folder + "/" + id + ".json" for folder in ["storm_tracks", "tracks"] for id in IDS]
    for name in new_files.copy():
        if name.endswith(".gd") and (ROOT / (name + ".uid")).exists(): new_files.append(name + ".uid")
    changes = {name: ("", text(ROOT / name)) for name in new_files}
    for name in ["game/resources/builtin_tracks.json", "game/tests/test_first_play_tutorial.gd", "game/tests/test_editor_retirement.gd"]:
        changes[name] = (text(OUT / "before" / name), text(ROOT / name))
    # Use current content with only this task's header removed as the base.
    # This excludes any intervening concurrent edits from the review patch.
    for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
        after = text(ROOT / name)
        start = after.index("<!-- STORM-FIVE-TRACKS-20261025 -->")
        end = after.index("<!-- /STORM-FIVE-TRACKS-20261025 -->") + len("<!-- /STORM-FIVE-TRACKS-20261025 -->")
        while end < len(after) and after[end] in "\r\n": end += 1
        changes[name] = (after[:start] + after[end:], after)
    before = text(OUT / "before/README.md")
    after = text(ROOT / "README.md")
    # Only the Local tracks paragraph belongs to this task.
    def paragraph(value: str) -> str:
        tail = value.split("## Local tracks and saves", 1)[1].lstrip("\r\n")
        return re.split(r"\r?\n\r?\n", tail, maxsplit=1)[0]
    changes["README.md"] = (after.replace(paragraph(after), paragraph(before), 1), after)
    patch = []
    for name, (before, after) in changes.items():
        for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile="a/" + name if before else "/dev/null", tofile="b/" + name):
            patch.append(line if line.endswith("\n") else line + "\n\\ No newline at end of file\n")
    (OUT / "checkpoint.patch").write_bytes("".join(patch).encode("utf-8"))
    report = {
        "date": "2026-10-25", "requirements": ["ST01", "ST02", "ST03", "R01", "Q01"],
        "engine": (ROOT / "godot-version.txt").read_text().strip(),
        "validation": {"all_car_checks": 165, "geometry_checks": 50, "catalog_headless": 33, "catalog_compatibility": 34, "catalog_desktop_mobile": 34, "tutorial": 168, "retirement": 31, "parser_scripts": 1204, "failures": 0, "completed_laps": 175, "diagnostic_contacts": 0, "exact_five_lap_replays": 5},
        "tracks": [{"id": t["id"], "name": t["name"], "length_m": t["route_m"], "objects": t["objects"], "source_sha256": sha(ROOT / "game/resources/storm_tracks" / (t["id"] + ".json")), "native_sha256": sha(ROOT / "game/resources/tracks" / (t["id"] + ".json"))} for t in runtime["tracks"]],
        "logs": captured_logs,
        "changed_files": sorted(changes),
        "source_hashes": {name: sha(ROOT / name) for name in changes},
        "capture_hashes": {str(p.relative_to(OUT)).replace("\\", "/"): sha(p) for method in ["gl_compatibility", "mobile"] for p in (OUT / method).glob("*.png")},
        "package_sha256": sha(OUT / "storm-tracks.zip"),
        "checkpoint": {"path": "checkpoint.patch", "sha256": sha(OUT / "checkpoint.patch"), "reverse_apply_check": "pending"},
        "limitations": ["Difficulty and appearance require owner driving review.", "Conservative diagnostic lap times are not human racing-time targets.", "No device attachment check or physical-device test, APK, deployment, purchase or live database mutation.", "Not published to online Free Race; local built-ins and importable creator files are ready.", "Concurrent workspace changes are preserved. Source hashes describe final capture time; running Godot processes retain their loaded script/resource versions."],
        "retained_corrections": ["initial-gantry-failure.json", "initial-uneven-knots.json", "initial-basin-rail.json", "logs/initial-capture.log", "logs/initial-catalog-path.log", "before-wayfinding-final-drive.json"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("STORM_PACKAGE_FINAL: five sources, 175 completed laps, task-only review patch prepared")


if __name__ == "__main__": main()
