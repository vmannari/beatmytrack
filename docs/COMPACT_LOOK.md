# Compact vehicle reference pass ? 2026-09-22

Requirements: V02/V04/V05 (original coherent vehicle art), Q01 (verification), R01 (presentation boundary). Owner supplied a before/after hatchback board requesting stronger shapes, larger wheels, dark reflective glazing and realistic small details.

## Implemented

The runtime compact gains rounded tyre shoulders (0.37 m model radius versus 0.36), wider visible rubber (0.28 versus 0.24 m), larger recessed alloy faces with rim lips and lug centres, projecting two-band wheel arches, single round layered headlights, stacked amber/red/clear rear lamps, bumper inserts, door handles/seams, scuttle vents, window gaskets and wipers. Blue cabin sides replace broad cream side pillars; cream hood/roof and dark glass retain the fictional compact identity. Opaque authored reflection planes keep the matte graphic style without runtime reflection probes. Roof receives a shallow bevel.

Wheel centres, body scale, canonical collision, handling and gameplay camera remain as before. The cosmetic rollover support envelope includes the slightly wider tyre/arch geometry. Existing suspension, steering, rolling pivots and brake material are retained. No new image asset, manufacturer identity, dependency or external service was used. The user reference is inspiration, not a shipping texture. Other cars and illustrated menu posters were outside this compact gameplay-model pass.

## Files

- `game/vehicle/car_visual.gd`: compact base palette, glazing, roof, wheel geometry and cosmetic roll support.
- `game/vehicle/compact_detail.gd` (+ UID): authored tyre mesh and shared-material trim/light/arch details.
- `game/tests/capture_compact_detail.gd` (+ UID): production scene captures from the gameplay camera and separate inspection cameras.
- `scripts/dev.ps1`: `CaptureCompactDetail` entry point using the pinned engine.
- This report, development/phase status, and `docs/evidence/compact-look/`.

## Commands and actual outcomes

All engine commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>` and pinned Godot 4.7.2.stable.official.ed1daf0bf.

- `CheckScript -ScriptPath res://vehicle/car_visual.gd`: initial check failed because the new global class had not yet been imported; `Import` registered it successfully. Subsequent graphical runs compiled and executed the new code.
- `CaptureCompactDetail`: succeeded, three views each for the saved pre-task model and final model. Front/rear inspection and normal gameplay captures inspected. Initial capture exposed a countdown overlay; the capture fixture now hides it. An open roof bevel corner was corrected before final capture.
- `TestVehicleBatch`: 30 checks, zero failures across all five cars. Compact: 353 source meshes to 39 batched meshes, 13,684 triangles; batching preserves bounds/triangles, rolling pivots and brake response. This is geometry validation, not phone performance evidence.
- `TestCars`: 95 checks, four failures in the pre-existing body-child-count assertions for pickup/classic/formula/kart (already documented before this task). All 15 five-lap runs complete with zero contacts and exact replay; compact visual/rolling checks pass. No test assertions were changed.
- `TestSuspension`: 28 checks, zero failures, repeated after the cosmetic support-envelope update.
- `git diff --check -- game/vehicle/car_visual.gd game/vehicle/compact_detail.gd game/tests/capture_compact_detail.gd scripts/dev.ps1`: passed (line-ending notice only).

## Evidence and review

[Before front](evidence/compact-look/before-front.png) ? [After front](evidence/compact-look/front.png) ? [Before rear](evidence/compact-look/before-rear.png) ? [After rear](evidence/compact-look/rear.png) ? [Before gameplay](evidence/compact-look/before-gameplay.png) ? [After gameplay](evidence/compact-look/gameplay.png).

[Task-only implementation patch](evidence/compact-look/implementation.patch) isolates this work from the extensive pre-existing uncommitted workspace changes; it is not a commit or merge of those changes.

