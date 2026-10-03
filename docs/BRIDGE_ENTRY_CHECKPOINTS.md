# Fast bridge checkpoint crossings — 2026-10-03

Latest follow-up: [Bridge-exit gate geometry](BRIDGE_EXIT_CHECKPOINTS.md) fixes
the compact's valid first-exit lane being rejected on Over and under, advances
acceptance to v17 and verifies matching rebuilt local API/worker artifacts.
The older rollout blockers below are historical observations.

Earlier follow-up: [Checkpoint notice timing](CHECKPOINT_NOTICE_TIMING.md) repairs
delayed warnings and strengthens this track's clean-lap/all-vehicle regression
coverage while retaining exact v16 acceptance and lap ticks.

Requirements R01/G01/T01–T04/V03/Q01. Owner report: Over and under intermittently
rejects a checkpoint when entering a bridge at speed.

The gate layer was compared with the car's layer **at the end of the tick**.
Over and under has a ground gate about 0.195 m before a ramp entrance and an
elevated gate about 0.256 m before an exit. At speed, one tick can cross the gate
and then change layers. The intended crossing was rejected even on the exact
route. Across both directions, six speeds and eight tick phases, the initial
reproduction failed **25 of 96** legitimate laps.

Runtime race, creator practice, verifier and fixture generation now pass the
canonical layer before the simulation step alongside its ending layer. When
the layer changes, checkpoint acceptance follows the bridge entrance/exit state
from the beginning of the sweep to the exact gate crossing. Finish crossings
and neighbouring-gate notices use the same calculation. Unchanged layers need
no extra sweep work. Gate order, widths, direction checks, wrong-layer rejection
and ordinary five-lap races remain enforced; no road or handling change.

Rules are **`standing-5-road-gates-v16`**, physics **0.49**, compiler **20**.
New server contracts upgrade v12/v13/v14/v15 manifests while preserving
immutable track revisions and historical boards. Replay inputs and the golden
oval times/content hash are unchanged. Previous-layer information is derived
from canonical simulation; it is not an additional client replay field or a
new rewind state variable.

Changed files in this slice:

- `game/race/track_session.gd`, `race_rules.gd`: exact crossing-layer checks and
  the new rules key.
- `game/core/game.gd`, `backend/runner.gd`, `backend/generate_fixture.gd`: pass
  the simulation layer from before each step for racing, creator proofs and
  replay verification.
- `game/tests/test_bridge_entry_checkpoints.gd`,
  `fixtures/over_and_under.json`: the unchanged original owner-authored track
  copied from the existing cache, 96 speed/phase/direction laps, every gate's
  wrong-layer rejection, six actual compact entry/exit steps, exact rewind
  reproduction, mixed-layer sweeps, finish transitions and a five-lap race.
- `game/tests/test_checkpoint_bridge_layers.gd`: the Dust cloud harness now
  passes previous-layer state and shares its race-recording helper.
- `game/tests/test_checkpoint_rules.gd`, `capture_checkpoints.gd`,
  `scripts/dev.ps1`: v16 assertion, actual fast runtime recovery capture with
  unique filenames, and the new test in full validation. Existing default
  checkpoint presentation checks remain separate and pass.
- `backend/bmt_backend/contracts.py`, `runs.py`,
  `backend/tests/test_review_reliability.py`, `fixtures/verified_oval.json`:
  compatibility, migration/immutable-board coverage and golden manifest key.
- This record/evidence, status/phase records, backend deployment/fixture notes
  and the linked Dust cloud record.

Actual validation uses pinned Godot 4.7.2 through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the
repository `.tools/backend-venv/Scripts/python.exe`:

| Command/action | Actual result |
|---|---|
| `TestScript -ScriptPath res://tests/test_bridge_entry_checkpoints.gd` | Final: 182 checks, zero failures. Both directions at 30/60/90/120/160/200 km/h, eight phases each; actual entry/exit and rewind at 120/160/200 km/h. Five compact laps finish in 25,685 ticks. |
| `TestScript -ScriptPath res://tests/test_checkpoint_bridge_layers.gd` | 258 checks, zero failures; Dust cloud still completes five laps at 29,116 ticks. |
| `TestRouteValidation`, `TestTracks` | 266 / 167 checks, zero failures, retaining shortcut, ordered recovery and historical exact replay invariants. |
| `TestRewind`, `TestPractice`, `TestReview` | 57 / 53 / 17 checks, zero failures. Practice reports an existing four-instance ObjectDB exit warning. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 248 scripts parsed, zero failures. |
| `CaptureCheckpoints -Screen bridge-entry` | Final: 23 checks, zero failures. The actual runtime physics step changes to the upper ramp, consumes the preceding ground gate and clears the missed marker/banner at approximately 119 km/h. Screenshots inspected. |
| `CaptureCheckpoints` | Existing default presentation regression: 131 checks, zero failures. |
| `python -m pytest backend/tests/test_verifier.py backend/tests/test_review_reliability.py backend/tests/test_domains.py -q -k 'not postgres'` | 102 passed, 59 PostgreSQL cases deselected. |
| `python -m pytest backend/tests/test_cloud_client.py -q` | Both actual HTTP/Godot cloud and creator-lifecycle integrations passed. |
| `GodotVerifier.verify_run` on the saved Over and under recording | Accepted: 25,685 ticks, five lap ticks `[5217,5120,5115,5112,5121]`, v16. Saved result below; quantized replay is retained under ignored `build/bridge-entry-checkpoints-2026-10-03/desktop-race.json`. |
| Scoped Ruff and whitespace check | Passed. |
| `Doctor` | Pinned engine/templates found; DN2103 attached. No export/install or physical-device driving. |
| Live manifest probe and `BackendStart` | API is unreachable. Startup still fails before building/replacing services with the previously documented WSL Ubuntu disk `ERROR_SHARING_VIOLATION`. |

