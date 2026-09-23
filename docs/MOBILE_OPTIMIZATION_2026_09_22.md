# Mobile rendering and road-gate optimization ? 2026-09-22

Requirements: R01/R03/R07/G01/V02/V03/V04/V05/Q01. Owner-authorized performance/quality tradeoff and revised lap validation contract.

## Implemented behavior

- Original seamless 1024?1024, 32 m surface-factor texture replaces repeated asphalt/sand noise arithmetic. Asphalt binder/mineral variation and directional grain remain; random crack/repair shapes are removed. Mipmapped sampling is shared by terrain, creator roads and bridge decks. Grass/shoulder blending, wet/ice effects and road geometry remain. Generator: `scripts/bake-surface-detail.py` (existing development numpy, no runtime dependency or external assets). Texture provenance is original procedural code, no third-party image.
- Directional shadows use a 1024 map, one orthogonal projection and 65 m range. Lighting remains; shadows lose resolution. Camera/handling were not changed by this task.
- Ordered swept road gates replace whole-route/history shortcut searches. Generated once; each tick tests the expected gate and its neighbour, consuming additional gates only if the same sweep crosses them in order. Telemetry projects onto three local segments using the simulation's existing hint. The per-tick work does not scan all route points.
- All required gates must be passed before finish. Missing a section highlights the required gate in the world/minimap and says to return. Recovery time remains on the clock. No +5 s penalty. Reverse travel, stationary overlap, skipped gates and completing the remainder after a hairpin cut cannot manufacture a lap.
- Owner rejected the initial dense arrangement. Final gates are approximately 12 m apart, supplemented at abrupt corners, with a 3 m deduplication distance and directions sampled over 4 m. This is about one sixth of the 2 m draft density, plus sharp corners. Widths are bounded by road width and nearby drivable cells, with small kerb tolerance. Only the missed gate is drawn across the world. Tight inside/outside lines are tested separately from infield cuts.
- Rule identity `standing-5-road-gates-v10` isolates new PBs from old penalty rules. Compiler 18 includes route widths in native data; visual kit 52 identifies the baked surface. Player files are preserved.

## Commands and tests actually run

All engine commands use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>` and pinned Godot 4.7.2.

| Action | Actual outcome |
|---|---|
| `TestRouteValidation` | 96 checks pass, final spaced gates. Includes 16 real Silmukka cuts plus recovery, two tight-radius inside/centre/outside sweep cases at three speeds, reverse/stationary checks and five complete laps. Desktop hot-path mean 2.65 microseconds/tick; this is not a mobile measurement. |
| `TestStartLine` | 27 checks pass with final gates: five laps both directions, exact physics replay, start-line editing. |
| `TestTracks` | 167 checks pass with final gates, all four historical tracks complete and replay exactly. No legacy invariant removed. |
| `CaptureCheckpoints` | 7 checks pass with final gates; actual missed sweep, world/minimap/notice, recovery and restart. |
| `TestResults` | 104 checks pass after replacing validation. |
| `CaptureBridgeHUD` | 157 checks pass. Obsolete injected +5 s expectation updated to the explicitly authorized no-penalty contract. |
| `TestSurfaceProfile` | 928 graphical checks pass for material binding, geometry retention and restoration. |
| `TestRecords`, `TestSurfaces`, `TestMobileControls` | 53 / 50 / 555 checks pass in this optimization task. |
| `ExportAndroid -QuickValidation` | Final export passes import/startup, driving 74, catalog 18, menus 22. Full all-project suite not run. |

Initial dense-gate compilation caught an Array typing error, fixed before final tests. Sparse gates failed legacy Offroad laps; final route-derived spaced gates pass those unchanged assertions. Dense offset-line experiments exposed an older Silmukka guide displaced toward grass; those blindly offset paths were not valid road-line fixtures. Final legitimate-line tests use explicit 10 m-wide tight bends, while the actual Silmukka fixture remains the shortcut/recovery test. Historic `test_route_validation.gd` and `test_silmukka.gd` retain old +5 s expectations and are not current rules acceptance; `TestRouteValidation` now invokes `test_checkpoint_rules.gd`.

## Physical phone comparison

Physical DN2103, Android 13, Mali-G77 MC9. Normal 0.667 render scale; same AI, touch-stress HUD, timing/Results telemetry, particles, weather and trails. Each track restarts, warms five seconds and samples 45 seconds. Runs are diagnostic/unscored. Before and final APK hashes, configurations, temperatures and raw reports are retained in `evidence/optimization-before-2026-09-22/` and `evidence/optimization-final-2026-09-22/`. Intermediate `optimization-after` evidence used sparse draft gates and is not the final result.

Commands:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -Baseline -SkipInstall -Seconds 45 -ReportName optimization-before-2026-09-22
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -Baseline -Seconds 45 -ReportName optimization-final-2026-09-22
```

