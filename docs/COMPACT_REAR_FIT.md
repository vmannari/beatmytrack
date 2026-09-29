# Compact rear attachment

Requirements: V01/V04/Q01; owner screenshot reported detached rear lights and bumper.

Changed `game/vehicle/compact_detail.gd`: rear lens and housing surfaces follow the body waist taper and rear corner chamfers, with embedded side walls. Rear bumper sits 0.14 model units inward. Hatch handle also sits against the sloping panel. Removed the obsolete overlapping box lamps from `game/vehicle/car_visual.gd`; shared brake material retains running/braking behavior. Existing unrelated edits in car_visual.gd are preserved. No canonical physics or camera changes.

Actual commands (pinned Godot 4.7.2):
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail`: succeeded, 10 desktop views saved.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHeadlights`: 56 checks, zero failures.

Inspected [rear](evidence/compact-look/rear.png) and [high rear](evidence/compact-look/high-rear.png) captures; attachments are seated against bodywork. Other captures refreshed by the existing capture command. Documentation: this file, DEVELOPMENT_STATUS.md and PHASE_0_PLAN.md.

No Android export or physical-device test performed. Device attachment was not checked. Remaining acceptance: owner review in motion and on phone. Working-tree change remains reviewable alongside pre-existing unrelated changes; no mixed commit created.

## Lower bumper follow-up

Owner requested more downward extension. Updated only compact_detail.gd geometry: rear profile bottom 0.435 -> 0.320 and top 0.630 -> 0.600 model units. A flatter rear-specific path covers the broad lower valance without bodywork poking through; front profile is unchanged. Refreshed the existing 10 evidence images. Ran `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureCompactDetail` twice while refining; both succeeded, final rear image inspected. The lighting checks above belong to the preceding attachment change and were not rerun for this profile-only adjustment. No device test or Android export; owner visual acceptance remains.
