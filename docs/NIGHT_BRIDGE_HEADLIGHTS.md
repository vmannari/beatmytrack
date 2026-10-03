# Night bridge headlight spill — 2026-09-29

## Scope and requirements

Owner clarification: ground-level headlights must not illuminate the bridge top, including while approaching or leaving an underpass.

Requirements: V02 (coherent biome/world presentation), V04 (readable vehicle lighting), and Q01 (verified regression/evidence). This is presentation-only: canonical handling, bridge collision, routes, camera framing and race rules are unchanged.

## Implementation

### Current crest correction (supersedes the layer split below)

`bridge_road.gdshader` now uses continuous Lambert diffuse instead of toon diffuse. This rejects below-surface light and smoothly attenuates light as the ramp normal turns away from the beam. `creator_bridge_visual.gd` reunites ramp and deck in one road mesh on layer 1; `bridge_presentation.gd` applies the same layer to legacy road surfaces. Structural meshes keep layer 2. No road geometry or canonical rules changed.

Performance: still one spotlight, shadows disabled, same road triangles and texture samples. The merged mesh removes the extra ramp mesh/draw from the preceding revision. Bridge roads participate in the existing light pass; no phone timings were collected, so a measured frame-time claim would be premature. Significant additional cost is not expected from this change.

Evidence: refreshed `CaptureHeadlights` captures include `ramp-approach.png`, `ramp-crest.png`, and `occlusion-on.png` under `docs/evidence/night-bridge-headlights/`. These exercise approach, elevated crest driving, and ground-level travel beneath the bridge. The earlier implementation descriptions below are historical.

Ramp follow-up: `game/track/creator_bridge_visual.gd` splits the two ramp road surfaces from the central deck. Ramp asphalt uses ordinary lighting layer 1 so approaching ground-level headlights illuminate the climb; the central overhead deck retains layer 2. Geometry and driving layers are unchanged. This applies to the asphalt bridge presentation used by the night biome; desert construction is unchanged.

Actual follow-up command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CaptureHeadlights` passed 81 checks. The [ramp approach capture](evidence/night-bridge-headlights/ramp-approach.png) was visually inspected and shows the lit ramp entrance. No physical-device test or Android export was performed. Ramp rails retain the bridge lighting layer; in-motion transition acceptance remains outstanding.

- `game/vehicle/car_visual.gd` retains one forward road spotlight. It normally illuminates ordinary world layer 1 and bridge layer 2; while the car is beneath a bridge it temporarily excludes layer 2.
- Creator and native bridge deck/structure meshes use visual layer 2. Directional biome lighting still includes them, while a headlight below cannot shade their visible top faces. Driving on the bridge restores headlight illumination.
- `game/track/native_track.gd` identifies when a ground-layer car is beneath either a creator bridge span or a native deck cell. A car already on the elevated layer never activates the underside light.
- `game/core/game.gd` excludes bridge lighting throughout ground-level travel using the presented state's driving layer. This covers approach, underneath and exit; elevated driving restores bridge lighting.
- `game/tests/test_headlights.gd` covers all five vehicles, dormant/active direction, light reuse, native bridge detection and desktop comparison captures.

There is no synthetic light on the bridge surface, no second spotlight and no headlight shadow-map cost. The established 20.4 m forward beam is unchanged; only its render-layer mask changes while beneath a deck.

## Actual verification

Commands run from the repository root with pinned Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 TestHeadlights
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 CaptureHeadlights
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev.ps1 TestConstruction
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --script res://tests/test_night_lighting.gd
git diff --check
```

Results:

- Latest approach follow-up: CaptureHeadlights passed 81 checks, including presenter integration outside the bridge footprint and ground/elevated/ground transitions. [Approach capture](evidence/night-bridge-headlights/approach.png) inspected. No Android export or device test performed.
- Night lighting: 15 checks, 0 failures.
- Construction/bridge race: 104 checks, 0 failures; five laps and zero contacts.
- Desktop Compatibility-renderer comparison inspected: [occlusion disabled](evidence/night-bridge-headlights/occlusion-off.png) and [occlusion enabled](evidence/night-bridge-headlights/occlusion-on.png). With occlusion enabled the beam no longer passes through and lights the top deck.
- `git diff --check` reported no whitespace errors; only existing line-ending notices appeared.

## Limits and remaining acceptance

- `adb` was not available on this shell path. No Android export, installation or physical-phone test was performed.
- Phone GPU cost and in-motion brightness still need device acceptance, especially at bridge entry/exit and at overlapping same-height bridge junctions.
- The bridge render-layer transition still needs in-motion validation on the target phone, especially at ramp/layer transitions.
