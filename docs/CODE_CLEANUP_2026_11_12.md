# Obsolete code cleanup

12 November 2026. Implements all six findings in the
[review](CODE_OBSOLESCENCE_REVIEW_2026_11_12.md).

## Changes

| Finding | Implemented change |
| --- | --- |
| Test-only upload APIs | Removed synchronous `queue_run` and unpaged `upload_jobs`. Active fixtures now await the production `queue_run_async` and paged `upload_history`; the historical population probe explicitly walks all pages. Recovery codecs, durable files and operation identities remain. |
| Retired part-photo renderer | Deleted the orphaned photo studio and its UID. Moved the thumbnail generator and its stable UID to excluded `tests/support/offline_kit_thumbnail.gd`; bakers/capture tools explicitly preload it. Removed shipping cache-accounting/clear hooks. Exact historical photo assertions now live in the separate offline-photo suite. |
| Inactive part highlight | Deleted the helper, private shader, UIDs, unused allocation and clears. Preview tests inspect the actual mesh overlays, paint colours and current callout instead of an always-empty helper dictionary. |
| Challenge compatibility setters | Removed all three old setters. Tests press the current rule controls and commit the draft through the real action. The small input driver lives under excluded test support. |
| Unused client helpers | Removed the ten reviewed methods, obsolete profile test-host stubs, dead object-controls signal and sole subscription. Active properties, WIP persistence, ghost settings, warming and geometry construction remain. |
| Unused backend helpers | Removed `conditional_snapshot`, `pending_exists` and the latter's two unused imports. Current response caching and telemetry processing remain. |

The offline generator keeps its original class identity so preserved historical
controls can still compile. No shipping source references that class. The
retired graphics-setting save keys, save upgrades, input-only pending-operation
recovery, historical backend contracts, bridge data and full-model wash
references remain supported.

## Validation

Godot checks use the pinned `4.7.2.stable.official.ed1daf0bf` engine, private
APPDATA/LOCALAPPDATA, an empty backend URL and Dummy audio. The asset photographs
are generated with the native Compatibility renderer. Logs retain the local
root-certificate-store diagnostic; zero parser failures does not mean the entire
engine log contains no diagnostics.

| Check | Result |
| --- | --- |
| Final production parser | 553 scripts, 0 failures |
| Actual App composition, including after publication | 141 checks, 0 failures |
| Driving | 72 checks, 0 failures |
| Pending input recovery | 44 checks, 0 failures |
| Actual asynchronous packing/persistence and frame yielding | 18 checks, 0 failures |
| Original-owner outbox recovery across account switch/restart | 11 checks, 0 failures |
| Completion confirmation | 14 checks, 0 failures |
| Current Challenge controls | 216 checks, 0 failures |
| Current Parts previews/materials/callout | 588 checks, 0 failures |
| Current Garage menu/option resource checks | 1,472 checks, 0 failures |
| Preserved offline photographs | 87 checks, 0 failures |
| Washing surfaces, including after publication | 54 checks, 0 failures |
| Profile | 23 checks, 0 failures |
| Demand-driven race work/current writer | 40 checks, 0 failures |
| Backend Rivalry and telemetry, SQLite | 22 passed, 25 deselected |
| Targeted backend Ruff | Pass |
| Complete prepared-asset preflight, isolated and live | 551 resources, 2,267 checks, 0 failures |
| Catalogue photograph provenance, isolated and live | Six native images, 157 current source hashes |

The outbox fixture's old transport double observed a retired `submit_run`
hook. It now holds the actual POST request and supplies the current submission
lookup response. Its original owner/key/evidence assertions remain. Its waits
use bounded elapsed time rather than assuming a fixed number of headless frames.

The menu-speed fixture now waits for deferred workbench preparation. The
demand-work fixture awaits navigation and the in-flight Rivalry entry read before
probing result polling; the added completion assertion prevents a busy entry
read from masquerading as a polling failure. First-write and idempotent-repeat
coverage both exercise the real asynchronous writer.

## Prepared assets and concurrency

Deleting unused geometry helpers changes source fingerprints even though their
bodies had no callers. The complete pipeline ran in an independent copy:
bases, 520 fitted modules, full-model Garage references, header template and
catalogue pictures were regenerated and passed both original strict preflights.

The first source fence rejected concurrent changes in `backend_client.gd`,
`network_health.gd` and `product_telemetry.gd`. No outputs from that rejected
snapshot were published. Those current files were copied into the isolated
project, its build identity was regenerated, and the complete preflight workflow
ran again. Its geometry and photograph prechecks passed without another bake.
Publication required full live/isolated input equality and changed-output
checks. Only generated resources were copied back. Live identity generation,
both live preflights and final import then passed.

The publication receipt covers 567 generated files, including retained historic
car assets; 556 files changed. The Kart and Super Rally catalogue PNGs remain
byte-identical. Four other active PNGs were freshly rendered. Exact prior files
were recovered by their recorded hashes from an existing isolated build for
comparison: Compact differs at two pixels, Electric at six, Forklift at six and
Hover at 83, out of 1,048,576 pixels each. Alpha is exact; the largest mean channel
difference is 0.000757/255. These are measured differences, not a claim of complete
pixel identity or a device appearance qualification.

Concurrent backend logging changes were also detected in `product_worker.py`.
They remain intact and are excluded from the cleanup patch by including them on
both sides of its private baseline. The main Git index was not used.

## Retained findings and limits

- The broad parser still reports old override-signature mismatches in five
  unrelated fixtures and the incomplete frozen parking-hall Garage fixture.
  The final production parser is clean. No excluded historical source was
  rewritten to conceal these errors.
- The wider reliability suite retains 17 checks/3 failures and a missing
  `daily_elimination` property on its old game double. Running the task-start
  test and task-start CloudTracks source reproduces the same three labels and
  script error. This is not a passing reliability-suite claim.
- Initial upload-fixture, menu-wait, input-adapter and global-class failures are
  retained with their corrected final runs. The full-parser attempt that first
  found the malformed nested call is retained too.
- An initial backend attempt selected parametrized PostgreSQL cases whose
  configured local service was unavailable. Final SQLite runs pass; PostgreSQL
  and native HTTP integration are not qualified by this task.
- Earlier demand-fixture runs wrote their inherited historical JSON output
  before the supported `--report` argument was supplied. The final task result
  is saved separately as `demand-settled.json`; the earlier output is not used as
  a new historical acceptance claim.

No device query/test, APK, owner-save edit, owner-process restart, live service
request or deployment was performed. Reload the app to use the cleaned sources.
No loading-time, memory, FPS or competitive-behavior improvement is claimed.

## Receipts and checkpoint

[Validation receipt](evidence/code-cleanup-2026-11-12/validation.json),
[source receipt](evidence/code-cleanup-2026-11-12/source-receipt.json) and
[reverse-checked task-only source patch](evidence/code-cleanup-2026-11-12/source.patch)
are retained with compact command logs and asset/picture provenance. Full raw
runs and the isolated build remain under `build/code-cleanup-2026-11-12/`.
