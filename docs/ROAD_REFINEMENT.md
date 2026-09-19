# Asphalt and verge refinement - 2026-09-15

## Owner correction: more even asphalt (track-kit-20)

Owner found the first pass patchy. V02/V04/V05: `surface_detail.gdshaderinc` now removes the secondary 2 m pigment layer and tonal thresholds, using continuous macro variation capped at +/-0.8% instead. Quiet grain and verge refinement remain. `native_track_visual.gd` records track-kit-20; status and Phase 0 updated.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"` succeeded on pinned Godot 4.7.2 / desktop Compatibility. All capture outputs succeeded; native cells preserved and zero bad road normals. Inspected and saved the [corrected bend](evidence/road-refinement/even-asphalt.png) and [log](evidence/road-refinement/even-asphalt.log). Scoped `git diff --check` passed. No new domain tests were run for this shader-only correction. Phone attachment was not checked; no phone or motion test performed. Owner appearance acceptance remains open.

Owner authorized items 1 and 2 from the road review. Requirements V02/V04/V05 and Q01; preserve G01/R01 simulation boundaries. Presentation version: track-kit-19.

## Changes

- `game/track/surface_detail.gdshaderinc`: shared asphalt uses approximately 6 m softly banded macro variation (+/-3.5%), a restrained 2 m pigment layer and isotropic 10 cm grain with reduced contrast (maximum +/-0.9%). Derivative filtering softens fine detail and tonal thresholds. Native terrain asphalt, creator pieces and bridge decks share the function.
- `game/track/native_track_visual.gd`: existing creator shoulders use slower world-space waves around the retained 1.35 m mean, bounded to 1.05-1.65 m. Existing exposed-edge/join clipping, grass blending and no-sand kerb rules remain. No new strips or drivable-boundary changes.
- This document, status/Phase 0 links and `docs/evidence/road-refinement/` record delivery. Original code; no external assets or dependencies.

Grass, road palette, lighting, camera, handling and user documents were not edited. Real-driving-data wear remains deferred in [WISHLIST.md](WISHLIST.md). Repair polygons and synthetic racing lines are outside this change.

## Actual verification

Commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, pinned Godot `4.7.2.stable.official.ed1daf0bf`:

| Command | Outcome |
|---|---|
| `CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"` before and after | Both succeeded: start, 12 route and 3 model captures; unchanged native cells and zero bad road normals. Existing track read only. |
| `TestPieces` | 164 checks, zero failures; unchanged golden cells, five laps with zero contacts. |
| `TestConstruction` | 73 checks, zero failures; five-lap bridge run, zero contacts, upper/lower traversal. |
| `CaptureBridgeHUD` | 95 checks, zero failures; graphical bridge captures succeeded. |
| `git diff --check` with the changed road/document paths | Passed; line-ending normalization notice only. |

Saved and inspected [before](evidence/road-refinement/before.png), [after](evidence/road-refinement/after.png), [start/join](evidence/road-refinement/join.png) and [bridge](evidence/road-refinement/bridge.png). Logs accompany the images. Desktop Compatibility on NVIDIA RTX 3090. The bend shows reduced directional streaking and broader verge variation. HUD/minimap differs between captures amid concurrent workspace changes; it is outside this road patch.

## Remaining acceptance

No physical-phone test, device enumeration, APK export, moving-lap video or GPU timing was performed. Owner visual acceptance and phone aliasing/frame pacing remain open. The extra asphalt pigment sample has not been profiled on Android. Thin geometry seams remain visible at some shoulder joins and bridge transitions; this material/variation pass does not establish that every join is seam-free. Broad theme and painted-intersection visual coverage remains pending.
