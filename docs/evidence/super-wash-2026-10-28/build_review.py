"""Build and verify an owned-source checkpoint without touching the Git index."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent


def main():
    paths = ["game/ui/garage_page.gd", "game/tests/test_super_wash.gd", "game/tests/test_super_wash.gd.uid",
             "scripts/translations/super_wash.tsv", "docs/SUPER_WASH_2026_10_28.md"]
    paths += [str(path.relative_to(ROOT)).replace("\\", "/") for path in sorted((ROOT / "game/localization").glob("*.po"))]
    paths.append("game/localization/messages.pot")
    additions = set(paths[:5]) - {"game/ui/garage_page.gd"}
    patch = []
    hashes = {}
    fixture = ROOT / "tmp/super-wash-checkpoint"
    fixture.mkdir(parents=True, exist_ok=False)
    for name in paths:
        path = ROOT / name
        after = path.read_text(encoding="utf-8")
        if name in additions:
            before = ""
        elif name == "game/ui/garage_page.gd":
            button = '\t\tvar super_wash := MenuStyle.button("Super Wash", _super_wash)\n\t\tsuper_wash.name = "GarageSuperWash"\n\t\tsuper_wash.custom_minimum_size = Vector2(160,60)\n\t\tactions.add_child(super_wash)\n'
            assert after.count(button) == 1
            before = after.replace(button, "", 1)
            before, count = re.subn(r"func _super_wash\(\) -> void:\n.*?(?=func _select_wash_tool)", "", before, flags=re.S)
            assert count == 1
        else:
            before, count = re.subn(r'\n\n#: game/ui/garage_page.gd\nmsgid "Super Wash"\nmsgstr [^\n]*\n', "\n", after)
            assert count == 1, name
        patch.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True),
                                          fromfile="/dev/null" if name in additions else "a/"+name,
                                          tofile="b/"+name))
        if name not in additions:
            target = fixture / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(before, encoding="utf-8", newline="\n")
        hashes[name] = hashlib.sha256(after.encode("utf-8")).hexdigest()
    review = HERE / "source-only.patch"
    review.write_text("".join(patch), encoding="utf-8", newline="\n")
    relative = str(review.relative_to(ROOT))
    directory = str(fixture.relative_to(ROOT)).replace("\\", "/")
    commands = [["git", "apply", "--check", "--reverse", relative],
                ["git", "apply", "--check", "--directory="+directory, relative],
                ["git", "apply", "--directory="+directory, relative],
                ["git", "apply", "--check", "--reverse", "--directory="+directory, relative]]
    receipts = []
    for command in commands:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        receipts.append({"command": command, "exit": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
        assert result.returncode == 0, receipts[-1]
    for name in paths:
        assert hashlib.sha256((fixture/name).read_text(encoding="utf-8").encode("utf-8")).hexdigest() == hashes[name], name
    report = {
        "date": "2026-10-28", "requirements": ["SW01", "SW02", "SW03", "Q01"],
        "source_sha256_lf": hashes,
        "validation": {"headless": [162, 0], "gl_compatibility": [176, 0], "desktop_mobile": [176, 0],
                       "easier_wash": [48, 0], "gentle_scrubbing": [428, 0], "locales": 12, "parse_exit": 0},
        "captures_per_renderer": 14,
        "limitations": ["Concurrent VehicleCustomisation.valid typed-array runtime errors retained in all Super Wash logs",
                        "Sandbox Windows certificate-store errors retained", "No whole-app error-free or device claim",
                        "Reload/rebuild and owner/device acceptance remain", "Ad integration is intentionally future work"],
        "checkpoint": receipts,
        "excluded": ["concurrent vehicle/editor/backend work", "generated build identities", "generated imports", "owner data"],
        "no_device_query_or_test": True, "no_apk_or_deployment": True, "no_main_index_writes": True,
    }
    (HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(f"SUPER_WASH_REVIEW: {len(paths)} source/doc files; forward/reverse checks and fixture hashes pass")


if __name__ == "__main__":
    main()
