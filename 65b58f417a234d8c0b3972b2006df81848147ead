# Ghost-cache backend deployment — 26 October 2026

The owner-authorized ghost-download update is live on the existing [backend](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app). Revision `bmt-stg-e7a444ab-api-gc-45c6feb833f8` receives **100% of API traffic** in `beat-my-track` / `europe-west1`.

Bootstrap now advertises `ghost_identity_version=1` and `ghost_wire_version=1`. Matching clients can check a ghost's current run/hash without downloading its recording, reuse their persistent device cache, and request the compact lossless recording on a cache miss. Both Challenges and Weekly Rivalry check existing access rules before metadata, cached server bytes or conditional 304 replies. Original clients retain ordinary JSON downloads.

Restart/reload a client containing the existing cache implementation so it refreshes bootstrap capabilities. Its cache remains bounded at 64 recordings / 64 MiB and survives client restarts.

## Release scope and preservation

Requirements GCD01–GCD05 cover ghost protocol activation, authority/backward compatibility, preservation, exact release checks and managed rollout.

The release overlays six files on the exact live website/API image: `app.py`, `challenges.py`, `rivalry.py`, `ghost_http.py`, `ghost_wire.py` and `immutable_payloads.py`. The three existing files receive only startup/capability and recording-response changes. Existing ghost access/target selection statements remain unchanged; preparation checks their syntax trees. The other **273 existing package files**, **165 canonical-project files**, Linux engine and locked dependencies match the original image byte-for-byte. [Exact overlay](evidence/backend-ghost-cache-deploy-2026-10-26/deployed-overlay.patch), [image/package proof](evidence/backend-ghost-cache-deploy-2026-10-26/package-proof.json).

The image is `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/ghost-cache@sha256:607104e6c611d789ce2c0944787c7fa89a7d047ff2403ade5287416482e2f055`.

Schema remains `0062_retire_discovery_cache`. Worker, migration job, smoke job and private Studio specifications remain exact. Runtime credentials, identity, capacity, networking and retention settings remain unchanged. Homepage, privacy, account-deletion and community-rules response hashes match the original public pages. Packing, cold archival and the wider working-tree features are separate releases.

The generic retained updater's old receipt predates the independently deployed website and Studio images. Its mixed-image refusal was respected; this deployment uses a reviewed API-only overlay and preserves those releases. No working-tree backend files, client files or owner processes were modified/restarted.

## Actual acceptance

- Exact Linux image: **80 passed, 2 skipped, 46 deselected, 1 pre-existing failure**. The failure is `test_additive_attempt_migration_preserves_existing_challenges[sqlite]`, at the existing “Drain creator achievement events before downgrading 0054” guard. The same unchanged test fails with the identical message on the exact original live image. No assertion or migration was weakened. [Original suite](evidence/backend-ghost-cache-deploy-2026-10-26/exact-image-tests.log), [original-image control](evidence/backend-ghost-cache-deploy-2026-10-26/baseline-control.json).
- Actual pinned Godot client against the frozen release package over loopback HTTP: **21 checks, 0 failures**. Eleven successful accesses use one full download and ten cache hits; a fresh client reuses the disk cache and withdrawal rejects a warm cached recording. All data/accounts are synthetic. [Native results](evidence/backend-ghost-cache-deploy-2026-10-26/native-client.json).
- Managed Cloud SQL backup **1793034686720** completed successfully before the API canary. No player database was exported/copied locally and no migration ran.
- Canary passed health/readiness, exact existing bootstrap fields plus the two ghost capabilities, missing-ghost handling and public-page comparisons while the old revision retained 100% normal traffic. Promotion then passed the same checks on the ordinary public URL; the temporary tag was removed.
- Final read-only verification at **2026-10-26T17:15:55 UTC** confirmed ready status, 100% traffic and zero observed provider entries with severity ERROR or above for this revision. This is a point-in-time observation, not sustained operational acceptance.

Previous revision `bmt-stg-e7a444ab-api-web-3f4205261369` remains available for traffic rollback. Its original image, the managed backup ID, actual commands, initial preparation failure, source hashes and final receipts are in the [machine-readable report](evidence/backend-ghost-cache-deploy-2026-10-26/report.json). Private resource metadata remains in ignored task-owned build storage. Evidence `code/` files are audit copies of the actual build-path entry points.

Owner/device gameplay acceptance and real download savings remain unmeasured. No physical-device attachment check/test, APK/export/install, real provider sign-in or purchase was performed. Existing PC backend services and the running game were not restarted. No full-scale capacity or cloud-bill claim follows from this rollout.