Remaining acceptance: owner assessment against the illustrated reference, moving/steering views on a physical phone, bright-light readability and GPU/frame-time measurement. The result is still a relatively low-poly in-engine interpretation; it does not reproduce the illustration's fine painted shading. Small trim is mainly visible in close-up. No Android export, install or device test was performed for this task.


## Front, hood and fender correction - 2026-09-22

Owner review identified a detached-looking grille, missing hood shaping and incorrect fenders. Requirements V02/V04/V05/Q01/R01. Changed `car_visual.gd` and `compact_detail.gd`: removed the original floating grille and duplicate thin arch strips; added a solid body-connected front fascia, inset grille/lamp assembly and bonnet shoulder; replaced the flat cream cap with a raised centre, sloped pressed edges, panel seams and washer nozzles. The fenders now have a narrow black opening lip, broader charcoal flare and sloping painted outer shoulder meeting the tapered body skin. Wheel centres, handling and camera are unchanged.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` (three final views saved and front inspected); `-Action TestVehicleBatch` (30 checks, zero failures, all five vehicles). Final compact is 432 source meshes batched into 42, with 13,912 triangles. The prior full-car results above are from the first pass, not rerun for this geometry-only correction. `git diff --check` passed for the edited tracked source files.

[Previous front](evidence/compact-look/front-first-pass.png), [corrected front](evidence/compact-look/front.png), [corrected rear](evidence/compact-look/rear.png), [gameplay](evidence/compact-look/gameplay.png), [isolated correction patch](evidence/compact-look/front-correction.patch). Existing first-pass patch remains historical. Logs: `front-correction-batch.log`, `front-correction-capture.log` in the same evidence directory. Status and phase-plan entries updated.

Owner visual acceptance and phone performance/readability remain outstanding. No device test or Android export was performed. This remains an authored low-poly interpretation of the reference.


## Side cleanup and fender highlights - 2026-09-22

Requirements V02/V04/V05/Q01/R01. Owner supplied actual gameplay and target images identifying black side artifacts and missing fender reflections. Removed oversized black box mirrors, duplicate side rub strips and the compact paint materials' blanket inverted-hull outline passes on open panels. Retained explicit window seals, thin door seams and lower sill trim. The door seams now follow the body's taper; small bevelled mirrors have stalks and inset reflective faces. A restrained waist highlight and lower door tone give the side shape without multiple black bars.

Fender geometry now uses shared vertex-colour material with a broad interpolated silver-blue sky highlight across the charcoal flare and blue shoulder. These are authored cel-style reflection tones, not dynamic environment reflections. No overlapping reflection cards or per-segment material instances. Inspecting both sides also found the right rim lips faced inward; corrected their orientation.

Changed files: `game/vehicle/car_visual.gd`, `game/vehicle/compact_detail.gd`, `game/tests/capture_compact_detail.gd` (adds both side views), this report and development/phase status. [Isolated patch](evidence/compact-look/side-correction.patch).

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` saved five views; both sides and front inspected, then rerendered after the rim orientation correction. `-Action TestVehicleBatch`: 30 checks, zero failures for all five cars; final compact 440 source meshes -> 47 batched, 14,020 triangles. `git diff --check` passed for edited tracked source. Logs saved as `side-correction-batch.log` and `side-correction-capture.log`. Full replay/suspension suites were not rerun for this presentation-only correction.

[Previous front](evidence/compact-look/front-before-side.png), [current front](evidence/compact-look/front.png), [left side](evidence/compact-look/side-left.png), [right side](evidence/compact-look/side-right.png), [gameplay](evidence/compact-look/gameplay.png). This supersedes the first-pass and front-correction screenshots at the current image paths; separate previous-front images retain comparison evidence.

Remaining: owner assessment against reference, motion and bright-light readability on a phone, and measured phone rendering cost. No phone test or Android export/install performed. Canonical handling, collision and gameplay camera were not edited.


## Curved nose and twin lamps - 2026-09-22

