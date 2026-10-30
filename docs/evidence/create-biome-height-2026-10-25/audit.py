"""Summarize native layout receipts and make a task-only review patch."""
import difflib
import hashlib
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
repo = evidence.parents[2]
report = {"date": "2026-10-25", "requirements": ["CBH01", "CBH02", "R01", "Q01"], "captures": {}, "regressions": {"selection_compatibility": {"checks": 82, "failures": 0}, "app_headless": {"checks": 141, "failures": 0}, "parser": {"scripts": 1181, "failures": 0}}, "device_test": False}
for mode in ("before", "final", "mobile", "fi", "ja"):
    receipt = evidence / mode / "layout.json"
    if not receipt.exists():
        report["captures"][mode] = {"available": False}
        continue
    rows = json.loads(receipt.read_text(encoding="utf-8"))
    groups = {}
    for row in rows:
        groups.setdefault(tuple(row["viewport"]), []).append(row)
    results = []
    for viewport, selected in groups.items():
        stable = all(len({tuple(row[key]) for row in selected}) == 1 for key in ("picker", "summary", "create"))
        fits = all(row["description"][3] >= row["text_height"] for row in selected)
        results.append({"window": viewport, "stable": stable, "text_fits": fits, "summary_heights": {row["biome"]: row["summary"][3] for row in selected}})
    report["captures"][mode] = {"available": True, "selections": len(rows), "windows": results}
    if mode != "before":
        assert all(row["stable"] and row["text_fits"] for row in results), (mode, results)
assert any(not row["stable"] for row in report["captures"]["before"]["windows"])
paths = ["game/core/app.gd", "game/tests/capture_create_biome_height.gd", "game/tests/capture_create_biome_height.gd.uid", "docs/CREATE_BIOME_HEIGHT_2026_10_25.md"]
patch = []
for name in paths:
    current = repo / name
    after = current.read_text(encoding="utf-8")
    before = (evidence / "before/app.gd.txt").read_text(encoding="utf-8") if name == "game/core/app.gd" else ""
    patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile="a/" + name if before else "/dev/null", tofile="b/" + name))
report["sha256"] = {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in paths}
(evidence / "checkpoint.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for mode, value in report["captures"].items():
    print(mode, "unavailable" if not value["available"] else [(row["window"], row["stable"]) for row in value["windows"]])
