# Studio staging deployment, 2026-10-11

The owner explicitly authorized deployment with **“deploy”** after reviewing the
Studio implementation and resolving its population/slot/ad-free choices.
The existing retained development backend now serves the new
[Studio](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#players).
Rollout completed at **15:29 Europe/Helsinki / 12:29 UTC** on 2026-10-11.

Requirements: **BMT-003, BMT-014, BMT-019, BMT-020, BMT-030, BMT-034,
BMT-050–052, BMT-075, BMT-085, BMT-100–104; PUR01/PUR04/PUR05; B05/B07/Q01**.
Deployment verifies the available Studio slice; it does not complete the missing
telemetry/provider/privacy/staff/experiment services in the requirements map.

## Deployed scope and preservation

The image is a frozen overlay on the actual prior retained image, rather than a
full rebuild of the dirty workspace. Exactly nine packaged files change:
`admin.py`, new `studio.py`, surgical `app.py` import/router registration and
`admin_ui/{index.html,app.js,style.css,studio.js,support.js,commerce.js}`.
The build proves **all 114 packaged game files and 96 other backend files are
unchanged**. Commerce, canonical handling/trajectory verification, schema and
existing rules/track/car contracts remain intact.

- Previous image digest: `d16a4a17e3cb64db4d1d654c818f2076a3b633399ede76a19f75d563987d872d`.
- Deployed digest: `8146e3af2c3b61fc1b6053d4827cb668925334c4203f2563d1428217bd677d89`.
- API revision: `bmt-stg-e7a444ab-api-00028-yak`, serving **100%** normal traffic.
- Schema remains `0023_operational_read_indexes`; the local unrelated schema0024
  work was not bundled or migrated.
- Fresh Cloud SQL backup **1791720921148** succeeded before any rollout.

Ownership/deletion protection were checked before deployment. API, worker,
migration/smoke jobs and the existing catalog job all reference the same new
digest. Runtime templates, secrets, service accounts, networking, CPU/memory,
scaling, probes, command/arguments and ownership labels are preserved. Cloud
Run's generated revision nonce, CLI metadata and job update timestamp are
recorded separately from configuration. No migration or catalog job was executed.

The API was first deployed as a zero-percent canary, with its original concrete
serving revision/percentage retained. Read-only acceptance passed before the
specific new revision was promoted. The temporary canary tag was removed after
final checks. Previous traffic, images and private configuration snapshots are
retained for rollback. No accounts/tracks/scores were reset, reseeded or pruned.

## Actual commands and outcomes

All actions used `.tools/backend-venv/Scripts/python.exe` and the owner-fenced
`.tools/backend_studio_rollout_20261011.py` helper. The generic updater and old
rollout scripts were not executed. Stages:

| Actual command/check | Outcome |
|---|---|
| `... backend_studio_rollout_20261011.py inspect` | Actual live resources match the prior retained digest; owner labels and SQL protection valid, schema0023, 395 players. |
| `... backend_studio_rollout_20261011.py prepare / build` | Frozen eight source copies plus two surgical app registration lines. Compile/import and unchanged-file proof pass; image uploaded by digest. [Proof](evidence/backend-studio-deploy-2026-10-11/packaged-proof.json). |
| `... .tools/backend_studio_image_tests_20261011.py` | **47 passed, 2 skipped, 25 deselected**, 31.77s, against the exact candidate with networking disabled and existing schema0023. Two skips are SQLite row-lock cases; PG was excluded here after the policy slice's real PG72-pass run. Existing Starlette/httpx warning plus three marker-registration warnings from the isolated test mount. [Log](evidence/backend-studio-deploy-2026-10-11/exact-image-tests.log). |
| `... backend_studio_rollout_20261011.py backup` | Successful fresh backup1791720921148. This is not a rehearsed-restore claim. |
| `... backend_studio_rollout_20261011.py canary / verify-canary` | Original normal traffic preserved. Ready/schema, all six exact UI asset bytes, inclusive population, stored player flags and race bundle/checksum/accepted pinned timing pass. |
| `... backend_studio_rollout_20261011.py promote / resources` | Specific canary revision promoted to100%; worker and three existing job image references updated. Image-only updates preserve runtime configuration and secret bindings. |
| `... backend_studio_rollout_20261011.py verify-live` | Normal URL passes the same checks: **395 total = 4 real + 391 artificial**, all flag values actual booleans, both classes readable in support, schema23 unchanged, six asset hashes exact and verified race evidence attachment/checksum valid. [Receipt](evidence/backend-studio-deploy-2026-10-11/verify-live.json). Counts are observed snapshots, not permanent expected population values. |
| `... .tools/backend_studio_live_browser_20261011.py` | **4 live browser checks**, zero JavaScript exceptions or administrative writes; coverage/Player type/accepted five-lap record/Lock work. Existing configured owner credential used solely for reads; no analyst credential was added. [Receipt](evidence/backend-studio-deploy-2026-10-11/live-browser.json). |
| `... backend_studio_rollout_20261011.py smoke` | Existing native fixture, storage and schema acceptance job succeeds; competition health **ready, one available worker**. This is explicit offline deployment diagnostics, not a replay fallback for race acceptance. |
| `... backend_studio_rollout_20261011.py finish` | All target digests/configuration guards pass,100% serving revision confirmed, temporary canary tag removed and retained local deployment receipts updated. [Rollout](evidence/backend-studio-deploy-2026-10-11/rollout.json). |

The build proof initially omitted its explicit `/app` import path; corrected
before rollout. Canary configuration comparison caught a generated nonce and
job comparison caught `run.googleapis.com/lastUpdatedTime`; only those observed
non-runtime metadata fields were normalized, with all runtime/ownership guards
retained. An inline diagnostic command had a quoting error and was replaced by
a saved script. The live configuration has an owner credential without an
analyst binding; acceptance uses that existing role without changing access
policy. No assertion or product invariant was removed to deploy.

## Evidence and limits

Live screenshots inspected: [coverage](evidence/backend-studio-deploy-2026-10-11/live-coverage.png)
and [Players with identities masked](evidence/backend-studio-deploy-2026-10-11/live-players-redacted.png).
Names and IDs are masked only for the saved screenshot; the shipped administrative
UI retains its authorized real records. Published receipts contain aggregate
counts/assertions, not credentials, identity subjects or player IDs. Runtime
configuration snapshots and diagnostic command failures remain private under
ignored `build/`; temporary Docker authentication files were removed.

The initial free slot and UTC calendar-month policy already existed in the
deployed commerce code and were preserved. The Studio source flag is now live;
all accounts remain included. Public/artificial competition isolation, optional
ghosts, five ordinary laps, authorized resume receipts, normal results first,
best-only scoring and durable/idempotent uploads are preserved through unchanged
game/domain files. No live purchase, grant, rating, publication or race-submission
command was executed during acceptance.

Changed delivery records: this report, Studio inventory/evidence map,
`BACKEND_UI.md`, the two earlier Studio reports, status/phase records and the
dated evidence/checkpoint directory. The implementation commits/patches retain
their original local-test history; deployment evidence is separate.

No physical-device test, Android export/install or phone attachment check was
performed. No real Google login/payment/ad-provider flow, load soak, restore
rehearsal or broad production acceptance is claimed. Owner review, narrow-device
and200% zoom acceptance and the documented missing services remain open. Any
later deployment beyond this existing staging target requires its own scope.
