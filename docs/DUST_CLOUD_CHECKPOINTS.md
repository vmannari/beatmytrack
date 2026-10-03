# Dust cloud bridge checkpoint repair — 2026-10-03

Latest follow-up: [Checkpoint notice timing](CHECKPOINT_NOTICE_TIMING.md) repairs
delayed warnings and confirms five laps without false notices. Its live API
manifest observation supersedes the earlier backend version/outage observations.

Later follow-up: [Over and under fast bridge crossings](BRIDGE_ENTRY_CHECKPOINTS.md)
advances current rules to v16 and checks the layer at each exact crossing within
a tick. The v15 Dust cloud record below remains dated evidence; its 258 checks
and five-lap simulation pass again under v16. Current backend rollout is still
blocked by the host disk lock.

Requirements R01/G01/T01–T04/V03/Q01: ordinary five-lap races must accept every
legitimate road section, reject missing sections and wrong-layer crossings,
and use the same canonical rules in the client and verifier.

The reported ninth gate (index 8) is at approximately `(1.712269, -24.83281)`.
The lower hairpin briefly runs parallel beneath the upper bridge rail. Rules
v14 classified that isolated point as elevated using its tangent and the bridge
footprint. Canonical collision resolution correctly kept the car on the ground
because it had never entered a bridge ramp. Consequently, even an exact
centreline lap stopped at that gate. The initial reproduction failed all five
lap assertions and the race-finish assertion.

Gate configuration now walks the automatic connected route in 0.25 m steps,
carrying the same creator bridge entrance/exit state used by canonical collision
resolution. This happens once during configuration; the per-tick gate loop is
unchanged. The lower hairpin receives a ground gate and actual bridge sections
retain their elevated gates. Start/finish initialization now uses the canonical
`atan2(forward.x, forward.y)` heading convention. The missed-gate marker uses
the configured gate layer, so this underpass marker is at ground height.

Rules advance to **`standing-5-road-gates-v15`**. Physics remains **0.49**, the
compiler remains **20**, and the shipping track document is unchanged. The
backend upgrades v12/v13/v14 manifests for new contracts without rewriting the
immutable track version or historical boards. The oval fixture changes only
its expected rules key; its inputs, times and content hash are retained.

Changed files for this task:

- `game/race/track_session.gd`, `race_rules.gd`: route-continuous gate layers,
  heading correction, marker layer accessor and versioned rules.
- `game/ui/checkpoint_marker.gd`: draw at the accepted road layer.
- `game/tests/test_checkpoint_bridge_layers.gd`, `fixtures/dust_cloud.json`:
  original owner-created Dust cloud document copied from its existing local
  backend cache; no credentials or player records. Tests include both route
  directions, three sweep spacings, a start line on the deck, Knit, rejection
  of every wrong-layer gate and finish, and an actual five-lap compact race.
- `game/tests/test_checkpoint_rules.gd`, `capture_checkpoints.gd`,
  `scripts/dev.ps1`: current rules assertion, underpass graphical capture and
  inclusion of the new regression in full validation.
- `backend/bmt_backend/contracts.py`, `runs.py`,
  `backend/tests/test_review_reliability.py`, `fixtures/verified_oval.json`:
  v15 compatibility, historical-board test transition, migration coverage and
  the pinned golden manifest.
- Status/phase records, the backend deployment and fixture notes, the dated
  review correction, this document and its evidence.

