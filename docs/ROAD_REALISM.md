# Procedural road realism - 2026-09-20

Owner reference authorizes a more realistic procedural road treatment for user-created tracks. Requirements V02/V04/V05/Q01 and R01; presentation version `track-kit-34`. Canonical geometry, collision, surfaces and handling are unchanged.

## Sharper uneven asphalt contour - 2026-09-20

Owner feedback found the asphalt silhouette too smooth compared with the sand and grass. `track-kit-35` now subdivides only the cosmetic asphalt cover outside the retained smooth white edge line at approximately 0.32 m intervals, then applies bounded 0.02-0.13 m world-space erosion with a sharper wave profile than the broad shoulder variation. Polygon-winding normals keep concave creator outlines filled; markings, authored width, collision and compiled surface cells remain exact.

Actual verification: `scripts/dev.ps1 TestPieces` passes 335 checks with zero failures, including density/amplitude bounds and unchanged canonical cells. `CaptureStyle` succeeds with 12 route views, three vehicle views, native cells preserved and zero bad road normals. The updated [route view](evidence/road-realism/creator-road-route.png) was inspected after rejecting an earlier concave-normal attempt that visibly removed asphalt. No phone test or performance profile was performed.

## Natural asphalt-to-sand transition - 2026-09-20

Owner screenshot exposed two defects in track-kit-35: geometry scalloping left hard black teeth and piece-end discontinuities, while the continuous white perimeter separated asphalt from the desired natural verge. Track-kit-37 supersedes that treatment.

- Asphalt returns to the continuous joined cover geometry, eliminating holes and exposed section ends.
- Dry asphalt now blends through a narrow, world-space broken mask into the exact `sand_detail()` shoulder material, matching the established sand-to-grass transition language.
- The decorative continuous white edge stripe is removed on sandy verges. Dedicated centre/finish markings, bridge presentation and raised kerbs remain.
- The final mask uses the road texel plus four immediate neighbours instead of the rejected broad nine-sample band, keeping the transition near the outer half-metre rather than consuming the road surface.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks and `TestSurfaces` passes 50 checks, both with zero failures. `CaptureStyle` succeeds with native cells preserved, 12 route views, three vehicle views and zero bad road normals. The updated [route view](evidence/road-realism/creator-road-route.png) was visually inspected. No physical-phone or moving-lap test was performed.

## Restrained border correction - 2026-09-20

Owner rejected track-kit-37 as far too irregular and explicitly requested only a slight break from perfect smoothness. Track-kit-38 restores the complete smooth white edge markings and retains the continuous asphalt mesh. The sand contribution is reduced to a maximum 16% tint, its noise amplitude is reduced from 42% to 12%, and its threshold is restricted to the extreme outside coverage. This supersedes the broad natural-transition treatment above: no visible scalloped silhouette is intended.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals; the [updated route view](evidence/road-realism/creator-road-route.png) confirms restored white lines and a nearly smooth border. No phone test was performed.

## Coverage-shape correction - 2026-09-21

The owner's live screenshot showed that track-kit-38 still produced a smooth, semi-transparent dark ribbon outside the white line. Track-kit-39 replaces opacity-like tinting with a true asphalt-versus-sand coverage transition. It uses the same world-space pigment frequency as `grass_fringe()`, half the sand/grass displacement (`0.16` versus `0.32`) and a wider smooth interval. The result keeps the white marking and continuous mesh while making the visible asphalt cutoff follow the sand/grass boundary language, slightly more smoothly. There is no translucent asphalt band.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, 12 route views, three vehicle views and zero bad road normals. The updated [route view](evidence/road-realism/creator-road-route.png) and a broad bend view were inspected. No physical-phone or moving-lap test was performed.

## Real-road edge proportion correction - 2026-09-21

The owner's real paving reference establishes three distinct zones: an inset white marking, a visible strip of solid asphalt beyond it, then a minimally irregular physical asphalt edge against the granular shoulder. The live game screenshot showed track-kit-39 was cutting coverage too close to the white line and still varying too much.

