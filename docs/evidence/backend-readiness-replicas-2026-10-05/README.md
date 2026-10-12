# Readiness and replica checkpoint evidence

See [requirements, behavior, actual commands and limitations](../../BACKEND_READINESS_REPLICAS_2026_10_05.md).

- `regression.xml`: affected regression batch, 176 passed/6 skipped.
- `final-readiness.xml`: final readiness/auth batch, 50 passed.
- `readiness.xml`: earlier readiness batch, 15 passed; the storage-expiry case is included in the final batch.
- `replicas.xml`: initial full process matrix, 21 passed/3 skipped.
- `replicas-final-faults.xml`: strengthened stale/killed-worker, storage-stall and timeout checks, 7 passed/1 skipped.
- `concurrent-admission.xml`: forced simultaneous publication/admission, 1 passed/1 SQLite skip.
- `replicas-smoke.xml`: initial fixture failure retained; synthetic credential values redacted, validation failure preserved.
- `scoped-change.patch` and `source-hashes.json`: slice-only checkpoint against saved task baselines, preserving earlier dirty changes.
- `checkpoint.py`: recreates the patch/hashes from the retained task baselines; no Git index/staging changes.

Test batches overlap; do not sum them. Tests use disposable data, explicitly labeled identity/verifier doubles and private loopback processes. No live player credentials or records belong in this evidence. No presentation or device capture is part of this backend slice.
