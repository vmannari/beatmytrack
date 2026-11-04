# Backend publication repaired and Track#1 published

3 November 2026. The owner's instruction to fix the backend followed the [read-only diagnosis](TRACK_1_PUBLICATION_DIAGNOSIS_2026_11_03.md) and authorised this correction and rollout.

PBF01 removes the verification worker's direct authentication-table reads from new-track classification and development publishing-slot eligibility. PBF02 durably retries database errors during the final publication save, with all candidate track/proof/slot writes rolled back. PBF03 deploys the correction while preserving existing results and recovers the owner's original Track#1 request without another upload, test lap or purchase.

The restricted worker had reached the final publication transaction, then failed on `SELECT identities...`: its database role correctly denied access to that authentication table. The development slot simulator contained another identity lookup on the same worker path. Both are corrected. Migration **0073_publication_publisher_check** installs two Boolean-only functions, `bmt_is_official_publisher(text)` and `bmt_has_development_identity(text)`. Each is a stable SQL security definer with `search_path=pg_catalog` and a fixed, fully qualified identity-table reference. PUBLIC receives no execute permission; the reviewed policy grants execution only to the worker. Raw identity subjects and session credentials remain inaccessible to that role. API-side authentication queries retain their original authority and behavior.

The publication savepoint now catches SQLAlchemy errors and records the existing bounded `validator_unavailable` retry state. A database error after candidate writes rolls back the catalogue, creator proof, news and slot effects; the original operation and evidence survive. Lost database connectivity can still prevent a retry-state write until connectivity recovers; normal durable claim/lease recovery remains in place.

The live backend and its separate website preview now use matching patch images. Four runtime files are overlaid on their exact deployed parents; unrelated workspace/gameplay/vehicle changes are excluded. All ten existing API/Studio/worker/job definitions use the new main image, with the separate website preview retaining its own inherited website files. Resource limits, credentials, runtime settings and traffic destinations are retained. The competitive manifest is exactly unchanged, including rules23, physics0.77 and checkpoint layout24. No historical result was rescored, reset or deleted.

Managed Cloud SQL backup **1793737724395** succeeded before migration and promotion. Main image: `backend@sha256:e4caf9d0ac2887c9bb75253da2a9563fa6b46a7ff1d4120900c7f5e0d99a55bf`. Website preview: `backend@sha256:aec9e53a6001c531be3a615ac2c068442a927313512fbfd2a8c9c8dbecfd97af`.

Track#1's original request **e1045945-cad2-46c8-8b29-d296f39b81ab** had exhausted three infrastructure attempts without creating a track. Recovery used the same owner/entitlement locks and queue admission policy, resetting only that failed request. The corrected worker published it on the first recovered attempt as version **9056493c-e753-44c4-8e89-612ee4715a65**. Uploaded document and proof hashes match before/after exactly; there is one track, one verified creator proof and one publication-slot record. Owner publishing capacity moved **3 to 2**, with source `initial_or_paid`. The public version endpoint returns the published track.

| Preserved inventory/result check | Before | After |
| --- | ---: | ---: |
| Boards | 469 | 470 |
| Personal bests | 7362 | 7362 |
| Lap personal bests | 7365 | 7365 |
| Runs | 20560 | 20561 |
| Rivalry groups | 35 | 35 |
| Rivalry members | 416 | 416 |
| Rivalry bests | 849 | 849 |
| Track versions | 434 | 435 |
| Publication-slot records | 117 | 118 |

The added board, run, version and slot record belong to the successful publication. These are aggregate checks rather than a byte-level export/comparison of private historical rows. No migration statement modifies those result tables. Final health reports **ready, one available worker, queue depth zero**. API/Studio readiness and private-listener checks pass; temporary rollout tags and the release lock are removed, and retained release receipts/default images are aligned.

Actual verification:

- Local SQLite publication selection: **14 passed, 2 skipped, 17 deselected**. The two SQLite concurrency skips are covered on PostgreSQL in the exact-image runs.
- Exact Linux main image: **86 passed, 4 skipped**. Exact website-preview image: **86 passed, 4 skipped**. Both include six real restricted-worker cases covering ordinary development creators, the official developer, Google subjects named `developer`, and development simulation on/off. Existing PostgreSQL role/privilege drift, publication idempotency, slot atomicity, owner fences, request retention, news and background scheduling checks pass. The injected real PostgreSQL commit error rolls back all effects and publishes once on retry with unchanged evidence.
- The same six worker cases with the original publication source produce **six expected permission failures**, directly reproducing the defect. The two remaining optional skips per exact-image suite require an older, unrelated privilege-checker snapshot; the new publication control ran in full.
- Both native Linux manifests compare equal to the pre-deployment manifest. Scoped Ruff, Python compilation, whitespace and task-only patch forward/reverse checks pass.
- Live additive migration confirms `bmt_worker` has no identity-column SELECT permission and can execute the official-publisher helper. Successful publication exercises the actual worker and preserved creator proof.

Initial harness and rollout findings remain explicit. A local invocation first used the wrong Python import root, and an unrestricted local parameterized run encountered the existing configured PostgreSQL endpoint errors and was stopped. The owned-container test run initially mounted tests too shallow for repository-relative fixture paths: **60 passed, 4 skipped, 26 fixture errors**. Correcting the mount produced the final clean selections; assertions and privilege gates were not weakened. The first canary-before-migration rollout attempt was interrupted after identifying the API's retained `/ready` startup dependency on the new schema, before promoting traffic. Migration and worker replacement then ran before starting the replacement services. The startup probe remained unchanged. Existing Cloud CLI/WSL sandbox restrictions required approved escalation; TLS verification used the existing Windows trust bundle, and credential values were not printed.

Changed runtime sources: `backend/bmt_backend/publications.py`, `commerce.py`, `database_privileges.py`, and `migrations/versions/0073_publication_publisher_check.py`. Regression sources: `backend/tests/test_publication_worker_privileges.py` and `test_publication_intents.py`. Supporting documentation and [evidence](evidence/publication-backend-fix-2026-11-03/) contain source snapshots/hashes, tests, original control, sanitized backup/recovery/acceptance receipts, rollout source and a checked task-only patch. A concurrent owner checkpoint captured intermediate task edits; the task uses separate before/after snapshots and never stages or writes the main Git index.

Actual commands included:

```text
# From backend/:
..\.tools\backend-secure-venv\Scripts\python.exe -m pytest tests/test_publication_intents.py -q -k sqlite --tb=short --show-capture=no

# From the repository root, using .tools/backend-secure-venv/Scripts/python.exe:
build/publication-backend-fix-2026-11-03/deploy.py inspect
build/publication-backend-fix-2026-11-03/deploy.py prepare
build/publication-backend-fix-2026-11-03/deploy.py build
build/publication-backend-fix-2026-11-03/deploy.py test
build/publication-backend-fix-2026-11-03/deploy.py push
build/publication-backend-fix-2026-11-03/deploy.py backup
build/publication-backend-fix-2026-11-03/deploy.py rollout
build/publication-backend-fix-2026-11-03/deploy.py recover
build/publication-backend-fix-2026-11-03/deploy.py verify
```

No phone query/test, APK/export/install, real purchase, local owner-save modification, owner-game restart or local PC-backend replacement was performed. The owner's app still held its earlier failed status at the final read-only inspection. **Tap Retry once to retrieve the existing successful request**; the backend's retry endpoint returns its published receipt without creating another publication or consuming another slot. Owner UI/device acceptance remains.
