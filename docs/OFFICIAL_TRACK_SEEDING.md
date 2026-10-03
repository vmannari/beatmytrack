# Official local-track publication — 2026-09-29

Requirements **B02–B07/B19, R01, Q01**. The owner chose to seed the locally
published/locked circuits into the backend and assign them to the fixed **Beat My
Track** development account.

## Delivered behavior

- Added an operations-only, stdin-driven seeder in
  `backend/bmt_backend/official_tracks.py`. It requires an explicit owner-name
  confirmation, resolves the stable `development/developer` identity, rejects a
  missing/disabled/renamed owner, stamps both server ownership and downloadable
  document attribution, and is idempotent by owner plus canonical content hash.
- Official seeding uses the pinned Godot verifier to regenerate the automatic lap
  route from the connected road pieces and validate the resulting document in one
  process. This migrated three older locally locked route snapshots without editing
  or deleting the local files.
- Official catalog entries do not receive a fabricated creator run, personal best,
  rating, or leaderboard result. The ordinary player-facing publish endpoint still
  requires a server-verified five-lap creator test.
- The PC development backend now publishes **Infinity**, **Narrow night**, and
  **The Wall**. The already published **Underpass** remains unchanged. All four are
  owned and attributed to **Beat My Track**.

## Actual validation

| Command/check | Outcome |
|---|---|
| `python -m pytest backend/tests/test_official_tracks.py backend/tests/test_verifier.py -q` | **34 passed**; one dependency deprecation warning. |
| `python -m ruff check ... official_tracks.py verifier.py test_official_tracks.py` | Passed. |
| `scripts/dev.ps1 -Action CheckScript -ScriptPath res://backend/runner.gd` | Passed with pinned Godot **4.7.2**. |
| `scripts/dev.ps1 -Action BackendStart` | Image rebuilt; pinned verifier import, 12,757-tick five-lap fixture and rewind regression passed; API/worker/database healthy. |
| First seed attempt | Safely rejected a Windows UTF-8 BOM before mutation; ingestion was made BOM-tolerant. |
| Second pre-migration attempt | Safely rejected legacy route snapshots before mutation; canonical route preparation was added. |
| Live seed | Three tracks published with stable version UUIDs. |
| Public metadata plus document download | Four entries returned; metadata creator, state, and document creator are `Beat My Track`, `published`, and `Beat My Track` for every entry. |
| Immediate seed rerun | All three returned `existing` with the same version UUIDs; no duplicates created. |

## Limits and acceptance

This updates the isolated PC development backend at `127.0.0.1:18181`; it is not a
production/NAS deployment. No gameplay/UI code, physics, local track file, verified
score, or rating changed. No screenshot was required because the implementation is
an operational catalog/data change rather than a UI presentation change. No Android
export or physical-phone test was performed.
