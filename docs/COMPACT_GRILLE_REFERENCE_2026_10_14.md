# Reference-led compact front — 2026-10-14

Requirements CGR05–CGR08/V04–V06/G01/R01/Q01: the owner rejects the initial grille and supplies the current car crop plus a classic-car photograph. The revised interpretation uses a broad recessed grille, fine metal ribs/lattice, rolled edging and one larger round lamp per side. This supersedes the previous four-lamp silhouette requirement for this revision. The vehicle remains an original fictional compact; no photograph pixels, watermark, real badge, purchased mesh or external texture enter the model.

The actual cooling opening grows from528mm to984mm. Six slim closed ribs sit ahead of48 cast vertical uprights with closed tapered returns. A narrow rolled metal surround follows the original nose bow; the previous visible screw heads are removed. Recessed mounting ribs, headers, folded radiator fins and an opaque rear closure remain. The complete grille is **1,538 triangles**, still below its existing1,600 limit.

The lamps use fitted rubber gaskets, smooth rolled bezels, shaped reflectors, internal bulb shields and convex fluted glass. Original lighting, specular reflection and filtered optical normals create their finish; the glass shader uses no texture reads or emission. The two lenses share one transparent draw. Full/simple optic geometry is independently cached in eight bounded mesh entries, while four immutable grille meshes are shared. Lamp hardware clears the original corner indicators by6mm and the grille by11mm. Functional night lenses use the same centers and retain one material batch, the original single spotlight/range/power/bridge masks and toggle behavior.

Saved car/part/livery IDs, original paint roles, tyres, wheel articulation, independent kit replacement, condition/wash mapping, retained camera controls and reflection targets remain. The previous grille-only condition metadata covers the fourth lattice material as well; condition reset and prepared-car material restoration are checked. Geometry stays cosmetic and does not write canonical state.

Changed runtime files: `game/vehicle/compact_grille.gd`, `compact_detail.gd`, `car_visual.gd`; new `compact_front_lamps.gd`/`compact_headlamp.gdshader` and UIDs; `game/ui/compact_kit_thumbnail.gd` photo-cache revision. Existing geometry/capture scripts are refined for the new actual aperture/optics and straight-on reference review. Native changes are one full front surface, its simple version and the compact body shadow, with manifests/provenance. **49 full +49 simple coachwork resources and24 other shadow files remain hash-exact** against task-start snapshots. Fifty full resources total **711,356 bytes**. The existing narrow bake options update86 kit photos and49 compact livery photos; part meshes/counts,16-photo cache, other car photos and saved pigments remain.

Actual commands use pinned Godot **4.7.2.stable.official.ed1daf0bf**, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Graphical runs explicitly select Compatibility or Mobile/Vulkan. Tests use direct model scenes or existing isolated storage, and introduce no player file/API writes.

| Actual command/script | Actual outcome |
| --- | --- |
| `bake_compact_coachwork.gd` |50 original resources /711,356 bytes; only front coachwork changed. |
| `bake_racing_car_models.gd --compact-front-only` | Final compact front/body shadow; all other native files retained. |
| `bake_compact_kit_previews.gd --photos-only`, both renderers |43 +43 final actual-model photos; prepared parts retained. |
| `bake_livery_previews.gd --vehicle=compact` |49 final native photographs. |
| `test_compact_grille.gd` | **272 checks, zero failures**: actual aperture/gap/closure rays, closed ribs/lattice/bezels, normal winding, optical/indicator fit, source/bake equality, condition/reset/prepared restoration and actual batched night-lens centers. |
| `test_expanded_compact_catalog.gd` | **1,543 checks, zero failures**: exact1,260 part recipes, all13,000 combinations per sampling level, actual maximum assembly, retained wash coordinates/roll clearance. |
| `test_racing_car_models.gd`, both renderers | **85 +85 checks, zero failures**: retained detailed/simple geometry, articulation, five shadow casters and original batching pixel tolerance. Compatibility differs in two channels by at most1; Mobile in three by at most2. |
| `-Action TestHeadlights` | **81 checks, zero failures**, original light/bridge/toggle behavior. |
| `test_incremental_compact_kits.gd`, both renderers | **346 +346 checks, zero failures**, actual car/pivots/paint/condition retained through selections. |
| `capture_compact_grille.gd`, both renderers | Eleven final native views each; ten matching pre-revision views retained. |
| `test_garage_reflections.gd`, both renderers | **25 +25 checks, zero failures**, real floor/deck reflections and retained lifecycle. |
| `test_script_parse.gd` | **758 scripts, zero failures** in the final shared workspace. |
| Final `-Action Import` | Pass, exit0, after the independent records dependency update. |

Initial import/reflection/parse attempts stopped on unrelated in-progress record-library changes (`MAX_RECORDS`, then an old test's `import_file` call). Those dependencies were updated independently; final import/reflection/parse reruns pass. [Validation receipt](evidence/compact-grille-reference-2026-10-14/validation.json) records the actual final outcomes.

Stock car is **101,660 detailed /39,756 simple** visible triangles, compared with105,374 /40,950 before this revision. Complete kit maxima are **166,016 /64,740**, below170,000. Visible submissions are55; simple stock shadows remain five casters /2,296 triangles. This retains the approved triangle ceilings while adding fine grille and optical detail; work counts are not phone FPS measurements.

Inspected native views: [before](evidence/compact-grille-reference-2026-10-14/before/gl_compatibility/fascia-straight.png), [revised front](evidence/compact-grille-reference-2026-10-14/after/gl_compatibility/fascia-straight.png), [Mobile front](evidence/compact-grille-reference-2026-10-14/after/mobile/fascia-straight.png), [close-up](evidence/compact-grille-reference-2026-10-14/after/gl_compatibility/grille-detail.png), [whole car](evidence/compact-grille-reference-2026-10-14/after/mobile/front-quarter.png), [fitted kits](evidence/compact-grille-reference-2026-10-14/after/gl_compatibility/fitted-front.png), [local grime](evidence/compact-grille-reference-2026-10-14/after/mobile/grille-dirty.png), [night lenses](evidence/compact-grille-reference-2026-10-14/after/gl_compatibility/night-lamps.png). Inspection poses live only in the fixture. [Asset/cost receipt](evidence/compact-grille-reference-2026-10-14/asset-receipt.json) and [task-only checkpoint](evidence/compact-grille-reference-2026-10-14/scoped-change.patch) exclude unrelated source work.

The first optical review prompted brighter internal reflector finish and smooth fitted normals. Fine cast returns keep the original grille-only limit. An initial night fixture incorrectly counted nodes after the existing batching step; it now checks the actual two geometry centroids and preserved single batch. All original invariants/tolerances are retained; the owner reference changes the intended aperture/headlight layout. Unrelated records-source changes were not edited by this task.

No physical-phone test, Android export/install, backend change, deployment, full Validate or physics merge regression was performed. Owner/reference quality review and physical-phone appearance/frame-pacing acceptance remain; AAA is the requested quality target. Restart/rebuild the client to load the revised geometry and photographs.
