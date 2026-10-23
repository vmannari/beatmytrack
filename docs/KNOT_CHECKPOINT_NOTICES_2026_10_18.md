# Knot checkpoint warning — 2026-10-18

KCN01–KCN02/G01/R01/Q01: reproduce the owner's premature missed-checkpoint
warning on Knot and fix its notice projection while retaining ordered acceptance,
bridge layers, actual shortcut warnings, replay and bounded local caches.

## Reproduction and correction

The fixture is an exact copy of the retained published Knot document, SHA-256
`c237960ed63d03361858789517d02a3bb742740fe3795753bed3a12e6de53b13`.
Its original catalog provenance is in [provenance.json](evidence/knot-checkpoints-2026-10-18/provenance.json).

At forward Compact simulation tick590, the car is at `(52.32339,-24.88533)`
on the ground approach around35.66m. Required gate index3 (the fourth checkpoint)
is still10.766m ahead along its normal. The old notice resolver reports progress
166.343m instead, borrowing a slightly closer future road arm. The warning clears
when the car later crosses the actual gate, so a completed-lap check alone misses
this defect. Constant ±2m and ±4m lanes reproduce it too; the centreline stays quiet.

The previous layer test evaluated the car's position with each candidate tangent.
Here, the ground road runs diagonally beneath an almost aligned bridge and is
misclassified as elevated. That excludes the correct required approach from the
notice preference even though the simulation retains its correct ground layer.

`TrackSession` now prepares each route branch's bridge layer by following the
same ramp continuity used for gate preparation. Quarter-metre subsegment states
also represent bridges between sparse ground vertices. Runtime evaluates the
projected point on that branch using one prepared state; it never walks the
route per tick. Non-creator bridge checks likewise use the projected road point.

Notice layout version4 rebuilds older cached notices without changing rules23.
Knot adds7,870bytes of prepared layer data; its complete serialized preparation
is15,300bytes. The largest preparation in the32-case catalog check is142,424bytes.
Existing prepared-track/world accounting includes these fields; cache budgets
remain unchanged. All six acceptance arrays match the task-start implementation.
Gate positions, spans, order, driving physics, track documents and records remain.

## Validation

Pinned Godot4.7.2 through `scripts/dev.ps1 TestScript`, with test user data under
`build/knot-test-user`. Tests are desktop diagnostics, not phone measurements.

| Check | Actual result |
| --- | --- |
| Knot focused regression, `--drive --compare-before` | 264 checks,0 failures |
| Forward physical Compact | five laps,36,030ticks,zero collisions/warnings |
| Reverse physical Compact | five laps,35,779ticks,zero collisions/warnings |
| Quantized replay, both directions | exact vehicle snapshots and lap times |
| Ten constant-offset lanes | five laps each,zero warnings, both directions |
| Existing notice regression | 537 checks,0 failures |
| Notice latency,27 catalog documents plus five fixtures | 2,171 checks,0 failures |
| Ordered gate rules | 266 checks,0 failures |
| Hairpins and actual Star driving | 65 checks,0 failures; five laps/47,712ticks |
| Bridge layers and actual Dust cloud driving | 259 checks,0 failures; five laps/29,154ticks |
| Rewind | 61 checks,0 failures |
| Final project parser, after helper cleanup | 890 scripts,0 failures |

The catalog retains511 blocked sampled cuts with no silent cuts. Worst
correct-layer reentry delay remains6.277m on Dust cloud; Knot's sampled blocked
cuts warn by reentry. These geometric sweeps are distinct from physical driving.
New assertions also cover every Knot gate's wrong-layer rejection and valid
recovery, sparse bridge projection, notice-version3 cache rebuild/reuse and exact
task-start acceptance. The focused regression is part of Validate; physical
replay and task-start comparison are explicit optional arguments.

The actual paused scene at the reproduced car/camera pose shows the old warning
and the corrected clear state. These are native renderer captures, not driving
videos:

- [Compatibility before](evidence/knot-checkpoints-2026-10-18/gl_compatibility/before.png)
  and [after](evidence/knot-checkpoints-2026-10-18/gl_compatibility/after.png).
- [Desktop Mobile before](evidence/knot-checkpoints-2026-10-18/mobile/before.png)
  and [after](evidence/knot-checkpoints-2026-10-18/mobile/after.png).

## Commands, artifacts and scope

Successful calls use `$env:APPDATA = Join-Path (Get-Location) 'build/knot-test-user'`
and this pinned entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/dev.ps1 TestScript -ScriptPath res://tests/test_knot_checkpoint_notices.gd -TestArgument '--drive','--compare-before' -CommandTimeoutSeconds 240"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_checkpoint_notices.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_checkpoint_notice_latency.gd -TestArgument --catalog -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_checkpoint_bridge_layers.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_knot_checkpoint_notice.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_knot_checkpoint_notice.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
```

Ordered-gate, hairpin, rewind and initial parser checks ran sequentially in one
PowerShell process with process-scoped execution-policy Bypass, using
`foreach ($knotTest in @('test_checkpoint_rules','test_hairpin_checkpoints','test_rewind','test_script_parse'))`
and `& ./scripts/dev.ps1 TestScript -ScriptPath ('res://tests/'+$knotTest+'.gd')`.
That entry point reuses one log path within a process; intermediate successful
counts are retained in the tool transcript and validation receipt. The final
parser runs separately after removing temporary diagnostic scripts.

The [evidence directory](evidence/knot-checkpoints-2026-10-18/) includes frozen
sources, original/final diagnostic logs, catalog results and a task-only patch.
The existing latency test writes into the prior hairpin report path; this task's
result is saved separately as `catalog-latency.json`, and the historical report
was regenerated using the frozen task-start session. Initial shell-policy and
sandbox log/certificate failures, a nested-shell variable-expansion error, and
the first historical-report helper's duplicate global-class error are retained
in the tool history. Successful tests ran with approved Windows certificate
access and workspace-only test saves. No failing assertion was weakened.

Changed runtime: `game/race/track_session.gd`. Added regression/fixture/capture
scripts, their UIDs, one Validate entry, this report and project status entries.
The source-only checkpoint preserves concurrent work and leaves the Git index
untouched. Owner driving acceptance remains. No phone attachment check/test,
APK export/install, live backend mutation or deployment was performed.
