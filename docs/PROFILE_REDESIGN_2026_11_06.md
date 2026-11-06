# Driver profile redesign — 6 November 2026

The profile now uses the existing menu palette, Barlow typography and native car photographs. A compact identity and racing summary lead into all five cars, with kilometres and race counts on each card. Created tracks and achievements share the next row; World Ranking and uploads are secondary. These are implemented Godot views, not image mockups.

## Requirements and implementation

| ID | Delivered behavior | Main sources |
| --- | --- | --- |
| PRF01 | Compact driver identity, four statistics, five simultaneous car cards in ordinary landscape widths, responsive two/three-column fleet on narrower layouts | `game/ui/own_profile_page.gd` |
| PRF02 | Exact prepared Garage pictures where available; existing equipped-header cache or model silhouette for custom misses; no new 3D capture or Garage opening | `game/ui/own_profile_page.gd` |
| PRF03 | Per-car completed-race counts and course kilometres persist in the same atomic transaction as local results; failed saves roll back both; existing saves remain readable | `game/persistence/driving_history.gd`, `local_records.gd` |
| PRF04 | Own published tracks use authenticated owner lookup and explicit pagination instead of a three-track name-search preview. Drafts use the existing cancellable worker and open the exact editor document. Route, biome, rating and race count are visible | `game/ui/own_profile_page.gd`, `backend/bmt_backend/tracks.py` |
| PRF05 | Achievement cards inherit wrapped content height, titles have a visible line, Prestige uses gold artwork, and deferred focus checks node lifetime. Collection/details open inside the profile and return to the same overview | `game/ui/achievements_menu.gd`, `achievement_badge.gd`, `own_profile_page.gd` |
| PRF06 | Private per-car verified history and published-version verified finish counts are grouped in SQL. Repeat finishes count separately from distinct drivers; rejected, artificial public, disabled public and creator-test runs are excluded as applicable | `backend/bmt_backend/profile_statistics.py`, `tracks.py` |
| PRF07 | 27 profile labels/explanations authored in all 12 supported locales; existing catalogue entries preserved | `scripts/translations/profile_redesign.tsv`, `game/localization/*.po` |

The new local `settings.driving_history` is optional and strictly bounded to the known vehicle identities and 1,000 track counters. It does not enter physics, score authority, rewards or uploaded proofs. Counts measure completed five-lap courses, not odometer telemetry or abandoned laps. Canonical behavior and existing achievement thresholds are unchanged.

The private `GET /v1/me/profile-statistics` returns current-car history and matching overview totals. `GET /v1/me/tracks?heads=true&profile_stats=true` adds `verified_races` for each returned version. Both are reads. There is no schema migration, publication, rescore, server write from profile viewing, or new external dependency.

## Native views

All identities/counts in these captures are isolated fixtures, not the owner's data.

- [Actual App with its normal menu shell and a populated local fixture](evidence/profile-redesign-2026-11-06/captures/actual-app-profile.png).
- [Complete overview at 1720 × 900](evidence/profile-redesign-2026-11-06/captures/profile-1720x900.png).
- [Created tracks, race counts and medals](evidence/profile-redesign-2026-11-06/captures/profile-records.png).
- [Achievement collection with visible titles](evidence/profile-redesign-2026-11-06/captures/achievement-collection.png) and [medal details](evidence/profile-redesign-2026-11-06/captures/achievement-detail.png).
- [400px layout](evidence/profile-redesign-2026-11-06/captures/profile-400x720.png), [German/long name](evidence/profile-redesign-2026-11-06/captures/profile-de.png), and [desktop Mobile captures](evidence/profile-redesign-2026-11-06/captures/mobile).

## Validation performed

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. All launches use an isolated `APPDATA` below `build/profile-redesign/user`, an empty `BMT_API_URL`, fixture records/libraries and the crash-dialog wrapper. No owner saves or running owner processes were changed.