Owner requested a slightly curved front and two round headlights on each side, supplying the menu close-up. Requirements V02/V04/V05/Q01/R01. `compact_detail.gd` now builds a shallow bowed fascia (7.5 cm centre-to-edge depth change across 1.6 model metres), matching grille strips, bumper and upper shoulder. Closed upper/lower surfaces connect the face to the existing body. Four layered round lamps follow the bow, with narrower central grille and small lens glints. `car_visual.gd` removes the old straight front bumper block and replaces wide corner indicators with slim vertical lenses beside the outer lamps. No canonical handling, collision or camera change.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` saved five refreshed views; front inspected. `-Action TestVehicleBatch`: 30 checks, zero failures across all five vehicles. Final compact: 907 source meshes -> 47 batched meshes, 18,286 triangles. `git diff --check` passed on edited tracked source. Logs saved as `quad-lamps-batch.log` and `quad-lamps-capture.log`. No full replay rerun for this geometry-only change.

[Previous front](evidence/compact-look/front-before-quad.png), [current front](evidence/compact-look/front.png), [task patch](evidence/compact-look/quad-lamps.patch). This report, development status and phase plan updated. Owner visual acceptance and phone performance remain pending; no device test or Android export/install performed.


## Front flare projection reduced 35 percent - 2026-09-22

Owner-requested 35% reduction, V02/V04/V05/Q01/R01. `compact_detail.gd` now interpolates each front arch vertex to 65% of its previous lateral offset from the body attachment at the same arch angle. Rear fenders, arch radius/height, wheels, highlights, collision and handling are unchanged. Status and phase plan updated.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` (five captures saved, front inspected); `-Action TestVehicleBatch` (30 checks, zero failures; compact remains 47 batched meshes / 18,286 triangles). No phone test or Android export/install. Owner visual acceptance remains pending.

[Before](evidence/compact-look/front-before-narrow.png), [after](evidence/compact-look/front.png), [isolated patch](evidence/compact-look/narrow-front.patch). Logs: `narrow-front-batch.log`, `narrow-front-capture.log` in the same evidence directory.


## Rounded glazing, nose and roof detail - 2026-09-22

Owner requested removal of the remaining black lower-side strip, further nose rounding, natural rounded window corners, a rounded windshield and faint roof lines. Requirements V02/V04/V05/Q01/R01. The compact lower shell is now body blue and its residual sill stroke is removed. Nose bow increases from 7.5 to 13 cm across the same width; lamp positions/angles follow the same curve. The side and rear glass and windshield now have quadratic rounded corners and inset gaskets. Windshield centre bows outward 3.5 cm, rear glass 1.2 cm, side glass remains planar. Old straight gasket overlays and angular reflection cards are removed; opaque vertex-colour glass tones provide a restrained reflection gradient. Roof has a warmer subdued cream, two faint longitudinal pressed lines and subtle outer tone panels.

Files: `car_visual.gd` (lower shell, cabin/roof), `compact_detail.gd` (nose, redundant trim), new `compact_glazing.gd` (rounded mesh construction and shared material), this report and status/phase docs. [Isolated patch](evidence/compact-look/rounded-glazing.patch).

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` saved five views; front and side inspected. `-Action TestVehicleBatch` passed 30 checks across all five vehicles; repeated after sharing the glass material, final compact 898 source meshes -> 49 batched, 19,084 triangles. No physics/replay suite rerun for this presentation-only revision. Logs: `rounded-glazing-batch.log`, `rounded-glazing-capture.log`.

[Before front](evidence/compact-look/front-before-round.png), [updated front](evidence/compact-look/front.png), [side and roof](evidence/compact-look/side-right.png). Camera and canonical handling/collision unchanged. Owner visual assessment, motion aliasing and physical-phone performance remain pending. No phone test or Android export/install performed.


## Visible glass curvature and front bumper - 2026-09-22

Owner's high rear screenshot showed the interior-only windshield bow was not readable and requested a stronger front bumper. Requirements V02/V04/V05/Q01/R01. `compact_glazing.gd` now samples long boundary edges and curves the seals and glass silhouette across the width, in addition to the interior bow. Front bow parameter increases to 0.10 model metres, rear to 0.07 so the rear glass visible in the supplied view also reads as curved. `car_visual.gd` supplies those values. `compact_detail.gd` gives the front bumper a taller 0.21 m face, 0.135 m projection relative to the fascia curve, slightly wider ends and a visible top edge; amber bumper lenses follow the new face. Canonical collision/handling/camera are unchanged; these are cosmetic dimensions.

`capture_compact_detail.gd` adds a high rear inspection camera matching the type of angle supplied by the owner. Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail`: six captures saved, front and high rear inspected. `-Action TestVehicleBatch`: 30 checks, zero failures across all five cars; compact 49 batched meshes / 19,828 triangles. No full replay rerun for this presentation-only change.

