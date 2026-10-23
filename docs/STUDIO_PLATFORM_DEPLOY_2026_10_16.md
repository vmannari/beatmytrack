# Studio platform deployment, 2026-10-16

The owner's **deploy the backend and ui** instruction is complete on the retained service:
[Studio](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#overview), [Operations and alarms](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#alarms).

API `bmt-stg-e7a444ab-api-00064-jid` serves100% traffic. Worker `bmt-stg-e7a444ab-worker-00030-x8p` and all
three existing migration/smoke/catalog jobs use the same pinned image. Schema is
`0040_studio_platform`; fresh successful Cloud SQL backup: **1792180080719**.
CompletedUTC: `2026-10-16T19:56:34.361268+00:00`.

Image: `europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:ee956efc3d2bcaa0e04e86e26af9d5d4b8af03cc5799c88ceaaf3edb6d84c5e8`.

The release includes the eight Studio workspaces, bounded prepared behaviour analysis,
full-scope diagnostic totals, release comparisons, durable incident response, all-pipeline
queue inspection, monetary/Coin ledgers and controlled presentation experiments. Its
additive schema prerequisites include0037 earnedCoins,0038 News and0039 friend publications.
External providers, staff MFA/SSO, notification destinations and business-only cohorts
remain unconfigured or disabled. The incident desk labels its missing continuous sources;
current checks work on demand. Independent watchdog hosting and log collection schedules
still require activation. Real Billing/RTDN/refund and settled reconciliation, native
experiment exposures, production load/restore and owner acceptance are not claimed.

The frozen package overlays only the validated Studio implementation and captured additive
prerequisites on the live image. Its canonical Godot sources, golden fixture, verifier Python,
compiler27/physics0.59/rules20 and previous challenge API remain exact. No newer concurrent
physics/rules, challenge-discovery migration, APK or phone work is included. No track revision
was appended: all27 existing official heads, downloaded document hashes and earlier links
remain available. Fifteen original-data fingerprints are exact across migration.

The tested image passed `128 passed, 3 skipped, 5 deselected, 1 warning in 134.15s (0:02:14)` and the actual PostgreSQL36-to40 migration, plus native
golden replay/rewind at build and real cloud native/schema/storage smoke. Canary and live
checks cover the new APIs and all packaged UI assets. Read-only Edge checks cover1440px and
390px, with no JS errors, failed admin reads, mutation requests or global horizontal overflow.
See [machine report](evidence/studio-platform-deploy-2026-10-16/report.json),
[rollout receipt](evidence/studio-platform-deploy-2026-10-16/rollout.json),
[image tests](evidence/studio-platform-deploy-2026-10-16/exact-image-tests.log),
[browser checks](evidence/studio-platform-deploy-2026-10-16/live-browser.json) and
[frozen provenance](evidence/studio-platform-deploy-2026-10-16/frozen-source.json).

Initial failures are retained: a packaging preflight named the wrong incident route and was
corrected before cloud changes. Two early PostgreSQL friend-publication checks returned an
empty feed;20 paired isolated repetitions and the complete image rerun are recorded with
diagnostics. A diagnostic bind mount initially targeted the read-only test directory; it was
moved to its own read-only path. No live writes or notifications were used for these tests.

The parent image and fresh backup are retained. The old schema36 image's readiness requires
schema36: do not route it blindly onto schema40. Any rollback must use a schema40-compatible
package or restore the backup with writers fenced and account for subsequent writes. No
destructive downgrade or restore rehearsal was performed. Existing secrets, runtime limits,
IAM bindings and storage scopes were preserved; temporary routing tags and the owned lock
were removed. See [activation runbook](STUDIO_PLATFORM_ACTIVATION.md) for remaining setup.
