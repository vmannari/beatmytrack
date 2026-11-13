# Multi-car World Ranking — 7 November 2026

The owner authorizes implementation of separate rankings for every playable car and one combined overall ranking, with dynamic weight for popular and competitive car fields. This is a local implementation; no service, account, device, APK or production database was changed.

## Requirements and behavior

| ID | Implemented behavior |
|---|---|
| MCW01 | Rally/Compact, Kart, Forklift, Volt and Hover each have an official five-track weekly Circuit and their own World/Country/Friends/Season standings. Skill cohorts share that car's pinned lineup. Retired cars are not reintroduced. |
| MCW02 | Distinct eligible non-artificial accounts with five verified weekly finishes supply the participation history. Eight previous calendar weeks are weighted oldest-to-newest at 1 through 8; absent/unpublished weeks count as zero. The participation bonus approaches a maximum 25%. Retries do not add participants. |
| MCW03 | Opposition strength uses prior car ability estimates with confidence from distinct completed competitive weeks. New cars borrow a shared skill seed; eight established weeks preserve car specialties. Ratings and ranking points are separate. |
| MCW04 | Each car counts its best 12 awards from 26 calendar weeks, and best six within a 13-week season. Overall counts the strongest three car totals at 100%, 40% and 15%. Missing cars do not dilute existing scores. Exact ties retain shared sporting positions. |
| MCW05 | The Garage newspaper and ranking details offer Overall plus the five playable cars, bounded pages/results, contribution breakdowns, current announced bonuses and entry into the selected car's Circuit. Garage selection is preserved. Cache identities and late-response fences include car/account scope. |
| MCW06 | Existing leases, foreground queue guard, one low-priority worker connection and atomic publication remain. Per-car archives support retry, expiry and scoped corrections; historical country and announced weights are preserved. A later published correction can change a future week's participation history. |
| MCW07 | Additive migration 0076 preserves legacy Compact history and refuses a populated downgrade. Administration exposes car scopes and participation receipts; preview/confirmation retain the selected scope. Matching API, worker and client deployment is required. |

## Exact scoring policy

The new policy is `multi-car-circuit-v2`; existing opened `compact-circuit-v1` weeks retain their original calculation. Prepared future weeks can adopt v2; opened lineups, contracts and car rosters stay pinned.

For eight oldest-to-newest qualified populations `n[i]`, let `U = sum((i+1) * n[i])`. The participation multiplier in basis points is:

```text
participation_bps = 10000 + floor(2500 * U / (U + 36000))
```

This is a weighted weekly mean with a half-bonus reference of 1,000 qualified accounts. A constant 100 / 1,000 / 4,000 weekly accounts gives multipliers 1.0227 / 1.1250 / 1.2000. The reference and smoothing are balance choices, not production calibration.

The announcement reads the latest published generation available at that week's opening, restricted to its published prefix and the preceding eight calendar weeks. The first admission stores the multiplier, population units and source snapshot for every prepared car. Closed generations published late cannot rewrite that announcement. Corrected histories affect later openings, while past awards retain their earned value. Legacy official Compact populations can contribute to the history; ordinary old Rivalries are not backfilled.

Every class first ranks its complete population on each of five tracks using exact doubled average places. The five-place sum and sorted track places determine weekly position, preserving ties. The existing full-field podium/tail curve supplies base awards of 1,000 / 850 / 775, then `isqrt(56250000 // (place+96))`.

```text
evidence_bps = isqrt(min(max(field_size-1, 0), 127) * 100000000 // 127)
strength_bps = clamp(10000 + 2 * (mean(confidence_adjusted_seed)-1500), 8000, 12000)
award = floor(base * evidence_bps * strength_bps * participation_bps / 1000000000000)
```

A solo field earns zero; other positive awards have a one-point floor. This replaces v1's embedded linear small-field scaling, rather than multiplying that old result a second time. Evidence limits very small fields, opposition strength represents their established competitive level, and the bounded trailing participation bonus reflects popularity. Maximum weekly award is 1,500, car total 18,000, overall total 27,900, and overall season total 13,950.

The auxiliary ability estimator uses quantized logistic expected outcomes against a bounded histogram of the actual car field, averaged over opponents. It updates once per completed competitive week, with gain 80 for the first four weeks and 40 thereafter, ratings bounded to 500–2,500. Confidence grows over eight competitive weeks; evidence older than the 26-week window expires. It is an Elo-style heuristic with provisional cross-car seeds, not a full TrueSkill implementation or a validated measure of absolute ability. Sparse/disconnected populations remain uncertain. It needs real population calibration before public competitive acceptance.

