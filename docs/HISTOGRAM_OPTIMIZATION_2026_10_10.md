# Histogram review and selection-driven refresh, 2026-10-10

Requirements: HOPT01 (measure histogram work), HOPT02 (no automatic refresh without track selection), RR06 (unified race/lap comparisons), TD06/TD08 (driver deduplication and public isolation), R01/Q01 (scoped implementation and measured evidence).

The owner requests lightweight histograms that stay fixed until a new track is selected, and explicitly confirms that post-race results should load once when opened. Discovery now loads the initially selected track once, then requests comparisons when another track is selected. Clicking the already selected track does not refresh its comparison. A new page still hydrates its initial selection; returning from another track is a new selection. Results initialize once when opened and retain that comparison through upload polling and verification completion. This preserves exact current-result placement without polling, retry timers or completion-triggered refreshes.

## Findings and implemented change

`CloudTracks.flush_outbox()` emits `changed` even with an empty outbox. The app polls it every second. `RaceComplete` subscribed to that broad signal and scheduled another comparison GET, including while hidden. The actual empty-outbox probe measured six redundant GETs in six idle polls, zero chart redraws, and another three GETs in three hidden polls. Equal-packet checks protected drawing but did not save server computation.

`game/ui/race_complete.gd` removes the signal subscription, debounce timer and deferred follow-up machinery. `game/ui/track_browser.gd` remembers the selection request and suppresses a second read for the same selected track while preserving first-load hydration. General cloud notifications and upload processing remain available to their existing consumers. There is no per-frame histogram construction; the sixteen-bar renderer already draws on demand.

`game/tests/profile_histogram_refresh.gd` exercises the real CloudTracks empty-outbox path with a mock network, including events while the first request is pending. It then changes the offered server packet, polls six times, hides the page and polls three more times. The final report proves one initial request, zero idle/hidden requests, zero idle redraws, and unchanged race/lap snapshots. `game/tests/test_unified_histograms.gd` adds same-selection/discovery-signal coverage and verifies one comparison request per new selection. Its mock now supplies the route and cloud status fields required by the newly exercised carousel path.

## Backend work and next optimization

The unified endpoint uses an incremental frequency projection for race PBs, but reconstructs each driver's best flying lap from all verified attempts. One request executes eleven SQL statements, four reading lap history. It deduplicates drivers across the comparable public/development boards. Candidate markers do not add a population sample, and exact placement is computed separately from the bins.

Measured locally with PostgreSQL 17, synthetic isolated records and ANALYZE after seeding; five endpoint calls per case, including the first call. These are endpoint calculation timings including local SQL, not live-host measurements or whole HTTP latency:

| Drivers | Verified attempts | Median calculation |
| ---: | ---: | ---: |
| 100 | 100 | 28.90 ms |
| 100 | 5,000 | 70.64 ms |
| 1,000 | 1,000 | 44.22 ms |
| 1,000 | 50,000 | 291.26 ms |

The next useful backend change is a durable per-driver best-flying-lap projection, maintained when runs are verified, with a lap or combined revision. Aggregate comparable race/lap populations once per revision and apply individual candidate markers/placement separately. Cache keys must include pinned rules, car, population visibility, bin count and frame bounds; reset cutoffs, disabled players and deduplication still apply. Avoid rebuilding the same best-lap subquery four times.

**The existing `Board.stats_revision` is insufficient for caching lap comparisons.** The probe adds a slower overall race with a faster flying lap: the histogram changes but the race PB and board revision do not. A cache or freshness check based only on that revision would serve stale laps. No backend runtime, schema, cache or deployment was changed by this task.

The disposable PostgreSQL runner uses an existing local image, an owned container and generated isolated schemas. It checks ownership before stopping its container, which was removed successfully. Fresh-table runs without ANALYZE were discarded as performance conclusions; final analyzed samples are retained. No external API or player records were modified. Probe source receipts are saved alongside the reports; their original execution directory is `build/histogram-review-2026-10-10`.

## Actual verification and evidence

All native commands use pinned Godot 4.7.2 stable ed1daf0bf through `scripts/dev.ps1`, with normal Windows certificate-store access. The graphical test used isolated APPDATA `build/histogram-review-2026-10-10` and BMT_RESULTS_EVIDENCE `docs/evidence/histogram-optimization-2026-10-10`.

- `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/profile_histogram_refresh.gd -TestArgument @('--report=C:/Codes/Godot/Beat my track/build/histogram-review-2026-10-10/client-report.json')`: passed, one initialization and zero later comparison requests. [Before](evidence/histogram-optimization-2026-10-10/client-before.json), [after](evidence/histogram-optimization-2026-10-10/client-after.json), [native log](evidence/histogram-optimization-2026-10-10/refresh-regression.log).
- `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical -CommandTimeoutSeconds 90`: **148 checks, zero failures**, three window sizes and pending/new selection captures. [Log](evidence/histogram-optimization-2026-10-10/unified-graphical.log), [inspected desktop capture](evidence/histogram-optimization-2026-10-10/discovery-1280x720.png).
- `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_results_histograms.gd -CommandTimeoutSeconds 90`: **37 checks, zero failures**, exact counts, independent result/PB markers, pinned domains and atomic race/lap packets. [Log](evidence/histogram-optimization-2026-10-10/results-histograms.log).
- `scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 90`: **99 checks, zero failures**. [Log](evidence/histogram-optimization-2026-10-10/app-tests.log).
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py -k 'sqlite and (histogram or results_comparison)' -q --tb=short --junitxml=build/histogram-review-2026-10-10/contracts.xml` with PYTHONPATH=backend: **5 passed, 1 skipped, 52 deselected**. The skip explicitly requires PostgreSQL repeatable-read concurrency. [Receipt](evidence/histogram-optimization-2026-10-10/contracts.xml).
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_test_drivers.py -k 'histogram or unified_comparison' -q --tb=short --junitxml=build/histogram-review-2026-10-10/driver-contracts.xml`: **2 passed, 13 deselected**, artificial lap reset/all-driver comparison and private board isolation.
- `.tools/backend-venv/Scripts/python.exe build/histogram-review-2026-10-10/owned_pg_probe.py`: final owned PostgreSQL benchmark exit **0**, owned container removed. [Samples and revision counterexample](evidence/histogram-optimization-2026-10-10/postgres-report.json), [log](evidence/histogram-optimization-2026-10-10/postgres-probe.log).

Initial graphical fixture failures exposed missing route `points`, cloud `status` and `refreshing`; those mock fields were added without relaxing assertions. One optional backend test launch used the system Python without pytest; rerun with the existing backend virtual environment passed. Earlier benchmark setup rejected an invalid environment/schema prefix; valid disposable development settings and the required owned schema prefix were used without weakening guards.

No phone attachment check or device test was performed. No Android export/install, full Validate, production deployment or backend update. Remaining acceptance: owner review in the populated live menu and on a physical device; benchmark and implement the durable lap projection separately if desired. The displayed comparison intentionally remains a snapshot until a new selection/view initialization.

Changed runtime files: `game/ui/race_complete.gd`, `game/ui/track_browser.gd`. Tests: `game/tests/profile_histogram_refresh.gd` and its engine UID, `game/tests/test_unified_histograms.gd`. This report, evidence, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md retain outcomes. The task-only patch records this slice against the existing dirty workspace without committing other work.
