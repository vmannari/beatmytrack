# Hybrid grass — 2026-09-23

**Current result: kit 57 introduces new meadow artwork and actual DN2103 comparisons.** See [visual/performance results](GRASS_PERFORMANCE.md) and [interactive comparison](evidence/grass/comparison.html). Earlier attempts below were rejected or superseded.

## Owner correction: restore vegetation detail

The owner rejected kit 55 as too plain. Kit 56 restores the original `painted_grass_v1.png` as the dominant albedo at its original 20 m world scale, with only 10% flat-colour blending and no extra positive mip bias. Broad macro shading is much weaker; the smooth yellow-green blobs no longer replace vegetation structure. Tufts sample the same painted texture and macro tint. Sparse opaque geometry and filtered fine normals remain. The synthetic `grass_albedo` map is retained as a prior experiment but is no longer sampled by the active grass colour function. No new art assets were generated.

Changed files: `surface_detail.gdshaderinc`, `grass_tuft.gdshader`, `grass_tufts.gd`, `native_track_visual.gd`, these notes, status/plan and evidence. Requirements V02/V04/V05/Q01. Actual pinned-build commands: `scripts/dev.ps1 -Action CaptureGrass` (17 checks passed), `TestGrass` (15 passed), `TestSurfaces` (50 passed), each invoked through PowerShell with `-NoProfile -ExecutionPolicy Bypass -File`. Refreshed driving and detail captures; driving view inspected at gameplay scale. [Rejected plain version](evidence/grass/rejected-plain-driving.png) and [revised detailed version](evidence/grass/hybrid-driving.png) use the same framing. No phone deployment, device test or profiling performed for this correction; owner visual acceptance and mobile motion/performance checks remain pending. The original implementation record below describes the rejected first pass.


Requirements V02/V04/V05/Q01; owner grass-only material/geometry request. Visual kit 55. No physics, route, timing, camera or track-data contract changes.

Grass in Pine and Storm uses three original baked 512×512 maps: a 32 m macro tile with roughly 4–10 m irregular medium/thick/dry patches, a 4 m albedo-factor tile containing 30–60 cm blade fans, and a 0.8 m normal tile containing 5–10 cm relief. Broad variation dominates fine contrast. Normal strength fades at subpixel size; all maps have mipmaps and anisotropic filtering. Ground, weighted terrain, road skirts and sand-to-grass fringes share world coordinates. Desert, Winter and Night city retain their existing ground appearance (Night city uses a neutral paved palette).

Five original opaque tuft meshes contain 3–7 folded blades / 6–14 triangles, about 5–10 cm high, with randomized rotation, 0.75–1.25 footprint scale, 0.8–1.2 height and subtle tint. Four irregular 1.5 m radius cluster areas per 16 m square occupy about 11% of clear ground before surface exclusions. Each cluster has 120 tufts. Tufts share the baked macro tint. 16 m MultiMesh batches support frustum culling; menu construction yields between batches. Grass replaces old green low-cover mounds; stones and authored objects remain.

No alpha cards, transparency, tuft shadow casting, physics bodies or grass AO pass. Tip sway is at most 6 mm. A conservative footprint margin excludes non-grass cells and bridge decks. All RNG and animation are presentation-only. The default circuit has **14,118 tufts / 42 batches**, with **2,270 tuft origins inside the captured driving viewport**. This viewport count is not a GPU draw count, occlusion measurement or performance result. The perceived material/geometry ratio remains an artistic target, not a measured percentage.

## Files and provenance

- `scripts/bake-grass.py`, `game/assets/textures/grass_{albedo,normal,macro_mask}.png` and import settings: reproducible mathematical texture baking using existing development numpy. No external images, downloaded assets, runtime generators or new runtime dependencies.
- `game/track/grass_tufts.gd`, `grass_tuft.gdshader`: original code-authored geometry, batching and shading.
- `native_track_visual.gd`, `surface_detail.gdshaderinc`, `ground.gdshader`, `terrain.gdshader`, `creator_road.gdshader`: shared bindings, relief and grass-only integration.
- `game/tests/test_grass.gd`, `scripts/dev.ps1`: headless checks and graphical evidence entry points.
- `game/diagnostics/surface_material_probe.gd`: historical shader adapter accepts the new relief interface and previously missing packed-sand flag; flat diagnostic modes disable grass relief. Historical `asphalt_previous` now also restores historical grass, so it must not be interpreted as an isolated current asphalt comparison. Production materials are restored after the probe.

## Actual validation

All Godot runs used `scripts/dev.ps1` and pinned 4.7.2.stable.official.ed1daf0bf. PowerShell invocation prefix: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action`.

| Command/action | Outcome |
|---|---|
| `python scripts/bake-grass.py` | Three deterministic maps baked; ~1.03 MB PNG total |
| `Import` | Passed; mipmap import verified |
| `CaptureStyle -StyleDocument 'C:/Codes/Godot/Beat my track/game/tests/fixtures/creator_default.json'` | Native cells preserved, driving/route/model captures saved during initial review |
| `TestGrass` | 15 checks passed |
| `CaptureGrass` | 17 checks passed; driving and close review captures saved |
| `TestSurfaces` | 50 checks passed |
| `TestDesert` | 24 checks passed |
| `TestBiomes` | 92 checks passed |
| `TestSurfaceProfile` | 928 checks passed, including actual shader rendering and material restoration |
| `Validate -QuickValidation` | Import/startup, 74 driving, 18 catalog and 22 menu checks passed; existing two-ObjectDB shutdown leak warning |

Initial failures were corrected: CaptureStyle needed an absolute document path; a placement check needed a clearance margin; headless Godot's dummy renderer does not retain MultiMesh transform buffers, so headless tests inspect exact submitted transforms while graphical tests also read the renderer buffers. Historical diagnostic shaders required the interface adapter above. None of the canonical invariants was weakened. Visual review also corrected dark backface shading and enabled missing import mipmaps.

Evidence: [driving view](evidence/grass/hybrid-driving.png), [close detail view](evidence/grass/hybrid-detail.png). Both inspected. The detail camera is test-only; the driving camera remains unchanged. Final logs are saved alongside the images.

## Remaining acceptance

A phone was attached (`adb devices` reported an authorized device), but **no Android export, installation, device test or device profiling was performed**. Desktop captures use Compatibility on RTX 3090 and do not prove mobile performance. Owner visual approval, motion/shimmer review on a phone, Android frame-time comparison and sustained thermal testing remain outstanding. Full replay regression was not run because canonical simulation is unchanged. Existing import warning: target SDK build tools fallback to 35.0.1.
