# Race start and finish polish - 2026-09-22

The five-red-light and animated-flag correction below supersedes the initial traffic-light/banner design.

Owner request / requirements: G01, V03, V05, R01, R03, R07, Q01.

Ordinary races retain the three-second staging period: red WAIT for two seconds, amber READY for one second, then green GO at release. Green fades out over the first 0.8 seconds. Lights use original vector artwork in a dark housing above the car; practice remains immediate and untimed.

At the final crossing, official simulation state, session time and telemetry stop updating. A separate deep-copied vehicle state runs 1.8 seconds of gentle braking with real track collisions, retained/releasing steering and the existing camera. FINISH appears above the moving car; a dark curtain blends into a 0.4-second Results reveal. Completion emits once. Retry resets lights, coast state and transition. No canonical physics or rules version change.

Changed files: `game/ui/race_cues.gd`, `game/core/game.gd`, `game/core/app.gd`, `game/tests/test_editor_practice.gd`, this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md; screenshots under docs/evidence/race-flow.

Actual commands (pinned Godot 4.7.2 through build entry point):

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestPractice`: 40 checks, zero failures (also rerun after curtain reveal adjustment). Headless exit reports two ObjectDB instances, as the prior practice suite did.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CapturePractice`: 44 checks, zero failures; desktop 1280?720 red/green/finish captures saved. Red and finish inspected. Captures precede the final curtain-to-results crossfade adjustment; static cue appearance unchanged.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestResults`: 116 checks, zero failures.

Tests drive six untimed practice laps and five scored laps, verify red/amber/green timing, movement after finish, unchanged official snapshot/time, exactly-once results, and retry reset.

Evidence: [red](evidence/race-flow/red.png), [green](evidence/race-flow/green.png), [finish coast](evidence/race-flow/finish.png).

Remaining acceptance: human feel of sequence and crossfade, phone readability/performance, unusual finish geometry and all vehicle coast behaviour. No Android export or physical-device test performed; device connection was not checked. Existing unrelated workspace changes retained; no broad commit of the dirty workspace made.


## Five red lights and chequered flag correction

Owner rejects road signals and static finish card. Requirements G01/V03/V05/R01/R03/R07/Q01. `game/ui/race_cues.gd` now draws five individual matte signal housings on a narrow gantry with red LED lens cells. One additional red illuminates every 0.5 seconds; all five hold through the end of the existing three-second staging and extinguish on the first racing tick. No amber/green or GO text. Extinguished housings fade away over 0.5 seconds.

Finish displays an original animated black/ivory chequered cloth with continuously deformed checks, moving silhouette and fold shading, a slim pole and small RACE COMPLETE caption. The flag eases in above the coasting car and transitions through the existing results curtain. Native vector UI, no external assets or dependencies. Official state/time and coast behaviour are unchanged.

Changed files: `game/ui/race_cues.gd`, `game/tests/test_editor_practice.gd`, this document, status/plan entries and evidence.

Actual validation through pinned Godot 4.7.2:

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestPractice`: 45 checks, zero failures. Existing two-instance ObjectDB exit warning persists.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CapturePractice`: 68 checks, zero failures. Includes five-light accumulation, all-red hold, exact lights-out/start-clock alignment, finish coast isolation and retry.
- Inspected desktop all-red, finish and sampled cloth captures at 1280x720.
- Optional GIF assembly could not run because Pillow is absent; saved a dependency-free HTML frame preview instead.

[Five red lights](evidence/race-flow/five-lights-ready.png), [lights out](evidence/race-flow/lights-out.png), [finish flag](evidence/race-flow/chequered-finish.png), [flag animation](evidence/race-flow/flag-animation.html). Preview shows sampled flag phases over a fixed gameplay frame, not a real-time driving recording.

No physical-device test or Android export performed; attachment not checked. Human animation/style acceptance and phone readability/performance remain pending. Earlier totals above describe the superseded design. Existing unrelated workspace edits retained without a broad commit.

## Supplied starting-light artwork — 2026-09-22

The owner-supplied starting-light artwork replaces the procedural countdown lamps. Requirements G01/V03/V05/Q01. The individual source states were not geometrically identical, so the supplied green lamp was used as the housing, bezel, highlight and LED-grid reference as directed. The accepted five-red-lights-then-lights-out timing remains unchanged; green is a geometry reference and is not displayed at GO.

For mobile cost control, the six visible states are precomposited into one transparent 3072×112 atlas (`game/assets/hud/start_lights_atlas_v1.png`, approximately 193 KB on disk). `RaceCues` preloads that texture and issues one texture-region canvas draw per displayed stage. It creates no runtime light nodes, shaders, child controls, geometry loops or per-frame image resources. The imported texture has no mipmaps because it is shown at a fixed UI size.

Changed files: `game/assets/hud/start_lights_atlas_v1.png` and its Godot import metadata, `game/ui/race_cues.gd`, `game/tests/test_editor_practice.gd`, this document, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. Evidence is under `docs/evidence/race-flow/supplied-lights/`.

Actual validation through pinned Godot 4.7.2:

- Initial `TestPractice` run failed because the new PNG had not yet been imported and therefore had no resource loader. No implementation test was reported as passing from that run.
- Pinned Godot headless editor `--import`: exit 0; imported the new atlas. It retained the existing Android build-tools fallback warning.
- `scripts/dev.ps1 -Action TestPractice`: 46 checks, zero failures. The prior two-instance ObjectDB exit warning remains.
- `scripts/dev.ps1 -Action CapturePractice`: 69 checks, zero failures. Desktop 1280×720 first-red, all-red and lights-out captures were inspected; housing geometry and lamp alignment remain consistent across states.

No Android export or physical-device profiling was performed. The one-draw implementation structurally removes the procedural lamp loops, but phone GPU time/readability and final human art acceptance remain acceptance checks.

Owner screenshot follow-up: the first atlas incorrectly overlaid complete lit housings, producing stacked black plates. The corrected atlas retains one unchanged five-housing base in every frame and replaces only measured, circular lens regions. A second capture-guided correction aligned those regions to the scaled gantry centres. Refreshed first-red and all-red desktop captures show consistent housing silhouettes without duplicate plates; runtime cost remains one draw and the corrected atlas is approximately 146 KB.

A later owner device screenshot exposed cumulative horizontal drift that was subtle at the earlier desktop capture size, especially on lamps four and five. Final per-lamp centres are measured independently from the rendered gantry rather than assumed uniformly spaced. The refreshed full-resolution all-red capture shows all five red lenses centred inside their bezels with no exposed unlit crescents. Rendering structure and countdown timing are unchanged.

Final owner follow-up identified a few remaining right-lamp pixels plus clipped right and bottom frame edges. Source alpha measurement found the previous crop ended 42 px before the right mounting-tab edge and 13 px before the bottom artwork edge. The final 3264×120 atlas uses the full gantry bounds with transparent padding and independently positioned lamps. The inspected full-resolution capture shows both end tabs, complete lower trim and five centred lenses. Atlas size is approximately 159 KB; it remains one preloaded texture and one draw.

The next close-up correctly identified the residual issue as scale accumulation, not five unrelated offsets. Original-source unlit-lens boundary detection measured centres at x=209/441/672/905/1138. Applying the exact full-crop scale produces runtime centres x=77/174/270/367/465 and y=60. The regenerated and reimported full-resolution capture shows equal bezel clearance through the rightmost lamp; atlas dimensions, draw count and countdown behavior are unchanged.

## Supplied race-complete panel — 2026-09-22

The owner-supplied black/gold RACE COMPLETE panel replaces the procedural waving chequered flag. Requirements V03/V05/R01/Q01. A transparent 1024×341 runtime texture preserves the supplied layout and is presented with one canvas draw; the former 120-cell continuously deforming cloth loop is removed. The panel scales to 78% of viewport width with an 820 logical-pixel cap and a short reveal fade. Finish coast, official-state isolation and the automatic 1.8-second Results fallback remain unchanged. Because the artwork says TAP TO CONTINUE, a new touch or primary-mouse press after a 0.25-second guard proceeds immediately; the guard prevents the final driving touch from dismissing it accidentally.

Changed files: `game/assets/hud/race_complete_panel_v1.png` and import metadata, `game/ui/race_cues.gd`, `game/core/game.gd`, `game/tests/test_editor_practice.gd`, this document, status/plan and refreshed evidence.

Actual validation: pinned Godot headless import succeeded; final `TestPractice` passed 48 checks and final `CapturePractice` passed 71 checks, including the guarded tap path. The 1280×720 completion capture was inspected. No Android export, phone test or device profiling was performed.
