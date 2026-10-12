2026-10-09 follow-up: overview rows/arrows now open track detail; races start there and Back to Rivalry returns to the hub. Removed redundant section tabs and overview race starts. See [current navigation and actual verification](RIVALRY_NAVIGATION.md).

2026-10-07 follow-up: automatic development membership/backend driving and the five-track Overview supersede the manual test-rival switch and older Overview guidance below. See [current behavior and actual verification](RIVALRY_HUB.md).

# Weekly Rivalry — 2026-10-04

The owner authorizes a championship inside **Race**, selected with the left trophy icon. The confirmed defaults are five tracks, groups of roughly 10–20 real drivers, and Monday 00:00 to the following Monday 00:00 UTC. Shared typography, navy panels, original scenic art, yellow actions and the fixed Race/Create/Garage header connect it to Free Race; championship status and targeted rival gaps distinguish its purpose.

| Requirement | Implemented behavior |
|---|---|
| WR01 / R01 / V03 | Trophy opens Weekly Rivalry inside Race; flag returns to Free Race. Race remembers its selected mode. Overview contains tracks and standings; rows/arrows open detail, where Race starts. Back to Rivalry returns to the hub; no section tabs remain. Existing page swipes and fixed header remain. |
| WR02 / V04 / V05 | Overview presents the podium, five visible tracks and scrollable standings for up to 20 drivers. Detail shows the route, four nearby drivers, next rival, ghost choice and Race action. Completed-week overview retains Continue. |
| WR03 / B01–B07 | Authenticated server memberships, pinned immutable track versions and vehicle/build contracts. A player joins at most once per week and contract. Random selection without replacement gives five tracks; random assignment chooses among open groups in the same skill band, capped at 20. |
| WR04 | Recent comparable verified PBs determine pace: median percentage of drivers beaten on up to 20 boards in 90 days, with at least three boards containing five drivers. Ten percentile bands keep known-skill drivers near their pace. Insufficient history uses an explicitly labeled placement pool. No client-supplied skill. |
| WR05 | Community eligibility requires rating **strictly above 4.0 AND strictly more than 100 distinct verified finishers** on the selected version. Multiple boards/attempts do not duplicate a driver. Official Beat my track tracks bypass popularity thresholds, with server-owned provenance. Published, visible, compatible tracks and active creators are required in either case. Latest published versions are selected; revisions stay pinned for the week. |
| WR06 / T01–T04 | Only a completed, canonically verified, weekly ticket-bound race changes the weekly PB. Scores use each track's best result; unlimited retries and slower results award no extra points. Equal ticks share rank and points. Overall points sum five track scores. |
| WR07 / GH01 / RW03 | Detail targets the rival ahead, weekly leader, own weekly PB or no ghost. Race Again refreshes the selected target's latest verified recording. Ghost poses come from server replay verification, not client uploads; no raw opponent inputs are exposed. Recorded positions include bridge/jump/kerb height, rewind branches and fractional endpoints, with bounded interpolation and no extrapolation. |
| WR08 / Q01 | Every rivalry race first opens the normal results summary with all-time PB feedback and lap analysis. Continue immediately shows provisional weekly position/gap/points from loaded standings, then replaces them with verified feedback. Verification cannot interrupt the summary. Pending verification remains visibly pending. Ended weeks settle queued races before the Overview finale; Continue acknowledges the completed week. Account/server/car changes fence old requests and snapshots. |

New groups form from actual entrants. Below ten drivers the UI says the group is forming; it never invents rivals or their times. Five eligible tracks are mandatory: otherwise join returns `NOT_ENOUGH_ELIGIBLE_TRACKS`. A new entrant starts without weekly times even if an all-time PB exists. Matches are per vehicle and pinned build, avoiding a car change becoming an advantage on a shared board.

The initial proposed track points are `30,26,23,20,18,16,14,12,10,8,6,4,2,1,1,1,1,1,1,1`. This is configurable balance code for review, not an approved progression economy. Divisions, promotion, rewards, PB-count awards and claims are not fabricated: no division progression system has been agreed. The finale reports actual rank, track wins and completed tracks and offers Continue.