Actual commands and outcomes (engine commands use
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`):

| Command/action | Actual outcome |
|---|---|
| `TestScript -ScriptPath res://tests/test_checkpoint_bridge_layers.gd` | Final: 258 checks, zero failures. Actual compact simulation finishes five laps in 29,116 ticks. |
| `TestRouteValidation` | 266 checks, zero failures; skipped-gate/hairpin, reverse, stationary, ordered recovery and legitimate lines retained. |
| `TestTracks` | 167 checks, zero failures, including historical native bridge fixtures and exact replay. |
| `TestReview`, `TestBridgeContacts`, `TestRewind` | 17 / 16 / 57 checks, zero failures. |
| `CaptureCheckpoints -Screen dust-cloud` | 17 checks, zero failures. Actual missed sweep, ground marker height, ground recovery, HUD clearing and restart. Both screenshots inspected. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 246 scripts, zero failures. |
| Repository venv `python -m pytest backend/tests/test_verifier.py backend/tests/test_review_reliability.py backend/tests/test_track_lifecycle.py backend/tests/test_domains.py -q -k 'not postgres'` | Final: 107 passed, one existing SQLite concurrency skip, 65 PostgreSQL cases deselected. |
| Repository venv `python -m pytest backend/tests/test_cloud_client.py -q` | Both real HTTP/Godot cloud and creator lifecycle integrations passed. |
| `GodotVerifier.verify_run` on the new quantized Dust cloud compact recording | Accepted all five laps; 29,116 ticks, lap ticks `[5915,5804,5791,5803,5803]`. Same document hash and v15 manifest. Result saved below; replay retained in ignored `build/dust-cloud-checkpoints-2026-10-03/desktop-race.json`. |
| Scoped Ruff and `git diff --check` | Passed. |
| `Doctor` | Pinned Godot/templates found; DN2103 attached. No device driving performed. |
| `BackendStart` | Failed before build/service replacement: Ubuntu's `ext4.vhdx` cannot attach because another process holds it (`ERROR_SHARING_VIOLATION`). Local API was already unreachable. |

Earlier test iterations exposed a diagnostic loop stopping 0.0046 m before
Knit's projected finish, and the backend test's stale v14 transition constant.
Both were corrected without weakening gate/lap assertions. The initial combined
backend run repeatedly timed out connecting to the configured PostgreSQL test
port 55439 and was stopped; the focused reproduction reported 13 passing SQLite
cases and one PostgreSQL setup error. The final SQLite/real-Godot run above is
the passing result. Existing Starlette/httpx deprecation warnings remain.

Backend startup was retried after `wsl --shutdown` (both listed distributions
were stopped) and a targeted `Dismount-DiskImage` of the Ubuntu disk. The sharing
violation persists. HCS diagnostic access requires administrator privileges.
No backend rebuild, container verification, database migration, publication,
player-file cleanup, NAS/production deployment or Android export/install was
completed by this task. The mixed working tree was not committed.

Evidence:

- [Missed underpass gate](evidence/dust-cloud-checkpoints-2026-10-03/missed-underpass.png)
- [Ground crossing clears the gate](evidence/dust-cloud-checkpoints-2026-10-03/cleared-underpass.png)
- [Desktop canonical verification](evidence/dust-cloud-checkpoints-2026-10-03/desktop-verification.json)

Remaining acceptance: clear the Windows/WSL disk lock (a Windows restart is the
available recovery step), run `scripts/dev.ps1 -Action BackendStart` to rebuild
matching API/worker artifacts, confirm v15 manifests and live Dust cloud race
tickets/replay verification, then restart the game for an owner-driven race.
Phone, NAS and production acceptance remain unperformed. The desktop fix is
verified; live development-server rollout remains blocked by the host.

Follow-up completion check on 2026-10-03: the v15 code, fixture and saved
verification evidence remain present. Both `/v1/manifest` and `/readyz` are
unreachable; Ubuntu and Debian are listed as stopped. A fresh `BackendStart`
attempt still fails before the build with the same Ubuntu disk sharing
violation. The Ubuntu disk remains attached as PhysicalDrive3, and this
session's administrator token is false. No implementation changed or earlier
tests were reclassified; live rollout still needs the host lock cleared.

Owner sign-in outage diagnostic on 2026-10-03 (B01/Q01): the saved game's
`backend.cfg` URL is `http://127.0.0.1:18181`. Actual commands and outcomes:

- `curl.exe --silent --show-error --max-time 8 http://127.0.0.1:18181/healthz`:
  connection failure; subsequent `/readyz` and `/v1/auth/options` probes also fail
  to connect (curl error 7).
- `wsl.exe --list --verbose`: Ubuntu and Debian both stopped.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BackendStart`:
  exit 1, before image build/service replacement, with
  `Wsl/Service/CreateInstance/MountDisk/HCS/ERROR_SHARING_VIOLATION` for Ubuntu's
  `ext4.vhdx`.
- `Get-DiskImage` on that exact Ubuntu disk: attached as `PhysicalDrive3`.
  `WindowsPrincipal.IsInRole(Administrator)`: false.

The offline local service explains the sign-in outage. A Windows restart is the
next recovery step after the earlier unsuccessful shutdown/dismount attempts;
no host restart was issued during this diagnostic. Then run BackendStart and
check readiness, matching v15 API/worker manifests and owner sign-in. Only this
document, DEVELOPMENT_STATUS.md and PHASE_0_PLAN.md were updated; runtime,
credentials, player files and database were unchanged. No phone attachment
check or physical-device test was performed. Interactive Google acceptance
and successful local rollout remain outstanding.
