# GCS/staging checkpoint evidence

See [requirements, changed files, actual commands/outcomes and acceptance limits](../../BACKEND_GCS_STAGING_2026_10_05.md).

- `providers.xml`: 25 passed/one intentionally unconfigured live GCS skip.
- `staging.xml`: initial offline orchestration batch, 19 passed.
- `cloud-tests.xml`: earlier combined batch, one golden-format smoke failure later corrected; failure retained.
- `regression.xml`: final affected batch, 98 passed/three skips, including corrected native Windows smoke and ownership/grants.
- `linux-smoke.xml`: packaged Linux staging smoke passed; real native engine/SQL with an isolated storage transport, not Google Cloud.
- `staging-plan.json`, `cleanup-plan.json`: actual target's reviewable UTF-8 previews. No secrets, tokens or cloud calls.
- `scoped-change.patch`, `source-hashes.json`, `checkpoint.py`: slice-only review checkpoint against saved task baselines, preserving earlier dirty work.

Batches overlap. Live GCS/Cloud Run/Cloud SQL acceptance is explicitly unperformed without CLI/ADC and pricing review. No live player data/credentials or cloud resources belong to this evidence. The ignored local staging config has a short proposed lease; refresh it before a later applied session.
