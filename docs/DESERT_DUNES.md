# Desert dunes and dry scrub — 2026-09-24

Requirements V02/V04/V05/Q01. Owner supplied desert photographs and requested sand with dunes, continuing the preceding mobile-performance constraint. Kit 58.

## Appearance and scope

Original sand artwork replaces the old vegetation-derived desert ground tint. Broad irregular crests, curved wind ripples and smoother swept gaps now cover loose desert ground, painted loose sand and roadside skirts in continuous world coordinates. The material tint compensates for the existing strongly orange light so the sand remains ochre rather than fluorescent orange. The low red-orange sunset, long shadows, compacted road, kerbs, driving model, dust emission and lifetime are unchanged.

The dune shapes are **material relief, not raised collision terrain**. Large dune shading is baked into original artwork; a subtle baked slope map provides additional lighting variation. This keeps all legitimately driveable off-road surfaces flat in the simulation and prevents a vehicle from sinking into decorative raised geometry. There is no runtime noise generation, terrain tessellation or dune physics. The broad dune artwork repeats at 24 m; the slope data repeats at 32 m. Both use mipmaps and anisotropic filtering, at 1024 runtime resolution.

Sparse dry grass fans replace a fraction of desert low-cover rocks. A low-bit placement bug had caused grid-aligned seeds to pick only rocks; desert selection now uses higher bits, choosing scrub at approximately one fifth of accepted sites. Each scrub fan is 18 opaque triangles with dark roots and straw tips, batched into the existing single low-cover mesh. Existing road/deck/object clearance, site budget and no-collision behavior remain. Other biomes retain their previous selection behavior. Authored objects remain unchanged.

The initial mathematical colour/normal trial read as overly regular stripes. Final colour uses original generated artwork; the mathematical field is retained only for subtle slope lighting. References are visual guidance, not shipping textures, and their watermark/content has not been copied into the project. [Exact prompt and provenance](DESERT_DUNES_PROMPT.md).

## Evidence and tests

[Saved desert circuit, new material](evidence/desert-dunes/track_3e26605a8a90165e/baseline.png), [same camera, old material](evidence/desert-dunes/track_3e26605a8a90165e/desert_original.png). Default-circuit comparisons are also in `docs/evidence/desert-dunes/`. The original unmodified scene capture is retained as `original-driving.png`. The material-only comparison keeps the new scrub mesh identical in both images; it is not a whole-build rollback. Desktop captures were inspected at gameplay height.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ...` and the pinned Godot 4.7.2 build/templates:

| Action | Outcome |
|---|---|
| `python scripts/bake-desert.py` | Original periodic packed height/slope data baked, 1024 square, 1,552,941 PNG bytes |
| `Import` | Passed, mipmaps enabled for artwork and slope texture |
| `TestDesert` | 31 checks pass, including deterministic five-car replay, compacted-sand behavior, dust and biome isolation |
| `CaptureDesert` | 41 checks pass; original/new default-circuit material captures |
| `CaptureDesert -Track track_3e26605a8a90165e` | 52 checks pass; saved track comparison plus dust/persistence captures |
| `TestSurfaces` | 50 checks pass |
| `TestGrass` | 15 checks pass |
| `TestBiomes` | 92 checks pass |
| `TestSurfaceProfile` | 928 graphical checks pass, including historical shader adapter and material restoration |
| `ExportAndroid -QuickValidation` | Fresh APK exported after import/startup, 74 driving, 18 catalog and 22 menu checks passed |

The existing Android build-tools fallback to 35.0.1 and driving-test two-ObjectDB shutdown warnings remain. Full replay regression was not rerun because no canonical physics changed.

## Phone comparison

The existing saved desert track is used on DN2103; no player tracks are copied, overwritten or deleted. `scripts/profile-features-phone.ps1 -DesertProfile -Seconds 15 -ReportName desert-performance-2026-09-24` installs the fresh APK and alternates old / new / old / new / old ground material. Each stage warms for five seconds and measures fifteen seconds. Normal dust, lighting, input, HUD, shadows and rules remain enabled. The probe uses unscored AI driving and saves no records. The final screenshot is taken after measurement and after restoring the new material.

The fresh APK installed successfully, but the phone was locked: Android reported NotificationShade focus and mDreamingLockscreen=true. The attempt timed out with 0/5 stages, so there are no device performance results or phone capture. The runner removed diagnostic markers and relaunched normal play. APK hash, configuration and device/battery information are retained in [the evidence directory](evidence/desert-performance-2026-09-24/). Device performance remains unverified; unlock is needed to repeat the comparison. This compares ground-material cost with identical new scrub geometry in all stages; it does not isolate the small scrub-mesh triangle change. Whole-frame wall-clock measurements are not GPU timestamps, and capped frame pacing can hide headroom differences.

## Changed files and acceptance

`game/track/{surface_detail.gdshaderinc,ground.gdshader,terrain.gdshader,creator_road.gdshader,native_track_visual.gd}` implement the material and scrub. `game/assets/textures/desert_sand_v2.png` and `desert_dunes_v1.png` plus import settings are the new assets. `scripts/bake-desert.py` reproduces packed slope data with existing development numpy; no runtime dependency. `game/tests/test_desert.gd`, `game/diagnostics/surface_material_probe.gd`, `scripts/dev.ps1` and `scripts/profile-features-phone.ps1` add validation, captures and bounded comparison modes. Status/plan and these documents record evidence.

Owner visual approval and longer driving/motion/thermal acceptance remain. Generated artwork is not mathematically guaranteed seamless; exact periodicity applies to the numeric slope map, while artwork joins are checked visually. No new gameplay hills, jumps or handling effects are claimed.
