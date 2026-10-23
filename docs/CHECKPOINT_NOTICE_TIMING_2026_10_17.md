# Prompt shortcut notices and correct approach recovery — 2026-10-17

The owner reports delayed shortcut warnings and a missed-checkpoint marker ahead
of the car. This changes the notice read model while retaining rules22's 2m
recovery, 8m spline candidates and Star's 34 forward / 35 reverse required gates.
Physics0.65, road geometry, vehicles, camera, gate acceptance and old boards remain.

## Reproduction and result

The collision route hint deliberately searches a local window to retain continuity
at intersections. After a shortcut it could stay on the abandoned road. The notice
projection also considered only that hint and the previous accepted gate. Some cuts
therefore remained silent until the finish. Separately, the spline notice envelope
used one maximum progress allowance across an entire folded approach; Star's
allowance reached roughly44m and delayed unrelated bypasses.

`test_checkpoint_notice_latency.gd --catalog` exercises Star in both directions,
three packaged road/bridge fixtures and the27 retained catalog documents. It walks
continuous0.2m sweeps with the normal incremental route hint and layer continuity.
These are geometric path diagnostics, not27 physical driving tests.

| Check | Frozen before | Final |
| --- | ---: | ---: |
| Blocked sampled cuts | 500 | 500 |
| Blocked cuts still without a warning after the path | 2 | 0 |
| Worst delay after correct-layer road reentry | 620.224m | 6.277m |
| Star forward worst delay | 341.124m | 0m |
| Star reverse worst delay | 348.979m | 3.333m |
| Reproduced false ahead warning on Silmukka | gate18 | clear |

53 cuts rejoin the road's X/Z position on the wrong layer. They remain required
to warn and block the finish, but are excluded from the correct-layer reentry
latency bound. The other447 sampled blocked cuts warn within8m, or4m for spline
tracks. Those are regression limits, not new driving rules. At overlapping roads,
the car can still be within the required approach's forgiving recovery corridor;
leaving that corridor provides unambiguous bypass evidence. The worst final case
is6.277m on Dust cloud; this allowance avoids recreating false approach warnings.

The exact repro is available in
[`baseline-catalog-latency.json`](evidence/checkpoint-notice-2026-10-17/baseline-catalog-latency.json)
and [`final-catalog-latency.json`](evidence/checkpoint-notice-2026-10-17/final-catalog-latency.json).
The before comparison loads the actual task-start session and corridor sources;
it prepares them independently when comparing gate geometry.

## Implementation

`TrackSession` prepares an8m spatial index of route segments once. Notices can
resolve the road physically reached after a shortcut instead of waiting for the
collision hint to catch up. The simulation's collision hint is untouched.

Where roads overlap, notice progress prefers the required approach while the car
remains in its road/recovery corridor and actual layer. This covers both bridge
underpasses and two ground-road arms. Exact projection ties retain the simulation
branch. The actual swept gate and layer acceptance tests remain unchanged.

Spline preparation also records the physical approach cells covered by all171
accepted lane references. Runtime protects that local approach instead of granting
the entire bend's maximum progress allowance everywhere. Preparation follows the
earliest crossings runtime can actually accept, including multiple intersections
on folded lanes. Cell sampling and adjacent-cell lookup conservatively cover the
full lane between gates; they never credit a gate or enlarge its accepted span.

Notice layout version3 independently fences retained rules22 caches. A cache with
old notices is rebuilt without changing the race key or gate geometry. All six
acceptance arrays match the frozen preparation on all32 cases. The largest
serialized gate/notice preparation among these cases is136,424bytes; existing
prepared-track/world cache admission accounts for the full track fields. Per-tick
work queries local buckets and the current gate's approach cells, with no new
route-history or trajectory storage.

## Validation and native evidence

Pinned Godot4.7.2 is used through `scripts/dev.ps1 TestScript`. Final checks:

| Script | Result |
| --- | --- |
| `test_checkpoint_notice_latency.gd --catalog` | 2154 checks,0 failures |
| `test_checkpoint_notices.gd` | 537 checks,0 failures |
| `test_star_checkpoint_consistency.gd` | 58 checks,0 failures |
| `test_star_gate_tolerance.gd` | 201 checks,0 failures; five real Compact laps,47712ticks,zero collisions,exact replay |
| `test_checkpoint_bridge_layers.gd` | 259 checks,0 failures; five real Dust cloud laps,29116ticks |
| `test_checkpoint_forgiveness.gd` | 48 checks,0 failures;38 forgiving paths,zero notices |
| `test_checkpoint_rules.gd` | 266 checks,0 failures |
| `test_rewind.gd` | 61 checks,0 failures |
| `test_script_parse.gd` | 847 scripts,0 failures |

The earlier bridge entry258 and exit2527 checks also passed during this task;
they preceded the final required-approach preference. The final focused crossing
regressions and physical Dust cloud/Star laps cover that last change. Logs,
identities and exact commands are recorded in the evidence report. The new
self-contained latency regression is included in Validate; catalog coverage is
optional because its retained documents live under build. Reports for fixture and
catalog scopes have separate paths.

The native capture reconstructs Silmukka's gate18 approach using the frozen and
final computed notice states at the same car/camera pose. The rejected marker
was0.869m ahead along its gate direction. Final presentation is quiet. These are
paused scene diagnostics, not physical driving demonstrations:

- [Compatibility before](evidence/checkpoint-notice-2026-10-17/gl_compatibility/before-ahead.png)
  and [after](evidence/checkpoint-notice-2026-10-17/gl_compatibility/after-ahead.png).
- [Mobile before](evidence/checkpoint-notice-2026-10-17/mobile/before-ahead.png)
  and [after](evidence/checkpoint-notice-2026-10-17/mobile/after-ahead.png).

## Retained initial attempts

The first spatial lookup removed the long catalog delays but could borrow progress
from a closer deck during an actual Over and under lap. Restricting progress to
the current layer alone then exposed a ground-road crossing on Dust cloud. The
final required-approach preference fixes both reproduced cases, now permanent
regressions. Actual five-lap Over and under checks pass at25685ticks; final Dust
cloud checks pass at29116ticks.

An initial spline approach map started at the nearest planned crossing. A legal
reverse variable-width lane could accept an earlier crossing and reach a gap in
that map. Recording runtime's earliest valid crossings fixes the regression.
An initial universal4m diagnostic bound was too strict at Dust cloud's overlapping
recovery corridors; its real6.277m case is retained and the raster bound is8m.
Forgiving driving margins are unchanged.

Initial frozen-loader/variable-scope parse mistakes and a PowerShell array-argument
attempt are retained in the tool history/logs. A later native capture encountered
an unregistered concurrent `AchievementProgress` class. Normal import encountered
the audio DLL copy lock held by the owner's running editor; that process was left
running. A recovery-mode import refreshed local classes without loading the
extension. The first relative log path produced a Windows path warning; the clean
retry uses an absolute log path. Concurrent achievement, bridge tire-mark and
phone-deployment work is preserved.

## Scope and acceptance

Runtime changes are limited to `track_session.gd` and `spline_gate_corridor.gd`.
The marker renderer and HUD artwork are unchanged. The task-only review patch
compares against saved task-start files and excludes concurrent changes; the Git
index is untouched. All generated captures and logs are local evidence.

Owner driving feel remains an acceptance check. No phone attachment check/test,
APK export/install, backend mutation or deployment was performed for this task.
The existing matching rules22 client/API/worker rollout requirement remains a
separate prior task; this fix introduces no new scoring key or backend contract.
