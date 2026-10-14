# Remaining winter/desert optimisation items

2026-10-13, owner requests all four remaining items. Requirements BPERF05 weathering uploads, BPERF06 offscreen tire-mark submission, BPERF07 zero-contribution particle shading, BPERF08 prepared geometry reuse; preserve V02/V04/V05/G01/R01/Q01, local cosmetics, original nine-second dust, five laps and canonical driving/scoring. The owner's parallel tire-mark task takes precedence over this task's trail work.

## Final implementation

- `game/vehicle/vehicle_weathering.gd`: split state-only melting from material updates, avoiding the second upload inside Desert exposure. Cache each of the twelve finish values and upload only changed values; configuration, restore, washing, reset and paint behavior remain. Unchanged values make zero upload calls. Exact pre-task state comparisons cover all five cars in Winter/Desert, including melt/wash/restore.
- `game/vehicle/trail_visibility.gd` and small hooks in `skid_trails.gd`: retain the parallel task's four-vertex joined ribbons, shading, pressure, sampling, original `MultiMesh` API, one draw and 16,384 allocated/stored slots. Conservative groups of 512 slots select a compact draw view in original global slot order. Stored segments are never deleted by visibility and reappear on return. Small/no-camera populations retain the original direct uploads. Camera refresh has a conservative metre of padding, a half-metre position interval, immediate projection/orientation/new-group refresh, and no repeated unchanged-view scan. Newly appended groups and partial groups update immediately; reset clears both counts. The draw count and retained count are distinct after compaction.
- `game/vehicle/sand_dust.gd`, `winter_snow_wind.gdshader`, `winter_air_snow.gdshader`: skip shading only when colour alpha, cloud shape, distance fade or opaque intersection gives exactly zero contribution. No low-alpha threshold, shorter lifetime, reduced density/count, smaller particles, changed wind/gravity or lower resolution is introduced. Dust birth and bridge guards remain.
- `game/track/native_track_visual.gd` and `game/ui/track_showroom.gd`: completed sliced non-editor previews now populate the existing bounded prepared-world cache and can be reused by the first race. Preview image keys include the visual kit. Road-memory entries may retain eight smaller documents rather than two, within the same 32 MiB limit; world-cache limits remain five/64 MiB. Kit 183 → 184 invalidates disposable presentation caches. Editor worlds remain excluded, and every restored world owns fresh mutable nodes/instance buffers.
- `scripts/dev.ps1`: fix `-EngineVerbose` placement before engine/user argument separation. Previously it was appended after `--` and became a user argument, preventing the requested cleanup diagnostics from showing engine details.

The provisional multi-draw trail-page approach was removed after the owner clarified precedence. The final renderer remains one draw. The saved trail-only baseline is reconstructed from the current parallel-task source by reversing only this task's visibility hooks; its geometry/shader/pressure changes are retained. Their separate measurements and source are recorded in [TIRE_RIBBONS.md](TIRE_RIBBONS.md).

## Actual measurements and limits

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, RTX 3090, 1600×900, 2× MSAA. Explicit unscored fixtures use no account/score adapters. Both before/after sides use the same final ribbon geometry and identical stored segment data. These are component measurements, not a physical-phone FPS prediction.

| Finding | Actual result |
| --- | --- |
| Unchanged weathering finish | Approximately 18–54 µs before versus 0.7–1.5 µs after, depending on car/biome; zero repeated uploads after the initial values. This times unchanged updates, not all active car presentation. |
| Wide-field culling fixture | All 16,384 marks retained; 512 submitted near the camera. Ground+marks stays at two total draws. Submitted primitives fall from 32,770 to 1,026 with the parallel task's two-triangle ribbons. |
| Trail appearance | Zero changed pixels on both renderers; original CPU transforms, pigment/custom arrays and cursor agree through a full overwrite. Remote uploads match the original renderer's actual packed precision. |
| Trail sampling | Final direct-path medians 39.316→37.727 µs Compatibility and 36.856→37.327 µs Mobile. Direction varies with process load; no guaranteed CPU speedup or full-game FPS gain is claimed. Active visibility also has bounded bounds/refresh/compaction work. |
| First race after preview, Compatibility | Winter terrain/scenery 525.077→1.434 ms; Desert 119.860→0.123 ms. |
| First race after preview, desktop Mobile/Vulkan | Winter 528.484→20.332 ms; Desert 131.488→0.142 ms. Both race paths already have preview-built road resources. This is prepared-world reuse, not a fresh-install cold-build reduction. |
| Particle pixel proof | Dust/air exact on both renderers; all Mobile comparisons exact. Compatibility wind changes five pixels and bank one pixel, at most 1/255. All restored reference images are stable; original tolerance ≤2/255 retained. |

