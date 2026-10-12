# Worker lifecycle checkpoint evidence

See [requirements, behavior, exact commands and limitations](../../BACKEND_WORKER_LIFECYCLE_2026_10_05.md).

- `final-regression.xml`: final affected SQLite/PostgreSQL batch, 212 passed/12 skipped.
- `final-lifecycle.xml`: final lifecycle/verifier batch, 57 passed/4 skipped.
- `linux-signals.xml`: four real Linux signal/crash-recovery cases passed.
- `verifier.xml`: initial native batch, 57 passed/two obsolete injection-hook failures; corrected cases pass in `final-lifecycle.xml`.
- `focused.xml`, `regression.xml`, `postgres.xml`, `recovery.xml`: earlier focused/affected batches, overlapping the final batches. Their results are not additive.
- `scoped-change.patch` compares only this slice with its saved starting files, preserving earlier dirty changes in those files. Reverse validation uses `git apply --reverse --check`.
- `source-hashes.json` records starting and final SHA-256 hashes for the scoped source/docs files. `checkpoint.py` reproduces checkpoint creation from saved task baselines while they exist.

Tests used synthetic data and disposable databases/containers. No credentials, live player records or external cloud data belong in this evidence directory. No presentation change or device capture is part of this backend slice.