The first actual-car test iteration used the opposite simulation Y direction;
its 12 failures were corrected by using `(0,-1)` for this track's entry/exit.
The 25 original speed/phase failures were fixed in the canonical acceptance
code; no lap or wrong-layer requirement was weakened. An initial capture also
exercised the default bearing suite; the dedicated bridge case now has its own
23 runtime checks and output names, while default presentation remains 131
checks. Existing Starlette/httpx deprecation warnings remain.

Evidence:

- [Missed entry immediately before the fast recovery](evidence/bridge-entry-checkpoints-2026-10-03/missed-entry.png)
- [Fast bridge entry clears the checkpoint](evidence/bridge-entry-checkpoints-2026-10-03/fast-entry-cleared.png)
- [Canonical five-lap verification](evidence/bridge-entry-checkpoints-2026-10-03/desktop-verification.json)

The local code fix and desktop verification are complete. The PC backend still
needs the WSL disk lock cleared and `scripts/dev.ps1 -Action BackendStart` to
rebuild matching v16 API/worker artifacts, followed by live ticket/replay checks.
No container rollout, database migration, publication, player-file cleanup,
NAS/production deployment, Android export/install or phone driving was performed.
Owner driving acceptance remains after restarting the game. No mixed-working-tree
commit was made.

## Live online-race diagnosis (2026-10-03)

B01/R01/T01-T04/Q01: the owner's "This version requires a different verifier
build" dialog is caused by mixed development-backend artifacts. This follow-up
supersedes the earlier unreachable-server observation above: the configured
`http://127.0.0.1:18181` now responds with healthy/ready status and schema
`0009_track_lifecycle`, but `/v1/manifest` still reports
`standing-5-road-gates-v14`. Workspace game rules and the running API's
`current_manifest()` require `standing-5-road-gates-v16`.

Actual read-only commands and results:

- `.tools/backend-venv/Scripts/python.exe -` ran an inline standard-library
  HTTP probe using only the URL from the saved game configuration. `/healthz`
  returned `ok`, `/readyz` returned `ready`, and `/v1/manifest` returned rules
  v14, physics 0.49 and compiler 20. `/v1/tracks?limit=100` returned 26 tracks.
  Public revision reads for My way, Saw and Dusty compared their upgraded
  contracts against the live verifier: the only mismatch was rules v16 versus
  v14; all vehicle entries matched.
- `wsl.exe -d Ubuntu -- docker compose --env-file .tools/bmt-pc.env -f
  backend/deploy/compose.pc.yaml exec -T api python -c ...` inspected the
  running API's contract transformation and bundled verifier rule file. The
  API returned v16 for a saved v14 contract; `/opt/bmt/game/race/race_rules.gd`
  still declared v14.
- Source inspection confirmed that `issue_ticket()` in
  `backend/bmt_backend/runs.py` returns this exact HTTP 409 when the upgraded
  track contract and active verifier disagree. `compose.pc.yaml` bind-mounts
  Python source; `backend/Dockerfile` embeds the game verifier during build.

The remaining correction is `scripts/dev.ps1 -Action BackendStart` through
PowerShell with `-NoProfile -ExecutionPolicy Bypass`, which rebuilds and
replaces the local API/worker and compares their manifests. Reuploading tracks
does not repair this deployment mismatch. This diagnosis changed only this
record, DEVELOPMENT_STATUS.md and PHASE_0_PLAN.md; no service rebuild/restart,
runtime change, race-ticket write, publication, database mutation, Android
export or physical-device test was performed. Device attachment was not
checked. Matching live v16 manifests and successful online ticket/replay
acceptance remain unverified by this follow-up.
