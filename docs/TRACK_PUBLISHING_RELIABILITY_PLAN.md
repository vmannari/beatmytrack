# Backend-owned track lifecycle: review and implementation plan

Reviewed 2026-10-03. Requirements **B01-B07/B19/B20, R01, T01-T04, Q01** and the
owner's request to make creating, testing, publishing and racing robust. This is
a review and implementation contract. The later owner-authorized fixes, PC
rollout and final test results are recorded in [TRACK_LIFECYCLE.md](TRACK_LIFECYCLE.md).
The review findings and commands below describe the earlier snapshot, not the
current live service. This contract supersedes local-master retention in the
proposed workflow, while preserving recoverable unpublished work.

Pre-existing runtime changes continued during this review. Findings below reflect
the final source inspection; test results identify their execution snapshot and
must not be read as a clean final-working-tree regression pass.

## Required outcome

The backend owns every synchronized track master, including private creator
revisions and published versions. Local storage contains disposable downloaded
caches, pending authoring changes and durable operations awaiting acknowledgment.
After publication and verified retrieval of that exact backend version, remove
the corresponding local original, autosave and local publication-lock copies.
The published track appears once and is opened through its backend identity.

Offline editing remains possible. Work created or changed without connectivity
is explicitly **Saved on this device / Waiting to sync**; it cannot truthfully be
called backed up until the backend acknowledges it. Drafts belong in Create;
ordinary Race discovery contains backend publications and their cached copies.
Creator practice is one ordered lap from the placed start line. Ordinary races
remain five laps. Publishing never starts another drive. Sharing/racing remains
free, and existing timing, rating and rewind authority remains on the server.

## Findings and evidence

[Reproducible probes](evidence/track-publishing-2026-10-03/review_workflows.py) use
temporary SQLite and a fake domain verifier to isolate identity behavior. Their
[results](evidence/track-publishing-2026-10-03/workflow-probes.json) also contain
read-only checks of the running development API and actual local track folders.
Fake-verifier results do not establish driving validity. Real canonical checks
are listed separately below.

