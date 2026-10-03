# Creator test and publish flow

2026-09-30 owner follow-up for R01/T01-T04/B02/B19/V03/Q01: **Test drive** and
**Publish** are separate creator actions. A complete test drive is a prerequisite;
pressing Publish must never start another race.

- The editor header now exposes Publish beside Test. It is disabled until the exact
  current document fingerprint has a completed test receipt. Any document edit
  invalidates the receipt and disables Publish again.
- The draft browser retains the same prerequisite and Publish action.
- For signed-in players, completing the test drive uploads the immutable draft and
  queues that completed drive for canonical backend verification. It does not publish
  automatically.
- Pressing Publish reuses the idempotently uploaded version and calls the publication
  endpoint. Pending verification produces a retry notice without entering gameplay.
  Once accepted, the local immutable publication lock is saved and the track enters
  the playable catalog.
- Signed-out publishing remains unavailable; the tested local draft stays saved.

Verification performed:

- `scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd`: passed with
  pinned Godot 4.7.2.
- `scripts/dev.ps1 -Action TestTyresLoad`: reached the editor/draft UI checks, then
  failed at the existing unsaved-departure expectation (`editor Load uses the same
  gallery`, followed by a null browser). This run is not reported as passed.

No phone was attached. No Android export or physical-device test was performed.
Remaining acceptance: signed-in end-to-end verification/Publish against the running
development backend, editor-header capture, and phone touch/layout.

## 2026-10-01 ? Dust cloud publication repair

R01/T01?T04/B02/B19/Q01. The actual Dust cloud WIP matched its completed-test
snapshot, but the upload outbox contained a zero-input rejection. Practice excluded
replay recording, and the five-lap standing-race verifier could not accept the
one-lap start-line practice contract. The manual save also had different route points.

Changes: `game/core/game.gd` records and freezes practice inputs at completion;
`game/core/app.gd` snapshots inputs/document/vehicle before network awaits, saves the
tested version, requests creator verification and reports actual publication errors.
`game/backend/{backend_client,cloud_tracks,runner}.gd` carry the explicit creator
purpose, reject empty recordings and replay one ordered lap from the placed start.
`backend/bmt_backend/{runs,worker,verifier,tracks}.py` bind the purpose to an owner-only
server ticket, verify canonical inputs, keep practice off public boards/PBs and permit
publication after verification. Ordinary race verification still requires five laps.
No schema migration or player-file deletion is needed. `backend/deploy/stage_verifier.py`
also includes TrackTheme's preloaded storm sky resources, fixing the discovered
headless packaging failure. Regression coverage is in `game/tests/test_editor_practice.gd`
and `backend/tests/{test_domains,test_verifier}.py`.

Actual checks:
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://core/app.gd`: passed, including final snapshot change.
- `scripts/dev.ps1 -Action TestPractice`: 53 checks passed. Real game input controls generated `build/creator-practice-proof.json`; recording freezes exactly at completion and restart clears it. Godot reports three leaked objects at exit.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_domains.py backend/tests/test_verifier.py -q -k "not postgres"`: 53 passed, 30 deselected. Includes actual game proof through HTTP upload/ticket/submission, real canonical worker verification and publication; leaderboard population remains zero. Incomplete proofs and using practice inputs as an ordinary race are rejected.
- Initial unfiltered domain run was interrupted after repeated unavailable PostgreSQL fixture errors; PostgreSQL regression acceptance is outstanding.
- `pytest backend/tests/test_cloud_client.py backend/tests/test_end_to_end.py -q -k "not postgres"`: ordinary five-lap HTTP end-to-end passed; broader Godot cloud-client test timed out at 150 seconds. Not reported as passing.
- `scripts/dev.ps1 -Action BackendStart`: initial image build failed due to missing `storm_sky.tres`; after fixing staging, image verification passed and local API/worker were recreated healthy. Redirected PowerShell invocation returned 1 despite its final successful ready output; independent `/readyz`, live ticket schema, and direct verification inside the running worker confirmed readiness and one accepted lap / 2605 input ticks.
- `git diff --check`: passed. Existing unrelated work remains in the working tree.

Recovery: restart the desktop game to load the fixed scripts, open Dust cloud's
latest draft while signed in, complete one fresh Test drive lap, then Publish after
verification. The historical empty replay cannot be recovered. No track has been
published on the owner's behalf. Physical-device testing and the owner's actual
Dust cloud drive/publish acceptance remain outstanding; no Android export was run.

Desktop evidence: `scripts/dev.ps1 -Action CapturePractice` passed 76 checks. `build/editor-practice.png` shows the retained untimed practice HUD; normal start/finish captures were also produced. No layout was changed.

## 2026-10-01 - Variable-width upload rejection follow-up

R01/T01-T04/B02/B19/Q01. Owner screenshot exposed a separate validation bug missed
by the constant-width oval. Reproduced the exact Dust cloud document rejection on
both Windows and the running Linux worker: all 96 route points/corners matched;
18 widths differed from regenerated float32 values by only 1.78e-15 to 5.33e-15
metres after JSON parsing. The verifier compared float64 arrays exactly.

`game/backend/runner.gd` now compares `PackedFloat32Array` widths, matching route
generation and canonical simulation precision. It still compiles the exact
submitted document, retains its content hash and checks route points/corners.
No road, rule, handling, or player-file edits are required.
`backend/tests/fixtures/variable_width_oval.json` is an original diagnostic oval
variant, not a copy of Dust cloud. `backend/tests/test_verifier.py` confirms its
JSON widths validate, preserves its exact compiled hash, and rejects a 0.00001 m
width change. Fixture provenance is in the adjacent README.

Actual commands: pinned Godot diagnostic compared Dust cloud's regenerated widths;
`GodotVerifier.validate_track` reproduced the pre-fix failure on Windows/Linux and
accepted the unchanged document locally after the fix;
`.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q`
passed 34 tests. `git diff --check -- game/backend/runner.gd backend/tests/test_verifier.py`
passed. `scripts/dev.ps1 -Action BackendStart` rebuild includes passing canonical
five-lap (12757 ticks) and rewind image checks. No UI layout change or new screenshot;
the owner's screenshot is the failure evidence. No physical-device test or Android
export performed. Actual player test/publish acceptance remains outstanding.

Post-rebuild acceptance: both running API and worker containers validated the exact
unchanged Dust cloud document and returned the same hash as Windows
(`37b86e448c6843bb56e615c7062110890690cb8ef01e7aee28c28e3537bcb08c`).
Local `/readyz` returned ready. BackendStart printed successful readiness although
PowerShell stderr redirection again yielded exit 1; independent live checks passed.
The failed upload never queued this drive and its input snapshot was only in memory,
so a fresh test is required; this server-only correction needs no game restart.