Tickets expire after two hours or at week end, whichever comes first. Upload must reach the server before expiry; a timely upload can finish verification after week end. Expired unuploaded tickets are terminal. Periodic menu refresh is every 30 seconds. Pending results use a 0.5-second scheduler, including during the normal summary, with one request in flight and bounded backoff for longer waits or connection failures. The existing durable outbox retains finished uploads across connection loss. Rivalry requires authentication and online ticket creation; no offline rivalry scores are inferred.

## Changed files and contracts

- Backend domain/API: `backend/bmt_backend/rivalry.py`, `rivalry_models.py`, `app.py`, `tracks.py`, `track_models.py`, `official_tracks.py`, `worker.py`, `maintenance.py`, `verifier.py`, `runs.py`, migration environment and `migrations/versions/0011_weekly_rivalry.py`.
- Server packaging: `backend/deploy/stage_verifier.py` now includes the pure bridge elevation sampler and personal recording class. The run-response bound is 8 MiB for bounded ghosts; track-result bounds and canonical frame limits remain unchanged.
- Client: `game/backend/weekly_rivalry_client.gd`, `cloud_tracks.gd`, `runner.gd`, `game/race/weekly_rivalry.gd`, `game/ui/weekly_rivalry_page.gd`, `race_mode_rail.gd`, `track_browser.gd`, `game/core/app.gd` and generated Godot UIDs.
- Shared presentation: `game/track/bridge_elevation.gd` extracts the existing pure height sampler verbatim. `bridge_presentation.gd` inherits it; the existing `personal_ghost_run.gd` parameter accepts that base. Mesh construction and canonical driving are unchanged.
- Tests: `backend/tests/test_rivalry.py`, `test_rivalry_http.py`, `test_rivalry_concurrency.py`, `fixtures/weekly_points_v1.json`, the preparation hook in `test_cloud_client.py`, `game/tests/test_weekly_rivalry.gd`, `test_weekly_rivalry_http.gd` and the historical start setup in `test_cloud_tracks.gd`.
- Contracts/evidence: [snapshot schema](schemas/weekly-rivalry-v1.schema.json), this document, deployment README, project instructions, status/plan entries and `docs/evidence/weekly-rivalry-2026-10-04/`.

Authenticated endpoints are `GET /v1/rivalry/current?vehicle_id=…`, `POST /v1/rivalry/join`, `GET /v1/rivalry/{group}`, `POST /v1/rivalry/{group}/tickets`, `GET /v1/rivalry/tickets/{ticket}/result`, `GET /v1/rivalry/{group}/tracks/{slot}/ghosts/{driver}`, and `POST /v1/rivalry/{group}/continue`. Writes require the existing idempotency key. A nonmember cannot read a group or ghost; results belong to their ticket owner. Snapshot, enrollment and verification share group locks for coherent PostgreSQL views.

Capacity reservations use a conditional atomic SQL increment and commit with membership; this preserves the 20-driver cap on SQLite, where row-lock syntax has no effect. The PostgreSQL skill-bucket lock also serializes new group creation.

Migration `0011_weekly_rivalry` adds four tables, `tracks.official` and `runs.ghost_hash`. Historical official provenance comes from the reserved development identity `developer`, not the display name. Operator seeding and future uploads by that identity set the flag; clients cannot set it. Weekly best runs/ghosts are protected by reference-aware retention. Weekly groups and ticket outcomes currently remain retained; a separate historical-season retention policy is not implemented.

## Actual verification

