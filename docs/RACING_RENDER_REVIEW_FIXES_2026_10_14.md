# Racing rendering review fixes, 2026-10-14

Owner authorization: "Fix those items", covering the three findings in [the second racing-render review](RACING_RENDER_REVIEW_2026_10_14.md). RRV01–RRV03 / V03–V05 / G01 / R01 / Q01.

Winter now prepares and updates its ground/bank fallback only when integrated surface snow is unavailable. Rendered audio uses the contact mix that weathering has just computed in the same synchronous callback. Appearance, camera, particle populations, local condition and canonical driving/scoring remain unchanged.

## Implementation

- Completed Winter worlds bind their original terrain/road/bank materials before deciding whether fallback bank anchors are needed. Integrated worlds skip bank mesh-array readbacks and anchor construction entirely.
- Integrated drawing skips fallback transforms, custom instance data, bounds and eight fallback shader writes. Original airborne grains and all opaque surface uniforms remain. Standalone/unfinished worlds retain exact original fallback buffers, clocks and bank selection. Empty contact-bank results are prepared once per configuration, including retries.
- Weak material owners and their current bindings are validated during the existing refresh. Late integration, same-count node replacement, removed integration and a cleared/restored material-slot mesh switch safely between the original paths. Resource restoration skips missing surfaces; no camera, geometry, shader artwork or permanent population change is introduced.
- `VehicleWeathering.present` returns its freshly sampled contact model only when it actually samples. Game passes it directly to rendered audio; the six contact weights are copied only when wheel dimensions and the consumer's grounded predicate agree. Acceleration/drive smoothing remains independent. Early/blocked/invalid weathering, pause, countdown, finish and incompatible predicates/dimensions retain fresh audio sampling.
- No contact result is cached across physics or rendered callbacks. In-place cell/theme edits at an unchanged tick, reconfiguration, reset and rewind therefore use current data. Physics contact observation still drives immediate surface/impact cues at its original cadence.

The review's roughly50% raw redundancy was an upper bound. The implementation removes **119 of479 queries**, leaving360 in the actual240-tick/120-frame fixture (about25% fewer). It deliberately retains fresh physics observation and avoids a mutable-track cache spanning independent callbacks. The shared argument has the explicit same-callback contract; no general long-lived memoization is added.

## Measured work and exactness

Pinned Godot4.7.2.stable.official.ed1daf0bf, Windows RTX3090, Compatibility/OpenGL and desktop Mobile/Vulkan. Four alternating original/current repetitions are retained in the [OpenGL report](evidence/racing-render-fixes-2026-10-14/gl_compatibility/report.json) and [Vulkan report](evidence/racing-render-fixes-2026-10-14/mobile/report.json).

The native fixture goes from one unused bank readback to zero, and90 fallback placements per600 moving-focus calls to zero. Typical Compatibility configuration changes from roughly17ms to1.2ms; desktop Vulkan samples are more variable, roughly20–65ms to1–2.4ms. Steady presentation savings are a few microseconds per call. These are component CPU measurements on a shared desktop, not phone FPS or a paired whole-race benchmark.

The archived original Winter script and optimized script use the same current world/material artwork. Final paired Winter framebuffers are byte-exact on both renderers. Standalone fallback instance buffers, source anchors, bank selection and clocks match exactly. Contact tests compare the original sampler and smoothing across all five cars, five biomes, twelve surface/layer/grounded combinations, water carryover and mismatched dimensions. Targeted tests also cover same-tick edits, retry, pause, owner replacement, late construction, lost integration, mesh restoration and an empty bank population.

Final targeted checks: **421 headless,426 Compatibility,426 Mobile**, zero assertion failures. Mobile and headless exit cleanly. The Compatibility diagnostic still reports an87380-byte GL texture leak on process shutdown and its launcher exits1, as in the review before these fixes; no growing gameplay leak or root cause is established.

Existing checks: graphical vehicle audio 1469, local washing 1383, weathering 805, rewind 61, driving 72 and standalone Winter 34 pass. Final project parse passes **725 scripts**. The audio adapter retains the original assertions and directs generated recordings to the task's build directory, preserving earlier evidence.

## Actual commands and integration outcomes

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_racing_render_review_fixes.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_racing_render_review_fixes.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_racing_render_review_fixes.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_racing_render_audio_regression.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_car_wash.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_vehicle_weathering.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_rewind.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_driving.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
```

Initial failures remain in command evidence. The real mesh-clear case exposed an unchecked null bank mesh, now guarded; the dummy backend cannot perform its null per-surface material lookup, so those three strict assertions run on both real backends. Original audio's headless pause assertion fails because headless loops are not playing; its unmodified graphical assertions pass. An initial adapter outside `res://tests/` was rejected by the standard launcher and moved into the accepted test directory.

Concurrent Winter shader/car-kit edits also interrupted checks: a fragment `INSTANCE_CUSTOM` reference, unregistered kit classes and a temporarily removed `BODIES` constant. The current concurrent shader fix and kit/class changes are preserved. A simultaneous restoration briefly duplicated the exact body-ID constant; only this task's duplicate was removed. No model/refactor/source-artwork fix from those tasks is claimed here. Import completes and the final parse passes. The old integrated-Winter assertion requiring unused analytic anchors was updated to accept actual integrated snow or the retained analytic fallback; standalone anchor/buffer checks remain strict.

The task-only [patch](evidence/racing-render-fixes-2026-10-14/implementation.patch) / [checkpoint](evidence/racing-render-fixes-2026-10-14/checkpoint.json) include only these implementation, diagnostic and documentation changes. Source baselines retain concurrent work. No shared Git index/branch, canonical contract, backend, APK, deployment or physical-phone state is changed by this task. Phone performance and the separate historical OpenGL shutdown warning remain acceptance/diagnostic limits.
