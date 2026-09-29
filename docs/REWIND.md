# Rewind and resume — 2026-09-29

Owner scope (latest revision): rewind up to ten seconds, choose where to resume, at most three resumes per race. One free resume each day, no rollover. One resume per rewarded ad with unlimited ads per day. Purchased/otherwise awarded resumes never expire. The owner explicitly permits rewind-assisted leaderboard results; the corresponding override is recorded in `AGENTS.md`. Ordinary full-race restarts remain free and unlimited.

## Requirements and implemented behavior

| ID | Behavior |
| --- | --- |
| RW01 | Race HUD Rewind button / Backspace opens a paused world preview. Timeline selects exact saved simulation states at 0.1-second intervals within the last ten seconds, initially at the current state. Cancel restores the original state without spending. |
| RW02 | Confirm restores vehicle dynamics, collision/hazard/loose-prop state, ordered gates, elapsed time, completed laps and telemetry. The discarded future is removed from selectable history. Presentation trails/particles and impact effects clear on resume. |
| RW03 | Three confirmed resumes maximum per race across all sources, enforced independently by the scene and backend. Restart is a fresh race contract. |
| RW04 | One free resume per server UTC day, reset at 00:00 UTC, no accumulation. Spend daily allowance before saved credits. Clock rollback cannot replenish a previously consumed day. UTC is the implementation convention; no timezone was specified by the owner. |
| RW05 | Saved credits do not expire. Internal, transaction-idempotent fulfillment supports `ad` (exactly one), `purchase`, and `award`. No daily ad-grant cap. Provider verification must precede this internal boundary. |
| RW06 | Authenticated credits use a server clock and PostgreSQL player-row locking. Consumption returns an immutable receipt tied to the race, ordinal and rewind timeline. Retries reuse the same key. No client-facing grant endpoint exists. |
| RW07 | `bmt-replay-v2` retains all chronological inputs, including discarded branches, plus up to three receipt-bearing rewind events. The API checks every receipt against that race; the engine verifies actual state restoration and the ordered-gate finish. Resumed results use the same leaderboard and canonical handling. |
| RW08 | Existing replay-v1 runs and pinned track/handling manifests remain valid. V2 is a versioned envelope extension, advertised by bootstrap; no canonical physics constants, timing rules or existing board identities changed. Durable upload outboxes preserve events and recover integer types after JSON reload. |

Rewind is available during timed races after some driving history exists; countdown, completed races, results and untimed editor practice do not offer it. Scrubbing is discrete at ten checkpoints/second (at most 101 checkpoints), rather than changing the canonical 120 Hz step. Preview may therefore reach just under ten seconds at a tick between checkpoints. The thirty-minute total-input upload bound includes discarded driving.

On an ambiguous consumption response, the selection stays fixed and Retry repeats the same request. Leave race remains available; the credit may already have been spent. A confirmed consumption remains spent if the race is abandoned or the process exits. There is no mid-race crash recovery. Guests have an atomic, device-local daily allowance only; guest saves cannot authorize ranked receipts. Signed-in resume consumption needs a working backend, while ordinary racing remains available offline.

## Integration and configuration limits

Ad provider, ad placement IDs, store product IDs, resume-pack sizes and prices have not been supplied. **No live ads, billing SDK, purchase flow or provider receipt validation is implemented.** The rewind screen reports ads and packs as unavailable when the wallet is empty; no simulated reward is granted. Provider choice and product configuration remain necessary to complete that part of the request. The internal grant function is not itself proof of an ad or purchase and must only be called by a trusted, verifying adapter or authorized server-side award process.

Database migration `0006_resumes` adds wallets, grants, race sessions and receipts. Existing accounts, tracks, scores and player files are retained. API/worker must run the updated game verifier for v2 submissions. No production deployment is authorized by this implementation.

As with the existing input-replay verifier, this validates submitted canonical driving and declared authorized rewinds. It is not an attestation that a modified client did not search/retry inputs offline; trusted-client/anti-tamper attestation remains outside this slice.

## Changed files

- Gameplay/UI: `game/race/rewind_history.gd`, `game/platform/resume_credits.gd`, `game/ui/rewind_panel.gd`, `game/ui/playground_hud.gd`, `game/core/game.gd`, `game/core/app.gd`.
- Online replay: `game/backend/backend_client.gd`, `game/backend/cloud_tracks.gd`, `game/backend/runner.gd`, `backend/bmt_backend/runs.py`, `backend/bmt_backend/verifier.py`, `backend/schemas/replay-v2.schema.json`.
- Credits/database: `backend/bmt_backend/resume_models.py`, `backend/bmt_backend/resumes.py`, `backend/bmt_backend/app.py`, migration environment and `0006_resumes.py`.
- Verification: `game/tests/test_rewind.gd`, `game/tests/test_cloud_tracks.gd`, `backend/tests/test_resumes.py`, latest-revision assertion in `backend/tests/test_auth_postgres.py`, and TestRewind/CaptureRewind actions in `scripts/dev.ps1`. `game/tests/test_race_results.gd` now isolates its cloud cache as well as local records. The stripped verifier staging/build checks include rewind dependencies and a v2 regression.
- Scope/status: `AGENTS.md`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

