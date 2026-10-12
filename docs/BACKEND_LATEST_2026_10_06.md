# Latest retained backend deployment — 2026-10-06

Requirements B01–B07/B19/B20/B23/R01/T01–T04/Q01. The owner authorized deploying the latest backend after Blind spot rejected the online race contract. The existing retained staging service in `beat-my-track`, `europe-west1`, now runs **creator-compiler-22** at the existing URL. API, worker, migration, smoke and catalog job templates use the same immutable image:

`europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:8ac5ad340faed6ea17b3ccb15e902d6a575a54b93c363e0770e566e26078c5ba`

Pinned engine remains `4.7.2.stable.official.ed1daf0bf`; physics remains `arcade-planar-0.50`, lap rules `standing-5-road-gates-v18`, five laps. Auth audiences, existing Google account/session secrets, development isolation, warm API minimum 1/maximum 2, worker count 1, database/storage settings and retention protection were preserved. No production deployment or Android export occurred.

## Actual rollout and retained data

Both owned compiler-20 artificial-driver schedulers were paused after checking their PID/command identity. The outstanding verification queue drained before the first switch. Fresh Cloud SQL backups succeeded before both deployment stages; the final pre-compiler-22 backup is `1791309553076`. Matching owned schema migrations completed before worker/API updates. Existing schema and player rows were preserved.

The first compiler-21 rollout passed cloud native/storage/schema/worker smoke and added current immutable revisions. During that rollout, concurrent editor work advanced the shared source and golden contracts to compiler 22. Native acceptance correctly rejected the mismatch. The second build and backed-up rollout now match compiler 22; the intermediate compiler-21 revisions were retained too. The general disposable staging script's changed-image refusal was not weakened. The owner explicitly authorized this retained update, performed through scoped ignored operator helpers with ownership checks.

All 27 official logical tracks received current immutable heads using the deployed native validator; original document hashes, titles, attribution and logical IDs remain unchanged. Prior manifests/links/boards were not rewritten. Public verification checked **87 historical links**, including all 34 original source revisions and the intermediate compiler-21 heads; stored source/intermediate manifests were compared where available. Old PBs, ratings and artificial-driver results remain attached to their original immutable contracts. They are not copied into new compiler-22 boards.

## Checks actually run

- Final compiler-22 image build checks the exact Linux engine, imports the packaged verifier and runs the existing 12,757-tick, five-lap oval replay with its complete golden manifest/lap assertions.
- `pytest backend/tests/test_catalog_transfer.py backend/tests/test_gcp_staging.py backend/tests/test_verifier.py backend/tests/test_test_drivers.py -q`: final compiler-22 **113 passed**. Includes real packaged native/spline proofs and HTTP refresh/idempotency.
- Domain batch: `pytest` over auth, domains, rivalry, track lifecycle, readiness, worker lifecycle, scalability, GCS and exception recovery with `-k 'not postgres'`: corrected source **157 passed / 8 skipped / 82 deselected**. This completed before the concurrent compiler-22 advance. Final compiler-22 native practice/publication recheck: **1 passed / 49 deselected**. These are overlapping checks, not an additive count of unique final-build tests.
- Real cloud smoke: restricted PostgreSQL role/schema; real native 12,757-tick replay; immutable GCS put/get/list/delete in the diagnostic prefix; HTTPS health/readiness/bootstrap; matching compiler-22 available worker. Credential-free operation results are in `cloud-job-results.json`.
- Real pinned Windows client through `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_retained_cloud_catalog.gd`: **196 checks / zero failures / 27 tracks**. Normal pagination, document hashes, compilation, geometry hashes, compiler/physics/rules and the original Blind spot online-ticket path pass. An existing development observer was used in isolated storage; no owner Google session was read, no race/PB/reward/membership was submitted, and the observer logged out. The private key was passed only through the child process environment and was not installed in the game or committed.
- Scoped whitespace and patch reverse checks are recorded with the checkpoint. No visible menu/style change was made by this deployment, so no new UI screenshot was required.

Exact operator actions from the repository root used `.tools/backend-venv/Scripts/python.exe .tools/gcp-staging/deploy-latest.py`: `inspect`, `build`, `backup`, `queue`, `migrate`, `deploy`, `catalog-check`, `catalog-apply`, `smoke`, then repeated inspection/build for the concurrent compiler change and `final-rollout` (fresh backup → migration → worker/API/jobs → catalog validation → immutable revisions → smoke → evidence → native acceptance). `.tools/gcp-staging/verify-latest.py` performs public integrity and isolated native acceptance. Existing private config/trust files were reused; no credentials are in the public evidence.

## Failures corrected and files

The initial sandbox-only native tests failed and were interrupted; the elevated gate was rerun. The stale local PostgreSQL test configuration points to an unavailable server: the first combined batch reported 129 passes, one client-fixture failure, two skips and 14 PostgreSQL connection errors. A broader initial run was interrupted after the same unavailable database was identified. Local PostgreSQL/concurrency acceptance is not claimed.

The strict client refresh peer returned a track ID without the required version ID. The test peer now supplies both; refresh, mutation-key and redirect assertions remain intact. Real practice publication also reproduced a typed-array initialization error in `RoadKerbs.creator_segments` for ordinary road pieces. Explicit typed initialization plus append repaired it; the native practice/publication/replay check passes. A first image was built before that repair and was not deployed; the rebuilt compiler-21 image was the intermediate rollout.

Operator-helper Windows output decoding and receipt bookkeeping were corrected. The first public-check helper incorrectly expected manifests in discovery summaries; it now reads immutable version details. The first native post-deployment acceptance exposed the concurrent compiler-22 advance rather than bypassing the hash assertion; the final rollout matches it. No invariant was removed to make checks green.

Own source changes: `game/track/road_kerbs.gd` typed initialization; `backend/tests/test_verifier.py` complete HTTP peer response; `game/tests/test_retained_cloud_catalog.gd` explicit compiler checks and opt-in isolated ticket acceptance. Documentation: this report, development/phase status, GCP runbook and the evidence/scoped patch. Deployment helpers, credentials/config and applied operator receipts stay ignored under `.tools/gcp-staging`. Concurrent source/editor changes were included in the final requested image and preserved in the working tree; they are excluded from this task's scoped patch.

## Remaining acceptance

Restart the desktop game or reopen Race to refresh the catalog. Running processes keep the scripts loaded when they started. Older game builds and old share-link contracts may still need their corresponding verifier build.

The two compiler-20 artificial-driver population plans remain **paused**. Their files, inputs, histories and verified results were preserved. Continuing the 200-per-track population requires new compiler-22 contract plans and recordings; old inputs/times were not relabeled. New Weekly Rivalry build keys may form separate groups; historical membership/standings remain stored.

No phone attachment check, physical-device test, Android export/install, full `Validate`, production/NAS deployment, restore test, load/capacity test or score/rating migration was performed. Physical-device racing and the owner's interactive Google online race remain acceptance items. This remains retained staging with its existing billing; no worker count or API resource limit was increased.
