"""Record the task-only review patch, unchanged known failures and final evidence."""
from pathlib import Path
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
import localization as catalog
import translate_catalogues as compiler


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run_python(name, arguments):
    result = subprocess.run([sys.executable, *arguments], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            env={**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"})
    (EVIDENCE / name).write_text(result.stdout + result.stderr, encoding="utf-8", newline="\n")
    return {"command": [sys.executable, *arguments], "exit_code": result.returncode, "log": name}


def missing(entries):
    return {key for key, value in entries.items() if key[1] and any(not text for field, text in value.items() if field.startswith("msgstr"))}


def read_log(name):
    data = (EVIDENCE / name).read_bytes()
    return data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")


def failures(name):
    return sorted(line for line in read_log(name).splitlines() if line.startswith("FAIL:"))


def summary(name):
    content = read_log(name)
    found = re.findall(r"([A-Z_]+): (\d+) (?:checks|scripts), (\d+) failures", content)
    if not found:
        raise ValueError(f"Missing completed test result: {name}")
    kind, checks, errors = found[-1]
    return {"suite": kind, "checks": int(checks), "failures": int(errors), "log": name}


commands = [
    run_python("tooling-inventory-final.log", ["-m", "unittest", "discover", "-s", "scripts", "-p", "test_localization.py"]),
    run_python("tooling-authoring-final.log", ["-m", "unittest", "discover", "-s", "scripts", "-p", "test_translation_authoring.py"]),
    run_python("completeness-final.log", ["scripts/localization.py", "check"]),
    run_python("strict-authoring-final.log", ["scripts/translate_catalogues.py"]),
]
assert all(item["exit_code"] == 0 for item in commands[:2])
assert all(item["exit_code"] != 0 for item in commands[2:])
messages = catalog.collect()
rows = compiler.authored()
coverage = {}
for language in compiler.LANGUAGES:
    old = catalog.parse_po((EVIDENCE / "before/localization" / f"{language}.po").read_text(encoding="utf-8"))
    new = catalog.parse_po((catalog.DESTINATION / f"{language}.po").read_text(encoding="utf-8"))
    unresolved = missing(new)
    assert unresolved == missing(old), language
    added = {key for key in new.keys() - old.keys() if key[1]}
    assert not added.intersection(unresolved), language
    problems = catalog.validate(new, messages, language)
    assert all(": untranslated message " in problem for problem in problems), problems
    coverage[language] = {"remaining_task_start_gaps": len(unresolved), "new_messages_with_copy": len(added), "placeholder_or_registration_errors": 0}

comparisons = []
for current, baseline in [("test_challenge_cards.log", "probe_translation_gaps_original_challenges.log"),
                          ("test_store_reference.log", "probe_translation_gaps_original_store.log")]:
    assert failures(current) == failures(baseline), (current, baseline)
    comparisons.append({"current": summary(current), "exact_task_start_in_process": summary(baseline), "same_failure_messages": True})

before = {}
for path in (EVIDENCE / "before").iterdir():
    if path.is_file():
        before[path.name.replace("__", "/")] = path.read_bytes()
for path in (EVIDENCE / "before/localization").rglob("*"):
    if path.is_file():
        before["game/localization/" + path.relative_to(EVIDENCE / "before/localization").as_posix()] = path.read_bytes()
for relative in ["AGENTS.md", "DEVELOPMENT_STATUS.md"]:
    current = (ROOT / relative).read_bytes()
    block = re.compile(rb"<!-- TRANSLATION-GAPS-20261025 -->.*?<!-- /TRANSLATION-GAPS-20261025 -->\r?\n\r?\n", re.S)
    assert len(block.findall(current)) == 1
    before[relative] = block.sub(b"", current, count=1)
new_files = ["scripts/translations/ui_gaps.tsv", "docs/TRANSLATION_GAPS_2026_10_25.md"]
for stem in ["test_translation_gaps", "probe_translation_gaps_original_challenges", "probe_translation_gaps_original_store"]:
    for suffix in [".gd", ".gd.uid"]:
        path = ROOT / "game/tests" / (stem + suffix)
        if path.exists():
            new_files.append(path.relative_to(ROOT).as_posix())
before.update(dict.fromkeys(new_files, b""))
patch, changed = [], []
for relative, original in sorted(before.items()):
    target = ROOT / relative
    if not target.exists():
        continue
    final = target.read_bytes()
    if original == final:
        continue
    original_text, final_text = original.decode("utf-8-sig"), final.decode("utf-8-sig")
    if original_text.replace("\r\n", "\n") == final_text.replace("\r\n", "\n"):
        continue
    patch.extend(difflib.unified_diff(original_text.splitlines(True), final_text.splitlines(True),
                                    fromfile="a/" + relative if original else "/dev/null", tofile="b/" + relative))
    changed.append({"path": relative, "before_sha256": digest(original) if original else None, "after_sha256": digest(final)})
patch_path = EVIDENCE / "checkpoint.patch"
patch_path.write_text("".join(patch).replace("\r\n", "\n"), encoding="utf-8", newline="\n")
review = subprocess.run(["git", "apply", "--reverse", "--check", str(patch_path)], cwd=ROOT, capture_output=True, text=True)
(EVIDENCE / "checkpoint-check.log").write_text(review.stdout + review.stderr, encoding="utf-8")
assert review.returncode == 0, review.stderr
logs = ["test_translation_gaps-final.log", "gl_compatibility-final.log", "mobile-final.log", "test_script_parse-final.log",
        "test_localization.log", "test_translations.log", "test_app.log", "test_results_challenge_setup.log", "test_achievement_detail.log", "test_rivalry_view_polish-final.log"]
results = [summary(name) for name in logs]
assert all(item["failures"] == 0 for item in results)
captures = []
for directory in ["gl_compatibility-final", "mobile-final"]:
    for path in sorted((EVIDENCE / directory).glob("*.png")):
        captures.append({"path": path.relative_to(EVIDENCE).as_posix(), "sha256": digest(path.read_bytes())})
assert len(captures) == 40
report = {
    "date": "2026-10-25", "requirements": [f"TG{i:02}" for i in range(1, 10)] + ["R01", "G01", "Q01"],
    "engine": (ROOT / "godot-version.txt").read_text().strip(),
    "authorship": "93 directly assistant-authored rows; no translation model or external translation service",
    "source_messages": len(messages), "authored_rows_total": len(rows), "coverage": coverage,
    "strict_completeness": "still fails on the same 36 task-start gaps per translated locale; not a complete language release",
    "commands": commands,
    "native_entry_point": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1",
    "native_environment": {"APPDATA": "workspace/build/translation-gaps-*-user", "BMT_API_URL": "", "services": "local in-process fixtures only"},
    "native_commands": [
        "-Action Import -CommandTimeoutSeconds 180",
        "-Action TestScript -ScriptPath res://tests/<suite>.gd -CommandTimeoutSeconds 180",
        "-Action TestScript -ScriptPath res://tests/test_translation_gaps.gd -Graphical -RenderingMethod <gl_compatibility|mobile> -TestArgument --evidence-root=res://../docs/evidence/translation-gaps-2026-10-25/<renderer>-final -CommandTimeoutSeconds 180"
    ],
    "passed": results, "known_regression_failures": comparisons,
    "initial_failures_retained": [
        "PowerShell execution policy blocked direct ./scripts/dev.ps1 invocation before process-local entry-point use",
        "import.log: sandboxed native startup could not read Windows root certificate store; import-final.log succeeds with automatic escalation approval",
        "native-initial.log: 1129 checks/24 failures from the fixture missing earned-tier unlocks; fixed without altering assertions",
        "compatibility-initial.log: 1301 checks/11 failures, retained Rivalry locale and timer targeting; corrected locale refresh and direct named timer coverage",
        "Tooling assertion originally assumed no Jules inventory entry anywhere; corrected to verify the intended Rivalry sample-data exclusion precisely"
    ],
    "changed_files": changed, "checkpoint": {"patch": "checkpoint.patch", "sha256": digest(patch_path.read_bytes()), "git_apply_reverse_check": review.returncode},
    "captures": captures,
    "acceptance_remaining": ["reload game", "owner/contextual language review", "physical-device visual/touch acceptance", "36 older catalogue gaps"],
    "not_performed": ["device attachment check", "physical-device test", "APK", "real authentication", "real purchase", "live mutation", "deployment", "owner-process restart", "Git index mutation"],
}
(EVIDENCE / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
print(f"EVIDENCE: {len(changed)} scoped files, {len(captures)} native captures, all added catalogue keys translated; 36 unchanged older gaps per locale")
