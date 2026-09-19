# Readable asphalt and simpler handrails - 2026-09-15

Owner correction: asphalt has lost its texture; bridges are too busy and handrails should be simpler and slightly higher. Requirements V02/V04/V05, preserving G01/R01. Track-kit-21 / bridge-ramps-4.

## Changed files and behavior

- `game/track/surface_detail.gdshaderinc`: approximately 25 cm aggregate, maximum +/-5% modulation, with filtering based on the grain's projected footprint. Previous 10 cm, +/-0.9% grain disappeared at the normal camera. Broad variation remains capped at +/-0.8%; no secondary patch layer.
- `game/track/creator_bridge_visual.gd`: plain rectangular blue-grey rail at 0.85 m above deck (previously 0.65 m), slim matching posts spaced approximately 8 m apart. Removed folded profile, dense secondary supports, yellow accents and chunky contrasting concrete posts. Footing/fascia and road markings remain.
- `game/track/bridge_presentation.gd`: native raster barriers raised from 0.65 to 0.85 m, with plain top/side coloring and no separate concrete posts or stacked colored bands. Native solid raster footprint remains distinct from creator rails.
- `game/track/native_track_visual.gd`: visual version bump. This document, status/Phase 0 links and `docs/evidence/road-rail-refinement/` record delivery.

No canonical collision, bridge height profile, handling, camera or user-track changes. Rail height is presentation only. Original code; no new external asset. Driving-data wear remains deferred.

## Actual commands and outcomes

Pinned Godot 4.7.2 through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action | Outcome |
|---|---|
| `CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"` | All captures succeeded; native cells unchanged, zero bad road normals. |
| `CaptureBridgeHUD` | 95 checks, zero failures; creator/native bridge captures succeeded and collision-layer preservation checks passed. |
| `TestConstruction` | 73 checks, zero failures; five laps, zero contacts, upper/lower traversal. Exit reports two leaked ObjectDB instances; cleanup remains uninvestigated. |
| Scoped `git diff --check` | Passed; line-ending notices only. |

Inspected desktop Compatibility captures: [asphalt](evidence/road-rail-refinement/asphalt.png), [creator bridge](evidence/road-rail-refinement/creator-bridge.png), [native bridge](evidence/road-rail-refinement/native-bridge.png). Actual logs are saved alongside them.

## Remaining acceptance

Owner texture strength and rail appearance acceptance remain open. No phone test, device enumeration, motion capture, GPU profiling or Android export performed. Grain filtering is not proof of shimmer-free motion. Existing thin bridge crest seams and native raster-edge stepping remain visible; this pass does not modify their geometry contracts.
