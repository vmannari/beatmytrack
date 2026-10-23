# Weekly Rivalry planning and Studio management — 2026-10-18

The owner requests metric-based randomized weekly track selection, four future weeks always planned, and Studio overrides for selected tracks. This slice implements that calendar locally. It does not deploy the backend or change live competitions.

## Requirements and behavior

| ID | Delivered behavior |
| --- | --- |
| WRP01 | Persist the current week and the next four complete Monday–Sunday UTC weeks, with five distinct tracks each, for every active verifier vehicle/build contract. The existing worker fills the rolling horizon, including while race work is queued. |
| WRP02 | Select eligible tracks through a weighted random draw using ratings, distinct verified finisher counts, eight weeks of recent use, planned use and biome diversity. Retain the existing community threshold: rating strictly above 4.0 and more than 100 verified finishers, with trusted official tracks as the alternative. |
| WRP03 | Content & competitions → Competitions → Weekly Rivalry shows four future line-ups, dates, metrics, car selection, current locked week and staff history. Owners can search eligible replacements, select a slot, preview before/after and save with a recorded reason. Analysts can inspect. |
| WRP04 | Race group creation consumes the persisted current plan. Manual line-ups persist through automatic maintenance and are used on rollover. Preserve existing groups, memberships, tickets, five-lap rules, best-only points, standings, development population boundaries and canonical physics. |
| G01 / R01 | Bounded indexed candidate windows, no document/blob reads or PB scans in planning, no new worker service or dependencies. Audited permanent command IDs, revision/preview/deadline checks and atomic plan/audit writes protect edits and retries. |
| Q01 | Actual backend checks, eight real Edge workflows at desktop/390px, screenshots, known limitations and a task-only source checkpoint. |

The current week locks at Monday 00:00 UTC even if no group has joined yet. Existing groups created before this feature retain their original assignments. Plans are specific to the active build and vehicle; a build change creates a new compatible calendar without rewriting old plans or results. Public and development test groups use the same scheduled versions with their original separate board scopes.

When fewer than five eligible tracks are available, the UI shows an incomplete calendar rather than inventing tracks or lowering eligibility. Future tracks that become unavailable or cease being eligible are repaired by the worker; other valid selections retain their exact slots. The source label changes to “Automatically repaired” and the plan revision increments. Manual choices otherwise remain fixed. Owners can also fill missing weeks immediately through an audited action.

## Implementation and selection policy

Migration `0043_rivalry_planning` adds `rivalry_week_plans`, uniquely keyed by UTC week and contract. Each row stores its five immutable version identities, metric snapshots, random seed, source and revision. Existing schema/data are not rewritten. The migration was applied only in owned test databases.

`backend/bmt_backend/rivalry_planning.py` owns generation and maintenance. A stable rotating UUID index window reads at most 1000 eligible candidate versions per vehicle, plus at most 25 already scheduled pins. History reads are limited to 1000 plans and 1000 groups within eight weeks; a track counts once per historical week. The oldest uses outside that window are not queried.

Sampling has no replacement within a week. Among candidates, the least-used tracks in the history/calendar are considered first. Within that set, weights use:

```text
rating = (rating_sum + 40) / (rating_count + 10)
popularity = 1 + min(2, log(1 + verified_finishers) / 4)
weight = max(0.1, rating - 3) * popularity / (1 + 2 * selected_same_biome)
```

This gives ratings ten prior votes at four stars, caps the popularity multiplier at three and reduces repeated-biome weight. The random seed is saved with the plan; normal maintenance never rerolls a valid line-up. Smaller catalogs may repeat tracks between weeks after unused choices are exhausted. These weights are an initial implementation choice, subject to owner acceptance.

Worker maintenance runs before claims, coalesced by a local monotonic timer and a transactional global database interval of 60 seconds. Per-contract locks serialize planners and owners. Planner errors roll back and are logged without preventing ordinary race processing. Group creation can initialize a missing plan if a worker has not prepared one yet.

`backend/bmt_backend/studio_rivalry.py` exposes read-only calendar/candidate GETs, owner-only `/prepare`, and plan `/preview` plus `/commands` POSTs. Previews bind all five versions, revision, reason, command and time for five minutes. Execution revalidates eligibility, active contract and UTC deadline, including the final write predicate. A saved `AdminAudit.command_id` returns its original response on retry, including after expiry or rollover. A reused ID with different content is rejected. SQLite reserves its writer; PostgreSQL uses command advisory locks and per-contract row locks. PostgreSQL execution remains untested here.

`rivalry.py` consumes scheduled versions when creating groups; its existing scope-specific board creation and scoring remain. `worker.py` invokes maintenance. `app.py` registers the administration router. `studio.py` declares coverage. `admin_ui/platform.js` and `style.css` implement the calendar, slot picker, metric search and confirmation using existing navigation/dialog/authentication guards. The browser retains the exact submitted command for ambiguous-network retries. `backend/schemas/rivalry-plan-v1.schema.json` documents the new command.

## Actual validation

Commands run from the repository root:

