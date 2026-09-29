#!/usr/bin/env python3
"""Zero-dependency structural validator for the bmt-adaptive-music skill."""

from __future__ import annotations
import json
import re
import sys
from pathlib import Path

REQUIRED = [
    "SKILL.md",
    "references/project-direction.md",
    "references/music-craft.md",
    "references/iteration.md",
    "references/mrt2-wsl.md",
    "references/adaptive-delivery.md",
    "references/evidence.md",
    "assets/STATE.template.md",
    "assets/round.template.json",
    "assets/provenance.template.json",
    "scripts/review_pack.py",
    "scripts/validate_skill.py",
    "tests/test_skill.py",
    "tests/agent-evals.json",
]

def fail(msg: str):
    print("FAIL:", msg)
    return 1

def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    errors = 0

    for rel in REQUIRED:
        p = root / rel
        if not p.is_file():
            errors += fail(f"missing {rel}")

    skill = root / "SKILL.md"
    if skill.is_file():
        text = skill.read_text(encoding="utf-8")
        m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, flags=re.S)
        if not m:
            errors += fail("SKILL.md has no YAML-style front matter")
        else:
            fm = m.group(1)
            if not re.search(r"(?m)^name:\s*bmt-adaptive-music\s*$", fm):
                errors += fail("front matter name is missing/incorrect")
            if not re.search(r"(?m)^description:\s*.+$", fm):
                errors += fail("front matter description is missing")

        for ref in re.findall(r"\((references/[^)]+|assets/[^)]+|scripts/[^)]+)\)", text):
            if not (root / ref).exists():
                errors += fail(f"SKILL.md link target missing: {ref}")

    for rel in ["assets/round.template.json", "assets/provenance.template.json", "tests/agent-evals.json"]:
        p = root / rel
        if p.is_file():
            try:
                json.loads(p.read_text(encoding="utf-8"))
            except Exception as e:
                errors += fail(f"invalid JSON in {rel}: {e}")

    for rel in ["scripts/review_pack.py", "scripts/validate_skill.py", "tests/test_skill.py"]:
        p = root / rel
        if p.is_file():
            try:
                compile(p.read_text(encoding="utf-8"), str(p), "exec")
            except SyntaxError as e:
                errors += fail(f"syntax error in {rel}: {e}")

    if errors:
        print(f"\n{errors} validation problem(s).")
        return 1

    print("PASS: bmt-adaptive-music structure is complete and uses no validator dependencies.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
