"""Build a scoped source checkpoint and receipts without using the main index."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BEFORE = HERE / "before"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

summary = "LR01-LR04/R01/Q01: Reference-led right login card retains the original alpine bitmap and controller flows. Owner authorizes the r6 draft: development-only unchecked agreement gates unsigned Google/development/guest actions, with a selectable in-game reader and byte-exact saved copy; acceptance stays in the current panel and is not persisted or sent. Native layout1643Compatibility/1643desktopMobile, terms17/19, localization62/tooling14/App141 pass. Each native layout saves72 views across original states and all12 languages, including portrait. Initial layout/import/detached-callback/fixture/argument/inventory findings remain recorded. Source/English inventory refresh retains current concurrent source literals; ten interface messages have120 translated placeholder checks. Sources, views, hashes and task-only patch: docs/LOGIN_REFERENCE_2026_10_27.md and docs/evidence/login-reference-2026-10-27/report.json. Reload and owner/Android acceptance remain. No attachment query/device test, APK, real auth/purchase, owner-save/backend mutation, deployment, owner-process restart or main-index staging/commit/merge. Concurrent runtime work and build identity preserved/excluded."
marker = "LOGIN-REFERENCE-20261027"
block = f"<!-- {marker} -->\n## Login screen closer to the supplied reference (2026-10-27)\n{summary}\n<!-- /{marker} -->\n\n"
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = ROOT / name
    current = path.read_bytes()
    if marker.encode() not in current:
        original = BEFORE / name
        original.parent.mkdir(parents=True, exist_ok=True)
        original.write_bytes(current)
        path.write_bytes(block.encode("utf-8") + current)

# The original fixture is also retained in the earlier reviewed checkpoint.
archived = (ROOT / "docs/evidence/sign-in-fit-2026-10-25/checkpoint.patch").read_text(encoding="utf-8")
part = archived.split("diff --git a/game/tests/capture_sign_in_fit.gd b/game/tests/capture_sign_in_fit.gd\n", 1)[1].split("diff --git ", 1)[0]
original_fixture = "".join(line[1:] for line in part.splitlines(keepends=True) if line.startswith("+") and not line.startswith("+++"))
fixture_copy = (HERE / "capture-fixture-with-locales.gd").read_text(encoding="utf-8")
reconstructed = fixture_copy.replace("var capture_locales: bool = false\n", "").replace('\t\tif argument == "--locales": capture_locales = true\n', "")
reconstructed = re.sub(r"\tif capture_locales:\n.*?(?=\tapp.queue_free\(\))", "", reconstructed, flags=re.S)
assert original_fixture == reconstructed, "original fixture must match the archived reviewed source"
fixture_before = BEFORE / "game/tests/capture_sign_in_fit.gd"
fixture_before.parent.mkdir(parents=True, exist_ok=True)
fixture_before.write_text(original_fixture, encoding="utf-8", newline="\n")

paths = [
    "game/core/app.gd", "game/ui/account_panel.gd", "game/ui/account_backdrop.gd",
    "game/ui/google_sign_in_button.gd", "game/ui/language_picker.gd",
    "game/ui/draft_terms_dialog.gd", "game/ui/draft_terms_dialog.gd.uid",
    "game/tests/capture_sign_in_fit.gd", "game/tests/test_login_draft_terms.gd", "game/tests/test_login_draft_terms.gd.uid",
    "game/assets/menu/sign_in_mark.svg", "game/assets/menu/sign_in_checkbox.svg", "game/assets/menu/sign_in_checkbox_checked.svg",
    "game/legal/terms-draft-2026-10-25-r6.txt",
    "docs/LOGIN_REFERENCE_2026_10_27.md", "AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md",
]
paths += ["game/localization/" + name for name in ["messages.pot", "en.po", "fr.po", "es.po", "de.po", "pt_BR.po", "ja.po", "ko.po", "nl.po", "it.po", "fi.po", "sv.po", "nb.po"]]
patch_text = ""
hashes = {}
app_concurrent_hunks_excluded = False
for name in paths:
    path = ROOT / name
    after = path.read_text(encoding="utf-8")
    prior = BEFORE / name
    before = prior.read_text(encoding="utf-8") if prior.exists() else ""
    if name == "game/core/app.gd":
        pattern = r"(?m)^func _account\(\) -> void:\n.*?(?=^func )"
        previous_section = re.search(pattern, before, flags=re.S).group(0)
        scoped_before = re.sub(pattern, lambda _: previous_section, after, count=1, flags=re.S)
        app_concurrent_hunks_excluded = scoped_before != before
        before = scoped_before
    if before == after:
        continue
    patch_text += f"diff --git a/{name} b/{name}\n"
    if not prior.exists():
        patch_text += "new file mode 100644\n"
    patch_text += "".join(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile="a/" + name if prior.exists() else "/dev/null", tofile="b/" + name))
    hashes[name] = {"after_sha256": sha(path), "task_start_sha256": sha(prior) if prior.exists() else None}

checkpoint = HERE / "task.patch"
checkpoint.write_text(patch_text, encoding="utf-8", newline="\n")
assert (ROOT / "game/legal/terms-draft-2026-10-25-r6.txt").read_bytes() == (ROOT / "docs/legal/TERMS_DRAFT.md").read_bytes()

# Git operates only in this disposable, normalized-text checkpoint directory.
scratch = ROOT / "build/login-reference-checkpoint-20261027"
scratch.mkdir(parents=True, exist_ok=True)
for name in hashes:
    destination = scratch / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text((ROOT / name).read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
commands = []
for args in [["git", "init", "--quiet", str(scratch)],
             ["git", "-C", str(scratch), "apply", "--reverse", "--check", str(checkpoint)],
             ["git", "-C", str(scratch), "apply", "--reverse", str(checkpoint)],
             ["git", "-C", str(scratch), "apply", "--check", str(checkpoint)],
             ["git", "-C", str(scratch), "apply", str(checkpoint)]]:
    result = subprocess.run(args, text=True, capture_output=True)
    commands.append({"argv": args, "exit_code": result.returncode, "output": result.stdout + result.stderr})
    if result.returncode:
        (HERE / "checkpoint-checks.json").write_text(json.dumps(commands, indent=2) + "\n", encoding="utf-8")
        raise SystemExit(result.stderr)
for name in hashes:
    assert (scratch / name).read_text(encoding="utf-8") == (ROOT / name).read_text(encoding="utf-8"), name
(HERE / "checkpoint-checks.json").write_text(json.dumps(commands, indent=2) + "\n", encoding="utf-8")

def result(log, expression):
    raw = (HERE / log).read_bytes()
    content = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
    match = re.search(expression, content)
    assert match, log
    return {"checks": int(match[1]), "failures": int(match[2]), "log": log}

checks = {
    "baseline_layout": result("baseline-native.log", r"SIGN_IN_FIT: (\d+) checks, (\d+) failures"),
    "compatibility_layout": result("native.log", r"SIGN_IN_FIT: (\d+) checks, (\d+) failures"),
    "desktop_mobile_layout": result("mobile.log", r"SIGN_IN_FIT: (\d+) checks, (\d+) failures"),
    "compatibility_draft_terms": result("terms-native.log", r"LOGIN_DRAFT_TERMS: (\d+) checks, (\d+) failures"),
    "desktop_mobile_draft_terms": result("terms-mobile.log", r"LOGIN_DRAFT_TERMS: (\d+) checks, (\d+) failures"),
    "localization": result("localization-native.log", r"LOCALIZATION: (\d+) checks, (\d+) failures"),
    "app": result("app.log", r"APP_TESTS: (\d+) checks, (\d+) failures"),
}
assert all(value["failures"] == 0 for key, value in checks.items() if key != "baseline_layout")
report = {
    "date": "2026-10-27", "requirements": ["LR01", "LR02", "LR03", "LR04", "R01", "Q01"],
    "checks": checks,
    "python_localization": {"tests": 14, "failures": 0, "log": "localization-tooling.log"},
    "catalogue": json.loads((HERE / "catalogue-audit.json").read_text(encoding="utf-8")),
    "screenshots": {name: len(list((HERE / name).glob("*.png"))) for name in ["native", "mobile", "terms-native"]},
    "draft_sha256": sha(ROOT / "docs/legal/TERMS_DRAFT.md"),
    "original_alpine_sha256": sha(ROOT / "game/assets/menu/sign_in_alpine_v1.png"),
    "acceptance_scope": "Development-only, current panel memory; not persisted or sent to the server. Rebuilding login resets agreement. Existing signed-in management is unaffected.",
    "legal_document_language": "English draft; interface controls translated into all twelve existing languages.",
    "runtime_sources": [name for name in paths if name.startswith(("game/core/", "game/ui/")) and name.endswith(".gd")], "source_hashes": hashes,
    "task_patch": {"path": "task.patch", "sha256": sha(checkpoint), "isolated_git_roundtrip": True, "main_index_used": False, "app_concurrent_hunks_excluded": app_concurrent_hunks_excluded, "fixture_baseline_matches_prior_reviewed_checkpoint": True},
    "limitations": ["Owner visual/wording and Android touch acceptance remain.", "No physical-device attachment query or test; Mobile is a desktop renderer.", "No APK, deployment, real auth/purchase, owner-save/backend mutation, owner-process restart or main-index staging/commit/merge.", "Runtime source patch excludes concurrent App changes outside _account and generated build identity; generated English/source inventories reflect current source literals."],
    "retained_attempts": ["Initial sandbox engine log denial.", "Original four long-error overflows; intermediate setup/status/translation overflows.", "New SVG required import before preload.", "Deferred fit on detached node fixed with tree guard.", "Popup reparenting and cross-window tooltip diagnostic corrections.", "PowerShell array quoting initially produced a comma-containing output path; corrected direct invocation captures all locales.", "Source catalogue inventory initially stale, including twenty missing entries with task-start owned UI controls; normal extractor refresh passes."],
}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "screenshots": report["screenshots"], "patch_files": len(hashes), "isolated_git_roundtrip": True}, indent=2))