```powershell
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_planning.py -k 'not postgres' -q --tb=short
& .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_planning.py backend/tests/test_rivalry.py backend/tests/test_rivalry_concurrency.py backend/tests/test_rivalry_week_completion.py backend/tests/test_rivalry_awards.py backend/tests/test_rivalry_appearance.py backend/tests/test_studio_operations.py backend/tests/test_studio_platform.py backend/tests/test_worker_lifecycle.py backend/tests/test_domains.py -k 'not postgres and not recorded_practice_through_real_publish_worker' -q --tb=short
& .tools/backend-venv/Scripts/python.exe -X utf8 scripts/test_rivalry_planning_console.py
& .tools/backend-venv/Scripts/python.exe -m ruff check backend/bmt_backend/rivalry_planning.py backend/bmt_backend/studio_rivalry.py backend/bmt_backend/migrations/versions/0043_rivalry_planning.py backend/tests/test_rivalry_planning.py scripts/test_rivalry_planning_console.py
& .tools/backend-venv/Lib/site-packages/playwright/driver/node.exe --check backend/bmt_backend/admin_ui/platform.js
git diff --check -- backend/bmt_backend/rivalry.py backend/bmt_backend/rivalry_models.py backend/bmt_backend/worker.py backend/bmt_backend/app.py backend/bmt_backend/admin_ui/platform.js backend/bmt_backend/admin_ui/style.css backend/bmt_backend/studio.py
```

Focused planner checks: **10 passed, 8 deselected**, recorded in [planner-tests.txt](evidence/rivalry-planning-2026-10-18/planner-tests.txt). They cover rolling planning, stable selection, metric influence, manual overrides becoming actual raced assignments, exact rollover/deadline protection, stale/expired previews, build fences, shortage visibility, automatic repair, atomic audit rollback and concurrent commands. The final regression also checks persistence through a new application instance.

The broader regression passed **106 tests, with 4 skipped and 83 deselected**, in 160.86 seconds. The four platform-specific signal tests remain skipped on Windows; PostgreSQL variants and the separately reproduced native-publication failure are excluded. See [backend-tests.txt](evidence/rivalry-planning-2026-10-18/backend-tests.txt).

Real Edge passed **eight workflows** at 1440×1050 and 390×844 with **zero JavaScript errors**, against an owned disposable loopback SQLite service. Checks include all four weeks, preview/cancel, saved replacement, search, server-committed/lost-response retry, competing-owner rejection, narrow layout and lock/analyst behavior. See [browser.json](evidence/rivalry-planning-2026-10-18/browser.json) and [browser-tests.txt](evidence/rivalry-planning-2026-10-18/browser-tests.txt).

- [Desktop calendar](evidence/rivalry-planning-2026-10-18/calendar-desktop.png)
- [Desktop before/after confirmation](evidence/rivalry-planning-2026-10-18/lineup-preview-desktop.png)
- [390px calendar](evidence/rivalry-planning-2026-10-18/calendar-mobile.png)
- [390px complete confirmation](evidence/rivalry-planning-2026-10-18/lineup-preview-mobile.png)

Scoped Ruff, JavaScript syntax, JSON parsing and whitespace checks pass. The existing Starlette/httpx deprecation warning remains.

## Initial attempts and limitations

An initial test command named a nonexistent `test_worker.py`; the corrected command uses the actual worker lifecycle/domain suites. The first unfiltered Rivalry invocation was stopped before the unavailable PostgreSQL parametrizations and rerun with explicit local selection. Initial Ruff fixture/import formatting findings were corrected. Node was absent from PATH; the existing Playwright-bundled executable completed the syntax check.

The first browser run reached its final lock check but used a forced pointer click against an inert page behind a modal. The corrected fixture invokes the existing Lock handler programmatically to exercise auth invalidation while a dialog is open; it does not weaken modal input blocking. The first desktop element capture let the sticky header overlap the calendar title; the final full-page capture starts at the top.

An initial broad run had **103 passed, 4 skipped, 79 deselected and one failure**: `test_recorded_practice_through_real_publish_worker[sqlite]` received HTTP 503 at track upload. A direct native probe reports `VerifierUnavailable: Canonical verifier reported an engine error`. The same test fails at the same upload with this task's saved pre-change backend modules loaded via an isolated import hook. This baseline failure is retained in [backend-with-baseline-failure.txt](evidence/rivalry-planning-2026-10-18/backend-with-baseline-failure.txt), [native-baseline.txt](evidence/rivalry-planning-2026-10-18/native-baseline.txt) and [native-probe.txt](evidence/rivalry-planning-2026-10-18/native-probe.txt). The final regression excludes that independently reproduced native-publication failure. No invariant was weakened or original game source changed.

The configured disposable PostgreSQL port `localhost:55439` is unavailable, and the existing Docker command could not reach a server. PostgreSQL-only checks were not run; [availability receipt](evidence/rivalry-planning-2026-10-18/postgres-availability.json). Load behavior with a production-sized catalog, selection-weight acceptance and owner workflow acceptance remain.

## Checkpoint and rollout

`docs/evidence/rivalry-planning-2026-10-18/before/` contains pre-edit existing sources. `task-only.patch` and `checkpoint.json` provide a reviewable source checkpoint and hashes without committing the large unrelated working tree. New schema, backend, worker and UI must roll out together after migration 0043. The existing worker maintains the horizon; no additional scheduler/service is required. Startup/rollover can take up to its next one-minute maintenance check; shortage or unavailable worker/verifier conditions remain visible.

No production database mutation, backend/UI deployment, APK/export/install, phone attachment check or physical-device test was performed. No external provider or notification service was added.