[High rear view](evidence/compact-look/high-rear.png), [front and bumper](evidence/compact-look/front.png), [previous front](evidence/compact-look/front-before-visible-curve.png), [isolated patch](evidence/compact-look/visible-curve-bumper.patch). Logs: `visible-curve-bumper-batch.log`, `visible-curve-bumper-capture.log`. This report and status/phase docs updated. Owner acceptance, phone readability and performance remain pending. No phone test or Android export/install performed.


## Reference roof edge and rear quarter windows - 2026-09-22

Owner annotated the reference's subtle roof edge and rear quarter glass. Requirements V02/V04/V05/Q01/R01. `car_visual.gd` replaces the two roof-centre pressings with a fine warm shadow/highlight pair following the roof cap's rolled perimeter. Rear quarter windows now taper to a raised lower rear corner, have a larger 0.15 m corner blend there, tighter pillar-side corners, and a slim muted light surround outside the dark rubber seal. `compact_glazing.gd` supports per-corner radii and an optional outer surround; other glass retains its existing settings.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` (six views saved, rear inspection view reviewed); `-Action TestVehicleBatch` (30 checks, zero failures, compact 50 batched meshes / 20,088 triangles). Initial roof-line placement read as an inset panel; moved it to the rolled perimeter before final capture. No full physics/replay rerun for this cosmetic adjustment.

[Previous rear](evidence/compact-look/rear-before-quarter.png), [updated roof/window view](evidence/compact-look/rear.png), [side](evidence/compact-look/side-right.png), [isolated patch](evidence/compact-look/roof-quarter.patch). Logs: `roof-quarter-batch.log`, `roof-quarter-capture.log`. Report and status/phase docs updated. Owner acceptance and phone readability/performance remain pending; no phone test or Android export/install performed.


## Dark wraparound front bumper - 2026-09-22

Owner compared reference/current bumper and requested the reference's dark shape and side extensions while retaining twin headlights. Requirements V02/V04/V05/Q01/R01. `compact_detail.gd` replaces the front block and grey alloy shelf with a continuous six-section chamfered rubber bumper swept across the bowed nose, rounded corners and short side returns. Returns finish before the wheel openings. Four round headlights and bumper indicators retained; rear bumper is outside this front-specific correction. No canonical collision/handling/camera edit.

Actual commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` saved six views; first render exposed inward-facing sweep normals, corrected and recaptured before final inspection. `-Action TestVehicleBatch`: 30 checks, zero failures across all five vehicles; final compact 50 batched meshes / 20,208 triangles. No full replay rerun for cosmetic geometry.

[Previous front](evidence/compact-look/front-before-wrap.png), [updated bumper](evidence/compact-look/front.png), [isolated patch](evidence/compact-look/wrap-bumper.patch). Logs: `wrap-bumper-batch.log`, `wrap-bumper-capture.log`. Status/phase docs and this report updated. Owner appearance acceptance and phone performance/readability remain pending; no phone test or Android export/install performed.
