"""Create a source/docs review patch from this slice's saved starting files."""
import difflib
import hashlib
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
files = {}
for name in ("backend/bmt_backend/config.py", "backend/bmt_backend/storage.py", "backend/deploy/object_archive.py",
             "backend/README.md", "backend/deploy/README.md", "backend/deploy/.env.example",
             "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    files[name] = evidence / ("before-" + name.replace("/", "__"))
for name in ("backend/bmt_backend/gcs_storage.py", "backend/bmt_backend/cloud_setup.py", "backend/bmt_backend/cloud_smoke.py",
             "backend/deploy/gcp/staging.py", "backend/deploy/gcp/README.md", "backend/tests/test_gcs_storage.py",
             "backend/tests/test_gcp_staging.py", "backend/tests/test_cloud_setup.py", "docs/BACKEND_GCS_STAGING_2026_10_05.md",
             "docs/evidence/backend-gcs-staging-2026-10-05/README.md",
             "docs/evidence/backend-gcs-staging-2026-10-05/checkpoint.py"):
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
