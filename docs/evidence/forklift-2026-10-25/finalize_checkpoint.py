"""Refresh the explicitly shared review snapshot; never writes Git/index or owner saves."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
BASE = ROOT / "build/forklift/checkpoint-base"


def main():
    manifest = json.loads((EVIDENCE / "source-hashes.json").read_text())
    patch = []
    for item in manifest:
        path = ROOT / item["path"]
        item["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        if item["role"] == "native model render" or path.suffix == ".png":
            continue
        before = ""
        if item["role"] == "shared integration/documentation context":
            saved = EVIDENCE / "before" / item["path"].replace("/", "__")
            before = saved.read_text(encoding="utf-8-sig")
            destination = BASE / item["path"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(before, encoding="utf-8", newline="\n")
        after = path.read_text(encoding="utf-8-sig")
        if before != after:
            patch.extend(difflib.unified_diff(
                before.splitlines(keepends=True), after.splitlines(keepends=True),
                fromfile="a/" + item["path"] if before else "/dev/null",
                tofile="b/" + item["path"],
            ))
    (EVIDENCE / "checkpoint.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    (EVIDENCE / "source-hashes.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    start = (EVIDENCE / "before/status.txt").stat().st_mtime
    runs = []
    for log in (ROOT / "build/logs").glob("*/*.log"):
        if log.stat().st_mtime < start:
            continue
        data = log.read_text(encoding="utf-8-sig", errors="replace")
        if not any(tag in data for tag in (
            "FORKLIFT_", "CAR_TESTS:", "APPEARANCE_SYNC:", "APP_TESTS:", "SCRIPT_PARSE:",
            "VEHICLE_AUDIO:", "LIVERY_PREVIEWS: forklift", "res://tests/test_forklift.gd",
            "res://vehicle/forklift_model.gd",
        )):
            continue
        destination = EVIDENCE / "logs" / f"{log.parent.name}-{log.name}"
        shutil.copyfile(log, destination)
        runs.append({
            "source": str(log.relative_to(ROOT)),
            "saved": str(destination.relative_to(ROOT)),
            "summaries": re.findall(r"^(?:FORKLIFT_TESTS|FORKLIFT_AUDIO_BASELINE|CAR_TESTS|APPEARANCE_SYNC|APP_TESTS|SCRIPT_PARSE|VEHICLE_AUDIO|LIVERY_PREVIEWS):.*$", data, re.M),
            "failures": re.findall(r"^FAIL:.*$", data, re.M),
        })
    (EVIDENCE / "runs.json").write_text(json.dumps(runs, indent=2) + "\n", encoding="utf-8")
    print(f"Refreshed {len(manifest)} hashes and {len(runs)} workspace run logs")


if __name__ == "__main__":
    main()
