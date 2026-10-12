2026-10-07 reference correction: [current presentation and actual checks](RIVALRY_REFERENCE.md) supersede this pass's visible test labels/footer, text-only podium and browsing lap labels. Backend automatic driving and isolation below remain.

# Weekly Rivalry hub and automatic backend drivers - 2026-10-07

The owner requests test drivers without a separate enable step, actual backend races/results, and a reference-led championship menu that exposes all five circuits immediately. This supersedes the former `TEST RIVALS: OFF / ON` interaction for the development slice. AAA is the visual target; owner and physical-device acceptance remain required.

| Requirement | Behavior |
|---|---|
| WR01-WR02 / WR09 / R01 / V03-V05 | Overview is the race hub: five visible circuit rows, scenic thumbnails, own rank/PB/points or an explicitly labeled verified leader time, selected yellow Race action and a direct Race control on each row. Selecting a circuit persists through navigation. Tracks retains larger route previews and now also has direct Race actions. Standings is a distinct expanded table with the overall player target. |
| WR08 / WR09 | Completed-week Overview uses the same podium, all-driver table and five track results, followed by Continue to the next week. Normal race results/PB/lap analysis still come first; Continue opens weekly feedback. |
| TD07-TD08 / WR03-WR07 / B01-B07 | A signed-in debug client automatically selects a service advertising enabled test drivers and creates/loads its development membership. No test-rival switch remains. The authenticated join's optional `automatic_test_drivers` field enrolls persistent artificial drivers to a target of 14 total members, still capped at 20. Existing filled groups can also be adopted for automatic driving. |
| TD02 / TD05 / TD08 / Q01 | The backend verification worker drives one canonical attempt at a time when the ordinary verification and track queues are empty. It records quantized controls, requests an ordinary rivalry ticket, uploads the replay and subsequently verifies it. Later attempts retain the existing weekly activity schedule. No time, PB, points or ghost is created by enrollment. |
| TD06-TD08 | Existing development/server configuration gates remain. Artificial identities, boards and results stay labeled and separate from public rankings, rating/eligibility data and real championships. Disabling development test drivers still rejects their existing sessions. Release clients use the real population. |

The worker discovers marked current-week groups automatically; there is no PC watcher or per-user fixture-fill command for this path. A human entering the next week/car/build creates or joins the matching group, which the worker then discovers. This does not pre-create weeks without entrants. It supports the five ordinary vehicle contracts; the live acceptance below uses compact.

Plans and recordings use bounded ordinary files beside the backend object directory. The same group/profile/week/track/attempt always has the same upload key. Losing an ephemeral worker filesystem regenerates the same first recording and recovers the original committed upload without adding a second run. Canonical generation observes cooperative worker shutdown. A worker only services groups compatible with its own full build and selected vehicle configuration. Missing/slower/rejected results are never promoted to wins. Quiet profiles may leave a circuit unplayed and controller noncompletion remains visible in the plan.

The API addition is optional and does not need a database migration of its own. Existing join requests keep their old idempotency request body when the new flag is absent/false. The snapshot/schema adds the optional boolean `automatic_test_drivers`. Internal group slot metadata marks automatic scheduling without changing road data, gates or the simulation. Test-driver names have unique server usernames; the menu presents their readable name beside the persistent TEST label.

The retained Google Cloud environment was already explicitly configured for development authentication/test drivers. The task updates that owned staging environment, preserving its database, historical recordings/links, secrets and current resource limits. The existing updater takes a successful fresh SQL backup, checks an empty old queue, migrates the current schema, updates matching API/worker/jobs, validates native replay/storage/worker health, and adds compatible immutable official-track revisions. A frozen source copy avoids including later concurrent workspace edits in the rollout. This task does not modify canonical handling, physics, road geometry or camera; the backend image includes the existing current `arcade-planar-0.52`, compiler 22 and gates v19 so the app and verifier agree.

## Changed files

- Backend: `bmt_backend/automatic_test_drivers.py`, the optional join/snapshot addition in `rivalry.py`, idle dispatch in `worker.py`, generator shutdown in `test_driver_generator.py`, generator injection and internal worker-origin support in `test_population_tool.py`, the optional internal URL setting in `config.py`, and PC worker origin in `deploy/compose.pc.yaml`.
- Client: `game/backend/weekly_rivalry_client.gd`, `game/ui/weekly_rivalry_page.gd`, rivalry signal integration in `game/core/app.gd`, and readable artificial names in `game/race/weekly_rivalry.gd`.
- Checks: new `backend/tests/test_automatic_test_drivers.py`, the real HTTP peer origin in `backend/tests/test_cloud_client.py`, and native weekly/test-driver menu/HTTP/live fixtures.
- Contracts/documentation: `docs/schemas/weekly-rivalry-v1.schema.json`, this document, `WEEKLY_RIVALRY.md`, `TEST_DRIVERS.md`, project instructions/status/phase plan and the scoped patch/evidence.

Existing original winter/biome artwork, fonts and menu icons are reused. The owner's supplied results image is guidance and is not a shipping asset. No new image generation, external dependency or runtime AI call is introduced.

## Actual checks

Godot uses exact 4.7.2 stable ed1daf0bf through `scripts/dev.ps1`; Python uses `.tools/backend-venv/Scripts/python.exe`.

