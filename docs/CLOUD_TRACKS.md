# Backend track library and verified competition

2026-09-29 owner request. Requirements **B02–B07/B19, R01, V03, Q01**: installed
starter content, backend discovery, downloaded track caching, name/creator search,
account ratings and verified high scores in the actual game menus.

## Delivered behavior

- Play refreshes published backend metadata in 100-item pages and merges it with
  the installed Starter Circuit and existing local tracks. Selecting a cloud track
  downloads its immutable document, checks the server's SHA-256 against the exact
  response bytes, validates it, atomically caches it and compiles it in the existing
  selection worker. Browsing does not download full track documents.
- Public catalog/document caches are separated by backend URL. Cloud identities
  use immutable version UUIDs, avoiding collisions with local draft IDs. Cached
  documents work without connectivity; corrupt files are rejected and re-downloaded.
  The last selected cached cloud track can be restored after restart.
- Search can target name, creator, or either; biome, favorites, My tracks, name/score
  sorting and random selection work over the complete fetched metadata snapshot.
  My tracks includes the signed-in player's cloud versions. New sorts published
  versions by publication time. Friends, trending, rivals and playthrough sorting
  remain visibly disabled because their supporting data does not exist.
- Track tiles and recommendations show the backend's aggregate rating/count for
  cloud versions. The rating control reads the current player's vote and eligibility,
  submits changes to the backend, then refreshes aggregates. It never converts a
  local star into a cloud vote. Self-rating and rating without a verified completion
  remain forbidden by the server. Pending verification can unlock the control.
- The selected track shows verified race PB/rank and the actual population histogram.
  High scores opens paginated standings and an authenticated Around me view for the
  selected vehicle and immutable version. Ties retain the backend's rank ordering.
  Results continuation also reads the verified rank from the backend.
- Signed-in cloud races obtain a compatible server ticket before starting. The
  game records the exact quantized inputs used by each canonical tick, excluding
  countdown, pause and finish presentation. Retry clears frames and obtains a fresh
  ticket. Practice never submits a competitive score.
- Completed inputs are atomically queued under the backend URL **and player UUID**.
  Stable idempotency keys survive restart and ambiguous network responses. A menu
  controller checks pending work every eight seconds, uploads, polls verification
  and reports acceptance/rejection. Backend times, never client times, populate PBs.
  JSON-restored integer controls are explicitly checked and serialized as integers;
  fractional controls are not silently rounded.
- Publish now uploads an authenticated immutable draft and starts its required
  five-lap verification race. Verified completion publishes that exact version.
  Retrying the same upload reuses a persisted key. Local editing/practice remains
  available without an account, and local files are preserved. Uploading a draft
  does not make it public before the verified run.
- If a signed-in race cannot obtain a ticket, the game offers an explicit offline
  race with local timing. Guest cached races also remain available. Offline attempts
  without a server ticket do not claim a verified score.

## Changed boundaries

`game/backend/cloud_tracks.gd` owns discovery, cache integrity, upload keys and the
durable replay outbox. `backend_client.gd` serializes overlapping menu requests,
checks account continuity and preserves raw document bytes for integrity checks.
Session response bodies are removed before returning sanitized authentication data.

`game/core/app.gd` connects the adapter to account-scoped menus, races, publishing
and results; `game/core/game.gd` only adds bounded input capture/reset outside the
canonical simulation classes. Handling, collision, timing and checkpoint rules are
unchanged. Other pre-existing presentation edits in that file are not part of this slice.

`track_catalog.gd`, `track_browser.gd`, `track_discovery_provider.gd`, `track_tile.gd`,
`track_rating.gd`, `race_complete.gd`, `draft_browser.gd` and `cloud_leaderboard.gd`
connect the visible controls. Existing scenery/assets were reused.

Backend `tracks.py` adds discovery preview metadata, canonical document response
bytes and authenticated vote/eligibility reads. `runs.py` adds a public version/vehicle
leaderboard lookup, including a truthful empty board before anyone has raced.
No database migration or authentication bypass change is needed.

