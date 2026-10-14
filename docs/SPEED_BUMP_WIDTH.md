# Independent speed bump width — 2026-10-12

The owner rejects uniform Size controls for spanning a road and requires an easy way to fill the road while retaining partial-width bumps. Requirements: SB06 (independent width), SB07 (fit actual road edges), SB08 (direct partial-width editing), SB01–SB05/G01/R01/T01–T04/V04/V05/Q01. This supersedes the initial speed bump's uniform sizing UI.

Select a placed bump and use **Fit road** to center it, align it across the road and set its width between the edges. Drag either yellow end dot to shorten/extend that end while the other stays fixed; drag the body to move it as before. **Width − / Width +** provide desktop/touch button alternatives in 0.5 m increments. The bump's new-placement options use a width slider in 0.25 m increments instead of Small/Medium/Large. Width ranges from 0.5 to 40 m. These actions preserve height and front-to-back thickness; a new bump remains 18 cm high and 2 m long along travel.

Fit uses shared ground-road section geometry, including rotation, local taper and spline widths. Layout-based roads use their shared samples; a free-painted/native fallback measures the ground cells across the local direction. It refuses distant-road snapping and bridge-only fitting. On complex overlapping roads it chooses the nearest containing ground cross-section; manual end editing remains available. A partial bump can be moved to one side to leave a clear lane, and uncovered tyres do not receive bump effects.

The optional `span` field is transverse width in metres. Legacy documents without it retain their exact existing scaled dimensions and are not migrated or deleted. Existing scaled bumps retain their old crown profile when edited; newly placed bumps use the standard profile. Copy, rotation, local saves and WIP recovery preserve span. End drags use the existing gesture journal: one Undo restores the entire drag, and a second finger cancels the tentative width change before navigation. Committed values are normalized to the existing JSON precision at the editor boundary, so raw authored-value save/reload equality remains exact.

The canonical braking/rebound formulas, physics `arcade-planar-0.54`, recorder schema 11, five-lap rules, trajectory verification and per-car cosmetics are unchanged. Compiler 25 pins the extended authoring contract; JSON remains creator-track-v5 with a bounded speed-bump-only span property. Starter hash: `bfd44ace20db1ca0319b04378b05ce78ae711f1b50654707408ea0cf8a47633a`. Before refreshing raster goldens, the original compiler-23 fingerprints/unchanged geometry and 1,800 prior-physics snapshots were checked by the existing contract suite. Prior checkpoint evidence remains intact.

Changed files: `game/editor/speed_bump_edit.gd`, `creator_objects.gd`, `track_document.gd`, `track_compiler.gd`, `object_browser.gd`, `editor_canvas.gd`; `game/core/app.gd`; `game/track/hazard_visual.gd` (module stripes retain their physical spacing across different widths); `docs/schemas/creator-track-v5.schema.json`; `game/tests/test_speed_bump_width.gd`, `test_speed_bumps.gd`, `test_creator.gd`, `test_winter_compiler_contract.gd`, `game/tests/fixtures/compiler_raster.json`; `scripts/dev.ps1` (includes the width suite in full Validate); generated UIDs, agent/status/phase instructions and both bump documents. No unrelated Garage, Rivalry, Winter, backend or player-file changes are included in the review checkpoint.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned Godot `4.7.2.stable.official.ed1daf0bf`:

| Arguments | Actual result |
|---|---|
| `-Action Import` | Passed after refreshing the concurrently added global classes. Earlier attempts encountered incomplete/unregistered Rivalry award and Garage detail scripts; those unrelated scripts were not edited by this task. |
| `-Action TestScript -ScriptPath res://tests/test_speed_bump_width.gd` | 362 checks, 0 failures. |
| Previous command with `-Graphical` | Compatibility/OpenGL: 368 checks, 0 failures. Actual full-width fit, partial-width end edit and width-options captures inspected. |
| Previous command with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan` | Mobile/Vulkan: 368 checks, 0 failures on desktop RTX 3090, not a phone. |
| `-Action TestScript -ScriptPath res://tests/test_speed_bumps.gd` | 9,045 checks, 0 failures; existing five-car brake/throttle advantage, JSON replay/rewind and editor/file persistence preserved. |
| `-Action TestScript -ScriptPath res://tests/test_speed_bump_contract.gd -TestArgument '--refresh-bump-golden'` | 1,818 checks, 0 failures before refreshing versioned identities. |
| `-Action TestCreator` | 113 checks, 0 failures, including complete diagnostic races and exact JSON replay in all five biomes. |
| `-Action TestScript -ScriptPath res://tests/test_object_browser.gd` | 67 checks, 0 failures. |
| `-Action TestCompilerRaster` | Eight fingerprints pass. |
| `-Action TestScript -ScriptPath res://tests/test_winter_compiler_contract.gd` | 29 checks, 0 failures. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 561 scripts, 0 failures. |
| `-Action TestApp` | 99 checks, 0 failures. |
| Existing `.tools/review/Scripts/python.exe` and `jsonschema.Draft202012Validator` | Schema valid; 21 accepted/rejected examples pass, including three biomes, bounds, invalid types and rejection on other object kinds. No package installed. |
| `-Action Doctor` | Matching engine/templates; empty ADB list. No phone attached. |

The width suite checks sixteen rotated/road-width fits, taper/curve/spline/painted-road fits, legacy profile retention, actual mesh dimensions, native touch and mouse handles, pinch rollback, whole-drag undo/redo, Copy and exact saved values. Ninety paired simulation ticks give byte-exact centre-crossing snapshots for 3 m and 16 m bumps; ninety more show that an uncovered lane follows the same movement as a track without a bump. Width JSON also retains the exact pinned identity.

An initial saved-value assertion exposed ordinary float serialization rounding after a free end drag. Normalizing at the edit boundary fixed it while preserving the exact equality assertion. A later diagnostic fixture mixed integer literals with the floating coordinates emitted by the actual editor; the pin hash already matched, and the fixture was corrected to the actual authored numeric types. Both original failure logs and successful final runs remain under build/logs; final logs are copied beside the evidence. The width-popup capture waits for its actual asynchronous world build to finish.

[Full road](evidence/speed-bump-width-2026-10-12/compatibility/full-width.png), [partial-width bump](evidence/speed-bump-width-2026-10-12/compatibility/partial-width.png), [width options](evidence/speed-bump-width-2026-10-12/compatibility/width-options.png). Root PNGs contain the corresponding Mobile captures. The two issues shown in the demonstration are the honest untimed straight practice area's route/start issues, not invented timed-race eligibility.

Remaining acceptance: restart and try **Fit road**, drag one end inward, and move the shortened bump to leave a lane clear. Owner acceptance remains for usability and handle/readout reach. No physical-device test, Android export/install, full all-domain Validate, backend tests/deployment or live writes were performed. Phone touch/lighting/frame pacing remain unverified. The existing client-server pin mismatch remains; compiler25 also requires a matching backend/catalog rollout before competitive starts. Ground-only fitting does not authorize upper-deck bumps or terrain sculpting.

The incremental task-only Git checkpoint is recorded in the evidence receipt and isolated review repository under `build/speed_bump_width/checkpoint-repo`; the main branch/index and concurrent work are preserved.
