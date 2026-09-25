# Contact shading, bridge depth and Grass cloud shadows — 2026-09-25

Requirements **V02/V04/V05/Q01**. Owner explicitly requested these three effects following the effects assessment. Current presentation version `contact-lighting-2`, visual kit `track-kit-80`; cloud visibility follow-up below supersedes the initial tuning. Canonical physics, gates, track content, camera framing and dust behaviour are unchanged.

## Delivered behaviour

- All five vehicles have a soft contact shadow sized to their body. Its projection follows the supporting ground/deck and ramp slope, stays below jumps, widens slightly and fades with airtime. Water suppresses the car contact shadow. The existing directional shadow remains responsible for the sun silhouette.
- Selected fixed scenery receives small contact projections: tree trunks, bushes, rocks/cliffs, barriers, logs, parked vehicles and buildings. Tree contact is deliberately narrower than the canopy. Instances are grouped in 32 m spatial batches. Movable tyres and lightweight props retain their existing sun shadows; no stationary shadow is left behind them.
- Each authored bridge has a softly feathered under-shadow. Reconstructed opaque surface positions ensure both lower road and lower car are shaded, while the bridge deck and cars above it remain unaffected. It follows the span heading, width and smooth ramp-height profile. No bridge collision or clearance geometry changes.
- **Grass (`pine`) only** receives world-anchored 18 m cloud patches, drifting about 0.91 m/s with a maximum alpha of 0.24. The pass shades opaque scenery, roads and cars consistently; it is absent in Desert, Winter, Storm and Night city. Animation stops while paused. Biome switching removes/recreates the pass without global shader state.

These are bounded depth-projection volumes plus one Grass-only full-screen pass, using the existing Compatibility renderer. They add no shadow-casting lights, render targets, downloaded artwork or runtime dependencies. Transparent particles render afterwards and the CanvasLayer HUD is unaffected. Depth reconstruction follows the renderer-specific NDC convention documented in [Godot advanced post-processing](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html).

## Changed files

- `game/track/contact_shading.gd`, `contact_shadow.gdshader`, `bridge_shadow.gdshader`, `cloud_shadow.gdshader`, `shadow_depth.gdshaderinc` and their UIDs.
- `game/core/game.gd`: vehicle contact and Grass-only cloud lifecycle/clock; diagnostic effect toggle.
- `game/track/native_track_visual.gd`, `creator_bridge_visual.gd`: shared scenery/bridge projections, including editor previews.
- `game/tests/test_contact_shading.gd`, `scripts/dev.ps1`: focused headless and actual rendered checks/captures.
- `game/diagnostics/mobile_race_probe.gd`, `scripts/profile-features-phone.ps1`: reversible `contact_lighting` on/off comparison, with production restoration.
- This report, development status/plan, asset provenance and `docs/evidence/contact-lighting*`.

Concurrent winter-frost changes in the shared workspace are a separate task, not part of this implementation or its Git checkpoint. The exported APK includes the current shared workspace; the Grass/Knot phone comparison does not exercise that winter effect.

## Initial implementation: actual desktop validation

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Action | Actual result |
| --- | --- |
| `-Action Import` | Passed |
| `-Action TestContactShading` | 23 checks, zero failures; two ObjectDB instances reported at shutdown |
| `-Action CaptureContactShading` | Final 44 checks, zero failures, Compatibility/OpenGL RTX 3090 |
| `-Action TestBridgeContacts` | 16 checks, zero failures |
| `-Action TestConstruction` | 82 checks, zero failures; five laps, zero contacts, both bridge layers exercised |
| `-Action TestVehicleBatch` | 35 checks, zero failures across five vehicles |
| `-Action ExportAndroid -QuickValidation` | Passed import/startup, 74 driving, 18 catalog and 26 menu checks; matching-template APK exported |

Rendered assertions verify actual lower-car shading, exclusion of upper deck/car, visible instanced scenery contact, moving cloud patterns, an unaffected opaque HUD swatch, layer-aware contact positioning, ramp pitch, airborne fading, biome isolation, paused animation and unchanged canonical snapshot/cells. Diagnostic captures explicitly hide the visual deck to expose the lower/upper car for pixel checks; this is test-only and not gameplay geometry.

Initial capture assertions exposed test-fixture mistakes: an empty corner was incorrectly treated as opaque HUD, projected samples did not account for viewport stretching, and duplicate automatic batch names omitted some groups from the on/off capture. Corrected the swatch/sample mapping and readable batch names; final checks retain the intended invariants. These earlier failed runs are not counted as passes.

