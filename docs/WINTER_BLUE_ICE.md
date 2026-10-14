# Winter blue ice and frosted tire scuffs — 2026-10-12

The owner requests cold light-blue roads and whiter tire marks, then supplies a closer road-colour/texture reference. This local cosmetic revision follows the reference's blue ice, broken pale scraping and road-aligned wear. Owner visual acceptance remains open.

## Requirements and changed files

- WE35: `game/track/winter_ice.gdshaderinc` moves the shared ice colour to `(0.40,0.51,0.63)`, retaining the original artwork and weak broad variation. Ground roads and bridges use that shared helper.
- WE36: `game/vehicle/skid_trails.gd` changes Winter ice marks to pale crystalline abrasion. Strength, opacity, width, relief, placement and fixed pool remain. Explicit normals from each contact-aligned instance shade ice scuffs as the underlying surface, including bridge ramps; the steep shared groove normals otherwise made even pale colours render dark. Other surface styles retain their lighting.
- WE37: `game/track/surface_detail.gdshaderinc` whitens positive fine scrape detail from the two already sampled original ice images. The existing directional UVs follow user-created bends; broad threads stay weak. Static worn paths also frost instead of darkening. Width-aware white edge blending and the original finish/roughness/reflection data remain.
- V04/V05, G01/R01, Q01: no camera, lighting, accepted bank/terrain shape, simulation, scoring or local car-condition change. No new textures, samplers, geometry, particle pools or draw calls. A few arithmetic operations use existing artwork; scuff normals use the existing instance transform.
- `game/track/native_track_visual.gd`: kit157→158 invalidates presentation caches. Concurrent unrelated Desert work subsequently advanced this version; its edits are preserved and excluded from the task-only patch.
- `game/tests/test_winter_environment.gd`: evidence directory for this task. `game/tests/capture_winter.gd`: optional output directory and staged ice-scuff preview, current contact-effect expectations and actual cached-bank geometry checks. `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document: actual delivery record.

## Actual verification

Pinned Godot 4.7.2.stable.official.ed1daf0bf through `scripts/dev.ps1`, with process execution-policy Bypass and normal Windows certificate/graphics access. All graphics measurements use an RTX3090 desktop.

| Actual command arguments after `scripts/dev.ps1` | Outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--video')` | Compatibility:101 checks,0 failures;314 draws,402255 primitives in fixture |
| Same command with `-RenderingMethod mobile` | Mobile Vulkan:101 checks,0 failures;330 draws,402255 primitives |
| `-Action TestScript -ScriptPath res://tests/capture_winter.gd -Graphical -TestArgument @('--ice-scuff-preview','--output-dir=res://../docs/evidence/winter-blue-ice-2026-10-12/interaction')` | Final Compatibility:170 checks,0 failures |
| Same capture with `-RenderingMethod mobile` and output ending `/interaction-mobile` | Final Mobile Vulkan:170 checks,0 failures |
| `-Action TestScript -ScriptPath res://tests/test_soil.gd -Graphical` |166 checks,0 failures; surface/load/slip/opacity/width behavior |
| `-Action Doctor` | Pinned engine/templates found; ADB list empty |

Total708 checks pass. Initial attempts are retained in logs: the old capture prohibited any ice powder, whereas the earlier accepted WE06 environment explicitly introduced a small rolling/drift wake. Runtime emission code is unchanged. The fixture now separately forbids tire smoke, bounds drift powder to17% emitter ratio and below33% of chips, requires loose snow to have over3× the powder, and caps straight ice wake at5%. A warm-cache attempt also expected a named bank node, but the existing mesh cache does not retain names. The bank invariant now requires visible nonempty geometry with the actual Winter bank material, preserving the rendering requirement on warm/fresh paths.

The close-up uses staged presentation samples on real Winter road contacts and verifies every sampled state is unchanged. It is not a physics trajectory or scored race. The motion previews use actual canonical fixture driving.

## Desktop cost

Actual diagnostic command: `-Action TestScript -ScriptPath res://tests/profile_winter_desktop.gd -Graphical -TestArgument @('--document=C:/Users/ville/AppData/Roaming/Circuit01Lab/cloud/fe772d2e756f39f351786a6c81dcb401f381848c01d5ea2cfdc05969d0cf0aed/cd0b5ca436fd1dd3e15256ba506fa528792e351bd6df13dbbaa49681d8e75262.json','--tag=blue-ice-final','--profile-dir=res://../docs/evidence/winter-blue-ice-2026-10-12/performance','--4k','--seconds=20','--modes=full')`.

Final Slippery 3840×2160 full-render-scale unscored driving: 2401 ticks, wind clock 20.005s,36 bank layers; frame median 3.280ms,p95 5.193ms, GPU median 2.393ms; 0 frames over16.667ms. This whole-scene sample is affected by desktop load and concurrent unrelated work. It is not an isolated incremental-cost/speedup comparison or physical-phone performance claim. The earlier `desktop-blue-ice` sample predates the final normal fix and is retained separately.

## Evidence and acceptance

[Normal driving](evidence/winter-blue-ice-2026-10-12/driving.png), [driving motion](evidence/winter-blue-ice-2026-10-12/driving-motion.html), [white scuff close-up](evidence/winter-blue-ice-2026-10-12/interaction/tracks/ice-scuff-preview.png), [Mobile scuffs](evidence/winter-blue-ice-2026-10-12/interaction-mobile/tracks/ice-scuff-preview.png), [validation](evidence/winter-blue-ice-2026-10-12/validation.json), [final profile](evidence/winter-blue-ice-2026-10-12/performance/desktop-blue-ice-final-gl_compatibility.json). Original asset provenance remains; the supplied reference is not a shipping texture.

Restart the running client to load the shaders. Owner colour/detail/mark visibility review remains, including selected cameras and varied creator tracks. No phone is attached; no phone visual/performance/thermal test, APK export/install, full Validate, physics regression, backend test/deployment or live write was performed.

The task-only Git checkpoint and source patch are in `build/winter_blue_ice`; main index/HEAD and concurrent edits are preserved. Shared source patches contain only this Winter change, rather than the concurrent Desert changes. Large motion HTML remains in workspace evidence.
