"""Collect completed checks and native captures without hiding earlier failures."""
import hashlib
import json
from pathlib import Path
import re

folder = Path(__file__).resolve().parent
labels = ["accepted-headless", "accepted-compat", "accepted-mobile", "accepted-preload-headless",
          "retained-carousel-headless", "retained-live-headless", "retained-live-compat",
          "retained-reflections-compat", "final-tools-headless"]
summary = {"checks": 0, "failures": 0, "runs": [], "captures": {}}
for label in labels:
    receipt = json.loads((folder / (label + "-receipt.json")).read_text())
    assert receipt["exit_code"] == 0, label
    log = (folder / (label + ".log")).read_text()
    report_path = folder / label / "report.json"
    if report_path.exists():
        report = json.loads(report_path.read_text())
    else:
        result = re.search(r"(?:GARAGE_ENTRY_CAROUSEL:|GARAGE_LIVE_ENTRY) (\{.*\})", log)
        if result:
            report = json.loads(result[1])
        else:
            result = re.search(r"GARAGE_OPENING_TOOLS (\d+) checks, (\d+) failures", log)
            assert result, label
            report = {"checks": int(result[1]), "failures": int(result[2])}
    assert report["failures"] == 0 and "SCRIPT ERROR:" not in log, label
    summary["checks"] += report["checks"]
    summary["runs"].append({"label": label, "report": report, "changed_sources": receipt["changed_sources"],
                            "engine_errors": re.findall(r"^ERROR:.*$", log, re.M)})
    for capture in sorted((folder / label).glob("*.png")):
        summary["captures"][str(capture.relative_to(folder))] = hashlib.sha256(capture.read_bytes()).hexdigest()
summary["earlier_failure_logs"] = ["focused-headless.log", "focused-compat.log", "focused-compat-v2.log",
                                   "retained-preload-headless.log", "retained-tools-headless.log"]
summary["standalone_mobile_shutdown_failure"] = "mobile-shutdown-failure.json"
(folder / "summary.json").write_text(json.dumps(summary, indent=2)+"\n")
print("Accepted checks:", summary["checks"], "failures:", summary["failures"], "native captures:", len(summary["captures"]))
for run in summary["runs"]:
    print(run["label"], run["report"]["checks"], "/", run["report"]["failures"], "changed:", run["changed_sources"])
