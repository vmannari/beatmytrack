"""Record only the decoration/footer correction; preserve concurrent status work."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
EXISTING = ["game/ui/rivalry_award_art.gd", "game/ui/weekly_rivalry_finale.gd", "game/tests/test_rivalry_awards.gd",
    "docs/RIVALRY_AWARDS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
ADDED = ["game/assets/ui/awards/crown.svg", "game/assets/ui/awards/crown.svg.import",
    "game/assets/ui/awards/laurel_left.svg", "game/assets/ui/awards/laurel_left.svg.import", "docs/RIVALRY_AWARD_DECORATION.md"]


def main():
    chunks = []
    manifest = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "files": {}}
    for filename in EXISTING + ADDED:
        after = (ROOT / filename).read_text(encoding="utf-8")
        before = (EVIDENCE / "before" / filename.replace("/", "__")).read_text(encoding="utf-8") if filename in EXISTING else ""
        base = "saved pre-correction version"
        if filename in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
            entry = (EVIDENCE / "status-entry.txt").read_text(encoding="utf-8")
            if after.count(entry) != 1:
                raise RuntimeError("Expected one correction entry; refusing mixed checkpoint")
            before = after.replace(entry, "", 1)
            base = "current content minus this correction entry; concurrent entries preserved"
        if before == after:
            continue
        header = f"diff --git a/{filename} b/{filename}\n"
        if filename in ADDED:
            header += "new file mode 100644\n"
        chunks.append(header + "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
            fromfile="a/" + filename if before else "/dev/null", tofile="b/" + filename)))
        manifest["files"][filename] = {"base": base, "before_sha256_lf": hashlib.sha256(before.encode()).hexdigest(),
            "after_sha256_lf": hashlib.sha256(after.encode()).hexdigest()}
    (EVIDENCE / "scoped-change.patch").write_text("".join(chunks), encoding="utf-8", newline="\n")
    (EVIDENCE / "checkpoint.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Decoration-only checkpoint: {len(manifest['files'])} files")


if __name__ == "__main__":
    main()