| Priority | Current behavior and consequence | Evidence |
|---|---|---|
| P0 | Running API reports ready at schema `0007_admin_audit`, physics `arcade-planar-0.39`, rules `standing-5-road-gates-v13`. Workspace expects schema `0008_review_reliability`, physics `arcade-planar-0.49`, rules `standing-5-road-gates-v14`. A client built from this workspace cannot obtain compatible contracts from this service. | Live `/readyz`, `/v1/manifest`; [current compatibility check](../game/backend/cloud_tracks.gd), [current readiness](../backend/bmt_backend/app.py). API health is insufficient to establish verifier compatibility. No service was restarted in this review. |
| P1 | Publication saves a playable local document and another document under `.published`; catalog indexing subsequently adds the backend version under a different ID. | [Local publication](../game/persistence/track_library.gd), [local indexing](../game/ui/track_catalog.gd), [cloud merge](../game/backend/cloud_tracks.gd), [shared profiles](../game/core/app.gd). All five public names also exist as local masters and locks: Dust cloud, Infinity, Narrow night, The Wall, Underpass. Names prove overlap, not document equivalence. |
| P1 | Every `upload_draft` calls `POST /tracks`. An edit produces a new fingerprint/key and a new logical track; lost upload-key storage can duplicate even an unchanged document. Existing version-creation API is unused by this client. | [Upload adapter](../game/backend/cloud_tracks.gd), [HTTP adapter](../game/backend/backend_client.gd), [backend creation](../backend/bmt_backend/tracks.py). Probe: same key reuses one version; a new key for the same document creates a second track with the identical blob hash; editing the same document ID creates a third logical track. Both identical tracks can be published and discovered. |
| P1 | Creator proof is copied in memory, then uploaded; only after upload and ticket success is its replay durably queued. A network/validator/ticket failure loses the reusable proof on exit. Guest tests persist only a tested-document snapshot. | [Test completion](../game/core/app.gd), [queue boundary](../game/backend/cloud_tracks.gd). The Dust cloud history in [creator flow](CREATOR_PUBLISH_FLOW.md) records this requiring a fresh drive. |
| P1 | Local `is_tested` enables Publish while backend verification may still be queued, rejected or absent. Publish retries upload and returns a generic failure; no persistent draft-to-version-to-run status reaches the creator UI. A successful publication followed by local-lock failure leaves no durable finalization operation. | [Draft actions](../game/ui/draft_browser.gd), [test snapshots](../game/persistence/track_library.gd), [publication](../game/core/app.gd). `/me/tracks` already exposes server draft states, but the creator flow does not reconcile them. |
| P1 | Async creator operations retain no workflow-wide account, library, document-revision or screen guard. Publishing an older snapshot calls `publish_document`, which writes it over the saved original. Concurrent edits/account departure can therefore produce stale UI or target the current library after an await. | Same app functions above, plus [profile changes](../game/core/app.gd). Source-confirmed risk; not reproduced against player files. |
| P2 | Track validation still launches Godot inside the HTTP write, with one nonwaiting process slot and a 90-second engine timeout. Client now allows 110 seconds for uploads, but long writes still occupy its authenticated-write lane and competing creators can receive 503. Version validation has now been moved before the numbering lock; retain that improvement. | [Validation/version creation](../backend/bmt_backend/tracks.py), [verifier slot](../backend/bmt_backend/verifier.py), [request serialization](../game/backend/backend_client.gd). |
| P2 | Worker converts infrastructure exceptions, including contract mismatch, into `verifier_unavailable`; retry exhaustion becomes `failed`. Client treats both failed infrastructure and invalid replay as terminal and skips them afterward. It has no user-facing requeue path. Worker derives expected contract from the version/current policy, rather than selecting an executable from the submitted attempt's pinned contract. | [Worker](../backend/bmt_backend/worker.py), [outbox polling](../game/backend/cloud_tracks.gd), [compatibility transformation](../backend/bmt_backend/contracts.py). Existing current-build upgrades are valuable but do not solve pending proofs spanning future builds. |
| P2 | Working-tree discovery now has snapshot cursors, compact persisted projections, per-track cloud-page deduplication and partial-progress retention. However refresh merges into the previous cache without an authoritative completed-snapshot replacement/removal step; hidden/removed entries can remain in the local feed. Client query completeness and restart/cursor behavior need acceptance. These improvements also have not reached the live schema-0007 service. | [Client refresh](../game/backend/cloud_tracks.gd), [server discovery](../backend/bmt_backend/tracks.py). Retain/test the new implementation rather than replacing it with the old offset design. |
| P2 | Published document caching already verifies exact bytes, but publication does not retrieve/cache its result or persist the local-to-backend identity. Starter Circuit, guest files and other profiles' locks are still independent playable sources. | [Integrity cache](../game/backend/cloud_tracks.gd), [catalog construction](../game/ui/track_browser.gd), [selection restoration](../game/core/app.gd). |
| Resolved during review / acceptance pending | A cloud rerun failed upload with `503 Track validator temporarily unavailable` after a concurrent runner edit referenced missing `RewindHistory.CAPACITY`. Source was subsequently changed to `WINDOW_TICKS`; the final script check passes. This demonstrates why rollout must validate the whole staged artifact, independently of API readiness. | [Runner](../game/backend/runner.gd), [history](../game/race/rewind_history.gd). Earlier `CheckScript` failure at line 136 was separate from the running service's old-build mismatch. |
| Resolved during review / acceptance pending | The first cloud integration run used retired `outbox.json.jobs` polling/direct reads and timed out. Current test code now uses `upload_jobs()`; final integration outcome is recorded below. | [Cloud integration test](../game/tests/test_cloud_tracks.gd). Retain all restart/verification assertions. First run's backend logs include a verified 12,757-tick race. |

The live public catalog has **five entries, no duplicate owner/name groups, and
no duplicate owner/document-hash groups**. Current observed duplication is
consistent with local/backend merging. Separate duplicate backend records were
reproduced only in the disposable domain probe; do not assume they already exist
in the live database.

Retain working foundations: content-addressed immutable blobs, authenticated
ownership, atomic local saves, idempotent domain writes, owner-only creator tests,
server timing, hash-checked cache reads, leased/fenced verification and versioned
boards. Existing uncommitted improvements already separate replay jobs, retain
finished races until enqueue succeeds, make optional standings asynchronous and
share the current manifest transformation. Newer edits also add cursor/projection
discovery, parallel authenticated reads, replay hashes and an upload-status dialog.
Do not reimplement them from the older
review's findings; test and integrate the actual working tree.

