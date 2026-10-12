"""Create a slice-only review patch from captured task baselines, without staging."""
import difflib
import hashlib
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
files = {}
for name in ("worker.py", "operations.py", "observability.py", "config.py", "verifier.py", "track_validation.py"):
    files["backend/bmt_backend/" + name] = evidence / ("before-" + name)
files["backend/tests/test_verifier.py"] = evidence / "before-test_verifier.py"
for name in ("backend/README.md", "backend/deploy/README.md", "backend/deploy/compose.yaml",
             "backend/deploy/compose.pc.yaml", "backend/deploy/.env.example", "DEVELOPMENT_STATUS.md",
             "docs/PHASE_0_PLAN.md"):
    files[name] = evidence / ("before-" + name.replace("/", "__"))
for name in ("backend/bmt_backend/worker_lifecycle.py", "backend/tests/test_worker_lifecycle.py",
             "backend/tests/worker_signal_probe.py", "docs/BACKEND_WORKER_LIFECYCLE_2026_10_05.md",
             "docs/evidence/backend-worker-lifecycle-2026-10-05/README.md",
             "docs/evidence/backend-worker-lifecycle-2026-10-05/checkpoint.py"):
    files[name] = None
patch, hashes = [], {}
for name, baseline in files.items():
    old = baseline.read_bytes() if baseline else b""
    new = (root / name).read_bytes()
    hashes[name] = {"before": hashlib.sha256(old).hexdigest() if baseline else None,
                   "after": hashlib.sha256(new).hexdigest()}
    patch.extend(difflib.unified_diff(old.decode("utf-8").splitlines(keepends=True),
        new.decode("utf-8").splitlines(keepends=True),
        fromfile="a/" + name if baseline else "/dev/null", tofile="b/" + name))
(evidence / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="")
(evidence / "source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
