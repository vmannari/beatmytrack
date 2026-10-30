# Sport hovercraft redesign — 2026-10-29

The owner rejects the previous leisure-craft model and requests a complete,
sportier design. This rebuilds the vehicle around a low single-seat racing
silhouette, a tapered bow and two integrated ducted fans.

## Requirements

- **HSR01:** replace the upright cabin, roof hatch, loose fan ring and fingered
  skirt with a formed low hull, swept shoulders, wraparound canopy and continuous
  pressure skirt. The nose is visibly narrower than the midbody from above.
- **HSR02:** two independently animated, counter-rotating fan frames sit in low
  fitted ducts. Sidewalls close the nacelles into the deck; four fixed supports
  connect the independently steering rear vanes to the guards.
- **HSR03:** slim fitted front and rear lights, night lenses, livery patterns,
  both sticker panels, paint, brake lights, weathering, washing, ghosts and
  detailed/racing models use the existing game systems.
- **HSR04:** the factory livery becomes red with charcoal accents. Existing
  valid saved colours and graphics are retained, not migrated or overwritten.
- **HSR05:** handling, collision configuration, camera and sound remain outside
  this visual redesign. The simulation source, handling source and hovercraft-4
  resource match their task-start hashes exactly.
- **R01/Q01:** native geometry, physical fit, livery, Garage, racing and saved
  appearance checks are recorded below. Owner appearance/motion and device
  acceptance remain.

## Views and dimensions

[Previous model](evidence/hovercraft-sport-redesign-2026-10-29/before-gl_compatibility/front.png),
[new model](evidence/hovercraft-sport-redesign-2026-10-29/after-gl_compatibility/front.png),
[rear fans](evidence/hovercraft-sport-redesign-2026-10-29/after-gl_compatibility/fan-detail.png),
[actual Garage](evidence/hovercraft-sport-redesign-2026-10-29/app-gl_compatibility/garage-1280.png),
[actual race](evidence/hovercraft-sport-redesign-2026-10-29/app-gl_compatibility/gameplay.png).
Matched views are captured in both Compatibility and desktop Vulkan Mobile.
Separate livery captures show the actual pattern, hood sticker and roof sticker.

| Model-space measurement | Previous | Sport redesign |
|---|---:|---:|
| Maximum height | 2.082m | 1.382m |
| Overall visible width × length | 2.250 × 4.234m | 1.993 × 4.200m |
| Bow / midbody half-width | 0.769 | 0.624 |
| Detailed triangles | 78,216 | 59,708 |
| Racing triangles | 24,968 | 18,500 |
| Racing shadow triangles | 838 | 906 |

The detailed and racing meshes use 23.7% and 25.9% fewer triangles respectively;
the new static racing shadow is slightly larger. The visual footprint is narrower,
while the existing approximate collision circle and handling are unchanged. Edge
contacts should therefore be included in owner/device play testing. These counts
are not phone frame-rate or AAA certification claims.

The fit audit samples actual full and racing deck triangles around both blade
envelopes. Covered samples retain at least 46.4mm and 42.95mm clearance
respectively; four edge samples per fan fall outside the upper deck mesh. The
blade-to-liner radial clearance is at least 13.1mm, sampled duct seating is
3.49–16.21mm, both nacelle sidewalls enter the deck, and all four supports meet
their hinges. It checks the actual arrays of both LODs, not just the height formula.

## Files, assets and provenance

Eight runtime sources contain this slice: `hovercraft_model.gd`, new
`hovercraft_sport_hull.gd`, `hovercraft_sport_drive.gd`,
`hovercraft_sport_surface.gd`, plus hovercraft-specific changes in
`car_visual.gd`, `livery_catalog.gd`, `vehicle_livery.gd` and
`vehicle_weathering.gd`. The original hovercraft integration fixture's fan
assertion now accepts either the historical single fan or the new independent,
counter-rotating pair; its other assertions remain intact.