## Final lifecycle and identities

```mermaid
flowchart LR
    A[Create or edit] --> B[Save locally and queue sync]
    B --> C[Backend private revision]
    C --> D[Validate exact revision]
    D --> E[Drive creator test]
    E --> F[Persist document, contract and replay]
    F --> G[Backend verifies proof]
    G --> H[Ready to publish]
    H --> I[Explicit Publish]
    I --> J[Backend publication receipt]
    J --> K[Retrieve and verify backend document]
    K --> L[Commit backend identity and cache]
    L --> M[Remove matching local originals]
    M --> N[Race backend version or cached copy]
```

Errors return to the saved operation at the appropriate step. The publish button
expresses intent only after verification; its operation survives a lost response.
There is no automatic publication simply because a test finished.

Use three separate identities:

1. **Authoring identity:** stable random 128-bit ID assigned before the first save,
   persisted with the local operation. Unique server mapping on
   `(owner_player_id, authoring_id)`. Existing v5 document IDs can be retained
   inside documents; their stable ID is carried as `authoring_id` in the workflow
   envelope. Explicit
   Duplicate/Remix creates a new authoring identity. Ordinary edit/save/test does
   not. Guest adoption is explicit and ownership is server-assigned.
2. **Logical track ID:** backend `track_id`, stable across private revisions and
   publications. Discovery shows one current published version per logical track.
3. **Revision/version ID:** immutable backend snapshot. Proofs, race contracts,
   share links, ratings and records identify an exact version. A subsequent edit
   makes another private revision of the same track; publication never overwrites
   existing version content or historical boards. Existing published locks can
   remain read-only initially; any later Edit new revision action must be explicit.

Idempotency keys still protect individual writes, but server uniqueness must also
protect identity when keys change, the app is reinstalled, or two devices retry.
Use a unique `(track_id, authoring_revision_digest)` constraint/upsert for exact
authoring retries. Reuse a previous immutable revision when identical content is
submitted again. Concurrent edits use `expected_head_revision_id` compare-and-swap;
retain both device payloads on conflict and require explicit selection or a fork,
never silent last-writer-wins. Recover mappings through the authenticated owner API.

Specify different hashes instead of treating them as interchangeable:

- `request_digest`: canonical source snapshot and explicit authoring metadata;
  defines whether an authoring retry is identical.
- `document_hash`: SHA-256 of exact backend canonical document bytes; verifies
  download/cache integrity. Server attribution changes are accounted for before
  the revision is returned to the client.
- `compiled_track_hash` plus compiler version: canonical simulation content;
  appears in the pinned verification contract. Today's compiler hashes the full
  document, including ID/name/creator, so do not strip those fields or migrate
  hashes silently. Keep this contract for this slice.

For online testing, synchronize then retrieve the server's exact document before
starting. Any route regeneration or attribution rewrite creates a new revision
and invalidates its previous proof. Never regenerate the document after the
recorded test and claim that the existing proof tested it. Future hash redesign
requires its own compiler/rules migration and regression gate.

## Server state and API contract

Separate authoring, validation, proof and publication state. A single `tested`
flag cannot represent the workflow. Persist at least:

| Record | Required data |
|---|---|
| Logical track | Owner, authoring identity, head private revision, current published version, hidden state. |
| Immutable revision | Revision digest, document/blob hash, validation contract, compact discovery projection, schema/compiler version, timestamps. Accept incomplete but safe authoring JSON as a private revision; valid race geometry is a later gate. |
| Validation/proof operation | Owner, revision, purpose, input/replay hash, pinned artifact/contract, status, attempt/lease fencing, failure code, retry timing and correlation ID. |
| Publication receipt | Owner, exact version/hash, published timestamp and durable operation ID. Commit state/current-published pointer/receipt atomically. |
| Client journal | Backend/account/authoring identity, local revision digest, exact snapshot and proof paths, server operation/version IDs, stable keys, phase and cleanup progress. Never credentials. |

Proposed API changes, names to be fixed in schemas/OpenAPI before coding:

- Create/recover a logical track by authoring identity; save an immutable private
  revision with digest and expected head. Fast HTTP acceptance after bounded
  structural checks/blob persistence, returning a durable operation ID and status
  URL. Queue canonical validation outside the request and DB numbering lock.
