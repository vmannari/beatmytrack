"""Derive the loading results from raw interleaved runs and image files."""
import ast
import hashlib
import json
from pathlib import Path
import statistics

folder = Path(__file__).resolve().parent
report = {"performance": [], "visual_pairs": 0, "sources": {}}
for label in ["interleaved-compat", "interleaved-mobile"]:
    data = json.loads((folder / (label + ".json")).read_text())
    receipt = json.loads((folder / (label + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0 and data["failures"] == 0
    assert receipt["before"] == receipt["after"], "sources changed during " + label
    controls = [r["wall_ms"] for r in data["samples"] if r["control"] and r["cycle"] > 0]
    cached = [r["wall_ms"] for r in data["samples"] if not r["control"] and r["worlds_before"] > 0]
    control_median, cached_median = statistics.median(controls), statistics.median(cached)
    reference = (folder / (label + "-1.png")).read_bytes()
    for cycle in range(2, 8):
        assert (folder / (label + "-" + str(cycle) + ".png")).read_bytes() == reference
        report["visual_pairs"] += 1
    report["performance"].append(dict(label=label, controls_ms=controls, retained_world_ms=cached,
                                      control_median_ms=control_median, optimized_median_ms=cached_median,
                                      reduction_percent=(1 - cached_median / control_median) * 100))
    report["sources"][label] = receipt["after"]
for path in folder.glob("*.py"):
    ast.parse(path.read_text(encoding="utf-8"))
report["first_laps"] = {}
for label in ["first-lap-compat-visibility-fixture", "first-lap-mobile", "desert-old-loader-mobile"]:
    path = folder / (label + ".json")
    if path.exists():
        data = json.loads(path.read_text())
        report["first_laps"][label] = data["first_laps"]
report["evidence_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted(folder.iterdir()) if p.suffix in (".json", ".log", ".png", ".py", ".gd")
                              and p.name != "report.json"}
(folder / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"performance": report["performance"], "exact_visual_pairs": report["visual_pairs"]}))
