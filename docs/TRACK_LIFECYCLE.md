# Backend-owned track lifecycle

Review repair follow-up (2026-10-03): overlapping local saves link acknowledged predecessors before first transmission; attempted requests retain their immutable keys. Explicit conflict Retry checks the server head and local upload receipt. Deleting a draft persists an owner-scoped archive intent, stops sync/restore and archives its private backend head without removing shared versions. See [R1/R9 repair and schema/test evidence](CODE_REVIEW_REPAIRS_2_3_2026_10_03.md).

Follow-up (2026-10-03): all 20 retained named saved circuits have now been restored to the PC backend. The catalog contains 26 unique publications, credited exactly to **Beat my track**; the six-publication count below records the earlier migration. See [track restoration](TRACK_RESTORATION.md) for current commands, integrity checks and desktop evidence.

Implemented 2026-10-03 for **B01-B07/B19/B20, R01, T01-T04, Q01** and the
owner's create/test/publish/drive reliability request. The earlier
[review and plan](TRACK_PUBLISHING_RELIABILITY_PLAN.md) records the starting
problems; this document describes the delivered behavior and verification.

## Identity and ownership

New drafts receive a random 128-bit `track_…` authoring ID before networking.
Existing document IDs remain valid. The backend enforces one mapping on
`(owner_id, authoring_id)`, and rejects an envelope that disagrees with its
document ID. Upload keys protect individual requests; identity uniqueness also
protects retries with different keys. Immutable content/name revisions are
deduplicated within that logical track. A changed draft gets another version,
while discovery, favorites and selection use `cloud_<track_id>`.

Version IDs remain the exact identity for proofs, downloads, sharing, ratings
and historical boards. Publishing a later revision replaces its single discovery
card; compiled caches invalidate the old version. Old share links and boards
retain their immutable documents. Local PBs already use the compiled content,
handling, physics and rules hash, so changing a display identity does not turn a
local result into a verified result.

Draft synchronization persists its expected head and stable request key. A
conflicting remote head is reported with `REVISION_CONFLICT`; the local snapshot
remains saved and Create offers **Save as new track**. Offline buffers coalesce
unuploaded changes while retaining completed proofs. Newer local edits are never
written over by a completed older test. Guest drafts are visible after sign-in
with an explicit **Use in my drafts** action; ownership is assigned by the server
and server attribution requires a compatible new test.

## Master documents and transitions

The backend owns accepted private revisions and publications. Local authoring
files are pending work/recovery buffers; network outages display **Saved on this
device / waiting to sync**, rather than claiming a backup. Owner-only head and
document reads restore private masters after reinstall without replacing pending
local edits. Public Race discovery contains backend publications and downloaded
caches. Local authoring buffers and bundled starter data are excluded from that
feed; creator practice remains available through Create.

```mermaid
flowchart LR
    A[Save pending draft] --> B[Backend private revision]
    B --> C[Background canonical validation]
    C --> D[Retrieve exact revision and test contract]
    D --> E[One ordered creator lap]
    E --> F[Persist recording and contract]
    F --> G[Server verification]
    G --> H[Ready to publish]
    H --> I[Explicit publish request]
    I --> J[Persist publication receipt]
    J --> K[Download and verify backend cache]
    K --> L[Commit index, binding and preferences]
    L --> M[Remove matching local copies]
```

`POST /tracks` with `defer_validation=true` performs bounded document storage and
fast private acceptance. The worker validates immutable blobs using a persistent,
leased/fenced queue; it alternates track validation and run verification. At most
32 pending validations per owner admit new revisions, returning a retriable 429
when full. This is a queue bound, not a track ownership quota. Invalid documents
remain private and cannot obtain race tickets or publication.

Online testing retrieves hash-checked canonical bytes and obtains the exact
creator contract before driving. Test completion saves the frozen document,
vehicle/build contract and input frames before any submission. Journals have
atomic writes and recovery copies, and proofs use separate files. Local completion
does not enable Publish: the backend must verify that exact revision. Repeated
creator proofs under replacement tickets reuse the same owner/board/replay run.
Creator tests do not mint leaderboard PBs or rewards.

Offline recordings retain their original contract. They can receive retrospective
creator-only tickets when compatible; expired unsubmitted creator tickets can be
replaced. This does not extend competitive ticket expiry. Wrong content, vehicle
handling or unsupported builds retain evidence and require a compatible build or
fresh test, without reinterpreting the recording. Failed infrastructure validation
and verification have explicit retry endpoints; invalid driving requires repair
or another test.

Publish stores explicit intent and an idempotency key before its HTTP request.
A lost response is recovered from owner status. After a receipt, the client
downloads the exact public document, checks its byte hash and compiles its cache.
It persists the cache index, backend binding and migrated favorites/selection
before cleanup. Write failure leaves the source and receipt for retry. Cleanup
removes only matching originals, WIP, `.published`, tested snapshots and matching
`.bak`/`.tmp` files. It preserves newer or unreadable data. Committed journals
retain a receipt instead of a local master and retire acknowledged proof files.

Account/backend scopes are captured across asynchronous work. Queued authenticated
requests reject account changes, response application checks the original scope,
and frozen tests retain their original library and vehicle. Creator status shows
syncing, validating, verifying, ready, publishing, cleanup and actionable errors.
Compact draft actions wrap and scroll rather than making Publish inaccessible.

## API and migration

Migration **0009_track_lifecycle** follows 0008 and adds nullable authoring/revision
identity columns, uniqueness constraints and persistent track validations. Legacy
tracks are recovered by embedded document identity and authenticated ownership,
never by title. Existing immutable blobs, links, boards and ratings are retained.

