# Telemetry backend deployment - 2026-11-12

The owner explicitly authorized the necessary migrations and backend deployment
after the [telemetry reliability fixes](TELEMETRY_RELIABILITY_FIXES_2026_11_12.md).
The retained Google Cloud backend now runs the qualified telemetry patch with
schema **0077_telemetry_loss_sources**. Final acceptance completed at
`2026-11-12T17:09:40.602646+00:00`. This supersedes the earlier fixes report's pending
PostgreSQL/deployment qualification; its original findings remain historical.

## Scope and requirements

| ID | Delivered and checked |
| --- | --- |
| TDP01 | Upgrade live schema 0075 through the required additive 0076 dependency to 0077; retain existing profile history and competitive results. |
| TDP02 | Deploy UTF-8 ingress sizing, negotiated loss-counter version 2, source watermarks, additive account erasure, safe worker failure diagnostics and bounded admin publication counters. |
| TDP03 | Preserve the separately deployed API, worker/jobs, Studio and website-preview packages outside the eleven reviewed/prerequisite files per image. |
| TDP04 | Verify the backup, real PostgreSQL upgrade/downgrade/re-upgrade, workload grants, exact images, canaries, live health, worker supervision and native/storage smoke. |
| TDP05 | Preserve runtime configuration, credentials, resources, routing, canonical racing contracts, owner data, devices and the main Git index. |

The four serving parents were resolved from actual traffic revisions, not only
service templates. The main API, worker/jobs, private Studio and preview had
different deployed parents. Each candidate applies the reviewed telemetry delta
over its own parent. Package proofs preserve 368/368/369/355 other package files,
respectively. The inherited canonical game tree is unchanged. All four native
manifests match the pre-deployment live manifest exactly.

0076 adds nine per-car ranking tables, a correction scope column and an index.
It is included solely because 0077 depends on it. Those nine tables remain empty
and have SELECT-only workload grants. Existing ranking version 1 and launch
configuration remain exact; no per-car ranking feature code, publication or
rescore was activated. `product_loss_sources` permits worker CRUD and API/admin
SELECT only; actual restricted-role checks pass.

## Rollout and preservation

Fresh managed SQL backup **1794501880825** is SUCCESSFUL and retained. Registry
publication used the exact tested local image IDs and recorded immutable digests:

| Role | Deployed digest |
| --- | --- |
| main | `sha256:eed982d0cc1e9d823ce3f9d50777aa7288055de2838fdfe5ce3d8e0027f9ef9c` |
| worker | `sha256:ee82be37ea1554ca80d49a353c1d66bb846adb055294bbb9f743466b6811a734` |
| studio | `sha256:176b61a4c5bb3f98302f704934fac076f9c5f76e9f8e1ffcb2d44dddf9048a9f` |
| preview | `sha256:66ad45544795a3cf15d7e0418db9b42d01b32290837d5103d40380fe2306544b` |
| smoke | `sha256:8c5184367333bc3608c718b49b0e7fba93ee44248e5a571a6c1492533cb710e2` |

Source input hash: `fae0b73c5d4ff525ac78d0cc091e2fb2bcffbb6da71fa4c9acf7d51211b67930`. Image-specific changed/unchanged hashes
are in the package proofs. Runtime changes were guarded image-only updates:
environment/secret references, service identity, commands, limits, volumes,
startup/liveness probes and worker replica count remain exact.

The background worker was paused for read-only fingerprints and migration;
pending race/publication/validation queues were empty at the initial snapshot.
No private rows were exported. Before/after aggregate hashes of these retained
fields match at a frozen cutoff:

| History | Rows | Fingerprint |
| --- | ---: | --- |
| `personal_bests` | 7391 | exact |
| `lap_personal_bests` | 7394 | exact |
| `rivalry_bests` | 860 | exact |
| `track_versions` | 467 | exact |

The migration reports no invalid indexes. The worker pool and regular jobs use
the worker candidate; the smoke job uses its fixture-only derivative described
below. Public API and private Studio serve their validated revisions
at 100%; the website-preview tag points to its separately preserved candidate.
The API default template matches the main image. Temporary telemetry tags were
removed and the owned deployment lock released.

## Validation and retained findings

250 distinct backend cases were qualified on each of the four exact images
(1,000 image/case combinations). Tests include real PostgreSQL contention,
migrations, effective permissions, consent/privacy, telemetry projection,
Unicode ingress, source lifetimes, network/quality/race/shader data, admin and
safe failure-site logging. No selected case remains unresolved. The native
marker and historical archive-checker controls were deselected in these suites;
the deployed native/storage smoke was run separately. Targeted Ruff passes.

