# Approved backend follow-up, 2026-10-16

The owner replied **"approve both"** to the two previously blocked proposals.
Both are now applied on the retained staging service:
[Overview](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#overview), [Alarms](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#alarms).
Revision `bmt-stg-e7a444ab-api-00059-vov` serves100% normal traffic with one matching worker.

- **Catalog:** exactly27 compiler27/physics0.59 published revisions were appended
  to the27 recorded official heads. Read-only HTTP pagination[20, 8]
  finds all27 new heads; every old share link remains available, every original
  document hash matches, and all15 original-data fingerprints remain exact.
- **Storage:** the existing runtime gained only `storage.objects.delete` under
  `gs://bmt-stg-beat-my-track-e7a444ab/bmt/v1/`. The condition excludes the
  independent `bmt-erasure-v1/` journal; all existing bindings are preserved.
  A unique disposable ordinary object was created, read, deleted and confirmed
  absent with the real runtime identity. No player object or real account was deleted.
- **Deployment:** the already tested prepared image is now active, with API,
  worker and existing jobs on the same digest. Schema36 and all other guarded
  runtime settings remain unchanged. No additional source was frozen or packaged.

Image: `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:b40044ddb8c6195525cb88b7cdc6869ab460094b2bdfde7e813cc2f74bf9016b`.
CompletedUTC: `2026-10-16T16:25:08.934070+00:00`.
Fresh successful Cloud SQL backup: **1792166965569**.

Actual stages: `inspect`, `backup`, `preview`, `grant-delete`, `heads`,
`permission-probe`, `maintenance`, `snapshot`, `schema`, `check-program`,
`catalog`, `canary`, `promote`, `smoke`, `catalog-http`, `browser`, `finish`.
The catalog program fences the exact27 approved head IDs/identities/numbers/hashes
before its transaction. Maintenance uses retryable503 writes and pauses the sole
existing worker; original-data comparisons run before promotion. A zero-traffic
canary passed before promotion, then native replay/storage/schema smoke, a matching
worker,17 byte-exact deployed UI assets and6 read-only live Edge checks passed.
The prior233-pass/5-skip candidate suite tested this exact prepared image; it was
not rerun here. Temporary tags and the owned lock were removed and retained local
deployment/population receipts now point to the active image.

Initial failures are retained: new-role bucket binding briefly returnedHTTP400
while role creation propagated, then the identical scoped binding succeeded.
The first permission probe successfully removed its ordinary marker, but expected
403 from a nonexistent journal marker and received404. The corrected probe records
that response; **journal exclusion is proved by the verified IAM condition**, not
by treating a missing object as a permission denial. The journal probe's
`ifGenerationMatch=0` could not remove an existing object. Local quoting and
indentation preflight failures were corrected before cloud catalog execution.

[Machine report](evidence/backend-approved-followup-2026-10-16/report.json),
[rollout](evidence/backend-approved-followup-2026-10-16/rollout.json),
[catalog HTTP proof](evidence/backend-approved-followup-2026-10-16/catalog-live-http.json),
[runtime marker proof](evidence/backend-approved-followup-2026-10-16/runtime-delete-probe.json),
[before fingerprints](evidence/backend-approved-followup-2026-10-16/data-before.json),
[after fingerprints](evidence/backend-approved-followup-2026-10-16/data-after-catalog.json).
Captured helper/tool dependencies and task-only patch/checkpoint are alongside these.

The initial [deployment report](BACKEND_LATEST_DEPLOY_2026_10_16.md) remains a
historical record of the earlier safe rollout; its pending approvals are now
resolved. Clients require compiler27/physics0.59. Later concurrent local
physics0.60, earned-coin/news work and other game/backend changes remain separate;
historical pinned contracts were not rewritten. No phone check/test, APK export,
install, real-account erasure, live purchase/sign-in, load soak or restore rehearsal
was performed. Owner workflow acceptance remains.
