from pathlib import Path
import difflib
import hashlib
import json
import shutil
import re

root = Path.cwd()
evidence = root / "docs/evidence/star-checkpoint-consistency-2026-10-16"
summary = ("Star checkpoint consistency: reproduced a 160 m route bypass saving91.11m under rules20. "
           "Rules21 retains84 forward/83 reverse mandatory spline gates selected across75 lane references; "
           "proposed uniform0.5m recovery beyond connected road/kerbs replaces uneven raster allowances. "
           "Keep paved/variable-width/start-edge lines, ordered crossing/layers, return recovery, no penalties, "
           "physical road/car/camera and immutable old boards. Bounded sweep5144/3561 deep cuts rejects all sampled deep cuts; "
           "focused64, final edge351 with five real Compact laps/47712ticks/exact replay, gates266/notices533/bridges259+258+2527/rewind61/catalog27/parser837 pass. "
           "Server legal acceptance/old exploit/new rejection pass. Historical physics050/rules20 diagnostic stays frozen; "
           "initial backend69pass/one fixture failure and original-rule autosave failure are retained. "
           "Actual commands/captures/final checks/task-only patch: docs/STAR_CHECKPOINT_CONSISTENCY_2026_10_16.md. "
           "Cold desktop preparation remains about1-2s under loading; retained preparation tens of microseconds. "
           "Matching client/API/worker rollout and owner/phone feel/loading acceptance remain; no phone attachment check/test/APK/deployment.")
status_baselines = {}
for name, prefix in (("AGENTS.md", "## Star checkpoint consistency override (2026-10-16)\n"),
                     ("DEVELOPMENT_STATUS.md", "2026-10-16 SC01-SC03/G01/R01/Q01: "),
                     ("docs/PHASE_0_PLAN.md", "2026-10-16 SC01-SC03/G01/R01/Q01: ")):
    path = root / name
    text = path.read_text(encoding="utf-8")
    addition = prefix + summary + "\n\n"
    if addition in text:
        text = text.replace(addition,"",1)
    status_baselines[name] = text
    if name == "AGENTS.md":
        heading, rest = text.split("\n", 1)
        text = heading + "\n\n" + addition + rest.lstrip("\n")
    else:
        text = addition + text
    path.write_text(text, encoding="utf-8")
    review_before = evidence / "review-before" / name
    review_before.parent.mkdir(parents=True,exist_ok=True)
    review_before.write_text(status_baselines[name],encoding="utf-8")

stage = root / "backend/deploy/stage_verifier.py"
stage_before = evidence / "before/backend/deploy/stage_verifier.py"
stage_before.parent.mkdir(parents=True, exist_ok=True)
stage_before.write_text(stage.read_text().replace('"track_session", "spline_gate_corridor",', '"track_session",'))

# Preserve the actual command output produced by scripts/dev.ps1. Source paths
# in this index identify the original logs; their contents are not synthesized.
log_root = evidence / "logs"
log_root.mkdir(exist_ok=True)
started = (evidence / "before/game/race/track_session.gd").stat().st_ctime
log_index = []
signatures = ("STAR_", "GATE_PREPARATION_US", "CATALOG_GATE_ROUTE", "CHECKPOINT_TESTS:",
              "CHECKPOINT_NOTICE_TESTS:", "BRIDGE_CHECKPOINT_TESTS:", "BRIDGE_ENTRY_TESTS:",
              "BRIDGE_EXIT_TESTS:", "START_LINE_TESTS:", "Rewind: 61", "SCRIPT_PARSE:")
for source in (root / "build/logs").glob("TestScript-*/test-script.log"):
    if source.stat().st_mtime < started:
        continue
    content = source.read_text(encoding="utf-8", errors="replace")
    if not any(signature in content for signature in signatures):
        continue
    destination = log_root / (source.parent.name + ".log")
    shutil.copyfile(source, destination)
    log_index.append({"source":str(source.relative_to(root)),"retained":str(destination.relative_to(root)),
                      "sha256":hashlib.sha256(source.read_bytes()).hexdigest()})
(evidence / "log-index.json").write_text(json.dumps(log_index,indent=2))

for name in ("star_backend_check.py", "make_star_baseline_start.py"):
    shutil.copyfile(root / "build" / name, evidence / "diagnostics" / name)

files = [
    "game/race/track_session.gd", "game/race/race_rules.gd", "game/race/spline_gate_corridor.gd",
    "game/track/native_track.gd", "backend/bmt_backend/contracts.py", "backend/bmt_backend/rivalry.py",
    "backend/deploy/stage_verifier.py", "backend/tests/test_verifier.py", "backend/tests/test_review_reliability.py",
    "backend/tests/fixtures/verified_oval.json", "game/tests/test_star_gate_tolerance.gd",
    "game/tests/test_checkpoint_rules.gd", "game/tests/test_bridge_exit_checkpoints.gd", "scripts/dev.ps1",
    "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
    "game/tests/test_star_checkpoint_consistency.gd", "game/tests/test_star_checkpoint_shortcuts.gd",
    "game/tests/test_checkpoint_catalog_routes.gd", "game/tests/capture_star_checkpoint_consistency.gd",
    "backend/tests/fixtures/rules_020/track_session.gd.txt", "backend/tests/fixtures/rules_020/race_rules.gd.txt",
    "backend/tests/fixtures/rules_020/README.md", "docs/STAR_CHECKPOINT_CONSISTENCY_2026_10_16.md",
]
for name in list(files):
    if name.endswith(".gd") and (root / (name+".uid")).exists() and not (evidence / "before" / (name+".uid")).exists():
        # Only new scripts need their new UIDs in this task's patch.
        if not (evidence / "before" / name).exists():
            files.append(name+".uid")
patches = []
hashes = []
for name in files:
    current = root / name
    before = evidence / "before" / name
    old = status_baselines[name] if name in status_baselines else (before.read_text(encoding="utf-8").replace("\r\n","\n") if before.exists() else "")
    new = current.read_text(encoding="utf-8").replace("\r\n","\n")
    if name == "backend/tests/fixtures/verified_oval.json":
        old = new.replace("standing-5-road-gates-v21","standing-5-road-gates-v20")
    if name == "backend/tests/test_verifier.py":
        physics_assert = re.search(r'^    assert real_verifier.manifest\(\)\["physics_version"\].*$',new,re.M)
        old = re.sub(r'^    assert real_verifier.manifest\(\)\["physics_version"\].*$',physics_assert.group(0),old,flags=re.M)
    if old == new:
        continue
    patches.append("diff --git a/"+name+" b/"+name+"\n")
    if not before.exists():
        patches.append("new file mode 100644\n")
    patches.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                   fromfile="a/"+name if before.exists() else "/dev/null",tofile="b/"+name))
    hashes.append({"path":name,"before_sha256":hashlib.sha256(before.read_bytes()).hexdigest() if before.exists() else None,
                   "after_sha256":hashlib.sha256(current.read_bytes()).hexdigest()})
(evidence / "scoped-change.patch").write_text("".join(patches),encoding="utf-8",newline="\n")
(evidence / "source-hashes.json").write_text(json.dumps(hashes,indent=2))
print("Scoped checkpoint:",len(hashes),"files; retained logs:",len(log_index))
