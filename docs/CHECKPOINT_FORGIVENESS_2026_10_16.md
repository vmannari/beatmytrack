# Forgiving checkpoints — 2026-10-16

Owner feedback rejects the previous checkpoint strictness as annoying. Requirements
CF01: permit ordinary edge mistakes; CF02: retain major shortcut rejection; CF03:
matching local/server contracts and honest driving evidence. This supersedes the
rules21 half-metre allowance and the requirement to reject every excursion more
than one metre from the road.

The actual task-start build blocks twelve of the 22 tested centre/edge paths:
offsets ±6.5, ±6.75 and ±7 m require returning to a gate in either direction.
The original ±6 m paths pass. These are synthetic positions sampled along the
unchanged physical Star geometry; the car-centre offset is not the distance off
the road. Baseline results are retained in `baseline-lanes.json`.

Rules22 gives creator-road gates a **proposed two-metre recovery buffer** beyond
the connected road/kerb edge, up from 0.5 m. Spline gate candidates are spaced
8 m apart instead of 3 m. Star now has 34 forward / 35 reverse required gates,
down from 84/83. All still require a forward swept crossing in order and the
correct bridge layer; a major missed section still requires returning. Road
geometry, car physics and the finish line are unchanged by this task.

Preparation considers quarter-metre interior offsets as well as wider boundary
and start approaches. It uses the same crossing arithmetic as racing. An early
crossing of a spline gate's infinite plane outside its finite span no longer
produces a warning while the car remains in a valid prepared approach. Wrong
bridge layers retain immediate warnings. This changes the warning only; it never
grants checkpoint credit. Repeated route projections are memoized during preparation
and the existing compiled-track cache remains in use, fenced by the scoring key
so retained tracks cannot reuse the old strict layout. Cold desktop preparation
varied by several seconds during concurrent checks; phone loading is unmeasured.

## Actual checks

All Godot commands use pinned 4.7.2 through:
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/<name>.gd`.
Logs and machine-readable results are retained under
`docs/evidence/checkpoint-forgiveness-2026-10-16/`.

- `test_checkpoint_forgiveness.gd -TestArgument --baseline`: actual rules21
  reproduces all twelve reported edge-path failures. Final regression: **48
  checks pass**, including 38 centre/edge paths through ±7 m without a false
  notice, four large cuts rejecting and return recovery without automatic penalties.
- `test_star_checkpoint_consistency.gd`: **58 pass**, including paved, wider-road
  and unrecentered start approaches. The two previous small-cut rejection cases
  are deliberately superseded by forgiveness; the original large bypass cases
  remain required. A wide reverse approach initially produced an early false
  warning, reproduced and fixed without relaxing gate credit or layer checks.
- `test_star_gate_tolerance.gd`: **201 pass**, including all eighteen five-lap
  paths, original deeper corner cuts, marker bounds and a real Compact race:
  five laps / 47,712 ticks / zero collisions / exact complete state and lap replay.
- `test_star_checkpoint_shortcuts.gd`: 5,144 chord candidates; **3,005** leave the
  new two-metre road-neighbourhood check, and none completes a lap. All sampled
  cuts saving at least 40 m reject. Smaller cuts inside the recovery zone are
  intentionally allowed; the largest accepted broad-phase candidate saves about
  36.68 m on this overlapping star-shaped road. This is a bounded sampling result,
  not an exhaustive no-shortcut guarantee. The original 91.11 m saving rejects.
- General gates266, notices533, bridge layers259, bridge entry258, bridge exit2527
  (all five cars), rewind61 and retained catalog centrelines27 pass. Catalog paths
  are geometric checks, not actual car driving on all tracks.
- `PYTHONPATH=backend .tools/backend-venv/Scripts/python.exe build/verify_forgiving_checkpoint.py`:
  matching rules22 geometry has 34 gates; real lightweight checker accepts the
  legal five-lap trajectory and rejects the original large shortcut. The real
  GodotVerifier accepts the 47,712-tick recording on the concurrent physics0.63 build.
- Backend board separation/standalone staging: **2 passed**. An initial staging
  attempt caught physics0.63 source while the independently maintained fixture
  was still0.62; after that concurrent work caught up, the checks pass. This task
  does not change physics or its historical archives.
- Project parse: **832 scripts / zero failures** before the standalone capture
  script was added; the latter compiles and runs in its native captures. The final
  parser result and Ruff/scoped-patch checks are retained with the logs.

The first revised envelope omitted some intermediate offsets and reproduced
false misses at ±5 m. The final envelope includes them. The first test used a
legacy penalty field removed by independent concurrent cleanup; it now checks
the actual race clock. That cleanup remains outside this checkpoint. Old rules21
sweep evidence is preserved separately; follow-up tests write to this task's folder.

## Review and remaining acceptance

Runtime changes: `game/race/race_rules.gd`, `track_session.gd`, `spline_gate_corridor.gd`.
Matching backend changes: `contracts.py`, `rivalry.py`; rules-key assertions and
expected fixture key are updated without changing replay/document bytes. The
new forgiveness regression is included in Validate. Frozen rules020/physics050
diagnostics remain unchanged. Actual-scene captures use the original car/camera;
they are paused marker diagnostics, not a physical-drive demonstration.

New attempts use `standing-5-road-gates-v22`; immutable old stored manifests and
boards are not rewritten. The review patch preserves concurrent cleanup,
physics/fixture and other work, and leaves the Git index untouched.

This is a local change. Owner driving feel and physical-phone loading/controls
remain acceptance checks. No phone attachment check/test, APK export/install,
live backend change or deployment was performed. Online use requires matching
client/API/verifier/worker rollout while retaining workers for pinned old tickets.