Overall totals are rounded down once after combining the three contributions. Exact hundredths and the counting car sporting records provide deterministic countback. Car names stabilize presentation only and cannot decide an overall sporting tie. Trying a low-scoring car cannot dilute an existing overall score. Expiry risk recomputes the best three after each car's oldest week leaves, allowing another car or reserve award to take over.

## Implementation and limits

`world_ranking_car_models.py`, `world_ranking_car_rules.py`, `world_ranking_cars.py` and `world_ranking_car_reads.py` provide the new tables, arithmetic, restartable phases and bounded reads. Existing `world_ranking_build.py` dispatches by policy behind the same lease/publication fence. Numeric indexes support player-range batches; class skill histograms are computed once, and all-car history batches share the original configured work budget. There is no all-player pairwise join and no canonical physics work in ranking settlement.

The existing current/previous publication retention and compact private archives remain. New car standings retain only current/previous or necessary staging generations; hot awards retain the existing rolling window plus recovery margin. Corrections rebuild original archived sporting inputs, preserve original published countries, and replace the publication atomically. Original private archive references remain visible to the existing object garbage collector.

`GET /v1/ranking`, `/v1/ranking/me` and player profiles accept `vehicle_id=overall` or a known car. Cursors pin car/scope/viewer/country/generation. Profile breakdowns contain at most eight car summaries and 26 selected-car results. Overall profiles explain contributions without inventing a combined weekly race position. [Wire schema](schemas/world-ranking-v2.schema.json). The bootstrap advertises version 2; legacy responses remain readable until the first multi-car publication.

The native controls retain existing account/safety cancellation, paging and close behavior. Official entry pins a separate session car and leaves the Garage preference intact. Three free Circuit resumes per attempt extend to every official car; test populations remain excluded. Ranking changes do not modify physics, driving inputs, car assets, ordinary race summaries or authored tracks.

## Validation record

Evidence is in [the task directory](evidence/multi-car-world-ranking-2026-11-07/). It includes original failures, final logs, native captures, baseline controls, a [source manifest](evidence/multi-car-world-ranking-2026-11-07/source-manifest.json) and a [task-only review patch](evidence/multi-car-world-ranking-2026-11-07/task.patch). The 47-file patch passes a forward application check in an isolated review tree and reverse/whitespace checks against the current workspace; no patch is applied to the shared tree.

| Check | Actual result / receipt |
|---|---|
| Backend ranking, Rivalry, planners, completion, awards, appearance, resumes/recovery wire, runtime-role and Studio regressions | **128 passed, 1 skipped, 96 deselected**; `backend-supported.log`. PostgreSQL and the independently failing native sticker catalogue comparison are excluded explicitly. Real pinned-engine rewind and saved-journal checks pass with normal Windows access and disposable profiles. |
| New native ranking, validators, cache/car/account fences and real App entry | **26/0 headless**, **32/0 Compatibility**, **32/0 desktop Mobile**; final UI logs. Native captures cover Overall, contributions, Volt history and both newspaper sizes. |
| Existing newspaper and scope presentation | **54/0** and **18/0** headless after the compact layout fix; `test_ranking_newspaper-final2.log`, `test_news_ranking_scope_style-final2.log`. Publication status shares the table-heading row; two full standings rows fit at 960x540 while touch controls retain 52px minimums. |
| Existing native client regressions | World Ranking **25/0**, car switching **40/0**, App **141/0**. The car-switch profile guard first rejected an incorrectly located disposable profile; rerunning within its required `build/rivalry-car-switch` test root passes. |
| Admin ranking page | Offline browser **7/0**, no page errors; mocked reads and preview, selected Volt scope preserved into confirmation, no correction applied. `admin-review.json` and three PNGs. |
| New translations | **156/0** catalogue/template and placeholder checks; 12 new messages in 12 languages, existing entries preserved. |
| Targeted Python style / patch whitespace | Ruff passes; task patch whitespace and forward/reverse application checked. |

