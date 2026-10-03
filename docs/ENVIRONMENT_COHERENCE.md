# Gameplay environment coherence — 2026-10-03

Requirements: V02 (mature matte/cel-shaded presentation), V04 (readability and mobile cost), V05 (shared creator presentation), R01/Q01 (preserved canonical data and actual evidence). The owner supplied the current gameplay screenshot and requested environmental improvements, explicitly excluding the HUD.

## Result

Presentation kit `track-kit-103`, contact shading `contact-lighting-6`.

- Pine and Storm retain the existing original meadow artwork. Filtered texture sampling, 38% palette blending and modest desaturation reduce fine contrast and yellow highlights; fine normal strength falls from 0.24 to 0.11. Broad meadow variation remains. There are no generated grass blades or wind.
- Existing clipped shoulders use the baked meadow macro field to vary where grass encroaches. The near-road soil stays visible; larger patches vary the apparent dirt width instead of adding high-frequency edge noise. The exposed asphalt transition and shoulder use the same quieter soil tint. Existing junction clipping, authored-paint precedence and exposed-edge geometry remain the authority.
- Dry asphalt uses reduced aggregate contrast and a restrained multi-metre binder field from the existing baked surface factors. Roads and bridge decks share the treatment. Compacted desert sand, wet Storm roads and winter ice retain their established surface functions. No new repair cracks, tyre decals or inferred racing/braking lines.
- Existing car and prop projections gain a firmer central contact with soft edges. Car strength changes from 0.25 to 0.34; the static default changes from 0.23 to 0.27. Jump-height fading, ramp pitch, bridge-layer placement and water exclusion remain.
- No new meshes, lights, shadow-map casters, render passes, external assets, runtime dependencies or collision objects. The dry asphalt adds one baked-factor lookup. Meadow verge blending replaces the old procedural fringe and reuses its computed coverage for colour and relief; phone cost has not been measured.

Gameplay camera, car dimensions, handling, road/kerb meshes, lap gates, rules and player documents are unchanged by this task. No HUD source or asset was edited. A source-hash audit detected an independent concurrent change to `game/ui/control_layout_editor.gd`. A concurrent solitary-piece kerb correction also appeared in `native_track_visual.gd`; only this task's version increment is staged from that file. Both unrelated edits are outside this task checkpoint.

## Evidence

[Interactive before/after comparison](evidence/environment-coherence-2026-10-03/comparison.html), [before](evidence/environment-coherence-2026-10-03/ajorata-before.png), [after](evidence/environment-coherence-2026-10-03/ajorata-after.png), [corner before](evidence/environment-coherence-2026-10-03/ajorata-corner-before.png), [corner after](evidence/environment-coherence-2026-10-03/ajorata-corner-after.png).

[Static meadow capture](evidence/environment-coherence-2026-10-03/grass-static/static-driving.png) and [bridge/prop contact capture](evidence/environment-coherence-2026-10-03/contact-shading/contacts-on.png). Actual desktop images were inspected. The paired style captures preserve their existing paused/countdown overlays; the contact/static captures use their existing diagnostic overlay settings. The supplied reference is not copied into shipping assets.

## Actual commands and outcomes

All Godot actions used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>` and the pinned `4.7.2.stable.official.ed1daf0bf` engine. Graphical runs used Compatibility/OpenGL on RTX 3090. Logs are under `evidence/environment-coherence-2026-10-03/`.

| Action / arguments | Actual outcome |
| --- | --- |
| `CaptureStyle -StyleDocument 'C:/Users/ville/AppData/Roaming/Circuit01Lab/tracks/track_acf29166cceaaa42.json'` | Before and final captures exit 0; collision cells preserved; 12 route views and three model views saved to build. Paired start/corner images retained. Final road normals and vertex counts match the baseline. |
| `TestRoadBuild` | 33 checks pass, including exact road mesh arrays across Pine, Desert, Winter and Night city, cached resource behavior and canonical preservation. |
| `TestContactShading` | 23 checks pass, including jump fade, ramps, bridge-layer contacts, batched props and canonical preservation. Three existing ObjectDB instances reported at shutdown. |
| `CaptureContactShading` | 45 graphical checks pass, including visible car/rock contact, bridge occlusion and opaque UI isolation. |
| `TestShoulders` | Shoulder union area 30, no overlapping interiors/failures; 71 visual-join and 18 internal-contour checks pass. |
| `TestSurfaceProfile` | 928 graphical checks pass across Ajorata and Storm, including material switching, shader binding, preserved meshes and restoration. Historical diagnostic compatibility was extended for the new verge helper. |
| `TestSurfaces` | 50 checks pass. |
| `TestGrass` | 15 legacy generator/material checks pass. Its printed tuft budget is an isolated generator diagnostic, not active scene density. |
| `CaptureGrass -Screen static -Track track_acf29166cceaaa42` | 21 checks pass; no generated grass in the actual race scene. At one-second separation, 0/2,158 grass and 0/13,034 road samples changed with cloud shading disabled. |
| `TestBiomes` | Initial and final runs: 107 checks, **five failures** in `New repeats required selection with fresh identity` at `game/tests/test_biomes.gd:76`. An intervening run failed parsing a concurrently edited `app.gd` call to `get_viewport_rect()`; that call was corrected outside this task before the final run. Unique per-process logs are retained as `biomes-initial-failure.log`, `biomes-test.log` and `biomes-final.log`. This is the creator New-document flow in the current mixed workspace, outside the environmental edits. No assertion was removed or weakened; a full-suite pass is not claimed. |
| `Doctor` | Pinned engine and matching export templates found; DN2103 attached. |
| `git diff --check -- <task code paths>` | Passes, with CRLF normalization notices. |

Read-only inspection used `Get-Content`, `rg`, `git status` and `Get-FileHash`; baseline source snapshots are under ignored `build/environment-coherence-baseline/`. The initial UI hash inventory is retained as evidence. Logs were copied from unique `build/logs/<Action>-<PID>/` folders because shared latest-log aliases changed during concurrent work. No player track files were modified or copied into the repository.

## Changed files

- `game/track/surface_detail.gdshaderinc`: shared meadow, asphalt and verge functions.
- `game/track/creator_road.gdshaderinc`: consistent roadside tint, meadow encroachment and shared colour/relief coverage.
- `game/track/contact_shadow.gdshader`, `contact_shading.gd`: firmer existing contact projections.
- `game/track/native_track_visual.gd`: presentation-kit revision invalidates previous road artifacts.
- `game/diagnostics/surface_material_probe.gd`: preserves historical comparison interface without changing its original art.
- `game/tests/test_contact_shading.gd`, `test_grass.gd`: new evidence destinations only; assertions unchanged.
- This report, task evidence, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

## Remaining acceptance and limits

No Android export/install, physical-device driving, GPU benchmark or thermal test was performed; the DN2103 was attached during Doctor. No mobile performance improvement is claimed. Owner visual acceptance, moving-camera stability and bright-light phone readability remain. Pine/Storm meadow and dry asphalt are the focus; other biome-specific ground art is retained. Automatic barriers, added props, wear decals and start/finish decoration are outside this material/contact slice.

No physics merge/full replay regression, backend modification, service deployment or production action was performed. The current creator identity failures remain visible. The task checkpoint includes only the environmental code, capture adapters, task status entries and new evidence/report; unrelated mixed-workspace work is excluded.