## Actual verification

Pinned build: `4.7.2.stable.official.ed1daf0bf`, through `scripts/dev.ps1`.

- `-Action Import`: passed.
- `-Action CheckScript -ScriptPath res://core/game.gd` and `res://core/app.gd`: passed.
- `-Action TestRewind`: 26 checks passed, including exact restoration, crossing a lap boundary, cancellation, daily persistence, and shared three-resume cap.
- `-Action CaptureRewind`: **29 checks passed**, including the lap-boundary assertion. The 1280×720 and 960×540 screenshots were inspected. An initial assertion incorrectly compared canvas coordinates to physical window pixels; corrected it to compare against the viewport's canvas rectangle, without changing layout requirements.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py -q --tb=short`: passed. Real game/HTTP/worker test performs a twenty-second rewind and reloads the durable outbox before receiving a verified result at 12,757 final ticks.
- `-Action TestDriving`: 74 assertions passed. First concurrent run exited with native access violation after assertions; isolated rerun passed with an ObjectDB cleanup warning. No simulation change was made to bypass it.
- `-Action TestPractice`: 49 checks passed; existing ObjectDB exit warning remains.
- `-Action Doctor`: matching engine/templates found; ADB reported **no attached device**. No physical-device test or Android export performed.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_resumes.py backend/tests/test_verifier.py backend/tests/test_domains.py -q --tb=short`: **88 passed, 6 skipped**. Skips are PostgreSQL-specific concurrency cases under the SQLite parametrization; PostgreSQL counterparts ran. Initial attempts could not connect to the stopped disposable fixture; interrupted them, started only `bmt-backend-test` with `wsl -d Ubuntu -- docker start bmt-backend-test`, and reran successfully. Stopped that fixture when testing finished.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q --tb=short -k 'not domains and not resumes and not verifier'`: **81 passed, 95 deselected**. Ran the one additionally excluded parametrization, `backend/tests/test_auth.py::test_invalid_resource_budgets_rejected_at_startup[verifier_timeout_seconds]`, separately: **1 passed**. Together these commands cover the full collected backend suite: **170 passed, 6 skips**, including native HTTP/outbox integration and PostgreSQL races.
- `-Action TestResults`: **191 checks passed**. Initial run mixed the owner's cached cloud tracks into the local-only recommendation fixture, causing a missing `library_directory` lookup. Isolated the test cloud cache and retained the original shared-directory invariant; no production recommendations were changed.
- `-Action BackendStart`: **passed**, rebuilding and replacing only local PC development services. First build failed before service replacement because the stripped verifier staging list lacked rewind-history dependencies; added them and extended the build gate with a v2 replay. Final Linux build verifies original and twenty-second-rewind replays at the same **12,757 ticks**, then applies `0006_resumes` and starts healthy API/worker containers. Existing volumes are retained.
- HTTP `GET /readyz` returns `ready`, schema `0006_resumes`; bootstrap advertises `rewind-1` and both replay envelopes. A temporary existing-developer session verified authenticated `GET /v1/resumes` and was logged out. **No real player resume was consumed or awarded** by that check.
- Ruff checks on changed Python files and `git diff --check`: passed.

Evidence: `build/rewind.png`, `build/rewind-compact.png`, `build/rewind-tests.log`, `build/rewind-capture.log`. Build artifacts are local and export-excluded.

Remaining acceptance: owner review of scrubbing/resume feel, phone touch targets and safe areas, mobile history/mesh/particle cost, provider selection and verified live ad/billing fulfillment, pack economics, and hosted deployment.


## Reference presentation and return easing (2026-09-29)

- **RW09 / V03:** owner-supplied rewind reference adapted to the live game: large title, translucent ink cards, gold resume action, lower timeline with time bubble, LIVE endpoint, minimap and recorded-preview transport (quarter, half and full speed; one-second steps; oldest/live shortcuts). Up to four blue ghost instances share the selected vehicle mesh and follow actual snapshots, with time labels and a connecting ribbon. Near the oldest moment they show the available later positions; otherwise they show preceding positions. Reference comparison, coaching and clip-export examples are not implemented features.
- **RW10 / R01 / B19:** Resume ramps from 35% cadence to full speed over 36 fixed callbacks (300 ms). Each executed canonical step remains 1/120 second, with exactly one quantized input and one race-clock tick. Fractional render interpolation follows the ramp. Reopening rewind is disabled during this brief transition, and restart clears it.
- **RW11 / Q01:** Cancel gets only a 60 ms camera easing. Simulation, input and scored time remain at full cadence, including repeated cancellations. This intentionally prevents using Cancel for additional slow-motion control. Both actions still release held controls. A cancelled rewind entered from Pause stays paused.
- LIVE cannot consume a credit, including a direct confirmation call. Preview transport is locked during confirmation and ambiguous receipts retain their selected moment for retry. Existing quota, credit lifetime and leaderboard policies remain unchanged.