Desktop images inspected: [gameplay](evidence/contact-lighting/gameplay.png), [overview](evidence/contact-lighting/overview.png), [contacts](evidence/contact-lighting/contacts-on.png), and [clouds after 45 seconds](evidence/contact-lighting/clouds-45s.png). Paused HUD and scripted poses are presentation evidence, not a human-driven race.

## Initial implementation: device validation and acceptance

Actual command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -ContactLightingProfile -Seconds 30 -ReportName contact-lighting-phone-2026-09-25
```

Exported APK installed successfully on attached **DN2103 / OnePlus Nord 2**, Android 13, Compatibility/Mali-G77 MC9, normal 0.667 render scale. Knot was driven by the existing real-simulation AI probe with synthetic touch stress; each stage warmed for five seconds then sampled 30 seconds. The middle stage hides these three new effects, retaining existing directional shadows, simulation, HUD, particles and contact-position computation.

| Stage | Median frame ms | p95 ms | p99 ms | Driven metres |
| --- | ---: | ---: | ---: | ---: |
| New effects enabled | 16.599 | 20.182 | 23.381 | 254.0 |
| New effects hidden | 16.622 | 20.384 | 22.308 | 267.7 |
| New effects enabled again | 16.675 | 20.186 | 22.182 | 267.6 |

This run shows no material median/p95 regression from the new rendering passes. It does not demonstrate that every frame meets 16.67 ms: the first stage had a 63.898 ms maximum, versus 33.108/31.104 ms in the next stages. The phone was already warm (battery temperature 43.4°C before, 42.5°C after); no sustained thermal/fleet acceptance is claimed. The comparison hides rendering, not every CPU preparation instruction, and follows moving gameplay rather than an identical fixed-camera GPU benchmark. Existing Android build-tools 35.0.1 fallback warning remains.

[Raw reports, configuration, APK hash and battery records](evidence/contact-lighting-phone-2026-09-25/) retained. [Phone screenshot](evidence/contact-lighting-phone-2026-09-25/custom-phone.png) inspected; the screenshot is paused after measurement and the diagnostic 10,000-lap target prevents the probe ending early. It does not alter normal five-lap races or save a record. The script removed diagnostic markers and restored normal play. A post-run `adb logcat -d -s godot` shader/script-error filter returned no matching errors.

Remaining owner checks: contact strength during ordinary driving/rollovers, bridge entrances at oblique headings, restrained cloud visibility in motion and bright-room phone readability. The under-shadow is an artistic approximation of occlusion, not physically baked lighting. It targets current authored bridges; retired legacy regression-only geometry retains its existing presentation. Transparent dust/spray is not relit by the opaque-depth effect. Final performance conclusions must be scoped to the measured device/tracks.

## Cloud visibility follow-up — 2026-09-25

The owner could not see the original cloud shadows. V02/V04/V05/Q01; `contact-lighting-2` / kit 80. The original maximum opacity of 8.5%, 32 m noise scale and 0.45 m/s drift made the effect read like a weak overall tint. Maximum opacity is now 24%, patch scale 18 m, drift 0.91 m/s, with a tighter mask transition and slightly more secondary shape detail. Soft-edged patches and clear gaps are easier to distinguish within the gameplay view. Renderer work/pass count is unchanged, as are contact/bridge shading, biome isolation, pause behaviour and canonical state.

Changed files: `game/track/cloud_shadow.gdshader`, version constants in `contact_shading.gd` / `native_track_visual.gd`, `game/tests/test_contact_shading.gd`, this report and status/plan. The rendered test now requires an appreciable area with at least 10% relative darkening and checks motion after **eight seconds**, replacing the inadequate tiny-change/45-second-only acceptance. Previous evidence is retained separately.

Actual commands through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`: `-Action CaptureContactShading` passed **45 checks**; `-Action ExportAndroid -QuickValidation` passed import/startup, 74 driving, 18 catalog and 26 menu checks, then exported successfully. Inspected [gameplay](evidence/contact-lighting-2/gameplay.png) and [eight-second cloud position](evidence/contact-lighting-2/clouds-8s.png). These are scripted desktop captures, not phone or human visual approval.

Actual phone command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/profile-features-phone.ps1 -TrackId track_1e3936d025fe7c82 -Baseline -Seconds 20 -ReportName cloud-visibility-phone-2026-09-25`. Updated APK installed successfully on attached DN2103; 176.2 m driven, median 16.555 ms / p95 20.456 ms / p99 26.144 ms. [Phone screenshot](evidence/cloud-visibility-phone-2026-09-25/custom-phone.png) inspected, raw results/hash retained, diagnostic markers removed and normal play restored. This is a short current-build smoke measurement, not an old/new cost comparison or thermal acceptance. Owner acceptance of visibility during actual driving remains outstanding.