Original image runs are retained: main 222 pass/28 findings; other images
249 pass/1 finding each. Successful corrected gates cover every original finding:
main 88 cases plus a final ten-case admin run; other images 36 cases each.
The production images were not rebuilt for these fixture corrections.

* The unchanged deployed parent reproduced the concurrent test's residual four
  credits. A single bounded diagnostic pass can fold a partial before remaining
  owners become eligible. The fixture now drives at most 64 bounded passes and
  retains exact 64-event/16-profile/no-pending/zero-credit assertions.
* The PostgreSQL admin fixture must opt into legacy test authentication when
  constructing its application, because route/reporting mounting occurs then.
  Its original concurrent idempotency and single-audit assertions remain.
* Running role tests against the provisioned rehearsal database left incompatible
  extension permissions for random schema roles. Fresh independent databases
  pass all effective-role tests. Migration rehearsal and image tests now have
  separate database lifetimes.
* An initial admin-fixture retry still configured the app after construction and
  failed 404; the final construction-time fixture passes. Original failures,
  JUnit reports and control logs remain private in the task build directory.
* External Ubuntu WSL compaction interrupted an early local run; tests resumed
  after it completed. A retired build helper disappeared during preparation;
  required helpers are now retained locally with this release.
* Pre-staging a zero-traffic revision before DDL failed the existing `/ready`
  startup probe. Original traffic remained exact; no probe was weakened. Fresh
  revisions were validated after migration. A CLI stdout/stderr parsing failure
  was corrected and its successful read-only execution receipt recovered. A
  temporary Studio tag exceeded Cloud Run's combined name limit; shorter tags
  were used, with no serving-traffic change from the rejected request.
  A successful app-based worker diagnostic emitted no result receipt; a fresh
  read-only, explicitly flushed matching-build heartbeat probe supplied the
  qualified worker receipt without repeating the worker rollout.
* The inherited smoke fixture still expected physics0.76/rules22 and an obsolete
  car catalogue. The unchanged worker parent and telemetry candidate reproduce
  identical native output: 12,757 ticks and all five original lap times. Only
  the smoke job receives a derivative image with expected global manifest
  metadata pinned to the pre-deployment live manifest. Track/replay/vehicle/tick
  inputs, expected track hash and route length, the backend package and all
  assertion code remain exact. Its native check and the full live storage smoke
  pass; production racing services retain the original four tested images.

Live API health/readiness/bootstrap, schema77 and counter version2 pass. Public
admin routes remain 404; private Studio denies missing staff authentication.
Public pages, unknown-ghost fence, preview and full racing manifest pass. The
matching worker is ready; product child startup appears in Cloud Logging with
zero matched structured/process failures in the recorded bounded window.
Native/storage smoke passes with 12,757 canonical ticks, zero player writes and
cleanup of its own storage objects.

## Receipts, commands and limits

Safe receipts: [release](evidence/telemetry-backend-deploy-2026-11-12/rollout.json),
[test reconciliation](evidence/telemetry-backend-deploy-2026-11-12/test-acceptance.json),
[PostgreSQL rehearsal](evidence/telemetry-backend-deploy-2026-11-12/postgres-rehearsal.json),
[runtime inventory](evidence/telemetry-backend-deploy-2026-11-12/final-runtime.json).
Private definitions, tokens, ephemeral test secrets and raw cloud logs are not
copied into documentation.

The resumable task-local driver is `build/telemetry-deploy-20261112/release.py`.
Qualified phases: `initialize`, `prepare`, `build`, image tests and
`accept_tests.py`, `push`, `backup`, `migrate`, `canaries`, `workers`, `promote`,
`verify`. The failed `prepare_canaries` attempt remains recorded. Fixture-only
source deltas are retained in `fixture-corrections.patch`, checked forward and
reverse byte-exactly; the earlier runtime fix checkpoint remains separate.

Prior immutable images and the managed backup are retained for an explicitly
reviewed coordinated rollback. No downgrade, restore, score reset, catalog
rebuild, ranking activation or private player export was performed. A software
rollback must account for the readiness schema fence and new counter history;
it is not an automatic database restore.

No device query/test, APK/client deployment, owner-process restart, owner-save
edit, root staging/commit or merge occurred. Updated client code remains a
separate rollout. These checks establish this backend release, not device
acceptance, full repository qualification or a capacity/performance benchmark.

Build-retention completion: disposable package/test copies and ephemeral fixture
password files were removed. The required `clean_build.ps1 -Apply` completed with
zero failures; remaining output is recent/protected and exceeds the target under
the documented grace policy. Concise release receipts and the fixture-only patch
remain in `docs/evidence`; raw build logs and task helpers are disposable under
the seven-day policy, not permanent archives.
