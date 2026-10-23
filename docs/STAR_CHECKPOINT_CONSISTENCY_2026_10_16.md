# Star checkpoint consistency — 2026-10-16

Owner reports very large shortcuts and inconsistent strictness on Star.
Requirements SC01: reject skipped route sections; SC02: preserve ordinary paved
inside/outside lines and shallow recovery; SC03: matching lightweight verification,
historical contracts and replay; G01/R01/Q01: retain physical road/car/camera,
version scoring, record actual checks and acceptance limits.

## Reproduction and implementation

The exact retained Star fixture has 400.589 m of route and originally 19 gates.
A chord from route distance 92 to 252 skips 160 m of route, saves 91.110 m of
travel and still completes five laps with the actual task-start rules20 source.
Its timestamped trajectory also passes the real lightweight checker when given
the original prepared gates. This is a synthetic movement reproduction, not a
claim that an automated physical car drove this shortcut.

Rules21 prepares denser candidate gates around splines, then selects a common
ordered chain that is reachable through 75 lane references: variable road widths,
steady interior offsets, and start/finish approaches with and without recentering.
Local offset folds are removed so a legal inside line never requires an artificial
loop. Star retains 84 mandatory gates forward / 83 reversed. The construction is
shared by local racing and exported server geometry; no gate is credited from
route projection or maximum historical progress.

Creator-road gates measure the connected local road/kerb span, stopping at its
first gap. A proposed **0.5 m car-centre recovery allowance** replaces the uneven
extra inside/outside allowances on raster roads. It preserves every tested paved
lane and the existing ±6 m Star wheel-off-road paths. This intentionally supersedes
the previous +1 m gate padding for the new scoring contract. Finish geometry,
strict ordered crossings/layers, required return to a missed section and zero
automatic time penalties remain. Legacy geometry-only test/native routes retain
their old width fallback.

Projection onto a nearby returning arm must not produce an early miss. Static
notice bounds cover the legal lane approaches, and crossing a later gate while
the required gate is still ahead cannot trigger a warning. These are display-only
bounds; acceptance remains swept finite gates. The compiled track retains its
immutable gate preparation for subsequent sessions, with fresh mutable session
state and no serialized cache field. Route rebuilding clears preparation.

Cold Star preparation in concurrent desktop checks was roughly 1–2 seconds,
under the existing race loading path; retained preparation was tens of microseconds.
These are desktop diagnostics, not phone latency/FPS measurements. The lane
references are a finite geometric construction, not a proof about every possible
driving line. Physical-phone feel and cold loading remain acceptance checks.

## Actual verification

Commands use pinned Godot 4.7.2 through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/<name>.gd`.
Detailed command logs, task-start source and native views are under
`docs/evidence/star-checkpoint-consistency-2026-10-16/`.

- `test_star_checkpoint_consistency.gd`: 64 checks, zero failures. Paved/edge,
  variable-width and unrecentered start lines pass in both directions without
  transient missed notices. Large cuts reject, and returning recovers the lap.
  Actual old-rule five-lap shortcut and new-rule full-route trajectories are saved.
- `test_star_checkpoint_shortcuts.gd`: 5,144 chord candidates saving at least 3 m
  (4 m endpoint/span grid, skipped spans 12–160 m); 3,561 leave the one-metre
  road-neighbourhood diagnostic. None of those deep candidates completes a lap.
  Broad plane candidates are confirmed with real session stepping. Remaining
  accepted off-road chords stay in that shallow neighbourhood; no universal
  no-shortcut claim is made.
- `test_star_gate_tolerance.gd`: 351 checks, zero failures on final rules. Eighteen
  five-lap centre/edge paths in both directions, existing deep-cut recovery,
  marker endpoints and real Compact edge driving pass. Real race: 47,712 ticks,
  five laps, zero collisions, exact complete input/state/lap replay.
- `test_star_spline_laps.gd`: 51 checks, zero failures on final rules. Checks the original physical/compiled centreline,
  inside offsets and both start directions, plus real centre/inside driving and
  canonical replay; its result is retained with the command logs.
- General gate266, notice533, bridge-layer259, bridge-entry258, bridge-exit2527
  (all five vehicles), rewind61 and retained catalog-centreline27 checks pass.
  Catalog checks follow geometric centrelines; they are not 27 physical driving
  or phone tests. Project parse: 837 scripts, zero failures after registry refresh.
- `PYTHONPATH=backend .tools/backend-venv/Scripts/python.exe build/star_backend_check.py`:
  real GodotVerifier accepts the 47,712-tick race on rules21; server geometry has
  the same 84 gates. Real trajectory checker accepts the legal route, reproduces
  old-gate shortcut acceptance, and rejects that same shortcut with new gates.
- Backend selected suite initially: 69 passed / one historical-fixture failure.
  The frozen physics050 diagnostic initially received current rules21/cache
  assumptions. Its adapter now explicitly restores exact archived rules20 source;
  historical replay and timing bytes remain unchanged. Final focused **3 passed**
  is recorded in `backend-final-focused.xml`; initial XML is retained separately.
- Ruff on changed Python source/tests passes. Native before/after marker captures
  pass five checks per renderer in Compatibility and Mobile and were inspected.
  These are paused actual-scene diagnostic views with the same car/camera pose.

Initial experiments retained in the logs include parallel dense gates rejecting
paved lanes, missing coverage of constant offsets through a widening, and missing
unrecentered start approaches. The final construction covers all three. Initial
1 m / 0.75 m allowances left sampled deep cuts; final 0.5 m passes the bounded
sweep while retaining tested recovery. A temporary resource rename overlapped
the parser scan; importing the registry then parsing passes. Initial sandboxed
Godot could not open its ordinary user log; normal log access was required.

An existing start-line autosave assertion fails with both current rules (1/27)
and the actual task-start rules (1/28, including the comparison-loader check).
The geometry/driving checks pass in both. This task does not change editor saves.

## Files and rollout

Runtime: `game/race/track_session.gd`, new `spline_gate_corridor.gd`, `race_rules.gd`,
and the nonserialized preparation field in `game/track/native_track.gd`.
Backend: `contracts.py`, `rivalry.py`, and standalone `stage_verifier.py` packaging.
Tests include new consistency, chord sweep, retained catalog route and native
capture scripts; updated rules-key assertions and the historical rules020 fixture.
`scripts/dev.ps1` includes both new focused regressions in Validate. Fixture JSON
changes only its expected rules key for this task; concurrent physics/content changes are kept.

Concurrent physics0.61/0.62 work arrived during the checks and is outside this
checkpoint. Per-command build identities and actual results are retained; this
is not a new acceptance claim for that independent work. Shared fixture/test
physics assertions are preserved and excluded from this task's review patch.
Status-file review baselines retain concurrent entries; the standalone packaging
baseline removes only this task's new helper registration. Actual task-start
snapshots are retained separately from those scoped review baselines.

New attempts use `standing-5-road-gates-v21`; immutable v12–v20 stored revisions
derive the effective current contract, and new boards remain distinct from old
boards. Historical physics050/rules20 replay diagnostics retain their exact source
pair. No stored track, score or player save is rewritten.

The fix is local. Matching client/API/verifier/worker rollout is required for online
use; existing tickets need their pinned workers during rollout. No backend/cloud
deployment, phone attachment check/test, APK export/install or player-data mutation
was performed. Owner driving acceptance, physical-phone feel/loading and broader
device performance remain. The scoped review patch leaves the Git index untouched
and preserves unrelated workspace work.