| Track | Before median / p95 | Final median / p95 | Rules CPU before / final |
|---|---:|---:|---:|
| Ajorata | 21.173 / 25.130 ms | 16.802 / 19.784 ms | 1.922 / 0.064 ms |
| Storm | 25.930 / 30.669 ms | 16.814 / 19.648 ms | 2.440 / 0.056 ms |

Final Results telemetry averages 0.056 ms (Ajorata) / 0.052 ms (Storm) per rendered frame. Frame medians improve 20.6% / 35.2%. Both p95 values remain above 16.67 ms, so some frames still miss 60 FPS. Final APK installed successfully; probe files removed and normal app relaunched.

Combined changes are measured together: do not add their savings to the earlier isolated experiments. CPU section timings are per rendered frame (potentially multiple physics ticks); GPU/CPU costs overlap. Median improvement is not a sustained 60 FPS guarantee. Runs are sequential, one device, finite AI paths, not a fleet or thermal soak.

## Changed files and evidence

Runtime: `game/race/track_session.gd`, `race_rules.gd`, `game/editor/track_compiler.gd`, `game/track/native_track.gd`, `native_track_visual.gd`, `bridge_presentation.gd`, `surface_detail.gdshaderinc`, `game/assets/textures/surface_factors_v1.png` and import settings, `game/project.godot`, `game/core/game.gd`, `game/ui/checkpoint_marker.gd`, `hud_road_map.gd`, `playground_hud.gd`.

Tooling/tests: `scripts/bake-surface-detail.py`, `scripts/profile-features-phone.ps1`, `scripts/dev.ps1`, `game/tests/test_checkpoint_rules.gd`, `capture_checkpoints.gd`, `test_bridge_hud.gd`. Documentation: this report, AGENTS, status and Phase 0 plan. A task-only patch compares with the saved pre-task dirty-worktree snapshot, avoiding unrelated handling/HUD/Results edits.

[Missed checkpoint capture](evidence/optimization-final-2026-09-22/checkpoint-missed.png). Desktop visual inspection retained the road's granular appearance; crack detail is absent. Remaining human acceptance: final quality on the phone, varied real racing lines around creator hairpins/intersections/bridges, and longer thermal runs. Gate validation enforces ordered road sections with kerb tolerance; it does not claim continuous tyre-by-tyre boundary policing between gates. No production service deployment.


## Inside recovery allowance ? 2026-09-22 follow-up

Owner feedback: gentle inside excursions that already lose grip/time were unfairly requiring a return. Requirements R03/R07/G01/V03/Q01. Rules v11 adds up to 3 m to the inside end of a gate. The allowance is full for local approach/departure deflections up to 30 degrees and smoothly falls to zero at 60 degrees, measured using route points 8 m before/after the gate. Straight gates and outside margins retain their bounds. Ordered progress and return on a genuine miss remain. This is a fixed geometric allowance, not a runtime estimate of time gained/lost.

Gate drawing now uses the midpoint of its asymmetric accepted span; the visible line matches both accepted endpoints. Widths/curvature are computed once, with no new per-tick search. New records use `standing-5-road-gates-v11`.

