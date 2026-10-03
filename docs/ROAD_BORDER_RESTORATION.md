# Original road-border direction — 2026-10-03

Latest owner revision: kit 109 uses a halfway blend of the original and smoothed shoulder edges. See [Balanced border follow-up](#balanced-border-follow-up--2026-10-03). The kit-108 restoration below records the preceding iteration.

Requirements: V02 (mature restrained scenery), V04 (readable road boundary), V05 (shared creator presentation), R01/Q01 (preserved canonical geometry and actual evidence). The owner prefers the road borders in the supplied original gameplay image and requests returning towards that direction. The image is a conversation reference, not a shipping asset.

Kit `track-kit-108` restores the pre-kit-103 grass-to-sand shoulder treatment: the original `grass_fringe` calculation again supplies the short, locally broken grass edge along the sand strip. Removed the replacement `meadow_verge` calculation and its diagnostic compatibility stub. This supersedes the alternative meadow blend documented in [KERB_VERGE_CORRECTION.md](KERB_VERGE_CORRECTION.md).

Sand tint and detail retain their original shared palette. Shoulder widths, white edge markings, road meshes, clipping/overlap ownership and authored surface masks retain their existing geometry. The worn concrete kerb treatment and lighter muted red remain. Flat terrain stays restored; HUD, camera, vehicles, canonical handling/rules and player documents receive no edits from this task. The material treatment is restored to the earlier source; this is not a claim of pixel equality to the owner's screenshot, whose track and framing differ from the diagnostic fixture.

## Changed files

| File | Change |
| --- | --- |
| `game/track/creator_road.gdshaderinc` | Use the original grass fringe for non-desert shoulders. |
| `game/track/surface_detail.gdshaderinc` | Remove the superseded meadow verge helper; original grass fringe remains. |
| `game/diagnostics/surface_material_probe.gd` | Remove the obsolete helper stub from the historical material probe. |
| `game/track/native_track_visual.gd` | Advance the visual cache version from 107 to 108. |
| This report, status/plan and evidence | Record source restoration, actual checks and captures. |

## Actual checks and evidence

Engine commands used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>`, pinned Godot `4.7.2.stable.official.ed1daf0bf` and matching templates. Graphical checks used Compatibility/OpenGL on RTX 3090.

| Action / arguments | Actual outcome |
| --- | --- |
| `TestSurfaceProfile -TracksPath 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks'` | 929 checks, zero failures, exit 0. Read-only Ajorata and Storm fixtures cover material/probe variants, unchanged meshes, palettes and masks. |
| `TestRoadBuild` | 33 checks, zero failures, exit 0; exact road mesh golden comparisons, cached geometry and canonical data preserved across Pine/Desert/Winter/Night. |
| `CaptureStyle -StyleDocument 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks/track_acf29166cceaaa42.json'` | Exit 0; native cells preserved, no invalid road normals, gameplay/12 route views/model views saved. Final gameplay and corner images inspected. |
| `Doctor` | Exit 0; pinned engine and matching templates found, DN2103 attached. |
| `git diff --check -- <changed code paths>` | Exit 0. |

[Before gameplay](evidence/road-border-restoration-2026-10-03/gameplay-before.png), [restored gameplay](evidence/road-border-restoration-2026-10-03/gameplay-after.png), [before corner](evidence/road-border-restoration-2026-10-03/corner-before.png), [restored corner](evidence/road-border-restoration-2026-10-03/corner-after.png). Before images are the retained kit-107 flat-ground captures from the preceding removal; after images were captured for this task. Existing paused/countdown overlays remain in diagnostic screenshots. Actual invocation logs are saved beside the images.

No Android export/install, physical-device driving, full `Validate` or GPU/thermal benchmark was performed. A phone was attached during Doctor. Remaining acceptance: owner review of the restored border character and phone readability in motion. No new assets, shader passes, geometry or dependencies were introduced. Unrelated dirty workspace changes are excluded from the checkpoint.

## Balanced border follow-up — 2026-10-03

The owner clarifies that the border should lie between the original and smoothed versions. Requirements V02/V04/V05/R01/Q01 remain. Kit `track-kit-109` uses an equal blend of the original `grass_fringe` and the quieter kit-107 shoulder mask. Local grass breakup remains visible with reduced contrast; broad grass patches do not vary the shoulder width. The blend applies only to Pine/Storm road shoulders. Authored terrain paint retains its original edge treatment, and sand colour, geometry, flat ground, worn muted-red kerbs, HUD and camera remain unchanged.

Changed files: `game/track/surface_detail.gdshaderinc` adds the shoulder-only blend; `game/track/creator_road.gdshaderinc` selects it for hybrid-grass shoulders; `game/diagnostics/surface_material_probe.gd` adapts the historical shader interface; `game/track/native_track_visual.gd` advances only the cache version. This report, status/plan and `docs/evidence/road-border-blend-2026-10-03` record the follow-up. No new textures, meshes or shader passes; one existing baked-factor sample supplies the smoother half of the blend. Device cost is unmeasured.

Actual commands used the same pinned `scripts/dev.ps1` entry point documented above:

| Action / arguments | Actual outcome for kit 109 |
| --- | --- |
| `TestSurfaceProfile -TracksPath 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks'` | 929 checks, zero failures, exit 0; includes graphical shader/probe variants for Ajorata and Storm. |
| `CaptureStyle -StyleDocument 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks/track_acf29166cceaaa42.json'` | Exit 0; native cells unchanged, valid road normals, gameplay/12 route views/model views saved. Gameplay and corner captures inspected. |
| `Doctor` | Exit 0; pinned engine/templates found, DN2103 attached. |
| `git diff --check -- <changed paths>` | Exit 0. |

[Balanced gameplay](evidence/road-border-blend-2026-10-03/gameplay-balanced.png), [balanced corner](evidence/road-border-blend-2026-10-03/corner-balanced.png). Compare the [original edge](evidence/road-border-restoration-2026-10-03/corner-after.png) and [smoothed edge](evidence/road-border-restoration-2026-10-03/corner-before.png) at the same fixture pose. Existing diagnostic countdown/paused overlays remain. Actual invocation logs are saved with the new captures.

No Android export/install, physical-device driving, full `Validate`, new physics regression or GPU/thermal benchmark was performed. A phone was attached during Doctor. Owner acceptance of this intermediate edge treatment and phone readability in motion remain. Only this follow-up's changes are included in the checkpoint.
