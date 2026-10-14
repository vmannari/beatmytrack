# Joined tire ribbons, 2026-10-13

The owner asks for a different tire-mark method that improves appearance while reducing drawing effort. Requirements: TR01 shared curve joins; TR02 smooth pressure/width changes; TR03 reduced geometry and measured drawing cost; TR04 retained surfaces, warm desert pigment, bridge guards and four-wheel persistence; V04/V05/G01/R01/Q01 presentation, cost, canonical isolation and actual evidence.

Each segment is now a four-vertex indexed ribbon with two triangles, replacing thirty vertices and ten triangles. Start/end cross-sections are carried in the existing instance transform. Each wheel reuses its previous deposited end as the next start; both edge corners meet exactly, including changes in width and contact height. Appending leaves the old instance untouched. Sharp reversals, material changes, discontinuities, airborne/rolled states, independent bridge layers and resets break the join safely. Four tiny per-wheel caches are added; no race-scale geometry reconstruction, new textures, passes or extra instance uploads are introduced.

The shader interpolates endpoint pressure and opacity, while the existing world-space grain/tread remains continuous. Smooth analytic groove normals replace the faceted raised profile; the geometry follows the sampled contact surface. Desert and ice use their approved contact-normal treatments. Desert source-colour pigment, compaction response and alpha constants remain exact. The 16,384 retained slots, four wheel contacts, 0.32m spacing, 1.5m discontinuity bound and surface style/width/relief/intensity functions remain. Camera, original dust, canonical handling/scoring and local per-car condition are unchanged by this slice. The cosmetic transform/custom-data layout changes; it is not a canonical simulation or save contract.

Shader positions use Godot's world-coordinate vertex mode; normals are explicitly derived from the contact and cross-section vectors, avoiding interpreting the packed transform as an ordinary rigid pose. The authored mesh has conservative custom bounds that include both cross-section columns. See the [Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

Changed files: `game/vehicle/skid_trails.gd`; new `game/tests/test_tire_ribbons.gd`/UID; existing `game/tests/test_tire_mark_seams.gd` now asserts the four-vertex/six-index representation and preservation of average endpoint pressure; `game/tests/capture_desert_tire_marks.gd` disables the live-race hitch observer for its deliberately frozen screenshots; this report, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and the evidence folder. Existing soil invariants were retained. No backend, physics/rules/content version, export or deployment change.

Concurrent visibility and hitch-monitor work was detected in this shared workspace and preserved. It is not included in this geometry slice's patch. The first frozen source contained a provisional `TrailInstancePages` wrapper that was subsequently removed by that work. `entry-source-with-pages.gd.txt` retains the original snapshot. The runnable geometry control in `skid_trails-before.gd.txt` retains the original thirty-vertex mesh, shader and deposition algorithm, with the same final `TrailVisibility` integration as the revised side. Consequently the paired comparison changes the ribbon geometry/pressure treatment while using the same visibility code. Early provisional 33-draw/page-wrapper measurements are superseded by the final two-draw comparisons below. The final static fixture keeps all 16,384 marks visible; no offscreen-culling benefit is claimed here.

