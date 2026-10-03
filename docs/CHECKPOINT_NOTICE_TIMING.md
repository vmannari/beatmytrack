# Missed checkpoint timing — 2026-10-03

Latest follow-up: [Bridge-exit gate geometry](BRIDGE_EXIT_CHECKPOINTS.md) repairs
valid compact lanes rejected after Over and under's first bridge. Rules v17
retains this notice timing, and matching local API/worker verification now passes.

Requirements R01/G01/T01–T04/V03/Q01. The owner reports that missed checkpoints
appear only after driving far away, following the Dust cloud and Over and under
bridge fixes. This follow-up repairs detection timing and retests acceptance.

The initial reproduction had 63 failures in 154 checks: wrong-layer crossings
rejected all 61 road gates across the two tracks without immediately setting
the missed flag, and two Silmukka hairpin bypasses remained silent at road
reentry about 23.9 m from the required gate. Existing tests checked the eventual
blocked finish, which did not guarantee an early warning.

Rejected forward crossings now report the current gate in that tick, whether
the rejection comes from its width or bridge layer. The notice uses the
simulation's local route branch: crossing beneath a future deck gate remains
quiet on the earlier road. A bypass that never intersects the gate plane is
also reported once local route progress exceeds the gate's legal turning
overlap. That overlap is baked from the road join and accepted span endpoints
so an inside miter can project onto the departure road before crossing the
gate without producing a false warning. The starting grid uses signed wrapped
progress and remains quiet. A rejected final finish crossing now highlights
the finish immediately too.

The existing persistent banner/arrow receives the missed flag on the first
presentation frame. Forward recovery clears it, and rewinding before the miss
restores the earlier notice state. There is no notification timer or wait for
another gate/finish. Runtime progress inspects three local route segments;
additional checks remain bounded rather than searching all gates each tick.

This changes notification state only. Ordered gate consumption, exact swept
bridge-layer acceptance, widths, finish timing, five laps and no-penalty rules
are retained. Rules remain `standing-5-road-gates-v16`, physics 0.49, compiler
20. The two compact replays retain their exact previous lap ticks; no further
record migration or rules-key reset is needed for this feedback repair.

Changed files:

- `game/race/track_session.gd`: immediate rejection/finish notices, baked legal
  overlap, bypass progress notification and shared local progress projection.
- `game/tests/test_checkpoint_notices.gd`: first-tick width/layer notices,
  continuous-hint hairpin bypasses, overlapping bridge branches, starting
  grid, rewind/replay, backward returns and forward/finish recovery.
- `game/tests/test_bridge_entry_checkpoints.gd`: all 96 speed/phase/direction
  laps now require no false warning; actual entry/exit and rewind checks cover
  all five vehicles.
- `game/tests/test_checkpoint_bridge_layers.gd`: both actual five-lap compact
  simulations explicitly reject any false warning during the entire race.
- `game/tests/capture_checkpoints.gd`: `--screen=late-notice` uses the actual
  runtime physics step to create a fresh miss and recover it, with unique
  screenshots. Other captures now supply the gate's actual route hint when
  creating their diagnostic miss.
- `scripts/dev.ps1`: includes the notice regression in full validation.
- This record/evidence, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and
  links from the earlier checkpoint repair records.

Actual commands use pinned Godot 4.7.2 via
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with
`-CommandTimeoutSeconds 120`. Python is the repository's
`.tools/backend-venv/Scripts/python.exe`.