All Godot commands used the pinned **4.7.2 stable ed1daf0bf** via `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Python used `.tools/backend-venv/Scripts/python.exe`.

| Actual command suffix | Outcome |
|---|---|
| `TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical` | Final **791 checks, zero failures**. Nine states at 1280×720, 960×540 and 1600×720; 27 screenshots. Button targets, viewport bounds, clipped footer, navigation, ties/points fixture, unranked 20-driver field, unavailable ghosts and malformed response checks. |
| `-m pytest backend/tests/test_rivalry.py backend/tests/test_official_tracks.py -k 'not postgres' -q --tb=short` | Final **13 passed, nine deselected**. Strict thresholds, trusted official provenance, five unique tracks, capped membership/rejoins, skill pools, privacy, idempotency, ties, queued/slower scores, settlement/expiry and a retained five-track scoring golden fixture. |
| `-m pytest backend/tests/test_rivalry_http.py backend/tests/test_verifier.py -q` | **58 passed**. Actual authenticated native game race → durable upload → canonical verification → points → derived ghost → fresh retry ticket → sign-out fencing. Also includes standalone staged verifier and completed 216,000-frame recording. |
| `-m pytest backend/tests/test_rivalry_http.py -q -s --tb=short --log-level=WARNING` | Final **one passed**, **17 native checks**, including refreshed own-weekly-PB ghost on retry. |
| `-m pytest backend/tests/test_rivalry.py backend/tests/test_official_tracks.py backend/tests/test_rivalry_http.py -k 'not postgres' -q --tb=short` | Final **14 passed, nine deselected**, after the atomic capacity reservation change. |
| `-m pytest backend/tests/test_rivalry_concurrency.py -q --tb=short --show-capture=no` | **One passed**. 21 concurrent newcomers plus one existing entrant in a disposable file-backed SQLite database retain groups ≤20, with exact membership/count agreement. |
| `-m pytest backend/tests/test_rivalry.py backend/tests/test_domains.py backend/tests/test_resumes.py backend/tests/test_official_tracks.py backend/tests/test_maintenance.py backend/tests/test_review_followups.py -k 'not postgres' -q` | **58 passed, 56 deselected** before the additional capacity/provenance cases; migration, existing domains/resumes/retention and canonical follow-ups pass. |
| `-m pytest backend/tests/test_rivalry_http.py backend/tests/test_cloud_client.py -q --tb=short` | Weekly integration and track lifecycle passed; historical normal cloud race fixture initially failed. Corrected its recorded start; final `test_cloud_client.py::test_cloud_library_against_http` rerun **one passed**, including actual Free Race, rewind upload and qualified ratings. |
| `TestApp` / `TestMenus` / `TestBridgeContacts` | **96 / 48 / 16 checks**, zero failures. |
| `TestScript -ScriptPath res://tests/test_personal_ghosts.gd` | **38 checks**, zero failures; three existing shutdown instance warnings. |
| `TestScript -ScriptPath res://tests/test_menu_page_swipe.gd` | Headless **100 checks**, zero failures. |
| `CheckScript -ScriptPath res://core/app.gd` | Passed, exit 0. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | **277 scripts**, zero failures. |
| `Doctor` | Pinned engine/templates found; **DN2103 attached**. No rivalry phone test, Android export/install or device driving performed by this task. |
| Ruff over backend/domain/tests/staging | Passed. |
| PostgreSQL `test_group_capacity_and_repeat_joins` | **One setup error**: configured disposable localhost PostgreSQL connection timed out. Concurrent enrollment is implemented/tested by that fixture but **not claimed verified** on PostgreSQL. SQLite sequential capacity/rejoin checks pass. |

Initial checks identified and repaired missing ghost dependencies in the staged verifier, its formerly too-small response bound, a stale v17 transition constant against the already-current v18 contract, and compact Overview/finale footer clipping. The Free Race replay fixture predates launch markers; after countdown/pause checks it now resets countdown observation and its input cursor to replay that exact historic start. Current launch rules and simulation were not weakened. An accidental `CheckScript` without `-ScriptPath` started the app and was interrupted; it is not a successful parse check. Sandbox engine certificate-store failures were resolved by authorized execution with Windows certificate access. FastAPI/httpx deprecation warnings remain.

