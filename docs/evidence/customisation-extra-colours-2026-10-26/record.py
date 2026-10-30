"""Record the narrow palette change and observed native review outcomes."""
from pathlib import Path
import difflib
import hashlib
import json
import re

evidence = Path(__file__).resolve().parent
repo = evidence.parents[2]
source = repo / "game/ui/garage_livery_menu.gd"
before = (evidence / "before/garage_livery_menu.gd").read_text(encoding="utf-8")
after = source.read_text(encoding="utf-8")


def palette(text):
    return re.findall(r'"([0-9a-f]{6})"', text.split("const PALETTE:", 1)[1].split("const Studio", 1)[0])


old, new = palette(before), palette(after)
observations = {
    "original_colours": len(old),
    "current_colours": len(new),
    "columns": 5,
    "rows": len(new) // 5,
    "added": new[len(old):],
    "original_order_retained": new[:len(old)] == old,
    "all_colours_distinct": len(set(new)) == len(new),
    "remaining_runtime_source_exact": before.split("const Studio", 1)[1] == after.split("const Studio", 1)[1],
}
runs = {}
for mode in ["initial-headless", "headless", "gl_compatibility", "mobile"]:
    folder = evidence / mode
    if not (folder / "command.json").exists():
        continue
    run = json.loads((folder / "command.json").read_text(encoding="utf-8-sig"))
    raw_log = (folder / "console.log").read_bytes()
    log = raw_log.decode("utf-16" if raw_log.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    run["summaries"] = [line for line in log.splitlines() if any(token in line for token in ["Customisation", "PALETTE_", "ERROR:", "FAIL:", "panel_reveal_point"])]
    saved = re.findall(r"PALETTE_SAVED: (\w+)=([0-9a-f]{6}) chosen=([0-9a-f]{6})", log)
    if mode in ["gl_compatibility", "mobile"]:
        run["saved_choices"] = len(saved)
        run["saved_choices_match"] = len(saved) == 15 and all(value == chosen for _, value, chosen in saved)
        run["screenshots"] = [path.name for path in sorted(folder.glob("*.png"))]
    runs[mode] = run

patch = "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile="a/game/ui/garage_livery_menu.gd", tofile="b/game/ui/garage_livery_menu.gd"))
(evidence / "task-only.patch").write_text(patch, encoding="utf-8", newline="\n")
report = {
    "requirements": {"EC01": "Add five distinct colours as one new row", "EC02": "Retain existing selection and local persistence", "EC03": "Review native layout at multiple window sizes"},
    "observations": observations,
    "runtime_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "runs": runs,
    "limitations": ["Desktop native rendering only", "The retained headless configurator stops at electric_coachwork.gd panel_reveal_point before reaching palette interaction", "The extra portrait capture clips the existing landscape shell; no portrait-layout change is included", "No device attachment check or physical-device test", "Owner appearance/touch acceptance remains", "No APK, deployment, live mutation, staging, commit, merge or owner-process restart"],
}
(evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"observations": observations, "runs": {mode: {key: value for key, value in run.items() if key in ["exit_code", "saved_choices", "saved_choices_match"]} for mode, run in runs.items()}}, indent=2))
