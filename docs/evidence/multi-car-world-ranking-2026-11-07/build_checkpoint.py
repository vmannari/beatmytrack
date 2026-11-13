"""Create a task-only review patch without staging the shared working tree."""
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
BEFORE = EVIDENCE / "before"
MARKER = "MULTI-CAR-WORLD-RANKING-20261107"
sys.path.insert(0, str(ROOT / "scripts"))
from localization import parse_po
NEW = [
    "backend/bmt_backend/world_ranking_car_models.py",
    "backend/bmt_backend/world_ranking_car_rules.py",
    "backend/bmt_backend/world_ranking_cars.py",
    "backend/bmt_backend/world_ranking_car_reads.py",
    "backend/bmt_backend/migrations/versions/0076_multi_car_world_ranking.py",
    "backend/tests/test_world_ranking_cars.py",
    "game/tests/test_world_ranking_cars.gd",
    "scripts/translations/multi_car_world_ranking.json",
    "docs/schemas/world-ranking-v2.schema.json",
    "docs/MULTI_CAR_WORLD_RANKING_2026_11_07.md",
]


def read(path):
    return path.read_text(encoding="utf-8-sig")


def sha(value):
    return hashlib.sha256(value).hexdigest()


def function(source, name):
    match = re.search(rf"^func {name}\(.*?(?=^(?:static )?func |\Z)", source, re.M | re.S)
    assert match, name
    return match.group()


def catalogue_base(original, current):
    """Keep additional concurrent entries at their current source-order position."""
    old_entries, new_entries = parse_po(original), parse_po(current)
    changes = json.loads((EVIDENCE / "task-messages.json").read_text(encoding="utf-8"))
    owned = {tuple(key) for key in changes["new"]}
    extra = set(new_entries) - set(old_entries) - owned
    old_blocks = original.rstrip().split("\n\n")
    blocks = current.rstrip().split("\n\n")
    def key(block):
        entries = parse_po(block)
        return next(iter(entries)) if entries else None
    for index, block in enumerate(blocks):
        if key(block) not in extra:
            continue
        following = [key(candidate) for candidate in blocks[index + 1:]]
        anchor = next((candidate for candidate in following if candidate in old_entries), None)
        position = next((i for i, candidate in enumerate(old_blocks) if key(candidate) == anchor), len(old_blocks))
        old_blocks.insert(position, block)
    return "\n\n".join(old_blocks) + "\n"


def main():
    scratch = ROOT / "build/multi-car-ranking-review-base"
    scratch.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "--quiet", str(scratch)], check=True)
    files = {}
    for path in BEFORE.rglob("*"):
        if path.is_file():
            name = path.relative_to(BEFORE).as_posix()
            files[name] = read(path)
    for name in NEW:
        assert name not in files
        files[name] = ""
    patch, manifest = [], []
    for name, original in sorted(files.items()):
        path = ROOT / name
        current = read(path)
        scope = "task file"
        if name in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
            pattern = rf"<!-- {MARKER} -->.*?<!-- /{MARKER} -->\n\n"
            original, count = re.subn(pattern, "", current, flags=re.S)
            assert count == 1
            scope = "only task marker; all concurrent tracker entries retained"
        elif name == "game/core/app.gd":
            original = current.replace(function(current, "_open_world_circuit"),
                                       function(original, "_open_world_circuit"), 1)
            scope = "only _open_world_circuit; concurrent header-capture changes excluded"
        elif name == "backend/bmt_backend/app.py":
            original = current.replace('"world_ranking_version": 2,', '"world_ranking_version": 1,', 1)
            scope = "only capability version; prior bootstrap work retained"
        elif name.startswith("game/localization/"):
            original = catalogue_base(original, current)
            scope = "only ranking messages; concurrent car-quality copy retained"
        if original == current:
            continue
        if original:
            base = scratch / name
            base.parent.mkdir(parents=True, exist_ok=True)
            base.write_text(original, encoding="utf-8", newline="\n")
        patch.append(f"diff --git a/{name} b/{name}\n")
        if not original:
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(original.splitlines(keepends=True), current.splitlines(keepends=True),
                     fromfile=f"a/{name}" if original else "/dev/null", tofile=f"b/{name}"))
        manifest.append({"path": name, "scope": scope, "before_normalized_sha256": sha(original.encode()),
                         "after_normalized_sha256": sha(current.encode()), "after_raw_sha256": sha(path.read_bytes())})
    patch_path = EVIDENCE / "task.patch"
    patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
    commands = [
        ["git", "-C", str(scratch), "apply", "--check", str(patch_path)],
        ["git", "-C", str(ROOT), "apply", "--reverse", "--check", str(patch_path)],
        ["git", "-C", str(ROOT), "apply", "--check", "--reverse", "--whitespace=error", str(patch_path)],
    ]
    results = []
    for command in commands:
        result = subprocess.run(command, capture_output=True, text=True)
        results.append({"command": command, "exit_code": result.returncode,
                        "stdout": result.stdout, "stderr": result.stderr})
    report = {"files": manifest, "patch_sha256": sha(patch_path.read_bytes()), "checks": results,
              "note": "Read-only apply checks. Scratch repository has no staged files or commits. Main index untouched."}
    (EVIDENCE / "source-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(manifest), "checks": [r["exit_code"] for r in results],
                      "patch_bytes": patch_path.stat().st_size}))
    if any(r["exit_code"] for r in results):
        for result in results:
            if result["exit_code"]:
                print(result["stderr"])
        raise SystemExit(1)


if __name__ == "__main__":
    main()