- Owner endpoints list private drafts with validation/proof/publication states,
  read exact immutable documents, and recover operation outcomes after reinstall.
  Enforce ownership for every private read and transition.
- A creator-test endpoint binds proof to owner/revision/contract and deduplicates
  the same proof even under another key. Online tests obtain their contract before
  driving. Retain the one-lap, no-rewind, no-leaderboard/no-reward purpose.
- Offline rehearsal records persist document/vehicle/build/inputs locally. On
  sync, accept a retrospective **creator-only** proof if its exact contract is
  supported and the server document matches. This extends the existing creator
  purpose; it must never become a retrospective competitive race ticket. If
  attribution or normalization changes the document, report that mismatch and
  require a fresh test of the returned revision, keeping the old proof.
- Explicit publication requires validation and a verified creator proof for that
  exact revision, with a supported contract. Return the committed receipt on
  retries, including requests with new keys for an already-published version.
  Read back outcome by operation ID after timeout. A locally completed test alone
  grants no publication authority.
- Distinguish `VALIDATION_PENDING`, `PROOF_PENDING`, `INVALID_DOCUMENT`,
  `INCOMPLETE_LAP`, `CONTRACT_UNSUPPORTED`, `WORKER_UNAVAILABLE`, `STORAGE_UNAVAILABLE`,
  `OWNERSHIP_CONFLICT` and `REVISION_CONFLICT`. Invalid input is terminal;
  infrastructure failure retains evidence and offers safe requeue after repair.
  Expose `retryable`, next poll/retry timing and actionable detail; do not encode
  all rejected and failed operations as the same generic error string.

Define and test bounds for private snapshots, proofs, queue/storage admission and
retention using existing limits first. No quota/paywall for legitimate drafts.
Separate draft validation and race proof queues so a long proof cannot starve
creator saves; use bounded slots, fairness, backoff, lease recovery and fenced
transactional finalization. An expired ticket does not invalidate a submission
already durably accepted. New ordinary-race submissions still follow the existing
ticket-expiry policy; show their deadline and preserve expired evidence honestly.

Pin an executable artifact and complete contract for each attempt: engine,
verifier, compiler, schema, physics, rules, vehicle config, simulation hash,
spawn/lap purpose and replay schema. Workers route to the matching available
artifact. Keep at least the prior active artifact while accepted attempts drain;
unsupported historical attempts get a specific recoverable/operator status.
Never reinterpret captured old inputs with new physics or silently rescore boards.
Make publication proof compatibility explicit on each supported contract update.
Test the existing `current_manifest` policy against immutable originals and
queued attempts; do not expand its substitutions indiscriminately.

## Client persistence and publication handoff

Introduce a typed `TrackLifecycleController` and a small atomic operation store.
Move creator network/recovery state out of `app.gd`; keep `TrackLibrary` as the
pending-authoring file adapter and `cloud_tracks.gd` as catalog/cache integration.
The lifecycle controller exposes per-track states to the editor and draft browser:
**Saved on device, Syncing, Validating, Test required, Uploading test, Verifying,
Ready to publish, Publishing, Finishing publication, Published**, with recoverable
failure actions. Each stage restores from persisted state/server reconciliation.

Before any network await after test completion, atomically persist the exact
document, quantized replay, selected vehicle, contract and proof operation. Verify
the writes; if storage fails, keep the finished practice instance and offer Retry
save. Restart/exit must not silently discard this finished proof. Resume uploads
after reconnect/relaunch without another drive when the document/contract remains
valid. Reuse existing per-job replay storage rather than another aggregate file.

Bind each async operation to captured backend URL, owner ID, authoring identity,
revision digest, library instance and controller generation. Account changes can
leave its original account's journal pending, but never apply a result, delete
files, refresh private metadata or display success in another account. Edits
during testing/publication invalidate only the new head's proof; a completed
operation remains attached to its frozen revision.

Publication finalization is an idempotent local transaction, executed immediately
or recovered after restart:

1. Save the backend publication receipt and exact version/hash durably. A lost
   HTTP response triggers server reconciliation, never another new logical track.
2. Retrieve that version through the backend document API; verify byte hash,
   schema, compile result and contract. Atomically write the disposable cache and
   its metadata. Retrieval/space failure leaves **Finishing publication**, keeps
   the source and allows retry; server publication is still acknowledged.
