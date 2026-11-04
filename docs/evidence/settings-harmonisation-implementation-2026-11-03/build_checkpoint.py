"""Build/verify a source-only task patch without touching the main Git index."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
COMMON = [
    "game/ui/settings_page.gd", "game/ui/race_pause_menu.gd", "game/core/game.gd",
    "game/core/app.gd", "game/soundtrack/audio_world.gd", "game/tests/test_camera_modes.gd",
    "game/tests/capture_camera_modes.gd", "game/tests/capture_personal_ghosts.gd",
    "AGENTS.md", "DEVELOPMENT_STATUS.md",
]
NEW = [
    "game/ui/race_settings_overlay.gd", "game/ui/race_settings_overlay.gd.uid",
    "game/tests/test_settings_harmonisation.gd", "game/tests/test_settings_harmonisation.gd.uid",
    "scripts/translations/settings_harmonisation.tsv",
    "docs/SETTINGS_HARMONISATION_IMPLEMENTATION_2026_11_03.md",
]
LOCALES = [p.relative_to(ROOT).as_posix() for p in (ROOT / "game/localization").glob("*.po")]
LOCALES.append("game/localization/messages.pot")
tree = EVIDENCE / ("checkpoint-tree-" + uuid.uuid4().hex[:8])
tree.mkdir()
patch = ""
entries = {}
expected = {}
for name in COMMON + NEW + LOCALES:
    after = (ROOT / name).read_text(encoding="utf-8")
    if name in NEW:
        before = ""
    elif name in LOCALES:
        before, count = re.subn(
            r'\n#: game/ui/settings_page.gd\nmsgid "Personal ghost settings apply to your next race\."\nmsgstr "[^\n]*"\n',
            "", after,
        )
        assert count == 1, (name, count)
    else:
        folder = "task-doc-base" if name in ["AGENTS.md", "DEVELOPMENT_STATUS.md"] else "before"
        before = (EVIDENCE / folder / name).read_text(encoding="utf-8")
    if before == after:
        continue
    expected[name] = (before, after)
    entries[name] = {
        "before_text_sha256": hashlib.sha256(before.encode()).hexdigest(),
        "after_text_sha256": hashlib.sha256(after.encode()).hexdigest(),
        "after_file_sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest(),
    }
    target = tree / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if name not in NEW:
        target.write_text(before, encoding="utf-8", newline="\n")
    patch += f"diff --git a/{name} b/{name}\n"
    if name in NEW:
        patch += "new file mode 100644\n"
    patch += "".join(difflib.unified_diff(
        before.splitlines(keepends=True), after.splitlines(keepends=True),
        fromfile="/dev/null" if name in NEW else "a/" + name, tofile="b/" + name,
    ))
patch_path = EVIDENCE / "implementation.patch"
patch_path.write_text(patch, encoding="utf-8", newline="\n")
prefix = tree.relative_to(ROOT).as_posix()
for options in [["--check"], [], ["--reverse", "--check"], ["--reverse"]]:
    subprocess.run(["git", "apply", "--whitespace=nowarn", "--directory=" + prefix,
                    *options, str(patch_path)], cwd=ROOT, check=True)
    if options in [[], ["--reverse"]]:
        reverse = bool(options)
        for name, (before, after) in expected.items():
            target = tree / name
            if reverse and name in NEW:
                assert not target.exists(), name
            else:
                assert target.read_text(encoding="utf-8") == (before if reverse else after), name
results = {}
for platform in ["Windows-gl_compatibility", "Windows-mobile"]:
    results[platform] = json.loads((EVIDENCE / platform / "result.json").read_text())
manifest = {
    "requirements": ["SHI01", "SHI02", "SHI03", "SHI04", "SHI05", "SHI06", "R01", "Q01"],
    "runtime_implemented": True, "native_results": results,
    "retained_checks": {"camera": 1502, "control_layout": 407, "drift_haptics": 45, "graphics": 146, "pause": 17},
    "retained_assertion_failures": 0, "full_parser_pass": False,
    "global_authoring_pass": False, "device_test": False, "audio_driver": "Dummy",
    "forward_reverse_content_checks": True, "main_index_touched": False,
    "patch_sha256": hashlib.sha256(patch_path.read_bytes()).hexdigest(),
    "sources": entries,
    "captures": {p.relative_to(EVIDENCE).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for platform in results for p in (EVIDENCE / platform).glob("*.png")},
}
(EVIDENCE / "report.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(f"Verified task-only patch forward/reverse and every source: {len(entries)} files, {len(manifest['captures'])} PNGs.")