Changed files: `game/ui/rewind_panel.gd`, `game/vehicle/rewind_ghosts.gd` and UID, `game/race/rewind_return.gd` and UID, `game/core/game.gd`, `game/tests/test_rewind.gd`, `game/tests/test_cloud_tracks.gd`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands through the pinned `scripts/dev.ps1` entry point:

- `-Action Import`: passed. The first TestRewind attempt preceded class registration and stopped on unknown `RewindReturn`; terminated that test process, imported the new script and reran. Import also reported recreating two unrelated existing UID files; they are not part of this checkpoint.
- `-Action TestRewind`: **40 checks, zero failures**. Covers exact restore, quotas, LIVE guard, recorded transport, history pool cleanup, 300 ms pacing, one input per canonical tick, repeated cancellation at full speed and camera easing expiration at 30/60/120 fps.
- `-Action CaptureRewind`: **43 checks, zero failures**. Inspected 1280x720 and 960x540 captures. First visual pass exposed incompatible source mesh indexing in flattened ghosts; expanded triangles to one vertex format and inspected the corrected captures. Final lower panel fits within the screen with a bottom margin.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py -q --tb=short`: **1 passed** (20.27 seconds; existing Starlette/httpx deprecation warning). Actual game/HTTP/worker flow still verifies the twenty-second rewind at **12,757 ticks**, including durable outbox reload. The test allows extra callbacks for the new pacing while consuming the same input sequence.
- `-Action TestDriving`: **74 checks, zero failures**; existing six-instance ObjectDB exit warning. Canonical simulation code was not changed.
- `-Action Doctor`: pinned engine and matching templates found; **no attached phone**. No Android export or physical-device test performed.

Evidence: `build/rewind.png`, `build/rewind-compact.png`, `build/rewind-tests.log`, `build/rewind-capture.log`, `build/driving-tests.log`. Captures are real rendered game scenes. Source reference is not a shipped asset; no new external art was introduced.

Remaining acceptance: owner's in-motion review of the proposed 300/60 ms durations, touch/safe-area checks, and mobile ghost-mesh cost. Snapshot preview remains discrete at 10 Hz. Provider fulfillment and pack configuration remain outstanding as above. No backend deployment is needed for this presentation change.


## Compact ten-second rewind revision (2026-09-29)

This owner revision supersedes RW01/RW09 presentation/window details above. **RW12:** open at the exact state where rewind was entered, with the slider at 0 seconds; no automatic jump back. **RW13:** choose up to two spatially separated recorded ghosts before and after the selected state, filling spare slots from the available side at endpoints, four maximum. All ghosts come from captured states at or before entry; no prediction/extrapolation. **RW14:** client history/credit checks and newly issued server receipts enforce 1,200 ticks (ten seconds), with at most 101 stored checkpoints. **RW15:** one approximately 120 px-high toolbar contains Cancel, timeline and a play-shaped button that confirms the selected resume. Timing and balances share its top row. Extra preview transport, speed controls, Live button and right-side cards are removed. At the unchanged current state, Resume remains disabled to avoid consuming a credit for no rewind. Error messages expand the toolbar upwards.

The canonical v2 replay reader retains its historical 20-second ceiling for already-issued receipts and old queued runs. New receipts cannot exceed ten seconds, and submission still requires an exact server receipt. This does not authorize new 20-second resumes. Existing 300 ms resume ramp, 60 ms visual-only cancel easing, daily/persistent credit policies and maximum three resumes per race are unchanged.

Changed files: `game/ui/rewind_panel.gd`, `game/vehicle/rewind_ghosts.gd`, `game/core/game.gd`, `game/race/rewind_history.gd`, `game/platform/resume_credits.gd`, `backend/bmt_backend/resumes.py`, their rewind/cloud/receipt tests, `AGENTS.md`, this document and both status documents.

Actual verification:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestRewind`: **41 passed**.
- Same entry point, `-Action CaptureRewind`: **45 passed**. Inspected current-position entry, both-sided historical ghosts and 1280x720 / 960x540 layouts. Evidence: `build/rewind-current.png`, `build/rewind.png`, `build/rewind-compact.png`, and rewind test/capture logs.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py backend/tests/test_resumes.py -q --tb=short -k "not postgres"`: **13 passed, 6 deselected**, 27.48 seconds. Includes exact ten-second acceptance, 1,201-tick rejection without spending, real HTTP/outbox verification at 12,757 final ticks, and legacy-receipt replay parity. PostgreSQL variants were not rerun for this bound/UI change. The first pass failed an old UI assertion expecting Resume enabled immediately on entry; updated it to require disabled at the current state and enabled after selecting history. Existing Starlette/httpx deprecation warning remains.
- `-Action BackendStart`: passed; local PC API and worker rebuilt/restarted healthy, retained schema `0007_admin_audit` and existing data. Linux original and legacy-rewind verifier checks passed. `/readyz` returned ready. New server receipt limit is active locally; no production deployment.
- Ruff on changed Python files: passed. `-Action Doctor`: matching engine/templates, no attached phone. No Android export/device test.

Remaining acceptance: owner touch/feel review, phone safe areas and ghost rendering cost. Ads and billing configuration remain outstanding as described above.