| Check | Actual result |
| --- | --- |
| `test_profile_redesign.gd`, headless | 379 checks, 0 failures |
| Same, native Compatibility | 390 checks, 0 failures; 11 captures |
| Same, desktop Mobile | 390 checks, 0 failures; 11 captures |
| Same, later verbose desktop Mobile without captures | Printed 379 checks, 0 failures, then stalled during shutdown; identified and stopped only the owned test processes |
| Retained `test_own_profile_page.gd` | 23 checks, 0 failures |
| Retained `test_records.gd` | 54 checks, 0 failures |
| Retained `test_achievement_detail.gd` | 758 checks, 0 failures |
| Retained `test_achievement_detail_layout.gd` | 1,220 checks, 0 failures |
| Broad `test_achievements.gd` | 424 checks, 3 Garage wash/customisation failures; exact same three failures in task-before UI/persistence control |
| `tests/test_profile_statistics.py`, SQLite | 4 passed, 4 PostgreSQL cases deselected |
| Same PostgreSQL cases | 4 setup errors: configured local database connection timed out; no PostgreSQL validation claimed |
| Scoped Ruff | Passed |
| Scoped translations | 324 message/placeholder checks passed; German native view inspected |
| Pinned editor import / `scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/own_profile_page.gd` | Completed; no profile parser failure |
| Task source whitespace / task-only patch | See `evidence/profile-redesign-2026-11-06/checkpoint.json` |

Representative commands actually run from the repository root:

```powershell
$env:APPDATA = (Resolve-Path 'build/profile-redesign/user').Path
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_profile_redesign.gd
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --script res://tests/test_profile_redesign.gd
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method mobile --script res://tests/test_profile_redesign.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/own_profile_page.gd
```

From `backend/`: `../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_profile_statistics.py -q -k 'not postgres'`, then the PostgreSQL selection; scoped Ruff checked `profile_statistics.py`, `tracks.py` and the new test. Raw retained logs are under the evidence directory. The before-control project copies UI/persistence and uses workspace junctions for unchanged resources; production sources were never swapped for the control.

## Initial findings and limits

The first responsive probe incorrectly compared physical window pixels with the project's 1280px logical canvas; the fixture now explicitly sets its content scale before measuring. A real wrapped status-label width issue, collapsed achievement titles, a clickable-stat child intercept, and a deferred focus-on-removed-control were corrected. The old records assertion assumed only `raced_tracks` could exist; it now compares the entire committed preference snapshot, including new history, preserving the rollback invariant. Initial backend assertions omitted the legacy fixture's ordinary creator qualifying race; the fixture contract was inspected and assertions corrected. No failing gameplay invariant was relaxed.

The Windows root-certificate-store diagnostic appears in existing and new engine launches. The accepted desktop Mobile run exited after reporting a single ObjectDB instance. A supplementary verbose run printed all 379 passing assertions but stalled before shutdown completed; it does not establish a clean teardown. After sandbox process inspection was denied, approved elevated read-only inspection identified only this task's console PID 37024 and child PID 34356 by the exact test command; those owned processes were stopped. No owner process was stopped. Verbose Mobile also reports RGB8-to-RGBA8 hardware conversion. The broader localization checker reports 6,943 existing/inventory errors; only this task's 324 authored entries are claimed validated. PostgreSQL's failed setup trace included a local test connection string; that log was redacted and is not included in the source patch.

**Historical completeness:** server history comes from retained verified ordinary runs. Old archived attempts and Daily flying-lap results are not reconstructed or relabeled as lifetime totals. The UI identifies verified/local recorded history and provides its historical limitation in tooltips. Local per-car counters start with this update; a missing old counter is a dash, not a fabricated zero. A genuinely new driver shows zero. Missing custom images retain the actual model silhouette until the existing image service has the exact saved appearance.

**Remaining acceptance:** matching backend rollout is needed for server per-car history and published race counts; older servers keep local values and show unavailable counts. Client reload/rebuild, owner appearance review, and physical tablet touch/appearance checks remain. No device attachment query or device test, APK/export, production deployment, real authentication, purchase, publication, owner-save modification or main Git index write was performed. Existing concurrent work and generated build identity changes are excluded from the task-only checkpoint. This is not a certification of AAA quality or device performance.
