"""Create and byte-verify a task-only patch without using the main Git index.

Default final mode requires the report and three exact journal prefix files.
Use --sources-only for an early checkpoint. Only explicit component manifests,
before snapshots and small summary receipts are read; no repository scan occurs.
Generated manifests/checkpoint receipts/patches and binary captures are excluded.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import time

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
REL_EVIDENCE = EVIDENCE.relative_to(ROOT).as_posix()
GENERATED = {"game/core/build_identity.gd", "game/project.godot"}
JOURNALS = ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md")
REPORT = "docs/MOBILE_PERFORMANCE_IMPLEMENTATION_2026_11_06.md"
SUMMARIES = ("profile/summary.json", "android/validation.json", "android/native-preflight.json",
             "idle/implementation-receipt.json", "checkpoints/summary.json", "integrated-native.json", "source-normalization.json", "normalized-validation.json")
NAVIGATION_EXISTING = {
    "game/core/app.gd": "game/core/app.gd",
    "game/core/features/race.gd": "game/core/features/race.gd",
    "game/tests/test_race_loading.gd": "test_race_loading.gd",
    "game/tests/test_startup_shell_flow.gd": "test_startup_shell_flow.gd",
}
NAVIGATION_NEW = ("game/core/race_loading_flow.gd", "game/ui/feature_loading.gd",
                  "game/tests/test_feature_navigation.gd", "game/tests/profile_mobile_optimization_driving.gd")


def sha(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None


def relative(path):
    value = PurePosixPath(str(path).replace("\\", "/"))
    if value.is_absolute() or ".." in value.parts or ".git" in value.parts or ":" in str(value):
        raise ValueError(f"Unsafe manifest path: {path}")
    result = value.as_posix()
    if result in GENERATED:
        raise ValueError(f"Generated identity cannot enter task checkpoint: {result}")
    return result


def collect(sources_only):
    files = {}

    def add(path, component, before_path=None, before_expected=None, declared_after=None, before_bytes=None):
        path = relative(path)
        if path in files:
            raise ValueError(f"Duplicate owned path: {path}")
        target = ROOT / path
        if not target.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError(f"Manifest target escapes workspace: {path}")
        after = target.read_bytes()
        if before_path is not None:
            before_bytes = before_path.read_bytes()
            if before_expected is not None and sha(before_bytes) != before_expected:
                raise ValueError(f"Task-before snapshot hash mismatch: {path}")
        elif before_expected is not None:
            raise ValueError(f"Missing task-before snapshot: {path}")
        files[path] = {"component": component, "before_path": str(before_path.relative_to(ROOT)) if before_path else None,
                       "before": before_bytes, "after": after, "declared_after_sha256": declared_after}

    for component, name in (("profile", "component-changes.json"), ("android", "component-changes.json"), ("checkpoints", "changes.json")):
        for row in json.loads((EVIDENCE / component / name).read_text(encoding="utf-8")):
            old = EVIDENCE / component / "before" / row["path"] if row["before_sha256"] else None
            add(row["path"], component, old, row["before_sha256"], row["after_sha256"])
    idle = json.loads((EVIDENCE / "idle/implementation-receipt.json").read_text(encoding="utf-8"))
    for path, declared in idle["files_sha256"].items():
        old = EVIDENCE / "idle/before" / path
        add(path, "idle", old if old.is_file() else None, declared_after=declared)
    for path, old in NAVIGATION_EXISTING.items():
        add(path, "navigation", EVIDENCE / "navigation/before" / old)
    for path in NAVIGATION_NEW:
        add(path, "navigation")
    for summary in SUMMARIES:
        path = EVIDENCE / summary
        if path.stat().st_size > 128 * 1024:
            raise ValueError(f"Summary unexpectedly large; review explicitly: {summary}")
        add(path.relative_to(ROOT), "summary")
    add(Path(__file__).resolve().relative_to(ROOT), "checkpoint-tool")
    if not sources_only:
        add(REPORT, "report")
        for journal in JOURNALS:
            prefix_path = EVIDENCE / "journal-prefixes" / journal
            prefix = prefix_path.read_bytes()
            current = (ROOT / journal).read_bytes()
            if len(prefix) < 32 or not prefix.endswith(b"\n") or not current.startswith(prefix) or current.count(prefix) != 1:
                raise ValueError(f"Journal must start with exactly the supplied prefix: {journal}")
            if not prefix.startswith(b"<!-- ") or b"<!-- /" not in prefix:
                raise ValueError(f"Journal prefix must be a complete marked task block: {journal}")
            add(journal, "journal-prefix", before_bytes=current[len(prefix):])
            files[journal]["prefix_path"] = prefix_path.relative_to(ROOT).as_posix()
            files[journal]["prefix_sha256"] = sha(prefix)
    return files


def manifest(files, sources_only):
    return {"scope": "sources-only" if sources_only else "final-with-report-and-journal-prefixes",
            "files": [{"path": path, "component": row["component"], "before_path": row["before_path"],
                       "before_sha256": sha(row["before"]), "after_sha256": sha(row["after"]),
                       "before_bytes": len(row["before"]) if row["before"] is not None else None,
                       "after_bytes": len(row["after"]), "declared_after_sha256": row["declared_after_sha256"],
                       "prefix_path": row.get("prefix_path"), "prefix_sha256": row.get("prefix_sha256")}
                      for path, row in sorted(files.items())],
            "excluded": [*sorted(GENERATED), "main Git index/history", "PNG/binary captures", "raw logs and full per-run source inventories",
                         "generated source-manifest/checkpoint receipts/patch outputs"],
            "changed_since_component_receipt": [path for path, row in files.items()
                                                if row["declared_after_sha256"] and row["declared_after_sha256"] != sha(row["after"])]}


def write_files(directory, files, phase):
    for path, row in files.items():
        content = row[phase]
        if content is not None:
            target = directory / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)


def compare_files(directory, files, phase):
    mismatches = []
    for path, row in files.items():
        target = directory / path
        actual = target.read_bytes() if target.is_file() else None
        if actual != row[phase]:
            mismatches.append(path)
    if mismatches:
        raise ValueError(f"{phase} byte comparison failed: {mismatches}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources-only", action="store_true")
    parser.add_argument("--preview", action="store_true", help="Write the bounded manifest without producing a patch")
    parser.add_argument("--name", default="task", help="Output basename; use another name to retain earlier attempts")
    args = parser.parse_args()
    if not args.name or not all(character.isalnum() or character in "-_" for character in args.name):
        raise ValueError("Output basename may contain only letters, numbers, hyphens and underscores")
    index = ROOT / ".git/index"
    index_before = sha(index.read_bytes()) if index.is_file() else None
    result = {"name": args.name, "sources_only": args.sources_only, "main_index_used": False,
              "main_index_before_sha256": index_before, "success": False}
    commands = []
    receipt = EVIDENCE / f"{args.name}-checkpoint.json"
    code = 1
    try:
        files = collect(args.sources_only)
        listing = manifest(files, args.sources_only)
        manifest_path = EVIDENCE / f"{args.name}-manifest.json"
        manifest_path.write_text(json.dumps(listing, indent=2) + "\n", encoding="utf-8", newline="\n")
        result.update(files=len(files), manifest=str(manifest_path), manifest_sha256=sha(manifest_path.read_bytes()),
                      changed_since_component_receipt=listing["changed_since_component_receipt"])
        if args.preview:
            result.update(success=True, preview=True)
            code = 0
        else:
            owned = ROOT / "build/mobile-performance-implementation-20261106" / f"checkpoint-{time.time_ns()}"
            owned.mkdir(parents=True)
            if not owned.resolve().is_relative_to((ROOT / "build").resolve()):
                raise ValueError("Private checkpoint directory escaped the owned build area")
            environment = os.environ.copy()
            for key in list(environment):
                if key.startswith("GIT_"):
                    environment.pop(key)
            empty_config = owned / "empty-git-config"
            empty_config.write_bytes(b"")
            hooks = owned / "empty-hooks"
            hooks.mkdir()
            environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=str(empty_config), GIT_ATTR_NOSYSTEM="1")

            def git(directory, *arguments):
                command = ["git", "-c", "core.autocrlf=false", "-c", "core.safecrlf=false",
                           "-c", f"core.attributesFile={empty_config}",
                           "-c", "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol",
                           "-c", f"core.hooksPath={hooks}", "-c", "user.name=Task checkpoint",
                           "-c", "user.email=task-checkpoint@local.invalid", *arguments]
                completed = subprocess.run(command, cwd=directory, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                commands.append({"cwd": str(directory), "arguments": arguments, "exit_code": completed.returncode,
                                 "stderr": completed.stderr.decode("utf-8", errors="replace"),
                                 "failure_stdout": completed.stdout.decode("utf-8", errors="replace") if completed.returncode else ""})
                if completed.returncode:
                    raise RuntimeError(f"Private Git command failed: {arguments}: {commands[-1]['stderr']}{commands[-1]['failure_stdout']}")
                return completed.stdout

            author = owned / "author"
            author.mkdir()
            write_files(author, files, "before")
            git(author, "init", "--quiet")
            git(author, "add", "--force", "--all", "--", ".")
            git(author, "commit", "--quiet", "--no-gpg-sign", "-m", "Task-before snapshots only")
            write_files(author, files, "after")
            git(author, "add", "--force", "--all", "--", ".")
            patch = git(author, "diff", "--cached", "--binary", "--full-index", "--no-ext-diff", "--no-color")
            patch_path = EVIDENCE / f"{args.name}.patch"
            patch_path.write_bytes(patch)
            result.update(patch=str(patch_path), patch_sha256=sha(patch), patch_bytes=len(patch), private_repository=str(owned))
            git(author, "diff", "--cached", "--check")
            result["strict_whitespace"] = True
            validator = owned / "roundtrip"
            validator.mkdir()
            write_files(validator, files, "before")
            git(validator, "init", "--quiet")
            git(validator, "apply", "--check", "--whitespace=error-all", str(patch_path))
            git(validator, "apply", "--whitespace=error-all", str(patch_path))
            compare_files(validator, files, "after")
            result["forward_byte_exact"] = True
            git(validator, "apply", "--reverse", "--check", "--whitespace=error-all", str(patch_path))
            git(validator, "apply", "--reverse", "--whitespace=error-all", str(patch_path))
            compare_files(validator, files, "before")
            result["reverse_byte_exact"] = True
            compare_files(ROOT, files, "after")
            result["workspace_sources_unchanged_during_checkpoint"] = True
            result.update(success=True, line_endings="Original bytes retained; autocrlf disabled. CRLF is explicitly recognized by strict whitespace checks.")
            code = 0
    except Exception as error:
        result["error"] = f"{type(error).__name__}: {error}"
    finally:
        index_after = sha(index.read_bytes()) if index.is_file() else None
        result.update(main_index_after_sha256=index_after, main_index_unchanged=index_after == index_before, commands=commands)
        if index_after != index_before:
            result.update(success=False, error="Main index changed during checkpoint; verify concurrent activity.")
            code = 1
        receipt.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(json.dumps({key: value for key, value in result.items() if key != "commands"}, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