Inspected evidence: [Overview](evidence/weekly-rivalry-2026-10-04/overview-1280x720.png), [Tracks](evidence/weekly-rivalry-2026-10-04/tracks-1280x720.png), [Detail](evidence/weekly-rivalry-2026-10-04/track-detail-960x540.png), [Standings](evidence/weekly-rivalry-2026-10-04/standings-1280x720.png), [Result](evidence/weekly-rivalry-2026-10-04/race-result-1280x720.png), [Finale](evidence/weekly-rivalry-2026-10-04/weekly-finale-960x540.png), [Forming group](evidence/weekly-rivalry-2026-10-04/forming-group-960x540.png). These use explicit synthetic UI fixtures; shipping never falls back to them. Existing cleared original menu atlas/backdrop assets are reused. The owner's reference board is not shipped.

Owner visual/gesture approval, real population balancing, PostgreSQL concurrency, real-Google/NAS acceptance and physical-device rivalry checks remain. Full Validate/physics regression, service rebuild/restart, deployed DB migration, production deployment and live player-data seeding were not performed. The additive migration and matching API/worker image are required before an existing service can serve this mode. A scoped Git patch is retained for review; unrelated workspace changes are preserved rather than committed together.

Review checkpoint: [weekly-rivalry.patch](evidence/weekly-rivalry-2026-10-04/weekly-rivalry.patch). `git apply --reverse --check --ignore-space-change` and targeted `git diff --check` pass. The app/ghost/status baselines preserve concurrent work. Raw Godot test logs accompany the screenshots; Python outcomes above come from actual disposable-service test runs.

## Normal results first — 2026-10-04

The immediate-feedback follow-up below retains this normal-summary-first flow.

WR08 / R01 / T01–T04 / GH01 / V03 / Q01: the owner's follow-up requires the ordinary result before rivalry feedback. `game/core/app.gd` now routes completed rivalry races through the existing `RaceResults`, including local all-time race/lap PB recording and qualifying personal ghosts. A dedicated summary state prevents asynchronous verification from replacing that screen. Continue opens the weekly result, using the existing pending/verified feedback. Race Again retains the rivalry context and fresh-ticket flow; Free Race still continues to `RaceComplete`.

Changed files: app flow, `game/tests/test_weekly_rivalry_http.gd`, this document, `docs/PREMIUM_RESULTS.md`, `AGENTS.md`, both status documents and the dated evidence below. No backend contract or canonical simulation changes.

Actual verification with pinned Godot 4.7.2 stable ed1daf0bf:

| Actual command | Outcome |
|---|---|
| `$env:BMT_CAPTURE_CLOUD = Join-Path (Get-Location) 'docs/evidence/weekly-results-first-2026-10-04'; .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_rivalry_http.py -q -s --tb=short --log-level=WARNING` | One passed; **29 native checks, zero failures**. Real five-lap replay/upload/verifier, prior-PB fixture comparison, saved PB/ghost, summary retained after verification, interactive lap selection, Continue, points and fresh-ticket retry. Four screenshots. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py::test_cloud_library_against_http -q --tb=short --log-level=WARNING` | One passed, including actual normal Free Race results/Continue/upload and rewind. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp` | **96 checks, zero failures**. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | **277 scripts, zero failures**. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Pinned engine/templates and DN2103 found. Initial sandbox adb configuration access failed; authorized rerun passed. Device driving/installation was not performed. |

[Normal results](evidence/weekly-results-first-2026-10-04/normal-results-1280x720.png), [compact summary](evidence/weekly-results-first-2026-10-04/normal-results-960x540.png) and [weekly feedback after Continue](evidence/weekly-results-first-2026-10-04/rivalry-feedback-960x540.png) inspected. Captures use an isolated actual HTTP test account and pinned replay; the deliberately slower prior personal record is a test fixture. All actual points come from backend verification. Existing httpx/Starlette deprecation warning remains. No phone test, Android export/install, full physics regression, existing-service restart or deployment. Owner/device flow acceptance remains.

Follow-up checkpoint: [normal-results-first.patch](evidence/weekly-results-first-2026-10-04/normal-results-first.patch), based on the completed rivalry implementation with unrelated workspace changes retained. Reverse applicability and targeted whitespace checks pass.


## Explicit development populations ? 2026-10-04

