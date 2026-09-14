# Surface response follow-up ? 2026-09-14

Requirements: G01 (driving response), V02/V04/V05 (surface presentation), R01 (local practice), and the owner's surface follow-up. This supersedes the deep-water blocking behavior documented in CREATOR_HAZARDS.md.

Pond/painted water (cell 3) now permits driving. Speed-dependent resistance strongly limits powered speed while allowing escape from rest; shallow water (cell 6) also slows the car. Object puddles retain reduced grip and additional speed-dependent resistance. Walls, scenery and world bounds remain solid. Bridge decks and airborne presentation do not submerge.

The car lowers progressively over a roughly 3 m shoreline footprint, reaching 0.48 m in ponds and 0.12 m in shallow water. Bilinear sampling avoids snapping between terrain cells. This is presentation-only depth, not terrain sculpting or fluid simulation. A reviewed Windows [shore capture](evidence/surfaces-water.png) shows lower wheels/body hidden by water while the roof stays visible. The fixture uses a square painted pond to isolate the transition.

Oil and water have independent 0?1 tire coatings. Three metres of exposure fully coats tires; actual resolved travel removes a full oil coating over 180 m, dirt/grass/sand over the existing 80 m, and water over 20 m. Waiting and airborne travel do not clean tires. At 36 km/h these correspond to approximately 18, 8 and 2 seconds. Oil retains up to 65% grip loss, dirt 25%, water 18%; the strongest coating applies rather than multiplying penalties. Reset clears all coatings. Dirt pickup remains slower on grass than sand/dirt. Water does not instantly erase existing oil.

Physics is `arcade-planar-0.18`; recorder schema 6 appends `[tire_oil,tire_water]` at snapshot index 17, giving 18 fields. Existing indices are preserved. Track geometry and creator document schema are unchanged. Local record rule keys already include the physics version.

Changed runtime files: `game/track/native_track.gd`, `playground_data.gd`, `game/vehicle/vehicle_simulation.gd`, `vehicle_state.gd`, `track_hazards.gd`, `game/core/game.gd`, and `game/persistence/handling_recorder.gd`. Regression fixtures: `game/tests/test_hazards.gd` and `test_tracks.gd`. Status and phase-plan entries accompany this document.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2:

- `TestTracks`: 163 checks, zero failures; existing circuit/bridge/replay/contamination tests and updated traversable-water requirement.
- `TestHazards`: initial targeted run, 148 checks, zero failures.
- `CaptureHazards`: final graphical run, 154 checks, zero failures, including coating pickup/recovery replay, retention order, stationary persistence, powered pond slowdown and shore depth. Screenshot inspected.
- `Validate`: passed import, 83 script parses, main-scene startup and all domain/UI suites. [Suite results](evidence/surfaces-validation.txt). `TestTracks` was rerun after the shallow-water adjustment and passed all 163 checks.
- `git diff --check`: passed.

Remaining acceptance: owner driving feel, shoreline appearance in motion and physical-phone frame pacing. No phone/device test or APK export was performed; attached devices were not enumerated and Android build-tools are unavailable. Replay equivalence is tested on the pinned Windows engine only. Tire coatings affect grip; this slice does not add tire decals or spray particles.
