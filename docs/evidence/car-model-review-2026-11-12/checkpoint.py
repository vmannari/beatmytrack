"""Create a source-only review patch without changing Git's index."""
import difflib
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
paths = [ROOT / "docs/CAR_MODEL_REVIEW_2026_11_12.md"]
paths += [OUT / name for name in ["review.gd", "showroom.gd", "components.gd",
                                 "run.py", "summarise.py", "checkpoint.py"]]
patch = []
hashes = {}
for path in paths:
    relative = path.relative_to(ROOT).as_posix()
    content = path.read_text(encoding="utf-8").splitlines(keepends=True)
    patch += [f"diff --git a/{relative} b/{relative}\n", "new file mode 100644\n"]
    patch += list(difflib.unified_diff([], content, fromfile="/dev/null", tofile="b/" + relative))
    hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
(OUT / "review-source.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
(OUT / "source-checkpoint.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
print(f"Source-only checkpoint: {len(paths)} new files; main index untouched")