Track-kit-40 shifts the coverage threshold outward from `0.30-0.76` to `0.025-0.22` and reduces world-space displacement from `0.16` to `0.04`. Most of the post-line strip is therefore opaque asphalt; only the final narrow edge transitions into sand. White markings, joined mesh geometry, collision and handling remain unchanged.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, 12 route views, three vehicle views and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) and [route view](evidence/road-realism/creator-road-route.png) were visually inspected. No physical-phone or moving-lap test was performed.

## Fine curve-edge correction - 2026-09-21

Owner feedback identified coarse sawtooth steps on curves. Track-kit-41 replaces the centre-heavy five-sample road coverage with a balanced 3x3 filter, reducing visibility of the canonical 0.5 m raster staircase. Procedural breakup frequency increases from `4.8` to `9.5`, while displacement drops from `0.04` to `0.012`. The pattern is therefore smaller and more frequent, and extends only minimally into the asphalt. The solid post-line asphalt strip and white markings remain unchanged.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) was inspected specifically for curve stepping. No physical-phone or moving-lap test was performed.

## Rounded edge-lobe correction - 2026-09-21

The owner marked the few desirable areas in track-kit-41: shallow, rounded asphalt lobes rather than fine nearly invisible noise. Track-kit-42 retains the balanced 3x3 filtering that removes curve stair-steps, changes breakup frequency from `9.5` to `3.4`, and raises displacement moderately from `0.012` to `0.026`. This produces broader smooth variations throughout the edge while remaining materially shallower than the rejected `0.04` sawtooth version. Post-line asphalt and white markings remain unchanged.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) was inspected. No physical-phone or moving-lap test was performed.

## Few-pixel transition-width correction - 2026-09-21

The owner clarified that the marked edge is the baseline: an almost smooth, narrow dark asphalt transition whose width varies by only a few pixels, but does so throughout the track. Track-kit-43 retains the filtered mask, increases repetition moderately from `3.4` to `5.5`, and reduces displacement from `0.026` to `0.005` (about 19% of track-kit-42). This removes the rejected lobes while keeping continuous low-amplitude variation around straights and curves. White markings and the opaque post-line asphalt strip remain unchanged.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) was inspected. No physical-phone or moving-lap test was performed.

## Continuous UV edge-fringe replacement - 2026-09-21

The owner screenshot confirmed that tuning the canonical 0.5 m surface-grid mask could only alternate between an invisible effect and coarse steps. Track-kit-44 removes that dependency. Creator asphalt now has a solid joined body ending 0.16 m outside the authored outline plus a dedicated 0.20 m cosmetic fringe along every exposed edge. `UV.y` measures exact distance across the fringe, so straights and curves share a continuous sub-cell transition independent of collision raster resolution.

The fringe remains mostly asphalt, transitions only near its outside edge, and varies its cutoff by a few pixels using world-space pigment. The underlying strip and sand shoulder overlap continuously; joins do not receive fringe geometry. White markings, canonical cells, collision and handling remain unchanged. This supersedes all earlier road-mask threshold tuning.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks and explicitly requires separate solid/fringe asphalt materials; `TestSurfaces` passes 50 checks. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) was inspected. No physical-phone or moving-lap test was performed.

## Small smudged material blend - 2026-09-21

With the fringe shape accepted, track-kit-45 changes only the material crossfade inside it. The asphalt/sand blend interval expands from `0.14` to `0.26` of the 0.20 m strip, approximately 3 cm to 5 cm in world space. Cutoff position, few-pixel width variation, fringe geometry, white markings and physics are unchanged. This creates a short smudged overlap rather than a crisp material boundary.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) was inspected. No physical-phone or moving-lap test was performed.

## 10 cm crossfade - 2026-09-21

Owner follow-up doubles only the accepted fringe's asphalt/sand material crossfade from approximately 5 cm to 10 cm. Track-kit-46 expands the smoothstep interval from `0.26` to `0.50` of the 0.20 m strip while preserving its midpoint, cutoff variation, geometry, white markings and physics.

Actual verification: `scripts/dev.ps1 TestPieces` passes 334 checks and `TestSurfaces` passes 50 checks, both with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. No physical-phone or moving-lap test was performed.