| Actual command | Outcome |
|---|---|
| `TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical` | Final 1,091 checks, zero failures; Overview/Tracks/Standings/detail/pending/results/finale/forming/sign-in at 1280x720, 960x540 and 1600x720. All five circuit choices fit without scrolling, every row launches its own selected circuit, and touch targets remain at least 48 logical pixels. |
| `TestScript -ScriptPath res://tests/test_test_driver_menu.gd -Graphical` | Final 503 checks, zero failures; actual canonically verified 14-driver HTTP fixture, permanent test notice, no enable selector, four sections/three dimensions. |
| `-m pytest backend/tests/test_automatic_test_drivers.py backend/tests/test_test_drivers.py backend/tests/test_rivalry.py backend/tests/test_worker_lifecycle.py -k 'not postgres' -q --tb=short --show-capture=no` | Final 41 passed, four skipped, 15 deselected. Includes a real idle worker's canonical five-lap recording, queued proof priority, verification, derived ghost, zero public population, identical upload recovery after loss of plan/cache, idempotent enrollment and disabled gates. PostgreSQL-specific checks are not claimed passed. |
| `-m pytest backend/tests/test_rivalry_http.py -q --tb=short --show-capture=no` | Final five passed. Native real race/upload/verification, normal results before weekly feedback, immediate Continue, expired access and same-/cross-process restoration all retain the player session. |
| `TestApp` | 99 checks, zero failures. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | Final 327 scripts, zero failures. |
| Ruff over the four new/affected driver source/test files | Passed. |
| `Doctor` | Exact engine and matching templates found; DN2103 attached. No physical-device gameplay/UI test, export or install was performed. |

Corrected intermediate failures are retained in the work record: Windows user-log/certificate sandbox access; a generator default captured before monkeypatching; loss of new Unicode glyphs through Windows stdin encoding; footer overflow in the completed-week view; unique artificial username collisions; a board's per-vehicle manifest compared with a full generator manifest; and the older native test helper advertising `localhost:8080` instead of its actual isolated HTTP listener. The session tests passed after correcting that peer origin; no scoring, replay, touch-size or timing assertion was removed to make them pass. Existing httpx/Starlette deprecation warnings remain.

Visual evidence: [Overview](evidence/rivalry-hub-2026-10-07/ui/overview-1280x720.png), [compact Overview](evidence/rivalry-hub-2026-10-07/ui/overview-960x540.png), [Standings](evidence/rivalry-hub-2026-10-07/ui/standings-1280x720.png), [completed week](evidence/rivalry-hub-2026-10-07/ui/weekly-finale-960x540.png). These layout captures are explicitly labeled concept fixtures. [Verified field](evidence/rivalry-hub-2026-10-07/verified-fixture/overview-1280x720.png) uses the retained genuine backend-verification fixture. Live staging acceptance passes 26 native checks with zero failures, including automatic membership, actual standings, verified ghost download/end bounds, real race-ticket issue and eight screenshots: [live Overview](evidence/rivalry-hub-2026-10-07/live/live-overview-1280x720.png), [compact Overview](evidence/rivalry-hub-2026-10-07/live/live-overview-960x540.png), [live Standings](evidence/rivalry-hub-2026-10-07/live/live-standings-960x540.png).

Remaining acceptance: owner visual/interaction approval, physical-phone readability/input/performance, other-car pace calibration, long-running contention/capacity and week turnover. Full physics regression/Validate, Android export/install and production deployment are not performed by this task.

## Retained staging outcome

The frozen current image rollout completed successfully, including fresh SQL backup `1791388723672`, existing schema migration, matching API/worker/jobs, replay/storage/readiness checks and immutable official-track revision refresh. [Deployment receipt](evidence/rivalry-hub-2026-10-07/deployment.json). The 41 staged canonical scripts still match the current workspace byte for byte. Existing resource counts/limits and development/Google separation are retained.

A fresh isolated observer joined Week 41 automatically with 13 persistent artificial rivals. The backend worker, without any PC watcher, delivered verified finishes on all five selected circuits: Dust cloud, Spiral, Silmukka, Starter Circuit and Narrow night. The first all-five acceptance recorded 4/3/1/1/5 distinct verified artificial drivers by circuit; this is 14 verified driver/circuit PBs, not completion by every profile. The worker keeps servicing scheduled attempts. [Actual field](evidence/rivalry-hub-2026-10-07/live-field.json) and [bounded progress check](evidence/rivalry-hub-2026-10-07/live-progress.json) retain exact server values. Normal public rankings are not populated by these runs.

The existing reserved Development username returned `USERNAME_TAKEN` during an initial operator probe, as in the preceding cloud-driver work. Acceptance therefore uses a fresh `rivalry-hub-observer` development identity and isolated app storage; no existing Google/Development account was renamed or its saved session read. Google clients use their own existing sign-in and are automatically enrolled when opening the updated rivalry. The actual owner Google session was not used for this test.

`TestScript -ScriptPath res://tests/test_automatic_rivalry_flow.gd` passes seven checks: initial entry, no repeat enrollment, adoption of a manual field, preservation of an older completed week, automatic entry after Continue, disabled-service fencing and malformed-marker rejection. This tests lifecycle responses; actual calendar-week turnover and broader population/performance acceptance remain pending.

Review checkpoint: [scoped source patch](evidence/rivalry-hub-2026-10-07/scoped-change.patch), rebased on the saved task-start source and latest unrelated changes in shared files. Reverse applicability and targeted whitespace checks are recorded. The mixed working tree is preserved; no combined Git commit is made.
