# Bridge and racing HUD refinement

Owner request, 2026-09-15: accepted kerbs; refine bridges and make the racing HUD match the illustrated menu with a tidier layout.

## Requirements and implementation

- **V02/V03/V04/V05:** mature cel-shaded world and menu-related HUD, preserving the high-oblique follow camera and whole-world framing.
- **G01/R01/R07:** keep accepted driving, separate bridge layers, accessible handling selection, and untimed editor practice.
- Creator bridges now have a concrete footing, a narrow folded steel barrier, discrete posts and amber reflectors, closed rail ends, expansion joints and a 42 cm shaded deck fascia. The existing 65 cm rail height, 75 cm collision footprint, deck elevation and ramp profiles are retained. No support pillars were added in drivable underpasses.
- Native bridges use the same steel/concrete tones and shaded fascia. Asphalt uses the existing road pigment shader; upward face winding fixes back-face darkening. `BridgePresentation.VERSION` is `bridge-ramps-2`; elevation calculations are unchanged.
- Lap and circuit occupy a bounded top-left card; race time is centred; restart/tracks/pause and the visible handling selector are grouped at top-right. Speed is a compact bottom-centre card clear of the pedals. Long circuit names truncate inside their card.
- Navy panels, cream Barlow Condensed type and warm yellow accents match the illustrated menu. Touch controls have the same visual language and a yellow pressed state. Hit regions, handedness and sizing remain unchanged. Countdown uses the same type and accent.
- Practice retains its untimed status/resume control, Restart, yellow Edit here action and handling selector, without lap/time/speed clutter. Developer tuning and telemetry remain accessible.

## Changed files

- `game/track/creator_bridge_visual.gd`, `bridge_presentation.gd`: structural bridge meshes and materials.
- `game/ui/race_hud_style.gd`, `playground_hud.gd`, `touch_controls.gd`: shared HUD styling, layout and touch rendering.
- `game/core/game.gd`: split circuit/lap presentation and countdown styling only for this checkpoint.
- `game/tests/test_bridge_hud.gd`, `scripts/dev.ps1`: layout/bridge witness and TestBridgeHUD/CaptureBridgeHUD entry points; suite included in future Validate runs.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document and evidence below.

All mesh details are original procedural code. Fonts are the existing cleared Barlow assets. No new raster assets or third-party dependencies. Existing uncommitted menu and visual suspension work is preserved separately.

## Actual verification

Commands run through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot **4.7.2.stable.official.ed1daf0bf**:

| Action | Actual result |
|---|---|
| `Import` | Passed; scripts imported. Environment reports missing Android build-tools. |
| `TestBridgeHUD` | 75 checks, zero failures: creator/native road normals and vertical structure, unchanged collision layers, HUD state isolation, target bounds and non-overlap, long title, compact speed, pause/resume. Logical sizes 960x540, 1280x720 and 1920x864. |
| `TestDriving` | 70 checks, zero failures; includes real HUD input, handling selection, restart, pause and camera headings. Four ObjectDB instances reported at test exit. |
| `TestPractice` | 31 checks, zero failures; six actual untimed laps, zero collisions, retained practice controls. Two ObjectDB instances reported at test exit. |
| `TestConstruction` | 73 checks, zero failures; five bridge laps, zero contacts, upper/lower traversal and editor construction. |
| `TestTracks` | 163 checks, zero failures; native bridge ramps, underpasses, rail tips, reverse escape and historical replay fixtures. |
| `CaptureBridgeHUD` | 79 checks, zero failures including four saved desktop screenshots. |
| `CaptureStyle -StyleDocument "$env:APPDATA/Circuit01Lab/tracks/track_5765ff853b63dea5.json"` | Read-only owner Curvy document; capture and route views saved; native cells preserved and flat road normal audit passed. |

**412 focused headless checks pass** across five suites. Full Validate/replay matrix and Android export were not run for this presentation-only slice. No canonical physics, collision, timing, track documents, grass, ground asphalt or accepted kerb changes.

## Desktop evidence

All images below are actual engine captures with the normal gameplay camera. Posed bridge witnesses freeze the simulation for inspection; these are not proof of touch feel or mobile performance.

- [Creator bridge and race HUD, 1280x720](evidence/bridge-hud/creator-race.png)
- [Native bridge and compact HUD, 960x540](evidence/bridge-hud/native-compact.png)
- [Untimed practice, 1920x864](evidence/bridge-hud/practice-wide.png)
- [Paused practice](evidence/bridge-hud/practice-paused.png)
- [Owner Curvy bridge](evidence/bridge-hud/curvy-bridge.png)

## Remaining acceptance

Owner visual acceptance remains pending. No phone is attached and no device test was performed. Bright-light readability, physical touch ergonomics, display cutouts and Android frame pacing still need an actual phone. Native raster bridge outlines retain their existing cell-shaped silhouette; this slice does not rebuild track topology. Existing test-exit ObjectDB warnings are recorded above, not counted as device validation.
