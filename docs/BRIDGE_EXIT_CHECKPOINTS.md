# Bridge-exit checkpoint repair — 2026-10-03

Requirements **R01/G01/T01–T04/V03/Q01**, including the owner's ordered-road-gate override. The owner identifies **Over and under, compact car, immediately after the first bridge**. The preceding exact-crossing and notice-timing repairs remain in place; this follow-up fixes the gate's physical orientation.

## Reproduction and change

Gate 12 is centred about 0.18 m beyond the first bridge's end. Its old direction followed the smoothed automatic route, which starts turning before the physical ramp ends. That tilted the gate across both the deck and ground. A compact on an ordinary road lane could therefore cross inside the legal gate width while still elevated, and be rejected because the gate centre expects ground.

The initial actual-vehicle reproduction failed **48 of 240** approaches: six seeded speeds from 30–200 km/h, eight simulation phases and five lanes within ±2 m of centre. The failing lane stayed on the road with zero collisions. Exact-centre route sweeps and the earlier bridge-entry tests had missed this geometry problem.

`TrackSession._bridge_gate_direction` now aligns ordinary gates near a physical ramp end with that bridge's axis, respecting travel direction. The affected zone covers at least 2 m and grows with the road width and the original gate's skew. Perpendicular underpass routes remain excluded; physical sharp-junction gates retain their bisectors. Gate centres, order and required count remain unchanged, and wrong-deck/ground crossings still fail. The same repair handles the second bridge when driving the reversed route.

Acceptance geometry changes, so **rules v17** replaces v16. Physics remains **arcade-planar-0.49**, compiler **creator-compiler-20**, engine **4.7.2.stable.official.ed1daf0bf**. The backend upgrades legacy v12–v16 contracts consistently for tickets and verification; immutable documents and historical boards stay pinned. The oval golden changes only its expected rules key, preserving recorded inputs, content hash and exact timing.

## Actual validation

All engine actions below used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with the pinned executable and `-CommandTimeoutSeconds 120` (300 for BackendStart).

| Command / check | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_bridge_exit_checkpoints.gd` | 2,527 checks, zero failures: 2,400 real exit approaches across all five vehicles, six seeded speeds, eight phases, five lanes and both affected travel directions; strict gate/finish layers also checked. Vehicle speed caps remain active. |
| `-Action TestScript -ScriptPath res://tests/probe_bridge_exit_checkpoints.gd` | 150 passes across the current 15 public bridge-track documents, both directions and five ±2 m route offsets. These are route/layer sweeps, not simulated vehicle races. |
| `-Action TestScript -ScriptPath res://tests/test_bridge_entry_checkpoints.gd` | 258 checks, zero failures; Over and under compact completes five laps in 25,685 ticks without false notices. |
| `-Action TestScript -ScriptPath res://tests/test_checkpoint_bridge_layers.gd` | 259 checks, zero failures; Dust cloud compact completes five laps in 29,116 ticks without false notices. |
| `-Action TestScript -ScriptPath res://tests/test_checkpoint_notices.gd` | 281 checks, zero failures; timely real misses retained. |
| `-Action TestRouteValidation` | 266 checks, zero failures; shortcut/inside-line invariants retained. Final checkpoint timing sample: 3.75 μs/tick on this desktop. |
| `-Action TestTracks` | 167 checks, zero failures; historical three-lap native handling/replay fixtures retained. |
| `-Action TestRewind` / `-Action TestPractice` | 57 / 53 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 257 scripts, zero failures. |
| `-Action CaptureCheckpoints -Screen bridge-exit` | Six checks, zero failures; actual compact driving at about 119 km/h reproduces the old rejection and accepts the same approach with the fix. Final captures inspected. |
| `-Action CaptureCheckpoints` / `-Screen bridge-entry` | 132 / 23 checks, zero failures. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py backend/tests/test_review_reliability.py backend/tests/test_domains.py -q -k "not postgres"` | 106 passed, 63 deselected; existing Starlette/httpx deprecation warning. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_cloud_client.py -q` | Two real HTTP/Godot integration tests passed against a disposable test service. |
| `.tools/backend-venv/Scripts/python.exe build/bridge-exit-checkpoints-2026-10-03/verify_recordings.py` | Both actual five-lap compact recordings accepted by the desktop v17 verifier with unchanged race/lap ticks. |
| `-Action BackendStart` | Final build/start exits 0; pinned import, 12,757-tick five-lap oval and ten-second rewind build checks pass. Local API and worker healthy. |
| `.tools/backend-venv/Scripts/python.exe build/bridge-exit-checkpoints-2026-10-03/verify_worker.py` | Rebuilt Linux worker accepts both compact recordings with identical ticks; both containers' TrackSession SHA256 matches the workspace exactly. Live API manifest is v17; readiness passes at schema 0010. |
| Scoped `ruff check`, `git diff --check`, `-Action Doctor` | Pass. Doctor finds DN2103 attached with matching engine/templates; attachment is not a device test. |