The owner subsequently approved artificial test drivers. Normal rivalry membership still uses real entrants. Separately configured, clearly marked test rivalries can use persistent artificial profiles that drive the canonical simulation and upload genuine recordings through verification. Their boards, memberships, public-population exclusions, scheduler and migration `0012_test_drivers` are described in [TEST_DRIVERS.md](TEST_DRIVERS.md).

## Immediate result feedback — 2026-10-04

WR08 / WR06 / TD07 / R01 / V03–V05 / Q01: the owner reported an excessive wait in the rivalry result screen. Read-only inspection of the existing PC development PostgreSQL service found six human and 140 artificial-driver verifications over the preceding four hours: both averaged 5.7 seconds from upload acceptance to completion. The latest human verification took 11 seconds. These integer-second figures include queue and replay work; they do not isolate processing time or network latency. The client additionally polled only every five seconds and stopped periodic polling during the normal results summary.

The completed race now prepares its position, nearest newly beaten rival, track-points change and overall position immediately from the latest loaded server standings. Feedback is labeled **PROVISIONAL RESULT**, **EXPECTED TRACK POSITION** and **verification pending**. It uses canonical elapsed ticks for ties and the server points policy, including positions 15–20. Every affected rival's projected points are included in the overall comparison. A slower retry adds no projected points; a first finish can move from unranked. This projection changes only the transient result view: it never writes verified standings, weekly PBs, persistent rewards or backend scores. It does not invent opponents. Concurrent rival finishes or new membership can change the eventual confirmed result.

Replay verification continues during the ordinary PB/lap summary and the weekly feedback. A 0.5-second scheduler calls a single-flight poll with a 500 ms minimum request interval for the first 15 seconds, 2 seconds up to a minute and 5 seconds thereafter. Network failures back off at least five seconds and respect a longer server Retry-After. Polling alone leaves Race Again enabled. Confirmed outcome data reaches the view before the separate full-board refresh completes. Rejected, failed, expired or malformed confirmed results remove the provisional award. Account reset and replacement-ticket checks fence old responses. The existing durable upload, server verification, authentication, simulation, rules and fairness queues are unchanged.

Changed source files: `game/race/weekly_rivalry.gd`, `game/backend/weekly_rivalry_client.gd`, `game/core/app.gd`, `game/ui/weekly_rivalry_page.gd`, `game/tests/test_rivalry_feedback.gd` and its UID, `game/tests/test_weekly_rivalry_http.gd`, and `backend/tests/test_rivalry_http.py`. Documentation updates are this file, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The transient projection introduces no saved/API schema or golden-physics changes. [Scoped source checkpoint](evidence/rivalry-feedback-speed-2026-10-04/feedback-speed.patch) excludes pre-existing mixed-workspace changes; reverse-apply and whitespace checks pass. No mixed-tree commit was made.

Actual commands used the pinned `4.7.2.stable.official.ed1daf0bf` engine through `scripts/dev.ps1`. PowerShell script calls used `powershell -NoProfile -ExecutionPolicy Bypass -File`; Python calls used `.tools/backend-venv/Scripts/python.exe`.