| Action / command | Actual result |
|---|---|
| `TestScript -ScriptPath res://tests/test_checkpoint_notices.gd` | Final: 281 checks, zero failures. All 61 gates' wrong-layer warnings/recovery, 16 continuous-hint hairpin bypasses, both sides at 30/60/120/200 km/h and three crossing phases, exact notice rewind/replay, earlier underpass branch, grid and rejected finish recovery. |
| `TestScript -ScriptPath res://tests/test_bridge_entry_checkpoints.gd` | Final: 258 checks, zero failures. 96 complete clean laps at 30–200 km/h, both directions/eight phases; all five vehicles' actual entry/exit and rewind; mixed sweeps; five compact laps at 25,685 ticks without a false warning. |
| `TestScript -ScriptPath res://tests/test_checkpoint_bridge_layers.gd` | 259 checks, zero failures. Dust cloud finishes five compact laps at 29,116 ticks without a false warning; both directions, bridge start and Knit remain covered. |
| `TestRouteValidation` | 266 checks, zero failures. Legal tight bends/inside miters, shortcut rejection, ordered recovery and high-speed sweeps retained. Desktop sample: 4.05 microseconds per tick; not a mobile measurement. |
| `TestTracks` | 167 checks, zero failures, including historical three-lap physics/replay fixtures. Ordinary races above remain five laps. |
| `TestRewind`, `TestPractice` | 57 / 53 checks, zero failures. Practice still reports four ObjectDB instances at exit. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 249 scripts parsed, zero failures. |
| `CaptureCheckpoints -Screen late-notice` | 25 checks, zero failures. Fresh wrong-layer crossing at approximately 119 km/h reports a miss in one physics tick, after less than 0.5 m travel; the first presentation frame has the banner. Actual deck-exit recovery consumes the gate and clears it. Both captures inspected. |
| `CaptureCheckpoints`, `CaptureCheckpoints -Screen bridge-entry`, `CaptureCheckpoints -Screen dust-cloud` | 132 / 23 / 24 checks, zero failures. Persistent bearing/visibility and both previous bridge recoveries retained. |
| `python -m pytest backend/tests/test_verifier.py -q` | 52 passed; existing Starlette/httpx deprecation warning. |
| `python build/checkpoint-notice-2026-10-03/verify_recordings.py` | Canonical desktop verifier accepts both saved five-lap recordings. Dust cloud: `[5915,5804,5791,5803,5803]`; Over and under: `[5217,5120,5115,5112,5121]`. Exact prior tick totals retained. Helper/replays are under ignored `build/`; results saved below. |
| Public `GET http://127.0.0.1:18181/v1/manifest` | Now reports matching rules v16, physics 0.49 and compiler 20, superseding the earlier v14 deployment observation. Read-only; no service rebuild performed by this follow-up. |
| `Doctor` | Pinned engine/templates found; DN2103 attached. No Android export/install or physical-device driving. |
| Scoped `git diff --check` | Passed; only ordinary CRLF-to-LF informational warnings. |

During development, the future-bridge-branch regression exposed a false notice
in the first repair attempt. A fresh nearest-vertex search selected the other
crossing road; sharing the bounded local projection fixed that failure.
Expanding actual-car coverage also exposed three invalid test assumptions:
the kart caps at 108 km/h, so the exit gate 0.266 m before the ramp end is
accepted in its first deck tick and exits on the second tick. The final test
asserts both states and exact rewind reproduction. Handling was not changed
to satisfy those assumptions.

Evidence:

- [First tick after the rejected crossing](evidence/checkpoint-notice-2026-10-03/first-tick-missed.png)
- [Actual fast recovery clears the notice](evidence/checkpoint-notice-2026-10-03/fast-recovery-cleared.png)
- [Both canonical five-lap results](evidence/checkpoint-notice-2026-10-03/desktop-verification.json)
- [Observed live API manifest](evidence/checkpoint-notice-2026-10-03/live-api-manifest.json)

Desktop code/tests and screenshot verification are complete. Owner driving
acceptance remains after restarting the game, especially legal inside lines
and both reported bridge sections. No physical-device driving, Android
export/install, full `Validate`, live ticket/replay write, service deployment,
NAS/production action, player-file change or mixed-working-tree commit was
performed by this follow-up. Matching live manifest alone does not establish
end-to-end online race acceptance.