## Worn white edge markings - 2026-09-21

Track-kit-50 gives the continuous white creator-road edge markings restrained age without weakening their geometry or readability. Low-frequency pigment loss contributes at most 5.5%, while sparse derivative-filtered chips expose up to 24% of the shared asphalt material. Raised kerb whites and dedicated finish markings are unchanged. No texture asset or gameplay data changes.

Actual verification: `scripts/dev.ps1 TestPieces` passes with zero failures and now checks that creator edge markings use one shared worn-pigment material. `TestSurfaces` passes 50 checks. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. No physical-phone or moving-lap test was performed.

## Stronger marking wear - 2026-09-21

Owner feedback found the initial wear too subtle. Track-kit-51 increases broad pigment fading from 5.5% to 12%, lowers the chip threshold from `0.76-0.82` to `0.66-0.78`, and raises maximum asphalt exposure from 24% to 42%. The marking geometry remains continuous and readable; kerbs and finish markings remain unchanged.

Actual verification: `scripts/dev.ps1 TestPieces` passes 340 checks and `TestSurfaces` passes 50 checks, both with zero failures. `CaptureStyle` succeeds with native cells preserved, all route/model views captured and zero bad road normals. The updated [broad bend](evidence/road-realism/creator-road-bend.png) was inspected for line readability. No physical-phone or moving-lap test was performed.

## Implemented

- `game/track/surface_detail.gdshaderinc` adds restrained 13-20 m world-space colour variation, sparse deterministic repair shapes and filtered sealed-crack lines to dry asphalt. Terrain asphalt, creator road pieces and bridge decks share the function, so joins do not expose a UV seam.
- `game/track/native_track_visual.gd` builds one compact L8 asphalt-coverage mask per creator visual and shares it across the combined road materials. The mask drives cosmetic verge wear only; it does not change the compiled road or collision boundary.
- `game/track/creator_road.gdshader` uses the mask for a softly broken dirt/wear band at exposed asphalt edges. Dirt roads, markings, grass, gravel, kerbs, wet Storm asphalt and Winter ice are excluded.
- Existing `SkidTrails` remains the dynamic tyre-mark layer: it follows four simulated wheel contacts, responds to slip/braking, accumulates repeated passes and batches marks into one MultiMesh. A synthetic ideal racing line was not added because it can misrepresent intersections, free paint and bridge layers.
- No external texture, runtime dependency or reference-image asset was added. All new marks are original deterministic shader logic.

## Actual verification

Pinned engine: Godot `4.7.2.stable.official.ed1daf0bf`, desktop Compatibility renderer.

| Command | Actual outcome |
|---|---|
| `scripts/dev.ps1 TestPieces` | 334 checks, 0 failures; includes the shared asphalt material/mask contract. |
| `scripts/dev.ps1 TestSurfaces` | 50 checks, 0 failures. |
| `scripts/dev.ps1 TestIce` | 69 checks, 0 failures. |
| `scripts/dev.ps1 TestStorm` | 54 checks, 0 failures. |
| `scripts/dev.ps1 TestSoil` | 155 checks, 0 failures; existing surface-responsive tyre marks retained. |
| `scripts/dev.ps1 CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"` | Succeeded; native cells preserved, 12 route views and three model views captured, zero bad road normals. |

Evidence: [creator overview](evidence/road-realism/creator-road.png) and [route view](evidence/road-realism/creator-road-route.png).

## Limits and remaining acceptance

- Repairs are deterministic from world coordinates and visual-generator version, not persistent player history. Real-driving-history wear remains deferred.
- This pass does not infer an optimal racing line; dynamic marks show actual driving instead.
- Captures were inspected on desktop. No Android export, physical-phone visual check, moving-lap shimmer check or frame-time profile was performed. Phone brightness, patch visibility in motion and sustained performance remain owner/device acceptance items.

## Reference asphalt texture - 2026-09-21

