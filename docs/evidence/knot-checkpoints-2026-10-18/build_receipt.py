"""Save this task's source diff and observed validation receipt; no Git writes."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
BEFORE = EVIDENCE / "before"
PATCH_BASE = EVIDENCE / "patch-base"

insertion = "    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_knot_checkpoint_notices.gd') 'knot-checkpoint-notice-tests.log'\n"
dev = (ROOT / "scripts/dev.ps1").read_text(encoding="utf-8-sig")
assert dev.count(insertion) == 1
(PATCH_BASE / "scripts").mkdir(parents=True, exist_ok=True)
(PATCH_BASE / "scripts/dev.ps1").write_text(dev.replace(insertion, ""), encoding="utf-8")

# Other tasks can update shared status files after our frozen snapshots. Build
# their patch base by removing only our exact section from the current text.
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    current = (ROOT / name).read_text(encoding="utf-8-sig")
    pattern = (r"## Knot checkpoint notice override \(2026-10-18\)\n"
               r"2026-10-18 KCN01-KCN02/G01/R01/Q01: [^\n]*\n\n") if name == "AGENTS.md" else r"2026-10-18 KCN01-KCN02/G01/R01/Q01: [^\n]*\n\n"
    prior, count = re.subn(pattern, "", current)
    assert count == 1, name
    destination = PATCH_BASE / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(prior, encoding="utf-8")

existing = {
    "game/race/track_session.gd": BEFORE / "track_session.gd",
    "scripts/dev.ps1": PATCH_BASE / "scripts/dev.ps1",
    "AGENTS.md": PATCH_BASE / "AGENTS.md",
    "DEVELOPMENT_STATUS.md": PATCH_BASE / "DEVELOPMENT_STATUS.md",
    "docs/PHASE_0_PLAN.md": PATCH_BASE / "docs/PHASE_0_PLAN.md",
}
added = [
    "game/tests/test_knot_checkpoint_notices.gd",
    "game/tests/test_knot_checkpoint_notices.gd.uid",
    "game/tests/capture_knot_checkpoint_notice.gd",
    "game/tests/capture_knot_checkpoint_notice.gd.uid",
    "game/tests/fixtures/knot.json",
    "docs/KNOT_CHECKPOINT_NOTICES_2026_10_18.md",
]
patch = []
files = []
for name in [*existing, *added]:
    path = ROOT / name
    old = existing[name].read_text(encoding="utf-8-sig") if name in existing else ""
    new = path.read_text(encoding="utf-8-sig")
    if old == new:
        continue
    patch.append(f"diff --git a/{name} b/{name}\n")
    diff = difflib.unified_diff(
        old.splitlines(keepends=True), new.splitlines(keepends=True),
        fromfile=f"a/{name}" if name in existing else "/dev/null",
        tofile=f"b/{name}",
    )
    for line in diff:
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    files.append({"path": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
(EVIDENCE / "task-only.patch").write_bytes("".join(patch).encode("utf-8"))

logs = {
    "baseline": "TestScript-7504",
    "baseline_diagnostic": "TestScript-14620",
    "corrected_diagnostic": "TestScript-26572",
    "knot": "TestScript-23368",
    "notices": "TestScript-25508",
    "catalog_latency": "TestScript-4192",
    "bridge_layers": "TestScript-22584",
    "compatibility_capture": "TestScript-15064",
    "desktop_mobile_capture": "TestScript-25788",
}
(EVIDENCE / "logs").mkdir(exist_ok=True)
for label, directory in logs.items():
    source = ROOT / "build/logs" / directory / "test-script.log"
    shutil.copy2(source, EVIDENCE / "logs" / f"{label}.log")

parser_candidates = [
    path for path in (ROOT / "build/logs").glob("TestScript-*/test-script.log")
    if "SCRIPT_PARSE: 890 scripts, 0 failures" in path.read_text(encoding="utf-8", errors="replace")
]
assert parser_candidates
parser = max(parser_candidates, key=lambda path: path.stat().st_mtime)
shutil.copy2(parser, EVIDENCE / "logs/parser.log")
logs["final_parser"] = parser.parent.name

fixture_hash = hashlib.sha256((ROOT / "game/tests/fixtures/knot.json").read_bytes()).hexdigest()
assert fixture_hash == "c237960ed63d03361858789517d02a3bb742740fe3795753bed3a12e6de53b13"
catalog = json.loads((EVIDENCE / "catalog-latency.json").read_text(encoding="utf-8"))
receipt = {
    "requirements": ["KCN01", "KCN02", "G01", "R01", "Q01"],
    "engine": "4.7.2.stable.official.ed1daf0bf",
    "fixture_sha256": fixture_hash,
    "notice_version": 4,
    "rules_key": "standing-5-road-gates-v23",
    "tests": {
        "knot": {"checks": 264, "failures": 0},
        "notices": {"checks": 537, "failures": 0},
        "catalog_latency": {"checks": 2171, "failures": 0},
        "ordered_gates": {"checks": 266, "failures": 0, "source": "captured tool transcript; batched dev log reused"},
        "hairpins": {"checks": 65, "failures": 0, "source": "captured tool transcript; batched dev log reused"},
        "bridge_layers": {"checks": 259, "failures": 0},
        "rewind": {"checks": 61, "failures": 0, "source": "captured tool transcript; batched dev log reused"},
        "parser": {"scripts": 890, "failures": 0},
    },
    "physical_knot": [
        {"reverse": False, "laps": 5, "ticks": 36030, "collisions": 0, "warnings": 0, "exact_replay": True},
        {"reverse": True, "laps": 5, "ticks": 35779, "collisions": 0, "warnings": 0, "exact_replay": True},
    ],
    "catalog": {
        "tracks": len(catalog),
        "blocked_cuts": sum(row["blocked_cuts"] for row in catalog),
        "silent_cuts": sum(row["silent_cuts"] for row in catalog),
        "maximum_prepared_bytes": max(row["prepared_bytes"] for row in catalog),
        "worst_correct_layer_delay_m": max(row["worst"]["delay"] for row in catalog),
    },
    "log_directories": logs,
    "source_files": files,
    "phone_test": False,
    "apk_export_install": False,
    "backend_mutation_deployment": False,
    "acceptance_remaining": "Owner driving acceptance on the updated client",
}
(EVIDENCE / "validation.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(f"Knot receipt: {len(files)} source files; {receipt['catalog']['blocked_cuts']} blocked cuts; zero test failures")