3. Commit the backend identity mapping and a cleanup tombstone. Suppress the
   mapped local original in catalogs immediately, even if filesystem cleanup must
   retry. Persist the published entry directly from the receipt/projection; do not
   depend on the next full discovery refresh to make it available.
4. Remap favorites, last selection, race history and local record references with
   a recoverable migration. A local PB stays labeled local/unverified; never merge
   it into server rankings. Migrate records only when compiled contract equivalence
   is established; otherwise preserve their historical identity. Favorites/history
   use logical track identity; actual driving/records use the selected version.
5. Delete only source files whose authoring identity and digest match the
   published snapshot: primary and `.bak`/`.tmp`, matching WIP recoveries, old
   tested snapshots/locks and creation metadata. Remove full local `.published`
   document copies in favor of the receipt. Keep unrelated/changed drafts and
   unresolved conflicts. A newer WIP is a distinct pending private revision and
   remains available in Create.
6. Record cleanup completion, compact acknowledged operation payloads under a
   documented retention policy and release pinned cache entries. On any failure,
   preserve the cleanup journal and retry deterministically on startup/reconnect.

Never rely on a cache as the only published copy. Cache eviction/reinstall must
leave the master retrievable from the backend. Cache manifests are server-scoped;
private draft caches and operation journals are additionally account-scoped. Pin
active race documents and pending handoff data; use a bounded LRU for other cached
documents, corruption detection and re-download. Do not evict pending proofs as
though they were ordinary cache files.

## Discovery and driving

- Build Race exclusively from backend published metadata and its cached snapshot.
  Remove guest/profile local-master scanning from ordinary Race and results
  recommendations. Pending drafts are discoverable only through Create/Test.
- Use `track_id` as the unique displayed item and retain `version_id` for downloads,
  sharing and timing. Cached and online entries hydrate the same item. Deduplicate
  API pages by identity and use stable keyset/cursor pagination with a defined
  refresh watermark, deterministic tie order and behavior for version updates.
  Complete/test the existing cursor/projection implementation, remove stale
  entries after authoritative refresh, and define query/page completeness.
- Register Starter Circuit as backend-owned cleared content. A packaged starter
  snapshot may serve as a preloaded cache only if it includes its real server
  identity/hash/contract; it is not a parallel local master. Keep export-excluded
  handling fixtures separate. Changing backend environments needs a matching seed
  manifest rather than reusing another server's IDs.
- Resolve and enable cached tracks immediately; standings load independently.
  Existing asynchronous detail hydration is retained. Corrupt/not-yet-cached
  tracks present Download/Retry and never silently substitute another course.
- Online races acquire a supported ticket for the selected exact version before
  starting. Capture, enqueue, submit and poll without blocking browsing. Failed
  Restart retains the current ticket/attempt; delayed responses cannot restart a
  departed race. Guest/offline cached racing remains free with local-only times.
- Show API availability, contract compatibility and verification-worker health
  separately. Validate API and worker artifact IDs at rollout; a healthy DB does
  not mean proof verification works. Avoid sending a player through a drive that
  the backend has already declared unsupported.

## Migration of existing tracks and duplicates

Inventory before mutation: backend logical tracks/versions/proofs/records, local
masters/WIPs/locks/test snapshots, upload keys and jobs. Produce an auditable
mapping report with outcomes **exact match, known legacy conversion, unsynced,
conflicting, unresolved ownership**. Back up both database/blobs and authoring data
before the implementation's cleanup rollout; exercise restoration first.

- Recover backend ownership/mappings from receipts and exact canonical documents.
  Authoring IDs are not ownership evidence. Match actual content and contracts;
  never delete or merge solely by name, theme, creator display name, or route shape.
- The official seeder intentionally regenerated legacy routes and attribution,
  so some older local copies will not have identical hashes. Reproduce its approved
  canonical transformation in a dry-run and record old/new hashes plus explicit
  owner mapping. Ambiguous results remain intact for resolution.
- Register existing backend logical tracks with their authoring identities when
  provenance is established. Backend-only records remain valid. Unsynced tracks
  become private backend revisions, without invented verified tests or silent
  publication; adoption of guest/unassigned files is explicit.
- If duplicate backend tracks are found, pick an auditable canonical logical
  listing and retain aliases to legacy versions/share URLs. Existing PBs, votes and
  replay evidence remain on their original contracts; do not combine them into an
  apparently verified new board. Distinct real remixes remain distinct tracks.