The backend command uses `.tools/backend-venv/Scripts/python.exe -m pytest` against `test_world_ranking_cars.py`, `test_world_ranking.py`, `test_rivalry.py`, `test_rivalry_planning.py`, `test_rivalry_week_completion.py`, `test_rivalry_awards.py`, `test_rivalry_appearance.py`, `test_resumes.py`, `test_resume_recovery_wire.py`, `test_runtime_privileges.py` and `test_studio_review_fixes.py`, with `-m "not postgres" -k "not postgres and not test_catalog_matches_native_assets" -q --tb=short --maxfail=3`.

Godot commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/<name>.gd -CommandTimeoutSeconds 180`, isolated `APPDATA` and empty `BMT_API_URL`. New UI captures add `-Graphical -RenderingMethod gl_compatibility` or `-RenderingMethod mobile`. The pinned engine is `4.7.2.stable.official.ed1daf0bf`; Mobile here means the desktop Vulkan renderer, not a physical device. Ruff uses the existing `.tools/backend-secure-venv/Scripts/python.exe -m ruff check` with the changed ranking/domain/admin/migration/test files.

SQL tests exercise actual phased settlement and atomic publication, 1/16/127/128-driver evidence boundaries, sporting ties, scoped correction and country restoration, frozen announcements versus later corrections, official admission/free resumes, shared skill seeds, archive failure/retry, multi-week car switching, 26-week expiry, migration/model agreement and populated downgrade refusal. No performance claim follows from these small SQLite fixtures.

Initial attempts retained in the evidence include a generated migration type-resolution error (corrected with explicit frozen FK types), Windows script-policy/certificate-store denials (rerun with the standard wrapper and isolated profiles), two legacy fixtures using inconsistent clocks (pinned consistently without weakening their assertions), compact newspaper clipping findings (corrected without reducing the existing two-row assertion), and a missing Playwright headless-shell binary (an installed Chromium was reused without downloading software).

The full localization catalogue currently has 6,823 unrelated stale/missing-entry errors. Before/after per-language counts are identical in `localization-baseline.json`; the 12 new ranking messages are translated and placeholder-checked in all 12 supported languages, with 156 catalogue checks including the template. Other authors' translations and work are retained. A concurrent lighter-car quality description added after the locale snapshots is preserved and excluded from the task patch; `localization-task.json` checks every shared entry and all new ranking placeholders.

The broader regression also exposes an existing 12-sticker backend/native catalogue mismatch. The global script parser reaches an existing `test_menu_quality.gd` override whose `_start_race` signature differs from the already-changed parent; this task does not change that parent method. These findings are kept separately from targeted ranking verification. The configured PostgreSQL test service at localhost:55439 timed out; PostgreSQL grants, execution and scale have not been qualified.

No phone/tablet attachment query or device test, APK export/install, live service request or deployment, owner-save/process manipulation, or main-index staging/commit was performed. Owner/device acceptance, PostgreSQL/capacity qualification and matching migration/API/worker/client rollout remain. The older million-player Compact measurements are not multi-car performance evidence.


## Rollout and remaining acceptance

1. Qualify migration `0076_multi_car_world_ranking` against the deployed PostgreSQL revision chain; its predecessor `0075_receipt_reference_indexes` was already concurrent workspace work when this task began. Review/apply the matching runtime-role grants for all nine new tables.
2. Drain the old ranking worker at an idle lease boundary, then roll out matching API and supervised worker code. Publish the matching client. Do not run an old worker against v2 work phases.
3. Retain the existing configured launch week. If ranking is disabled (`0`), announce a future Monday through the existing launch controls after qualification. Prepared future weeks adopt v2; already-opened legacy weeks preserve their pinned policy. The first new car's weights start neutral when no qualified history exists.
4. Verify all five pinned lineups and ticket contracts, selected-car resumes, worker retry/publication, cursors and correction preview in staging. Calibrate the 1,000-driver bonus reference and provisional strength estimator with representative populations before accepting competitive balance. Measure bounded worker/API behavior on PostgreSQL at the intended population.
5. Review the native captures and test entry, car switching, contribution explanations and the compact newspaper on the target Android device after an explicitly authorized build/install. No such build or deployment was performed here.

The scoped patch excludes unrelated concurrent header-capture changes in `game/core/app.gd`, pre-existing bootstrap work outside the capability version, concurrent lighter-car localization, generated build identity and other authors' changes. Current source and initial working-tree records are preserved; the main Git index is untouched.