The catalog diagnostic fetched public immutable documents using read-only local API requests via `build/bridge-exit-checkpoints-2026-10-03/fetch_tracks.py`; the corpus stays in ignored `build/`, outside shipping. One early reverse-route diagnostic stopped before its laterally offset finish plane. Extending the walk 2 m beyond the nominal route length made it actually cross the finish; no finish or checkpoint assertion was removed.

The first local backend rebuild succeeded. A later rebuild with the final width-dependent gate-zone refinement initially failed readiness while concurrent workspace changes added schema 0010 and briefly changed a Python import. Applied the existing local migration with `wsl.exe -d Ubuntu -- docker compose --env-file .tools/bmt-pc.env -f backend/deploy/compose.pc.yaml run --rm migrate`, then repeated the pinned BackendStart successfully. No migration or unrelated backend feature was authored for this checkpoint repair. Existing account/track volumes were retained.

## Evidence and changed files

[Old-angle rejection](evidence/bridge-exit-checkpoints-2026-10-03/first-exit-baseline.png) and [corrected acceptance](evidence/bridge-exit-checkpoints-2026-10-03/first-exit-fixed.png) show the compact on the first exit's road. The baseline capture reconstructs the v16 gate direction inside the diagnostic harness; it is not an old shipping binary. The fixed run restores the same saved simulation/session state, then drives the identical lane with the corrected gate. Both runs use real vehicle simulation and runtime checkpoint handling.

Retained verification: [desktop](evidence/bridge-exit-checkpoints-2026-10-03/desktop-verification.json), [Linux worker and exact source hashes](evidence/bridge-exit-checkpoints-2026-10-03/worker-verification.json), [live manifest](evidence/bridge-exit-checkpoints-2026-10-03/live-api-manifest.json), [readiness](evidence/bridge-exit-checkpoints-2026-10-03/local-readiness.json) and [scoped Git patch](evidence/bridge-exit-checkpoints-2026-10-03/checkpoint.patch).

The same folder retains the initial 48-failure log and final exit, entry, Dust,
catalog, route-invariant, replay, capture and parse logs. The task-only patch is
prepared with Python `difflib`; `git apply --reverse --check
docs/evidence/bridge-exit-checkpoints-2026-10-03/checkpoint.patch` passes without
changing the shared Git index or working files.

Changed runtime/contracts: `game/race/track_session.gd`, `game/race/race_rules.gd`, `backend/bmt_backend/contracts.py`, `backend/bmt_backend/runs.py`.

Changed checks/tooling: new `game/tests/test_bridge_exit_checkpoints.gd` and `probe_bridge_exit_checkpoints.gd` with engine UIDs; `game/tests/capture_checkpoints.gd`, `game/tests/test_checkpoint_rules.gd`, `backend/tests/test_review_reliability.py`, `backend/tests/fixtures/verified_oval.json`, `scripts/dev.ps1`. Earlier owner track fixtures and replay inputs are retained unchanged.

Changed documentation: this report and evidence, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, `docs/BRIDGE_ENTRY_CHECKPOINTS.md`, `docs/CHECKPOINT_NOTICE_TIMING.md`, `backend/deploy/README.md`, `backend/tests/fixtures/README.md`. Unrelated concurrent workspace changes are preserved; the scoped patch is the reviewable checkpoint, with no mixed-workspace commit.

## Remaining acceptance

Restart the desktop game so new sessions bake v17 gates, then drive the compact through the first Over and under bridge exit at ordinary and high speeds, including small inside/outside deviations. Complete a five-lap race and check a genuine bypass still gives a prompt return indication.

No Android export/install or physical-phone driving was performed, although DN2103 is attached. The full `Validate` action, NAS/production rollout and live authenticated ticket/leaderboard submission were not performed. Worker checks invoke canonical verification directly and write no competition records. Phone driving, owner confirmation and future changed-track geometry remain acceptance checks.