The runtime contracts are exposed in FastAPI OpenAPI:

- `POST /tracks`: authoring ID, deferred validation and expected head (`new` means
  no previous logical track expected).
- `GET /me/tracks?heads=true`: owner master revision recovery.
- `GET /me/track-versions/{id}` and `/document`: owner validation/proof status and
  exact canonical bytes.
- `POST /me/track-versions/{id}/retry-validation` and `/runs/{id}/retry`: retained
  infrastructure retries; incompatible/invalid attempts are not silently accepted.
- Existing publish, public document, ticket, leaderboard and rating endpoints
  retain exact immutable version identities.

`BackendStart` builds the pinned verifier before replacing local services and
compares the complete API and worker manifests afterward. Its Linux acceptance
includes the original five-lap replay and approved ten-second rewind. An older
twenty-second build fixture was corrected without weakening the current limit.

## Actual development migration

Before changes to live authoring storage, backed up PC PostgreSQL, object storage
and userdata under ignored `build/track-lifecycle-backup-2026-10-03/`.
Rebuilt **PC development only**, schema 0009, physics 0.49, rules v14, pinned
Godot 4.7.2. API and worker manifests match.

The approved official seeder adopted existing IDs, recovered logical tracks and
registered Starter Circuit as a backend publication without inventing a race or
PB. Its pre-piece polygon was represented with connected straight pieces and a
placed start line; cyclic ordering was chosen to satisfy existing route spacing.
This backend starter revision has its own validated hash; the original bundled
test fixture was not overwritten. Dust cloud received a new immutable canonical
revision after route preparation; all five existing logical track IDs survived.

Ran `ReconcileBackendTracks` using the production lifecycle against the PC service:
**6 publications, 6 hash-checked compiled caches, 6 compatible race contracts**.
The five previously published tracks have **zero remaining matching local
original/WIP/publication/tested copies**, including backup/temporary variants.
The [reconciliation report](evidence/track-publishing-2026-10-03/implementation/live-reconciliation.json)
records the observed identities and remaining-file audit. No production/NAS
deployment, data merge, fabricated verification or purchase was performed.

## Files and checks

Primary changes: backend track models/migration, `tracks.py`, `track_validation.py`,
`runs.py`, `worker.py`, official seeding and the development build probe;
client `track_lifecycle.gd`, `cloud_tracks.gd`, `backend_client.gd`, TrackLibrary,
TrackCatalog, app creator/race integration and draft/track browsers. Regression and
operations helpers live in `backend/tests/test_track_lifecycle.py`,
`test_cloud_client.py`, `test_pc_development.py`, `game/tests/test_track_lifecycle.gd`,
`export_backend_starter.gd`, `reconcile_backend_tracks.gd` and `scripts/dev.ps1`.
Substantial unrelated edits predated and continued during this task; no mixed
working-tree commit was created.

| Actual command | Outcome |
|---|---|
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q -k 'not postgres'` | 193 passed, 1 skipped, 67 deselected; includes real canonical verification. Later lifecycle-specific changes were checked separately below. |
| `python -m pytest backend/tests/test_track_lifecycle.py -q` using the repository venv | 19 passed, 1 SQLite concurrency skip, across SQLite and disposable PostgreSQL. Covers identity retries/concurrency, owner head recovery, head conflict, invalid documents, exact creator proof, infrastructure retry and lease fencing. |
| `scripts/dev.ps1 -Action BackendTestLifecycle` | 2 real Godot/HTTP/worker integrations passed. Graphical race/cache/rating/rewind: 51 checks. Final creator lifecycle fault rerun: 40 checks, 0 failures, including a scope change during publication. |
| `scripts/dev.ps1 -Action TestApp` | 96 checks, 0 failures after backend-only catalog/identity fixture updates. |
| `scripts/dev.ps1 -Action TestWorkflow` | 207 creator workflow checks, 0 failures. |
| `scripts/dev.ps1 -Action TestPractice` | 53 checks, 0 failures; exit reports three ObjectDB leaks in the final run (four in an earlier run). |
| `scripts/dev.ps1 -Action TestCatalog` | 21 checks, 0 failures. |
| `scripts/dev.ps1 -Action TestReview` | 17 reliability checks, 0 failures. |
| `scripts/dev.ps1 -Action BackendStart`, `GenerateBackendStarter`, `ReconcileBackendTracks` | Development build/migration/manifest comparison, original starter export and live handoff passed. |
| Scoped Ruff and `git diff --check` | Passed; CRLF normalization notices are informational. |

Commands above use `powershell -NoProfile -ExecutionPolicy Bypass -File` for the
PowerShell entry point. Earlier runs exposed a fast-path projection regression,
stale launcher mock, UI initialization timing and an SQLite resume-wallet lock;
they were corrected or exercised through the real cancel/retry path. Earlier
failed runs are not counted as passes.

[Creator verification screenshot](evidence/track-publishing-2026-10-03/implementation/creator-verified.png)
and [backend Race catalog](evidence/track-publishing-2026-10-03/implementation/race-backend-catalog.png)
are captured from the real HTTP integration on desktop. Further race captures
include 1280×720 and 960×540. Device **DN2103 is attached**, but no Android
export/install or physical-phone publishing/network-failure test was performed.
NAS/production migration, real Google-account publication, physical process-kill,
network switching, device storage exhaustion and owner visual/touch acceptance
remain acceptance checks. Unsupported historical verifier builds retain proofs;
there is no registry of older executable artifacts in this slice. A removed or
corrupt disposable cache requires a backend connection to retrieve again.