Changed files: `game/race/track_session.gd`, `game/race/race_rules.gd`, `game/tests/test_checkpoint_rules.gd`, this report and status/plan. Actual commands: `TestRouteValidation` passes 108 checks (including both curve directions, inside recovery, oversized/outside rejection, visible endpoints, and all previous hairpin cuts); `CaptureCheckpoints` passes 7 checks, `TestStartLine` passes 27, and `DeployAndroid -QuickValidation` passes focused checks and installs/launches successfully on the attached phone. See `evidence/checkpoint-forgiveness-2026-09-22/` for final logs and screenshot. No handling changes; no new phone performance benchmark. Human acceptance of the new tolerance on the complained-about curves remains.

## Bridge texture restoration — 2026-09-22

Requirements: V02/V04/V05/Q01. Creator bridges lost asphalt detail because their material did not bind the new baked `surface_factors` sampler. Added the existing shared texture binding in `game/track/creator_bridge_visual.gd`; deck and ramp geometry and physics are unchanged.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureBridgeHUD` using pinned Godot 4.7.2. Result: 157 checks, zero failures. Inspected the desktop screenshot and confirmed visible asphalt grain across the creator bridge deck and ramp. [Screenshot](evidence/bridge-texture-2026-09-22/creator-race.png).

Changed files: the bridge visual script, this document, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and the screenshot above. No Android export or device test performed; device attachment was not checked. Remaining acceptance: owner review and phone appearance. This is a one-line material fix on top of the existing uncommitted mobile optimization work.


## Outside recovery and marker clarity - 2026-09-22

Requirements R03/R07/G01/V03/V05/Q01; owner screenshot follow-up. Rules v12 adds up to 6 m beyond the existing outside gate allowance on bends, ramping smoothly from negligible to clear curvature. Inside recovery taper and ordered forward crossing remain intact. New rule identity separates local PB comparisons from v11. Straight gates and the finish line retain their bounds.

The missed marker separates the road span (65% opacity) from development-only off-road extensions (22% opacity). Both world and HUD labels say exactly "Missed checkpoint". `CheckpointMarker.SHOW_DEVELOPMENT_MARGINS` is the single removal switch. Road spans use route width bounded by sampled drivable cells; the cell resolution can cause small edge differences at complex junctions. Margin endpoints match the accepted gate bounds.

Changed runtime files: `game/race/track_session.gd`, `race_rules.gd`, `game/ui/checkpoint_marker.gd`, `playground_hud.gd`, `game/core/game.gd`. Tests: `game/tests/test_checkpoint_rules.gd`, `capture_checkpoints.gd`. Documentation: this report, development status and Phase 0 plan. A [task-only patch](evidence/checkpoint-outside-2026-09-22/checkpoint-outside.patch) preserves the pre-existing dirty workspace as the comparison base; unrelated changes were not committed.

Actual commands used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 <Action>` with pinned Godot 4.7.2:

- `TestRouteValidation`: 122 checks pass, including outside excursions on 6/10 m tight bends, both windings on gentle bends, bounded excessive excursions, existing 16 real hairpin shortcuts/recovery and five-lap completion.
- `TestStartLine`: 27 checks pass, including replay and both directions.
- `TestTracks`: 167 checks pass, including legacy complete laps and deterministic replays.
- `TestRecords`: 53 checks pass.
- `CaptureCheckpoints`: 14 checks pass, checking actual miss/recovery/restart, exact labels, road width, transparency and acceptance extensions. Initial capture caught unchanged HUD wording; fixed and rerun successfully.

[Desktop screenshot](evidence/checkpoint-outside-2026-09-22/checkpoint-missed.png) captured and inspected. No Android export/install or physical-device test performed. Remaining acceptance: owner driving the reported bend and judging outside forgiveness and margin visibility on phone; arbitrary creator junctions are not exhaustively verified. No vehicle-physics change or merge; full all-project regression not run.
