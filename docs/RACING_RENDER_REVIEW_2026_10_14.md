# Racing rendering review, 2026-10-14

Owner request: "Make another review pass", following the implemented car, spatial/terrain and remaining racing-render work. This is a review with isolated diagnostics, **no shipping rendering changes**. Requirements RRV01–RRV03 / V03–V05 / G01 / R01 / Q01. Existing artwork, camera, condition, populations, caches and canonical behavior are retained.

The remaining confirmed opportunities are modest desktop CPU savings. Cold driver compilation remains a more consequential phone concern, but the latest trail preparation has not been evaluated on the phone by this review.

## Findings

| ID / priority | Location and trigger | Improvement and expected impact |
| --- | --- | --- |
| RRV01 / medium, loading | `game/track/winter_snow_wind.gd:63`, `_prepare_visual_sources` at line69. With integrated snow already bound to actual terrain/road/bank materials, configuration still reads bank mesh arrays, visits vertices and builds fallback anchors. The fixture binds six integrated materials and creates52 unused anchors. | Determine whether fallback cards are needed before preparing their bank sources. Retain the original path when integration is unavailable. Measured source preparation is about **16–26ms per call** on this desktop fixture; that is a potential preparation saving, not steady racing FPS. The source work is not repeated every frame. |
| RRV02 / low, racing | `game/track/winter_snow_wind.gd:153–167`, `_place_ground` and `_place_banks`. Ground/bank card transforms, custom data, bounds and eight shader parameters still update while both batches end each frame with `visible_instance_count=0`. | Skip these fallback-only updates while integrated snow owns the visible drawing. Preserve airborne grains and every terrain uniform. Across600 moving-focus calls, the current code performs30 ground refreshes and60 bank refreshes; the isolated alternative performs zero. Potential saving is roughly **0.006–0.013ms per call** here. It adds no GPU draw reduction because those batches already draw zero instances. |
| RRV03 / low, racing | `game/vehicle/vehicle_audio.gd:258`, `:406`; `game/vehicle/vehicle_weathering.gd:146`; `game/vehicle/surface_audio_model.gd:46`. Physics audio observes four wheel contacts, then rendered audio and weathering query the same state again. | Reuse only the pure contact result across consumers. Keep acceleration/drive smoothing, collision cues and weathering exposure separate. The actual Game callback probe records **479 queries for240 distinct inputs**,239 redundant, with identical six-component material mixes. This removes about50% of those queries. Their measured redundant cost is about **0.05–0.06ms per rendered frame**, before cache overhead; whole-frame gain will be smaller. Fence track/contact-data revision, wheel dimensions, pose/layer/tire-water, grounded predicate, reset/rewind and immediate same-tick changes. |

RRV01 and RRV02 concern the same superseded fallback presentation at different stages. They must keep fallback behavior available for standalone/unfinished worlds. A count of bound materials alone should not become a permanent assumption if later scene replacement removes integration.

## Rain candidate and current phone evidence

Storm still issues190 rain `draw_line` calls per redraw. A diagnostic alternative retains exact190 endpoints, colour, width and antialiasing, precomputes immutable seeds/speeds/lengths, and uses one `draw_multiline`. All three rain pairs are byte-exact on both desktop renderers. However, measured total draw callbacks, including unchanged lens trails, show **no reliable speedup** and sometimes regress. These are Canvas API calls, not190 independently proven GPU draws: the engine can already batch them. This review does **not** recommend shipping that alternative on the available timing evidence.

The previous phone report records a974.903ms cold event near tick86, with Mali compiler samples and the first trail MultiMesh candidate. The current workspace already has `game/vehicle/trail_render_preparation.gd` and the covered App draw. That is newer than the installed hazard-test APK. Do not present the historical event as a reproduced failure of the newest source, or the new preparation marker as proof that every driver variant is compiled. A new attributable cold/primed device pass remains necessary. See [the actual phone investigation](DESERT_HITCH_INVESTIGATION_2026_10_13.md).

## Evidence and limitations

Pinned Godot **4.7.2.stable.official.ed1daf0bf**; Windows RTX 3090; Compatibility/OpenGL and desktop Mobile/Vulkan. Reviewed native kit 193 and Winter wind 14. Source SHA-256 values are recorded in the [Compatibility report](evidence/racing-render-review-2026-10-14/gl_compatibility/report.json) and [Mobile report](evidence/racing-render-review-2026-10-14/mobile/report.json). Concurrent independent work remains outside this review.

The diagnostic is [review_racing_render_2026_10_14.gd](../game/tests/review_racing_render_2026_10_14.gd). Alternatives exist only in in-memory scripts in that isolated engine process. The contact probe invokes real Game physics/presentation callbacks for240 ticks and120 render frames, without accounts, records, competitive starts or uploads. Query timing excludes the observer's recording work. It uses one Winter circuit/handling configuration, so it does not establish a universal saving across cars and tracks.

Winter current/skip comparisons are byte-exact in the final settled pairs on both renderers. Earlier Mobile runs failed the strict exact comparison with a one-level byte difference. A follow-up control found the same21865 changed bytes/maximum1 in a frozen original and an original reset, without enabling the alternative. Those failures remain in the evidence; the final probe compares against the repeated-original control and retains both control results. This identifies variation in that diagnostic, not its renderer cause and not a general all-camera equivalence proof.

Four alternating repetitions bound the Winter timing comparison. Source-query timings are three repeated readbacks, not a cold GPU or physical-phone measurement. No percentage phone FPS, thermal improvement or general hitch-free claim follows from these results.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_racing_render_2026_10_14.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_racing_render_2026_10_14.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
```

The final Mobile run completes259 checks, zero failures, exit0. Compatibility component assertions pass, but the isolated process reports an87380-byte GL texture leak at shutdown and the launcher exits1. Additional post-draw teardown waits did not establish a clean exit. This is retained as a diagnostic limitation; no growing gameplay leak or root cause is established. The initial direct launcher invocation also hit the host PowerShell execution policy; the documented explicit launcher invocation succeeds in starting the pinned engine.

The [task-only checkpoint](evidence/racing-render-review-2026-10-14/checkpoint.json) / [patch](evidence/racing-render-review-2026-10-14/review.patch) contain the diagnostic, report, evidence and exact status/plan entries. No shared branch/index, runtime, backend, physics contract, APK, deployment or physical-device state is changed. New implementation and phone acceptance remain separate work.
