# Daily track reference page and medals

**DMP01** follows the supplied page composition: large scenic track card, right-hand personal result/medal/target/nearby standings panel, car selector and Race again action, plus a seven-day strip beneath the preview. The existing top navigation, exact selected track geometry, author, biome and server countdown are retained.

**DMP02** awards medals for elimination stages actually passed, not the percentile of an earlier fast lap:

| Award | Stage cleared | Required successful flying laps |
| --- | --- | --- |
| Bronze | Top 75% | 1 |
| Silver | Top 40% | 4 |
| Gold | Top 20% | 6 |
| Elite | Top 1% | 9 |

**DMP03** gives the 1% result a separate icy platinum medal, engraved star, outer selection ring, laurels and Elite title. Existing bronze, silver and gold medals remain visible. The current medal has an outer ring. All award artwork is native drawing plus the existing authored laurel SVG; no new raster generation or external assets.

**DMP04** saves the best completed daily stage and best flying lap independently, so a worse retry cannot remove a medal or replace a faster lap. The opening lap is excluded. Local progress uses an atomic, bounded `records.json.daily.json` sidecar beside the existing account-specific records file, pinned by UTC day, track revision, car and engine/handling/rules/compiler identity. It retains five weeks, has a 512-entry/512KiB limit, and refuses to overwrite unsupported or unreadable saves. Weekly medals follow UTC Monday–Sunday for the selected car; future days show a dash and today has a yellow underline.

**DMP05** shows the remaining lap-time improvement to the next medal. If a fast earlier lap already beats that time but the required stage was not cleared, the panel explicitly asks for that stage. Race totals cannot award medals. The personal nearby row keeps the original millisecond lap time rather than displaying a rounded tick conversion.

The page and View all dialog use `/v1/track-of-the-day/lap-standings`, based on the same compatible, deduplicated all-time flying-lap population as the elimination cutoffs. The endpoint supports nearby candidate comparisons and cursor pages. A single immutable histogram snapshot supplies cutoffs, ranks and generation; small populations use their stored driver map, larger populations read the existing flying-PB rank index. Driver names come from eligible identity rows. Candidate comparisons replace the player's old PB for relative placement only; they do not write scores. Track/day/car/account/generation fences reject stale replies and cursors. The earlier ordinary daily race-time endpoint remains available to its existing callers.

## Local acceptance

Native screenshots and per-run logs are in [the evidence folder](evidence/daily-medal-page-2026-10-31/). The page captures use actual App/runtime UI with explicit synthetic feed, lap-limit and standings fixtures. They are not live account data. Medal persistence fixtures pass actual `DailyElimination.observe` stages before committing.

Actual commands from the repository root:

```powershell
python docs/evidence/daily-medal-page-2026-10-31/run_native.py test_daily_medal_page --graphical
python docs/evidence/daily-medal-page-2026-10-31/run_native.py test_track_of_day_presentation --graphical
python docs/evidence/daily-medal-page-2026-10-31/run_native.py test_daily_standings
python docs/evidence/daily-medal-page-2026-10-31/run_native.py test_daily_elimination_app
python docs/evidence/daily-medal-page-2026-10-31/run_native.py test_daily_elimination
.tools/backend-secure-venv/Scripts/python.exe -m ruff check backend/bmt_backend/daily_standings.py backend/bmt_backend/daily_lap_standings.py backend/tests/test_daily_lap_standings.py
python docs/evidence/daily-medal-page-2026-10-31/checkpoint.py
```

From `backend`:

```powershell
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_daily_lap_standings.py tests/test_daily_elimination.py tests/test_daily_standings.py tests/test_track_of_day.py -k 'not postgres' -q --disable-warnings --tb=short --basetemp=../build/daily-medal-page-backend-final
../.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_daily_lap_standings.py tests/test_daily_elimination.py -k 'not postgres' -q --disable-warnings --tb=short --basetemp=../build/daily-medal-page-backend-validated
```

Results:

- Final focused backend suite: **5 passed, 4 deselected**. Covers flying-lap pages, nearby rank changes for faster and slower candidates, compact indexed populations, scope/cursor fencing and retained cutoff behavior. Earlier broader daily selection/standings regression: **20 passed, 19 deselected**; the subsequent compact-population test also passed separately. PostgreSQL/device markers were not enabled.
- Final native medal page: **88 checks, 0 failures**. Covers all medal boundaries, persistence, UTC weekly history, account/car isolation, stale responses, View all, linked car changes, twelve desktop languages and six narrow component layouts. Captures include bronze, silver, gold, Elite and no-result states.
- Retained native daily-page fixture: **77 checks, 0 failures**, including long-caption separation, touch/keyboard entry, loading/error/empty states, rollover and translated action fitting.
- Retained standings fixture: **35 checks, 0 failures**; actual App elimination flow: **13 checks, 0 failures** headless; rules/results: **101 checks, 0 failures** headless.
- **312 scoped catalogue entries** in twelve languages pass nonempty/format-token checks. Scoped Ruff passes. Source checkpoint verification and exact final file hashes are in `report.json`.

Every automated Godot launch uses the pinned 4.7.2 build through `scripts/run_no_crash_dialog.py`, with separate test APPDATA/LOCALAPPDATA and an empty service origin. No owner save, real authentication or live service was used.

## Findings retained

Early captures exposed the old 440px artwork minimum overlapping the new week strip, a crowded result card, translated countdown width in the narrow component, and long-caption route overlap. These were corrected and the retained route-clearance assertion passes. The original page fixture's separate 400px height assertion was adapted to retain its 160,000px² minimum feature area while sharing height with the requested week strip; feed counters now count only the featured-track authority request, with the new lap requests covered separately. The old empty-board caption expectation was updated to the explicit flying-lap metric. No timing or medal assertion was relaxed.

A first translation append stopped because the shared placeholder regex interpreted literal percentage text as printf tokens. The scoped check distinguishes numeric percentage signs and `%%` escapes from real format tokens; all actual placeholders remain checked. Initial failed runs/logs remain in the evidence directory. Isolated native runs report the existing Windows root-certificate-store warning; they make no external service request. No crash is treated as a pass.

## Remaining acceptance

Medals and weekly progress are local cosmetic records, consistent with the preceding elimination implementation; this task adds no server-authoritative survival score, currency award or cloud medal sync. The new lap-standings API and client need a matching authorised rollout. No migration or new grant is needed because the API already reads the underlying lap/identity tables.

Reload/rebuild and owner visual/gameplay acceptance remain. No phone/Android test, APK, live service mutation, deployment, owner-process restart, main-index staging, commit or merge was performed. No device performance claim is made. Concurrent work is preserved; the task patch is relative to this task's source snapshots, not repository HEAD.