Actual commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action / suffix | Actual outcome |
| --- | --- |
| `TestScript -ScriptPath res://tests/test_tire_ribbons.gd` | 14 checks, zero failures; exact shared corners on a slope, pressure, material change, reset, no old-segment mutation, zero-length/vertical-contact rejection, ring capacity and approved average deposits. |
| Same with `-Graphical -RenderingMethod gl_compatibility` | 19 checks, zero failures; actual curved/straight and five-surface before/after images plus three paired full-budget rendering stages. |
| Same with `-Graphical -RenderingMethod mobile` | 19 checks, zero failures; same renderer-specific captures and checks. |
| `TestSoil` | 163 checks, zero failures; canonical surface/contact/intensity/persistence checks. |
| `TestScript -ScriptPath res://tests/test_soil.gd -Graphical -RenderingMethod gl_compatibility` | 166 checks, zero failures, including GPU transform/colour/custom-data checks after visibility integration. |
| `TestDesert` | 87 checks, zero failures; original dust and exact five-car packed/loose-sand replay behavior. |
| `TestScript -ScriptPath res://tests/test_bridge_trails.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--folder=res://../docs/evidence/tire-ribbons-2026-10-13/bridge-compatibility/'` | Eight checks, zero failures; 9,740 unprotected roof pixels become zero with the retained geometric guard. Ground/deck separation and legitimate deck marks pass. |
| Same with Mobile and `bridge-mobile/` | Eight checks, zero failures; 9,533 unprotected roof pixels become zero; same unchanged assertions pass. |
| `TestScript -ScriptPath res://tests/capture_desert_tire_marks.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--folder=res://../docs/evidence/tire-ribbons-2026-10-13/desert-compatibility/'` | Six actual scene views: rolling/braking/loose sand, each with a matching surface-only view; 396 segments per marked view. Canonical snapshot, cells and content hash unchanged. |
| Same with Mobile and `desert-mobile/` | Six matching Mobile scene views; 396 segments each, same warm pigment/first rolling alpha 0.0647/braking alpha 0.1045 and preservation assertions. |
| `Import` | Passed; registered the concurrently added visibility class. |
| `Doctor` | Matching engine/templates; OnePlus DN2103 attached. No physical-phone test performed. |

Desktop RTX 3090, 1600x900, 2x MSAA, VSync disabled, all 16,384 marks visible. Three alternating rendering pairs each have sixty warm-up and 240 measured frames; emission sampling has nine alternating before/after repeats of 6,000 calls. Results include the simple ground:

| Measurement | Original geometry | Joined ribbons |
| --- | --- | --- |
| Tire triangles | 163,840 | 32,768 (80% fewer) |
| Vertices per instance | 30 | 4 (86.7% fewer) |
| Total visible primitives including ground | 163,842 | 32,770 |
| Total draws, both renderers | 2 | 2 |
| Compatibility GPU medians, ms | 0.340 / 0.302 / 0.299 | 0.151 / 0.151 / 0.152 |
| Mobile GPU medians, ms | 0.252 / 0.254 / 0.254 | 0.119 / 0.119 / 0.119 |
| Compatibility emission median, microseconds/sample | 44.82 | 46.96 |
| Mobile emission median, microseconds/sample | 51.38 | 51.66 |

The static fixture's median GPU work falls about 50% in Compatibility and 53% in Mobile. The vertex/triangle counts are exact; GPU figures are desktop measurements, not whole-game or phone FPS. The new shared-contact bookkeeping adds a small emission cost in the paired runs, approximately 2.14 and 0.28 microseconds/sample. Frame/render-CPU tails vary with other local processes; no general frame-pacing improvement is asserted. The final horizontal-degeneracy guard was also checked headless: 42.02 -> 45.01 microseconds/sample in that run. The same fixed draw budget and sampling remain.

Known intermediate issues are retained in runner logs: first prototype rewrote previous transforms and increased CPU cost; it was replaced with immutable endpoint reuse. Concurrent visibility class creation required Import; concurrent game creation temporarily referenced a missing hitch-monitor source. Mobile frozen-scene capture then encountered that observer reading an unavailable dust property; only the deliberately frozen screenshot fixture disables it, while normal game diagnostics remain as authored by the other task. Paired pixel tests compare banding with the already improved exact-length baseline; their tolerance preserves low seam contrast, rather than claiming another percentage reduction from the original overlap pass. An early historical seam diagnostic wrote to its prior evidence folder; the original control images/report were restored from the matching saved control and retained run output.

Evidence lives under `docs/evidence/tire-ribbons-2026-10-13/`: `*-before.png`, `*-after.png`, five-surface comparisons, renderer-specific `*-profile.json`, actual desert/bridge scene views, preserved source/control and runner logs. `preserved-functions.json` checks exact style/width/relief/intensity functions and constants. `implementation.patch` is the task-only Git-format checkpoint, checked against the current files. The real workspace/branch/index and unrelated edits are preserved.

Remaining acceptance: owner review of pressure transitions, grass/snow groove shading, very sharp turns, dense overlapping laps, and physical-phone appearance/performance. No phone execution, APK export/install, whole-game performance run, full regression or production/backend deployment was performed for this slice.