Requirements V02/V04/V05/Q01/R01. Track-kit-47 responds to the supplied race image with more legible fine aggregate, small dark pores and restrained weathering in the matte charcoal binder. Original world-space shader logic is shared by creator roads, painted asphalt and bridges; derivative filtering fades subpixel grain. The accepted 10 cm fringe blend, road geometry, camera and canonical physics are unchanged. Wet/ice branches retain their existing appearance. The reference is inspiration only, not a shipping asset.

Changed implementation files: `game/track/surface_detail.gdshaderinc`, `game/track/native_track_visual.gd`. Documentation: this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands (via PowerShell -NoProfile -ExecutionPolicy Bypass -File):
- `scripts/dev.ps1 TestPieces`: 334 checks, zero failures.
- `scripts/dev.ps1 TestSurfaces`: 50 checks, zero failures.
- `scripts/dev.ps1 CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: successful initial and final captures, native cells preserved, zero bad road normals, all 12 route views and model views saved. The final adjustment only reduced grain contrast after visual inspection.

[Final desktop screenshot](evidence/road-realism/reference-asphalt.png), [capture log](evidence/road-realism/reference-asphalt-capture.log). Desktop Compatibility renderer, pinned Godot 4.7.2. No device test or phone performance profiling performed; attachment status was not checked. Owner visual acceptance and moving-camera/phone shimmer checks remain. Existing unrelated work was preserved; no combined commit of the dirty workspace was made.

## Irregular road-aligned grain - 2026-09-21

Requirements V02/V04/V05/Q01/R01. Owner follow-up requests more irregular asphalt with slight direction along the road. Track-kit-48 warps the mineral field, varies aggregate density and strengthens uneven weathering. Creator-road bodies and fringes carry a local road-axis attribute derived from their own centerline samples, interpolated with double-angle encoding so reversed headings agree. World-space symmetric noise samples produce short, broken directional grain. The axis accounts for simulation Y mapping to negative world Z. Existing geometry, fringe crossfade, wet/ice materials and canonical simulation remain unchanged.

Changed files: `game/track/native_track_visual.gd`, `game/track/creator_road.gdshader`, `game/track/surface_detail.gdshaderinc`, this document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. All shader artwork is original code; no reference image ships.

Actual commands via `powershell -NoProfile -ExecutionPolicy Bypass -File`:
- `scripts/dev.ps1 TestPieces`: 334 checks, zero failures, canonical golden unchanged.
- `scripts/dev.ps1 TestSurfaces`: 50 checks, zero failures.
- `scripts/dev.ps1 CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: passed, including final world-axis sign correction; native cells preserved, zero bad road normals, route/model captures OK.

[Final screenshot](evidence/road-realism/directional-asphalt.png), [final capture log](evidence/road-realism/directional-asphalt-capture.log). Desktop Compatibility captures inspected. Free-painted asphalt and bridge decks receive irregular grain but retain isotropic detail because this pass supplies the road-axis attribute only to creator ground-road meshes. At intersections the visible section supplies its own direction. Owner visual acceptance, phone performance and moving-camera shimmer checks remain. No device test performed; phone attachment not checked. Unrelated dirty-workspace changes retained.

## Crisper asphalt follow-up - 2026-09-21

Requirements V02/V04/V05/Q01/R01. Owner found track-kit-48 smudgy. Track-kit-49 reduces broad binder variation from 0.09/0.09/0.15 to 0.035/0.03/0.045 and directional wear contrast from 0.22 to 0.15. Irregular fine aggregate, density variation, local road direction and accepted edge blend remain intact. Changed implementation files: `game/track/surface_detail.gdshaderinc`, `game/track/native_track_visual.gd`; documentation: this file, development status and Phase 0 plan. Original procedural material only; no additional asset or dependency.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestSurfaces` passed 50 checks, zero failures. No phone/device or moving-camera test performed. Owner visual acceptance remains outstanding.

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"`: first process stalled and was terminated; retry succeeded with native cells preserved, zero bad road normals and all route/model views OK. Final desktop capture inspected: [crisper asphalt](evidence/road-realism/crisper-asphalt.png), [capture log](evidence/road-realism/crisper-asphalt-capture.log). No stale capture used.
