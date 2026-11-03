"""Summarize real-App loading-art review and retain native image hashes."""
import hashlib
import json
from pathlib import Path
import re

folder = Path(__file__).resolve().parent
summary = {"checks": 0, "failures": 0, "runs": [], "captures": {}}
for label in ("compat", "mobile"):
    receipt = json.loads((folder/(label+"-receipt.json")).read_text())
    report = json.loads((folder/label/"report.json").read_text())
    log = (folder/(label+".log")).read_text()
    assert receipt["exit_code"] == 0 and report["failures"] == 0 and "SCRIPT ERROR:" not in log, label
    summary["checks"] += report["checks"]
    summary["runs"].append(dict(label=label, checks=report["checks"], failures=report["failures"],
                                changed_sources=receipt["changed_sources"],
                                motion=re.findall(r"changed_samples=(\d+)",log),
                                engine_errors=re.findall(r"^ERROR:.*$",log,re.M)))
    for capture in sorted((folder/label).glob("*.png")):
        summary["captures"][str(capture.relative_to(folder))] = hashlib.sha256(capture.read_bytes()).hexdigest()
(folder/"summary.json").write_text(json.dumps(summary,indent=2)+"\n")
print("Native checks:",summary["checks"],"failures:",summary["failures"],"captures:",len(summary["captures"]))