## Executed validation

| Command | Actual outcome |
|---|---|
| `.tools/backend-venv/Scripts/python -m pytest backend/tests -q -k 'not postgres'` | Final run: **122 passed, 33 deselected**, 75.88 s. Includes the real graphical cloud integration; PostgreSQL-only cases were not rerun for this slice. [Output](evidence/cloud-tracks/backend-tests.txt). |
| `BMT_CAPTURE_CLOUD=<absolute docs/evidence/cloud-tracks>` with `python -m pytest backend/tests/test_cloud_client.py -q -s` | Real HTTP API, disposable DB, real canonical worker and graphical Godot app: **47 checks, zero failures**, 20.93 s. The final full-suite run also passes this integration after the rank/histogram presentation refinement. |
| `scripts/dev.ps1 -Action TestCatalog` | 18 checks, zero failures. |
| `scripts/dev.ps1 -Action TestResults` | 191 checks, zero failures. |
| `scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd` and `-Action Import` | Passed with pinned 4.7.2. Import retains the existing Android build-tools fallback notice. |
| `python -m ruff check --config backend/pyproject.toml backend/bmt_backend backend/tests/test_cloud_client.py` | All checks passed. |
| `scripts/dev.ps1 -Action BackendStart`; `wsl -d Ubuntu -- docker compose --env-file .tools/bmt-pc.env -f backend/deploy/compose.pc.yaml restart api worker` | Existing isolated PC development services updated; accounts and volumes retained. `/readyz` reports ready at migration 0005. No production/NAS deployment. |
| Android SDK `platform-tools/adb.exe devices` | Empty device list. **No phone test or Android export performed.** |

The integration test exercises real game physics and input capture for all five laps:
**12,757 ticks / 106.308 seconds**, matching the server verifier. It also covers
idempotent publication, restart-before-upload, per-account outboxes, corrupt-cache
repair, offline cached reads, name/creator filters, ownership, per-vehicle boards,
pagination, forbidden votes, changed votes without aggregate inflation, rating UI,
the actual Play menu, results submission/rank and compact Race-button containment.
These are disposable fixture accounts; they are not seeded into the PC catalog.

Desktop evidence, inspected at 1280×720 and 960×540:

- [Play menu, 1280](evidence/cloud-tracks/cloud-menu-1280.png)
- [Play menu, 960](evidence/cloud-tracks/cloud-menu-960.png)
- [High-score dialog](evidence/cloud-tracks/cloud-scores.png)
- [Verified results, 960](evidence/cloud-tracks/cloud-results-960.png)

## Remaining acceptance and explicit limits

- The PC backend's published catalog is currently empty. Existing local courses
  were **not silently bulk-published or assigned invented verification scores**.
  The owner was asked whether these should seed the shared catalog or remain local
  until individually published. Pending that choice, all original files remain
  playable and editable under their existing ownership rules.
- The bundled Starter Circuit remains an offline/local fixture; cloud competition
  is attached to published immutable versions. A larger registered shipping starter
  pack is not introduced by this change.
- The current client downloads a complete metadata snapshot for responsive offline
  filtering, bounded by the existing server pagination limit (10,000 offset) and
  an 8 MiB cache document. Bigger catalogs need query-driven server pagination and
  persisted discovery projections. Full track documents are still lazy downloads.
- Cache eviction/storage-budget UI and cloud draft synchronization are not included.
  Outbox documents are bounded at 8 MiB; a failed durable enqueue is reported rather
  than treated as uploaded. Server tickets expire after two hours, so an unsent
  attempt cannot be accepted indefinitely offline. Rejected/expired attempts do not
  appear as verified scores.
- Only total five-lap race PBs have backend boards. Best-lap values remain local and
  lap percentile UI explicitly reports that lap rankings are unavailable.
- Physical-phone layout/touch, intermittent mobile networking, performance, NAS/TLS
  deployment and real-Google interactions require separate acceptance. No new
  production server URL, social features, progression or commerce were introduced.
