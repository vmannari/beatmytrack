# Daily limits, countdown and result cleanup

**DFL01**: Daily publication selects every supported car's nine flying-lap cutoffs and stores them atomically in `track_of_days.lap_limits`. The existing daily-state lock serializes publishers. The source is the compatible, deduplicated accepted flying-lap PB population; race totals do not select cutoffs. Published values survive later PB improvements, histogram refreshes, retries, connection restarts and repeated discovery maintenance. The next daily event selects a new set. No player request initialises or recalculates cutoffs.

The discovery worker prepares all car records before publishing the daily event. Pending accepted-lap backfill prevents partial publication. A car with no recorded flying laps retains that unavailable state for the day instead of receiving invented or moving limits. Selection stores its car manifest, population, cutoffs, generation and publication time. A mid-day contract change cannot silently replace them. On the first rollout, an existing event without stored limits is prepared once by discovery maintenance; it remains unavailable to the daily feed until that preparation commits.

The limits endpoint performs a stored-record lookup. Nearby/full lap standings can still refresh their comparison population while returning the same stored daily targets. Current population-access restrictions continue to apply. Their live comparison generation and the fixed limits generation are distinct.

**DFL02**: The countdown shows `HH:MM`. Tabular numerals and a reserved translated label width prevent time changes from resizing the counter. Text updates once per minute; rollover still checks the actual remaining seconds. Width is recomputed only for layout/font/language sizing, and stays fixed as the time counts down within that layout.

**DFL03**: Post-race results contain flying-lap numbers and times, stages passed and the earned medal. The cutoff percentages and Limit column are removed. The page's medal hints also omit cutoff percentages and retain the time gap/target for the next medal. The earned Elite award remains distinct. Gameplay still shows the active target while driving.

## Changed sources

- Client: `game/ui/track_of_day_page.gd`, `game/ui/daily_elimination_results.gd`, `game/ui/daily_result_card.gd`.
- Producer/API/schema: `backend/bmt_backend/daily_fixed_limits.py`, `track_of_day.py`, `daily_standings.py`, `discovery_worker.py`, `discovery_models.py`, and migration `0072_fixed_daily_lap_limits.py`.
- Tests: new `backend/tests/test_daily_fixed_limits.py` and `game/tests/test_daily_fixed_presentation.gd`; the existing cutoff/lap-standings fixtures now explicitly prepare their durable event before reading it.
- Five new messages in `scripts/translations/daily_fixed_limits.tsv`, with scoped additions to all twelve PO catalogues.
- Evidence, isolated runner and task-only checkpoint: `docs/evidence/daily-fixed-limits-2026-11-01/`.

## Actual validation

From the repository root:

```powershell
python docs/evidence/daily-fixed-limits-2026-11-01/run_native.py test_daily_fixed_presentation --graphical
python docs/evidence/daily-fixed-limits-2026-11-01/run_native.py test_daily_medal_page --graphical
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/daily_fixed_limits.py backend/bmt_backend/daily_standings.py backend/bmt_backend/track_of_day.py backend/bmt_backend/discovery_worker.py backend/bmt_backend/discovery_models.py backend/bmt_backend/migrations/versions/0072_fixed_daily_lap_limits.py backend/tests/test_daily_fixed_limits.py backend/tests/test_daily_elimination.py backend/tests/test_daily_lap_standings.py
python docs/evidence/daily-fixed-limits-2026-11-01/checkpoint.py
```

From `backend`:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_daily_fixed_limits.py tests/test_daily_elimination.py tests/test_daily_lap_standings.py -k 'not postgres' -q --disable-warnings --tb=short --basetemp=../build/daily-fixed-limits-final-cars
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_track_of_day.py tests/test_daily_standings.py -k 'not postgres' -q --disable-warnings --tb=short --basetemp=../build/daily-fixed-limits-retained
```

- Final focused backend: **12 passed, 11 deselected**. Includes real accepted-PB changes after publication, connection-pool restart, next-day renewal, all-car preparation before the first read, four concurrent publishers, pending backfill, read-only preparation gates, zero-population stability, migration rollback/re-upgrade, lap standings and cutoff scope checks.
- Retained daily curation/standings backend: **16 passed, 16 deselected**. No PostgreSQL run was requested or performed.
- Native Compatibility presentation: **307 checks, 0 failures**. Covers fixed width across nine time samples in twelve languages, HH:MM formatting and post-race result contents at desktop/portrait sizes. Final run has no fixture resource-leak warning.
- Retained medal page: **88 checks, 0 failures**, including all medal tiers, weekly persistence, car/account/stale-response fences, linked standings and multilingual layout.
- **60 scoped catalogue checks** and scoped Ruff pass. Checkpoint forward/reverse application, normalized content and final hashes are recorded in `report.json`.

All native commands use the pinned Godot 4.7.2 executable through `scripts/run_no_crash_dialog.py`, isolated test APPDATA/LOCALAPPDATA, and an empty service origin. Page responses are explicit fixtures. Screenshots include `fixed-hours-minutes.png` and both result outcomes at two sizes. No live account or owner save was used.

The first presentation run had nine test failures because its time assertion assumed the clock appeared at the end of every translated phrase. The corrected check finds the clock token, preserving the no-seconds requirement for languages that put text after the time. A subsequent passing run reported fixture-only retained regex resources; moving matching into a synchronous helper removed that warning in the final run. The existing isolated Windows root-certificate-store warning remains. These earlier logs are retained and were not reported as clean passes.

## Rollout and remaining acceptance

Migration **0072** must precede the matching discovery producer/API rollout. Existing whole-table role grants already cover the added column; API reads remain SELECT-only. A coordinated rollout at the next daily boundary avoids mixing legacy moving-target attempts with the new publication policy. Migration and tests were run only against owned local fixtures; no live database was migrated and no service was deployed.

Reload/rebuild and owner acceptance remain. No phone/Android test, APK, owner-save mutation, owner-process restart, deployment, main-index staging, commit or merge was performed. Only desktop Compatibility was exercised for the new presentation. The task checkpoint preserves concurrent work and is relative to this task's source snapshots.
