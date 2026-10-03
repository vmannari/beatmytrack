# Original road-border direction — 2026-10-03

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