- Run the new handoff for proven published equivalents. Remove corresponding
  local originals only after receipt/retrieval/cache/mapping commit succeeds.
  Unmatched unpublished work remains in Create, with sync/conflict status. This
  enforces the owner's removal rule without deleting untransferred edits.

## Implementation order and reviewable checkpoints

Deliver one vertical slice/checkpoint at a time; the existing dirty working tree
must first be separated into reviewed changes, rather than committed wholesale.

| Slice | Concrete delivery and principal files | Exit gate |
|---|---|---|
| 1. Compatibility baseline | Reconcile existing review fixes, migrations, staged canonical sources and API/worker builds. Integrate/validate updated per-job integration polling/assertions without weakening their invariants. Add artifact/contract reporting and startup/rollout checks. `backend/{bmt_backend/contracts.py,app.py,worker.py}`, `backend/deploy/{stage_verifier.py,compose.pc.yaml}`, `scripts/dev.ps1`, `game/tests/test_cloud_tracks.gd`, game compatibility UI. | Fresh isolated backend reports the same supported contract as the client; real creator and ordinary-race proofs succeed through HTTP and worker. Worker-down and stale-artifact states are reported accurately. Plan an explicit running-dev update after this gate; production remains a separate authorization. |
| 2. Backend identity and private revisions | Migration/constraints, owner recovery/status APIs, safe draft snapshots, queued validation and stable discovery projection. `track_models.py`, `tracks.py`, `worker.py`, `storage.py`, migrations/schemas; lifecycle controller/journal and draft sync UI. | Two devices/different keys produce one logical track and one identical revision; edits make revisions, not tracks. Incomplete drafts survive reload. PostgreSQL conflicts and concurrent writes behave as specified. |
| 3. Durable test and explicit publish | Persist proof before networking; online preflight/offline creator recovery; progress/errors/requeue; exact revision publication receipts. `app.gd`, `game.gd`, backend run/proof APIs, `cloud_tracks.gd`, lifecycle controller, `draft_browser.gd`, editor actions. | Finish test, kill app or disconnect at each await, relaunch and reach Ready without redriving a valid proof. Publish starts no race, exposes no private revision publicly, and never grants a competitive PB for creator practice. |
| 4. Backend-only handoff and catalog | Receipt/cache/mapping/cleanup journal, record/favorite migration, Race deduplication, creator-only drafts, cursor feeds, seeded starter cache, migration dry-run/report. `track_library.gd`, `track_catalog.gd`, `track_browser.gd`, `track_discovery_provider.gd`, `app.gd`, seeder and migrations. | Publish once -> exactly one Race card, backend document retrieved, matching originals removed. Restart/offline/cache corruption/eviction reproduce the same identity; changed WIP survives. Legacy migration report reviewed before executing cleanup. |
| 5. Failure acceptance and operational gate | Fault-injection suite, real app scenario, Android lifecycle/network tests, backup/restore and worker/artifact monitoring. Extend existing backend/Godot suites and evidence, avoiding tests that merely mirror helper code. | Entire matrix below passes against PostgreSQL and real pinned Linux verifier; desktop and attached-phone walkthroughs complete. No claim of shipping robustness from unit tests alone. |

No physics tuning, economy, online social modes, external SDKs or new dependencies
are needed for this scope. Exact endpoint names and retention/budget values are
engineering contracts to finalize in Slice 2, not an excuse to postpone recovery.

## Acceptance matrix