The offline baker saves 254 immutable full/racing meshes under
`game/assets/vehicles/hovercraft_sport_v3`. Every saved vertex, normal, UV and
index array matches its procedural source, and mutable materials stay local.
The source signature includes all four sport geometry sources. The former v2
model resources remain byte-exact: 351 historical files checked. Six Garage
templates, the racing shadow, menu/header/Garage/news images and all 49 livery
photos are refreshed. The asset manifest records hashes, including the shared
template context, without claiming those other cars' source work as this task.

All shapes and native pictures are original project derivatives. Existing
CompactFinish and opaque analytic glass are reused. General hovercraft
construction was informed by [Hovercraft Club of Great Britain racing](https://www.hovercraft.org.uk/racing/);
no source photograph, branding, third-party model, generated bitmap or new
runtime dependency ships. See `hovercraft_sport_v3/PROVENANCE.md` and
`licenses/ASSETS.md`.

## Actual verification

All engine commands use the pinned `4.7.2.stable.official.ed1daf0bf`, via
`scripts/dev.ps1`, isolated `build/hovercraft-sport-review` APPDATA and an empty
`BMT_API_URL`. Exact scripts and logs are retained in the evidence `commands/`
and `runs/` directories. The native review is Windows desktop, not Android.

| Check | Result |
|---|---|
| Native model review, Compatibility / desktop Mobile | 21/0 each, including silhouette, mesh validity, two fan pivots, steering, saved-colour normalization and night light |
| Actual full/simple triangle fit audit | 71/0, with source hashes and sampled clearance metrics |
| Native livery pixel review, Compatibility / desktop Mobile | 19/0 each; pattern 53,394/52,012 changed pixels, hood sticker 2,964/3,041, roof sticker 707/805 |
| Mesh bake | 254 exact array round-trips, private material slots |
| Actual App Garage/ordinary race, both renderers | 10/0 each; two prepared-template hits per run |
| Actual Game turn/recovery/braking presentation, both renderers | 14/0 each; rendered heading and untouched simulation snapshots |
| Retained persistence, model, weathering and fan audio | 31/0 headless |
| Retained hovercraft racing model | 22/0; one 906-triangle racing shadow caster |
| Six-car prepared scene comparison | 24/0 native; retains original assertions with renderer-default-aware material comparison and current Kart kit capability |
| Actual saved appearance recovery | 83/0 native, including all six cars and read-only fake-server recovery |
| Pinned import and explicit app/model `CheckScript` | Pass |
| Full `test_script_parse.gd` | Fails on the unchanged historical `tests/fixtures/parking_hall_before/garage_page.gd:67`, missing `_build_wash_requirement()` |

The first generic `CheckScript` invocation omitted `-ScriptPath` and hit a
startup `add_child()` error. Explicit `res://core/app.gd` and
`res://vehicle/hovercraft_model.gd` checks both pass; the failed attempt is kept.
An initial sport shape passed its numerical checks but visual inspection exposed
dark lamps, a canopy tip opening, unsupported rudder hinges and gaps under the
fairings. Those were corrected before the final fit, livery and native reviews.

The non-hovercraft template audit finds Compact, Pickup, Kart and Forklift
geometry arrays exact against their task-start scenes. The Electric scene is
different: the task-start template had stale Electric/Kart source fingerprints,
and the required global cache refresh bakes the current concurrent Electric
model. All six refreshed scenes have current source guards and the current
prepared-scene assertions pass. No Electric source was edited by this slice.

## Checkpoint and remaining acceptance

`report.json`, `assets.json`, `surfaces.json`, `fit-audit-gl_compatibility.json`,
`template-context.json` and native records contain exact hashes and metrics.
`task.patch` is a 30-entry source/metadata checkpoint. It passes Git forward and
reverse checks, with exact bytes verified in an isolated task-owned control and
a reverse check against current files. Binary derivatives, concurrent changes,
generated build identity and user data are excluded from the patch; the asset
manifest records dated binary hashes separately.

Reload/rebuild to see the new model. Owner judgment of the design, movement,
edge-contact feel and physical Android appearance, memory and performance remain.
No physical-device attachment query/test, APK, real auth/purchase, owner-save/live
backend mutation, deployment, owner-process restart or main-index staging/commit
was performed. No phone FPS or AAA certification is claimed.
