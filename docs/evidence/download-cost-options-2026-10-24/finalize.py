"""Validate this analysis and retain its task-only checkpoint."""
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DOC = ROOT / "docs/DOWNLOAD_AND_COST_OPTIMISATION_2026_10_24.md"


def main():
    commands = []
    for arguments in (("-m", "ruff", "check", str(HERE)), ("-m", "compileall", "-q", str(HERE)),
                      ("-X", "utf8", str(HERE / "audit.py"))):
        run = subprocess.run([sys.executable, *arguments], cwd=ROOT, capture_output=True,
                             text=True, encoding="utf-8", check=False)
        commands.append({"command": [sys.executable, *arguments], "exit_code": run.returncode,
                         "stdout": run.stdout, "stderr": run.stderr})
        if run.returncode:
            raise RuntimeError(commands[-1])
    evidence = json.loads((HERE / "report.json").read_text(encoding="utf-8"))
    assert evidence["arithmetic"]["two_object_writes_per_race_operations_month"] == 600000000
    assert 2639 < evidence["arithmetic"]["two_object_writes_per_race_eur_month"] < 2640
    assert 20 < evidence["arithmetic"]["ideal_128_records_per_pack_put_eur_month"] < 21
    expected = {"validation.json", "scoped-change.patch"}
    count = 0
    for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", DOC.read_text(encoding="utf-8")):
        if link.startswith(("https://", "http://", "#")):
            continue
        target = DOC.parent / link.split("#")[0]
        assert target.is_file() or (target.parent.resolve() == HERE and target.name in expected), link
        count += 1
    validation = {"date": "2026-10-24", "commands": commands,
                  "arithmetic_checks": "passed", "relative_links_checked": count,
                  "document_sha256": hashlib.sha256(DOC.read_bytes()).hexdigest(),
                  "runtime_tests": "Not run: analysis and evidence only; no runtime edits",
                  "device_tests": "No physical-device or phone/tablet attachment checks"}
    (HERE / "validation.json").write_text(json.dumps(validation, indent=2) + "\n", encoding="utf-8")
    paths = [DOC, *sorted(p for p in HERE.iterdir() if p.is_file() and p.name != "scoped-change.patch")]
    patch = []
    for path in paths:
        name = path.relative_to(ROOT).as_posix()
        baseline = subprocess.run(["git", "show", "HEAD:" + name], cwd=ROOT, capture_output=True, check=False)
        before = baseline.stdout.decode("utf-8").splitlines(keepends=True) if baseline.returncode == 0 else []
        after = path.read_text(encoding="utf-8").splitlines(keepends=True)
        patch.append(f"diff --git a/{name} b/{name}\n")
        if baseline.returncode:
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(before, after, fromfile="/dev/null" if baseline.returncode else "a/" + name,
                                         tofile="b/" + name))
    (HERE / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    checked = subprocess.run(["git", "apply", "--reverse", "--check", "--", str(HERE / "scoped-change.patch")],
                             cwd=ROOT, capture_output=True, text=True, check=False)
    if checked.returncode:
        raise RuntimeError(checked.stderr)
    print(json.dumps({"lint_compilation_arithmetic": "passed", "relative_links": count,
                      "checkpoint_reverse_check": "passed", "checkpoint_files": len(paths)}))


if __name__ == "__main__":
    main()