Short particle/GPU timer stages vary with desktop activity and include the proxy ground. They do not establish a reliable incremental particle speedup. The implementation removes known zero-contribution work; further physical-device profiling remains necessary. Raw alternating stages are retained, including slower samples. The cold preview build still costs time when no prepared world exists or an entry is evicted.

## Actual commands and outcomes

All engine commands use `powershell -NoProfile -ExecutionPolicy Bypass` and `scripts/dev.ps1`. Normal Godot user logs/caches required permitted runner access. No older PATH engine was used.

- `TestScript -ScriptPath res://tests/test_biome_followup.gd -Graphical`, then Mobile with `-RenderingMethod mobile -RenderingDriver vulkan`: final 146 checks each, zero failures. Exact condition/ring state, GPU precision, pixel stability, leave/return, append/reset, fixed draw/budget and preview/cold/restored mesh parity. Task-owned JSON/PNG evidence in `docs/evidence/biome-performance-followup-2026-10-13/{gl_compatibility,mobile}`.
- `TestScript -ScriptPath res://tests/test_particle_followup.gd -Graphical`, both renderers: nine checks each, zero failures; actual material routines frozen on deterministic depth/particle proxies. Evidence in `particles-gl_compatibility` / `particles-mobile`.
- `TestScript -ScriptPath res://tests/test_vehicle_weathering.gd`: 860 checks, zero failures.
- `TestScript -ScriptPath res://tests/test_car_wash.gd`: 1,383 checks, zero failures.
- `TestScript -ScriptPath res://tests/test_tire_ribbons.gd`: parallel renderer's 14 headless checks, zero failures.
- `TestSoil`: 163 checks, zero failures.
- `TestDesert`: 87 checks, zero failures, including original dust and five-car behavior.
- `TestDriving`: 72 checks, zero failures.
- `TestRewind`: 61 checks, zero failures.
- `TestRoadCache`: 70 checks, zero failures.
- `TestScript -ScriptPath res://tests/test_prepared_race_load.gd`: 80 checks, zero failures; restored mutable buffers/props isolated and canonical driving exact.
- `TestScript -ScriptPath res://tests/test_script_parse.gd`: final 618 scripts, zero failures; earlier 619 reflected the provisional helper that was subsequently removed.
- `TestScript -ScriptPath res://tests/test_bridge_trails.gd -Graphical`, both renderers: eight checks each, zero failures; protected roof pixels zero.
- `TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture','--video','--seam-proof','--output-dir=<task folder>')`: 106 checks, zero failures; 150 actual motion frames and 33,357 seam-contribution pixels, zero unstable pixels.
- `TestScript -ScriptPath res://tests/capture_desert_refinement.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--stage=after','--evidence-root=<task folder>')`: six actual gameplay/dust views, 60,799 bank vertices / 184 clods, canonical cells/hash unchanged. First final capture produced a shutdown resource warning; two subsequent captures, including true engine verbose after the runner fix, completed cleanly. The initial warning is retained, not counted as a clean runner result.
- `Doctor`: matching engine/templates and OnePlus DN2103 attached. No physical-phone run/performance test performed.
- `Import`: failed while a concurrently open Godot editor held `~bmt_windows_audio_v3.dll`; the editor was not closed or altered. Runtime script/graphical suites and parse checks passed independently. No import/export success is claimed for that invocation.

Intermediate equivalence failure was caused by the parallel task changing geometry after the original snapshot; comparison was rebased to its final renderer. A provisional culling implementation added unnecessary sampling/unchanged-view cost; the final direct-upload path and cached view guard replace it. A pigment assertion initially compared half-precision renderer data with unquantized CPU values; the final assertion compares both renderers' original/compacted precision, with exact CPU state and the same pixel threshold retained. A particle fixture initially passed a Window to a Node3D helper and was corrected. No acceptance assertion or threshold was weakened.

Inspected [culled tire marks](evidence/biome-performance-followup-2026-10-13/mobile/trails-after.png), [dust proof](evidence/biome-performance-followup-2026-10-13/particles-mobile/dust-after.png), [Winter driving](evidence/biome-performance-followup-2026-10-13/winter-motion/driving.png), [Winter motion](evidence/biome-performance-followup-2026-10-13/winter-motion/driving-motion.html) and [Desert dust](evidence/biome-performance-followup-2026-10-13/desert-gameplay/after/driving-dust.png).

No canonical physics/rules/compiler contract change, backend operation, live score write, Android export/install, full Validate or production deployment. Remaining acceptance: owner review of the merged tire renderer, physical-phone/thermal frame pacing, active-culling overhead on representative tracks and genuinely cold/evicted cache cases. The task-only patch/isolated checkpoint excludes the parallel tire geometry/appearance, hitch-monitor, trophy-wall and other unrelated work; shared index/HEAD remain unchanged.