| Command | Actual final outcome |
|---|---|
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rivalry_feedback.gd -Graphical` | **24 checks, zero failures**; 20-driver first finish/ties/slower retry/projection isolation, invalid time, single-flight polling, cooldown, network backoff, rejection, account and ticket fences, and two inspected full-menu captures. One measured preview calculation took **552 µs**. |
| `python -m pytest backend/tests/test_rivalry_http.py -q -s --tb=short --show-capture=no` before addition of the fifth scenario | **Four passed** in 74.29 s; 28/28/29/30 native checks. Normal, expired-access, second-client and separate-process session cases all confirm automatically while preserving the normal summary. Measured confirmation waits were **4.240, 4.498, 3.622 and 3.437 s**. No test-driven outbox flush or result poll is used in this wait. |
| `python -m pytest backend/tests/test_rivalry_http.py -k immediate_continue -q -s --tb=short --show-capture=no`, with `BMT_CAPTURE_CLOUD` set to this evidence directory | **One passed**, four deselected, in 20.17 s; **33 native checks**, zero failures. Five-lap canonical race, durable upload, immediate pending view, automatic confirmed replacement, updated board, ghost and retry. Continue built the view in **11 ms** and reached the next process frame in **22 ms**, passing the retained 250 ms desktop limit. Confirmation took another **2.996 s** after the two pending captures. Four HTTP captures inspected. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd` | **764 checks, zero failures**. |
| `scripts/dev.ps1 -Action TestApp` | **96 checks, zero failures**. |
| `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **288 scripts, zero failures**. |
| `scripts/dev.ps1 -Action Import` | Pass; new test UID generated. |
| `python -m ruff check backend/tests/test_rivalry_http.py` | Pass. |
| `scripts/dev.ps1 -Action Doctor` | Pinned engine/templates found; DN2103 and emulator-5554 attached. Device presence is not device acceptance. |
| `git apply --reverse --check --whitespace=error-all docs/evidence/rivalry-feedback-speed-2026-10-04/feedback-speed.patch` | Pass. |

Initial sandbox WSL access and Godot log-directory access were denied; narrowly scoped reruns with normal desktop access succeeded, without an automatic approval rejection. The first full HTTP run then had one stale-board assertion failure because confirmed feedback now precedes the board refresh. The harness now waits for that independent refresh before assessing Overview; it still verifies the real points and rank. An initial compact-screen assertion mixed physical window pixels with logical viewport coordinates; it now checks actual viewport bounds. Two graphical Continue measurements of 280/277 ms included the never-rendered race's first 3D shader compilation: the harness had driven all 12,757 canonical inputs before displaying the game once. It now renders the race and normal summary before measuring a real Continue interaction; the **250 ms limit was retained** and the final measurement is 22 ms. The Python HTTP runs retain one existing Starlette/httpx deprecation warning.

Inspected evidence: [20-driver pending comparison](evidence/rivalry-feedback-speed-2026-10-04/provisional-1280x720.png), [compact comparison](evidence/rivalry-feedback-speed-2026-10-04/provisional-960x540.png), [real HTTP pending result](evidence/rivalry-feedback-speed-2026-10-04/provisional-feedback-1280x720.png), [compact HTTP pending result](evidence/rivalry-feedback-speed-2026-10-04/provisional-feedback-960x540.png), [confirmed result](evidence/rivalry-feedback-speed-2026-10-04/rivalry-feedback-1280x720.png), [compact confirmed result](evidence/rivalry-feedback-speed-2026-10-04/rivalry-feedback-960x540.png), and [verification summary](evidence/rivalry-feedback-speed-2026-10-04/verification-summary.json). The 20-driver image is an explicit UI test fixture; HTTP screenshots use a disposable server and a real canonically verified single-human championship. Shipping uses actual downloaded membership only.

**No phone/emulator driving test, Android export or installation was performed for this change.** No live human run was submitted, service restarted, migration applied, NAS/production deployment or full physics regression performed. Existing user data and local services were preserved. Restart the PC game to load the client changes; the backend needs no rollout. Owner acceptance, physical-device latency and behavior during concurrent rival updates remain outstanding. The 22 ms and 552 µs values are separate desktop fixture samples, not mobile benchmarks or a server-verification speedup. Final standings still require replay verification.

## Immediate rivalry page on entry, 2026-10-09

WR01–WR03 / WR08 / TD08 / B05 / R01 / V03–V05 / Q01: the owner reported a different view appearing before the weekly status. An empty client model previously rendered the Join introduction while membership was unresolved, including during automatic enrollment. Prepared swipe pages could also retain that introduction after a background response.

The first signed-in frame now uses the championship's existing backdrop and standings/five-track layout with empty loading shapes and one loading status. Actual downloaded standings remain visible during refreshes. Join appears only for guests or a resolved nonmember/error state. Refresh starts before explicit navigation; offscreen and returning rivalry pages follow membership changes, and promotion rebuilds their content from the current model. Existing account/server/car scope fences remain active. No invented driver, time or score is displayed during loading. Concurrent removal of redundant section tabs and Overview race actions is preserved.

Changed files: `game/core/app.gd`, `game/ui/weekly_rivalry_page.gd`, `game/tests/test_rivalry_entry.gd` and its generated UID, this document, `DEVELOPMENT_STATUS.md`, and `docs/PHASE_0_PLAN.md`. This changes presentation/navigation only; no API/save schema, golden replay, canonical physics, scoring or population contract changes.

All successful Godot commands below used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with the pinned `4.7.2.stable.official.ed1daf0bf` engine.

| Actual action/arguments | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_entry.gd -Graphical -CommandTimeoutSeconds 60`, with `BMT_RIVALRY_ENTRY_CAPTURE_DIR` pointing to this evidence directory | Final **64 checks, zero failures**. Inspect the first frame and five subsequent frames with delayed responses, repeat refreshes, account changes, offscreen updates/page promotion, confirmed nonmembers, automatic enrollment, errors and guests. Four captures at 1280×720/960×540. |
| `-Action TestScript -ScriptPath res://tests/test_automatic_rivalry_flow.gd -CommandTimeoutSeconds 45` | **Seven checks, zero failures**; enrollment, finale and disabled-service isolation. |
| `-Action TestApp -CommandTimeoutSeconds 120` | **99 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -CommandTimeoutSeconds 120` | **1,196 checks, zero failures**, using the current concurrent menu correction. |
| `-Action TestScript -ScriptPath res://tests/test_menu_page_swipe.gd -CommandTimeoutSeconds 120` | **234 checks, zero failures**. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90` | **388 scripts, zero failures**. |
| `-Action Doctor` | Pinned engine/templates found; **OnePlus Pad 2 OPD2403, serial f0ba474a attached and authorized**. No physical-device test performed for this fix. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/rivalry-entry-2026-10-09/build_checkpoint.py`, `git apply --reverse --check --whitespace=error-all docs/evidence/rivalry-entry-2026-10-09/scoped-change.patch`, and targeted `git diff --check` | Seven-file task-only patch generated; reverse applicability and whitespace checks pass. |

Inspected [initial loading layout](evidence/rivalry-entry-2026-10-09/ui/loading-1280x720.png), [compact loading layout](evidence/rivalry-entry-2026-10-09/ui/loading-960x540.png), [resolved Overview](evidence/rivalry-entry-2026-10-09/ui/overview-1280x720.png) and [compact Overview](evidence/rivalry-entry-2026-10-09/ui/overview-960x540.png). Resolved screenshots use an explicit isolated UI fixture; shipping receives server data only. The loading screen contains no fixture values or new art assets.

Initial direct script invocation hit Windows execution policy; the documented process-scoped invocation succeeded. Sandbox Godot log/ADB directory access initially failed; normal desktop access succeeded without an automatic approval rejection. The first transition test accessed a neighbor before the existing menu slide completed; the fixture now finishes that slide before inspecting its prepared pages, retaining the immediate-entry/frame assertions. An initial `CheckScript` invocation omitted `-ScriptPath` and started the app instead of checking scripts; only its owned process was stopped and the dedicated parser fixture was run. These attempts are not counted as passed checks.

First entry after starting the app still requires a membership request; it displays the correct rivalry loading layout while awaiting actual data. No live backend race, device UI test, Android export/install, full Validate, backend rollout or production action was performed. Owner review on the attached tablet and real-network entry latency remain acceptance checks. [Scoped review checkpoint](evidence/rivalry-entry-2026-10-09/scoped-change.patch) preserves unrelated workspace changes.

The owner's subsequent correction removes even the empty first-load layout: authenticated membership now preloads, and the current menu remains visible until the first response is ready. Race mode pages transition vertically with stationary navigation. See [RACE_MODE_CAROUSEL.md](RACE_MODE_CAROUSEL.md) for the superseding behavior, actual commands, 70 entry/52 carousel checks, verified HTTP race and screenshots.
