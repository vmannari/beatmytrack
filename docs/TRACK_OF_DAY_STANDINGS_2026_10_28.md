# Track of the Day: today's verified standings

Delivered locally on 2026-10-28. The owner chose **today's races**, rather than the track's all-time records. Matching backend rollout and client reload/rebuild remain; nothing was deployed.

## Requirements and behavior

| ID | Delivered behavior |
| --- | --- |
| TDS01 | A Standings action on the featured page opens a styled, responsive results panel. |
| TDS02 | Each UTC day ranks one best verified five-lap time per driver and immutable vehicle board. Both server ticket issuance and submission must fall within that day. Later verification belongs to the original day. |
| TDS03 | Car selection, competition ranks with shared ties, times, leader gaps, ten-row pages and exact eligible racer count. The driver's highlighted best remains visible outside the current page. |
| TDS04 | Separate loading, empty, guest, failure and expired-day states; refresh after verification; stale replies fenced by day, revision, vehicle, account and API origin. Old rows and own result clear during scope changes. |
| TDS05 | Worker-maintained durable daily minima and an indexed read endpoint. First/improved daily results still verify when an earlier all-time PB is faster. Skipped hints never become standings. |
| TDS06 | Migration/backfill, workload grants, contract schema and eight new messages translated in all twelve supported languages. |
| R01 | Actual-App native UI, backend SQLite/PostgreSQL, real native-client HTTP, retained navigation and daily presentation checks. |
| Q01 | Scoped source checkpoint, reproducible helpers, screenshots, initial findings and explicit rollout limits. |

The daily cohort includes ordinary verified races on the featured revision and matching vehicle/rules board during that UTC day, including races launched elsewhere. A ticket from yesterday or submission after midnight does not enter today's results. Test drivers, test-population boards, creator tests, disabled/deleted players and unavailable tracks are excluded. There is no all-time fallback or additional reward.

## Implementation and rollout

Eleven runtime sources change:

- `game/ui/track_of_day_page.gd` and new `game/ui/daily_standings.gd`.
- `backend/bmt_backend/track_of_day.py`, `worker.py`, `non_improving_runs.py`, `database_privileges.py`, `app.py`, `migrations/env.py`.
- New `daily_standings.py`, `daily_standings_models.py` and migration `0071_track_of_day_bests.py`.

`GET /v1/track-of-the-day/standings` accepts pinned day/revision/car and keyset cursor. It reads `track_of_day_bests`, keyed by day/board/player, with order index `(day, board_id, time_ticks, player_id)`. Successful verification updates a strictly better minimum in the existing transaction. Exact count/rank queries scale with the daily population; this is not a constant-cost or production load claim. GET does not aggregate raw runs or write scores; the existing request-rate bucket write remains.

Migration 0071 follows 0070, seeds only retained eligible verified history, and preserves daily minima after raw evidence retention. Its one-time history scan has not been timed against live volume. API/admin receive SELECT; worker receives SELECT/INSERT/UPDATE; no DELETE grant. Bootstrap advertises standings version 1. Deployment must coordinate migration, grants, API and worker, followed by the matching client. No live migration or release was attempted.

Supporting files include two backend tests, two native helpers, the JSON response schema, eight-row translation TSV, thirteen catalog/template updates and stable Godot UIDs. Canonical simulation and physical configuration are unchanged. Concurrent vehicle, Garage, catalogue and backend work is excluded from the source checkpoint.

## Validation

| Check | Result | Evidence |
| --- | --- | --- |
| New daily tests plus retained non-improving and Track of Day backend suites, SQLite selection | 42 passed; 41 PostgreSQL cases deselected | `logs/backend-sqlite-923acd8e.log` |
| New PostgreSQL cases | 6 passed; 6 SQLite cases deselected | `logs/backend-postgres-ba6fb628.log` |
| Production Godot BackendClient against local FastAPI/PostgreSQL | 1 pytest passed; native 4 checks, 0 failures | `logs/backend-postgres-2fa02d0e.log`, `logs/native-http.log` |
| Actual-App UI, Compatibility | 46 checks, 0 failures; 11 captures | `logs/run-22196.log` |
| Actual-App UI, desktop Mobile renderer | 46 checks, 0 failures; 11 captures | `logs/run-14596.log` |
| Retained daily presentation | 59 checks, 0 failures | `logs/run-30864.log` |
| Retained race mode input | 57 checks, 0 failures | `logs/run-22988.log` |
| Eight new messages across twelve catalogs | 96 checks, 0 errors | `localization.json` |
| Owned Python Ruff | Passed | `logs/scoped-ruff.log` |
| Full backend Ruff | Three findings outside this task: `cloud_setup.py`, `rivalry.py`, `studio_erasure.py` | `logs/broad-ruff.log` |
| Text encoding | 1,550 files, zero issues | `text-encoding.json` |
| Task-only source checkpoint | Actual working-tree reverse check; isolated forward/reverse exact comparison passed | `source.patch`, `checkpoint.json` |

