# Track of the Day flying-lap elimination

Requirements: **DE01** nine sequential cutoffs (75, 60, 50, 40, 30, 20, 10, 5, 1%); **DE02** exclude the opening lap and judge each subsequent lap independently; **DE03** use all recorded compatible best flying laps for the selected track/car (owner confirmed); **DE04** display the current target, elimination/completion and retry; **R01** retain ordinary racing and existing records.

The daily event now runs one opening lap followed by nine flying laps. The first missed cutoff ends the attempt at the finish line; passing the ninth flying lap completes the challenge. Equality qualifies. A faster earlier lap cannot rescue a slower later lap. An authorised rewind restores the applicable stage from the restored lap history. Retry resets all stages and fetches fresh limits; limits remain frozen during an attempt.

`GET /v1/track-of-the-day/limits` reads the existing durable best-flying-lap population, with one best per driver and the existing compatible comparison scope. It does not aggregate race totals or estimate values from histogram bins. Each cutoff is the ascending nearest-rank quantile: rank `ceil(population * percentage / 100)`, with all ties at that time qualifying. Empty or unavailable populations do not produce made-up limits. Day/version/car, snapshot board identity and the client engine/track/physics/handling contract are checked before starting. Public reads and signed-in moderation checks follow the existing daily standings boundary.

The main timing display shows the percentile and **lap limit**, above the current lap clock. The opening lap has no target. The result table contains flying laps only. The daily menu describes the opening lap and nine scored laps. New messages are supplied in all twelve offered languages.

## Score compatibility

Elimination attempts have their own **local results**, and do not submit variable-length or ten-lap totals to the existing five-lap race service. They do not overwrite ordinary PBs, achievements or ghosts, and do not receive verified race rewards. The existing daily standings continue to show verified ordinary five-lap races on that track. This task does not implement a new elimination leaderboard or a server-authoritative survival/reward contract. The cutoff service needs to be deployed alongside the client before this mode can start against a live backend; no deployment was performed.

## Changed files

- Runtime: `game/race/daily_elimination.gd`, `game/core/game.gd`, `game/core/app.gd`, `game/ui/playground_hud.gd`, `game/ui/track_of_day_page.gd`, `game/ui/daily_elimination_results.gd`.
- Backend: `backend/bmt_backend/daily_elimination.py`, `backend/bmt_backend/daily_standings.py`. No schema migration.
- Tests: `game/tests/test_daily_elimination.gd`, `game/tests/test_daily_elimination_app.gd`, `backend/tests/test_daily_elimination.py`.
- Language source: `scripts/translations/daily_elimination.tsv`; scoped additions to the twelve `game/localization/*.po` catalogues. New GDScript files have UID companions.
- Evidence runner and scoped checkpoint: `docs/evidence/daily-elimination-2026-10-31/`.

## Actual validation

Commands run from the repository root unless a working directory is specified:

```powershell
python docs/evidence/daily-elimination-2026-10-31/run_native.py test_daily_elimination --graphical
python docs/evidence/daily-elimination-2026-10-31/run_native.py test_daily_elimination
python docs/evidence/daily-elimination-2026-10-31/run_native.py test_daily_elimination_app --graphical
python docs/evidence/daily-elimination-2026-10-31/run_native.py test_track_of_day_presentation --graphical
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/daily_elimination.py backend/bmt_backend/daily_standings.py backend/tests/test_daily_elimination.py
```

From `backend`:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_daily_elimination.py tests/test_daily_standings.py tests/test_track_of_day.py -k 'not postgres' -q --disable-warnings --tb=short --basetemp=../build/daily-elimination-pytest-final
```

- Backend: **18 passed, 17 deselected**. Tests cover exact quantiles, ties, tiny/empty fields, lap-vs-race separation, authenticated/public responses, day and car fencing, and retained daily selection/standings behavior. Scoped Ruff passes.
- Native Compatibility rules/results: **107 checks, 0 failures**, including all nine cutoff boundaries, opening-lap exclusion, retry, rewind, old-fast-lap isolation, incompatible manifest rejection, actual Game initialization/restart, and result columns in twelve languages at narrow width.
- Actual App: **16 checks, 0 failures**. Finish-line crossing enters elimination and the finish transition; completion displays a single result panel; retry refreshes limits and clears progress; exit returns to Daily; missing limits cannot start a race. The main HUD displays the cutoff instead of the race total.
- Existing daily-page native regression: **77 checks, 0 failures**, including keyboard/touch behavior, rollover and translated action fitting. New copy is visible in the page captures.
- Final headless rules/results: **101 checks, 0 failures**; **132 scoped catalogue checks** pass. Checkpoint results are recorded in `report.json`.

The native runner sets isolated APPDATA/LOCALAPPDATA and an empty backend origin, uses the pinned Godot 4.7.2 executable, and wraps every noninteractive engine launch with `scripts/run_no_crash_dialog.py`. Synthetic cutoff responses are explicit fixtures. App gameplay and UI tests use actual runtime scenes; they are not a live-account or device test.

## Findings and acceptance limits

Initial attempts included a pytest import failure from the wrong working directory; a runner argument parsed as a script name; six viewport-fit failures caused by the test retaining the project's 1280px stretch canvas; a Japanese daily-action overflow fixed by shorter copy and panel spacing; and test fixture import lint findings, subsequently fixed. A PowerShell-to-Python Unicode cleanup attempt failed before catalogue writes; the corrected cleanup reads UTF-8 source keys from disk. These were not treated as passing runs. The isolated Windows engine emits a root certificate-store warning; no tests contact an external service. Graphical App fixtures logged frame hitches up to 453.007ms. No phone performance or cold-load claim is made.

Screenshots include the daily menu at several sizes, standalone elimination/completion tables, and actual App opening-lap/target/elimination states. The final source patch is made relative to task-start snapshots, with normalized-text forward/reverse application checks and exact final file hashes. It excludes pre-existing changes and leaves the main Git index untouched.

Reload/rebuild, coordinated backend rollout and owner gameplay acceptance remain. **No Android/device test, APK, live service mutation, owner-save mutation, owner-process restart, deployment, staging, commit or merge was performed.**