| Scenario | Required invariant |
|---|---|
| Double click, changed idempotency key, simultaneous two-device retry, reinstall | One logical master and one identical immutable revision; owner can recover identity/status from backend. |
| Edit/rename after test, edit during Publish, concurrent remote edit | Proof stays on its exact revision; new edits stay recoverable and require their own proof; no wrong-file overwrite/cleanup. |
| Airplane mode or process death before upload, after acceptance but before response, during proof polling/publication | Durable operation resumes from server outcome; no duplicate master or valid-proof loss. |
| Disk full/write failure/corrupt journal at proof capture and every cleanup phase | Honest failure; original proof/source or recoverable server reference retained; no false success or resurrection through `.bak`/`.tmp`. |
| Worker unavailable/crash/lease expiry/stale worker finishing; queue full | Bounded fair retry and fencing; no duplicate finalization; infrastructure outage is distinct from invalid driving. |
| Client/API/worker compiler/physics/rules/config mismatch, deployment while proof pending | Unsupported work is caught before online test; accepted work uses its pinned executable or explicit retained recovery state. Historical boards unchanged. |
| Invalid/incomplete lap, missing road gates, bridge underpass/overlap, variable widths, start-line direction | Canonical failure is actionable; legitimate one-lap creator proof succeeds with actual controls on pine/desert/night/winter/storm and all five vehicles. Five-lap race invariants unchanged. |
| Account switch/logout/refresh failure or expiry at every network boundary | Old operation remains with its original owner/backend; no wrong-account UI success, cache disclosure, publication or deletion. |
| Publication success but download/cache/selection migration/deletion fails | Server receipt remains known, one mapped Race entry, cleanup retries; newer unpublished edits survive. |
| Discovery changes between pages, over 10,100 tracks, same-name distinct tracks | Stable bounded pagination; no duplicate cards/skipped-page corruption; no name-based accidental merges. |
| Offline after publish, cache eviction/corruption, reinstall, restart with last selection | Backend remains master; cached data is usable when intact and re-downloadable when online. Missing cache is reported honestly. |
| Existing local/official converted files, backend duplicate aliases, old records/share links | Dry-run mapping auditable; only proven transferred originals removed; all historical records/links retain provenance. |
| Backup restored into isolated environment | Accounts, draft/public masters, immutable blobs, proof references and aliases recover together; integrity checks and real verification pass. |

## Actual validation and limitations of this review

| Actual command | Actual outcome |
|---|---|
| `.tools/backend-venv/Scripts/python.exe docs/evidence/track-publishing-2026-10-03/review_workflows.py` | Passed domain assertions; reproduced duplicate logical tracks, same-key reuse and edit-to-new-track behavior. Read-only API/local checks recorded five public entries and overlapping local masters/locks. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py backend/tests/test_verifier.py backend/tests/test_end_to_end.py backend/tests/test_official_tracks.py -q -k 'not postgres'` | **75 passed, 31 deselected**, 64.99 s. Includes real pinned Godot verification, recorded creator proof and two-player publish/share/race/rate/leaderboard HTTP flow. One dependency deprecation warning. PostgreSQL cases not executed. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestPractice` | **53 checks, 0 failures**. Practice recorder/start-line behavior passes; four leaked ObjectDB instances reported at exit. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCatalog` | **21 checks, 0 failures**. Existing query/carousel assertions do not test local/cloud publication reconciliation. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py -q` | **1 failed**, 152.02 s; child Godot process exceeded the 150-second timeout. Backend logs showed canonical acceptance, but the test retains obsolete aggregate-outbox reads. Not a client-integration pass. |
| Same cloud-client command after concurrent test/runtime edits | **1 failed**, 4.81 s; upload returned 503 validator unavailable. Current polling uses `upload_jobs()`, so the previous stale-access finding is historical, not the final source state. |
| Final cloud-client rerun after runner correction | **1 failed**, 151.35 s; Godot child again exceeded 150 seconds. Backend logs show verified 12,757-tick races and successful subsequent leaderboard/rating/record-detail reads. Remaining hang was not isolated; current client integration is not passing. No further reruns were made. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://backend/runner.gd` | Initial run **failed**, exit 1, missing `RewindHistory.CAPACITY`. Rerun after a concurrent correction to `WINDOW_TICKS` **passed**, exit 0. No runtime repair was made by this planning task. |
| `git diff --check -- DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md docs/TRACK_PUBLISHING_RELIABILITY_PLAN.md docs/evidence/track-publishing-2026-10-03` | Passed. New untracked plan/probe artifacts separately checked for trailing whitespace, valid local links and Python syntax; passed. |

Changed review files: this plan, the execution/probe artifacts in
`docs/evidence/track-publishing-2026-10-03/`, and appended current-work entries in
`DEVELOPMENT_STATUS.md`/`docs/PHASE_0_PLAN.md`. No runtime/UI presentation, player
data or running service was changed. No screenshot is necessary for this review.
No Android export or physical-device test was performed; attachment was not
checked. PostgreSQL concurrency, actual player's drive/publish recovery, mobile
process/network failure and NAS/production acceptance remain outstanding. No
backend restart/deployment, publication, migration cleanup or Git commit was run.