Backend fixtures exercise authorization, worker publication, faster historical PBs, first/better/slower daily results, ties across page boundaries, self outside the page, car/revision/day isolation, time boundaries, visibility, migration seeding and indexed reads. They use the existing fake verifier for synthetic inputs. The native HTTP case uses the production Godot JSON decoder and transport against a real local API/database; it is not a new independent physical replay proof. UI captures use clearly synthetic test standings, not real player records.

Reproduction commands from the repository root (use `.tools/backend-secure-venv/Scripts/python.exe` for `python`):

```powershell
python docs/evidence/track-of-day-standings-2026-10-28/run_backend.py -- tests/test_daily_standings.py tests/test_non_improving_runs.py tests/test_track_of_day.py -k "not postgres"
python docs/evidence/track-of-day-standings-2026-10-28/postgres_lab.py create
python docs/evidence/track-of-day-standings-2026-10-28/run_backend.py --postgres -- tests/test_daily_standings.py -k postgres
python docs/evidence/track-of-day-standings-2026-10-28/run_backend.py --postgres -- tests/test_daily_standings_native.py -k postgres
python docs/evidence/track-of-day-standings-2026-10-28/postgres_lab.py cleanup
powershell -NoProfile -File docs/evidence/track-of-day-standings-2026-10-28/run.ps1 -Renderer gl_compatibility
powershell -NoProfile -File docs/evidence/track-of-day-standings-2026-10-28/run.ps1 -Renderer mobile
powershell -NoProfile -File docs/evidence/track-of-day-standings-2026-10-28/run.ps1 -ScriptPath res://tests/test_track_of_day_presentation.gd -Headless
powershell -NoProfile -File docs/evidence/track-of-day-standings-2026-10-28/run.ps1 -ScriptPath res://tests/test_race_mode_input.gd -Headless
python scripts/text_encoding.py --json docs/evidence/track-of-day-standings-2026-10-28/text-encoding.json
python docs/evidence/track-of-day-standings-2026-10-28/checkpoint.py
```

The runners use the pinned `scripts/dev.ps1` entry point, isolated user folders, and ownership-checked restoration of generated build metadata. The recorded PostgreSQL fixture used the cached PostgreSQL 17 image on loopback with fresh credentials, isolated test schemas and no owner database. All schemas, the owned container and its private credential files were removed; see `postgres-lab.json`. The reusable helper additionally bounds future fixture CPU/memory; those bounds were not applied to the recorded test instance, and no performance measurement is claimed.

## Preview and retained findings

[Featured page](evidence/track-of-day-standings-2026-10-28/after/gl_compatibility/daily-with-standings.png), [standings](evidence/track-of-day-standings-2026-10-28/after/gl_compatibility/standings-1280x720.png), [small viewport](evidence/track-of-day-standings-2026-10-28/after/gl_compatibility/standings-844x390.png), [own result outside page](evidence/track-of-day-standings-2026-10-28/after/gl_compatibility/own-outside-page.png), [Finnish](evidence/track-of-day-standings-2026-10-28/after/gl_compatibility/finnish.png). Matching desktop Mobile captures, loading, empty, failure, guest and rollover views are retained in the evidence directory.

Initial attempts are retained rather than presented as passing:

- Running pytest outside the backend directory failed package import; the runner supplies the correct working directory.
- An overbroad read-only assertion caught the existing rate limiter. The final assertion allows only that bucket write and still rejects score/domain writes and raw-history reads.
- The native popup initially retained an oversized zero-width wrapping measurement and shared popup decoration. Final construction opts out before App's node-added observer, measures at usable width, sizes after layout, bounds the close icon, and reserves a scrollbar lane. Original viewport failures remain in logs; final size/readability assertions pass.
- Real HTTP caught integral JSON numbers arriving as Godot floats. Validation now accepts finite integral numbers and rejects fractions, booleans and non-finite values. Both a JSON round-trip regression and the real HTTP test pass.
- The first PostgreSQL attempt used an unavailable saved lab address; its verbose driver traceback exposed a local test credential in tool output. No secret is copied into these artifacts. Further output is captured/redacted and tests use a fresh disposable loopback lab; the owner's saved configuration is unchanged.
- Import completed with an unavailable Android build-tools warning. No Android export was attempted. Existing global translation completeness is outside the scoped eight-message check.

Source hashes, exact checkpoint validation, text-encoding results and logs are recorded in [report.json](evidence/track-of-day-standings-2026-10-28/report.json). No device attachment query/test, APK, real authentication/purchase, owner-save/live-data mutation, deployment, owner-process restart or main-index staging/commit/merge. Reload, coordinated backend rollout and owner/device appearance/input acceptance remain.
