"""Recover previous review observations from its original retained log.

The old fixture hardcodes its results path. A later run overwrote that file;
its own result is archived here. The 2026-10-28 original log retains every
JSON observation plus the final check/failure count. Reconstruction is
semantic: there is no claim of byte identity with the overwritten file.
"""
import json
import re
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent
previous = root.parent / "track-editor-fixes-2026-10-28"
result = previous / "focused/headless-gl_compatibility/results.json"
archive = root / "retained-review-current-results.json"
if not archive.exists():
    shutil.copyfile(result, archive)
log = (previous / "direct-test_editor_review_items-headless-final.log").read_text(encoding="utf-8")
observations = {}
for line in log.splitlines():
    if line.startswith("TRACK_EDITOR_AUDIT "):
        key, value = line.removeprefix("TRACK_EDITOR_AUDIT ").split(" ", 1)
        observations[key] = json.loads(value)
summary = re.search(r"EDITOR_REVIEW_ITEMS: (\d+) checks, (\d+) failures", log)
if summary is None or len(observations) != 12:
    raise SystemExit("Original log incomplete; cannot reconstruct receipt")
data = {"checks": int(summary[1]), "failures": int(summary[2]), "observations": observations}
result.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True, indent="\t"), encoding="utf-8")
print(f"Reconstructed original {data['checks']}/{data['failures']} receipt from 12 logged observations; current run archived separately.")
