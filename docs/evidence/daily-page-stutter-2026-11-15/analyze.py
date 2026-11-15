"""Collect retained frame samples, diagnostics and exact screenshot controls."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
LABELS = ["baseline-compatibility", "paired-before-1", "paired-before-2",
          "paired-after-1", "paired-after-2", "isolate-garage",
          "final-garage-profile", "final-profile-2", "final-profile-mobile"]


def main():
    report = {"profiles": {}}
    for label in LABELS:
        receipt = json.loads((OUT / (label + "-receipt.json")).read_text())
        report["profiles"][label] = {
            "frames": json.loads((OUT / label / "frames.json").read_text()),
            "errors": receipt["errors"], "exit_code": receipt["exit_code"],
        }
    before = OUT / "paired-before-1/ready.png"
    after = OUT / "final-profile-2/ready.png"
    report["screenshot_control"] = {
        "before": str(before.relative_to(OUT)), "after": str(after.relative_to(OUT)),
        "before_sha256": hashlib.sha256(before.read_bytes()).hexdigest(),
        "after_sha256": hashlib.sha256(after.read_bytes()).hexdigest(),
        "exact": before.read_bytes() == after.read_bytes(),
    }
    (OUT / "summary.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({label: value["frames"][0] for label, value in report["profiles"].items()}, indent=2))
    print("SCREENSHOT_EXACT", report["screenshot_control"]["exact"])


if __name__ == "__main__":
    main()
