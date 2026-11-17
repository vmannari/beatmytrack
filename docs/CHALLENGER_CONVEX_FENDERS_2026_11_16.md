# Challenger continuous front fenders ? 16 November 2026

The marked upper fender is rebuilt as one convex crown, with a continuous shoulder and refitted bonnet seams. The accepted rear bodywork supplies the shoulder treatment and visual reference.

[Final fender](evidence/challenger-convex-fenders-2026-11-16/final/mobile/simple/white-fender-close.png) ? [Previous fender](evidence/challenger-convex-fenders-2026-11-16/before/white-fender-close.png) ? [Front corner](evidence/challenger-convex-fenders-2026-11-16/final/mobile/simple/white-owner-corner.png) ? [Full detail](evidence/challenger-convex-fenders-2026-11-16/final-full/mobile/full/white-fender-close.png) ? [Rear control](evidence/challenger-convex-fenders-2026-11-16/final/mobile/simple/white-rear-corner.png) ? [Reflection sweep](evidence/challenger-convex-fenders-2026-11-16/highlights/mobile/simple/white-sweep-right-1.png)

## Plan and source repair

CFX01: distinguish the physical dent from its shading, then replace the overlapping upper skins with one convex patch. The previous crown has measurable inward curvature. Separate source charts, underlapping seam banks and long triangles also produce inconsistent highlights. Normal-only and width-deformation prototypes were rejected.

The new offline height field is a smooth minimum of supporting hull planes fitted to the existing fender and outer bonnet. Its concave height graph describes a convex exterior. Three measured anchors retain the leading, outer and cowl reference heights. Both detail levels share the field. A constrained lattice follows the bonnet outline and shoulder; local diagonal selection keeps its sampled geometry convex.

CFX02: join that crown to a coherent shoulder. Two local rows stop long triangles spanning the complete roll. A measured cross-section uses the accepted rear's 9 mm fillet treatment and smooth longitudinal controls. Inner wheel-well returns remain separate surfaces. Normals follow the crown and shoulder profiles, with cofactor transport at retained transitions. Twelve upright bonnet-return faces per tier have a separate outward normal domain. The existing contour-pair channels survive; bonnet ribbon positions retain their original plan coordinates and seat 1.8 mm above the actual hood triangles.

CFX03: retain the centre intake, extractors, roof, glazing, lamps, wheel contacts and accepted rear. Buried bonnet skirts pay for the local topology. The material roles, paint and shaders stay unchanged. The result occupies the existing 22 native material meshes per tier, with no new runtime mesh or smoothing operation.

CFX04: regenerate the existing attachment grid from actual final hood triangles, then use model revision 16 to refresh native meshes and fitted parts. The normal Blender-to-Godot export and native bake produce both tiers. Actual prepared consumers, livery previews and car pictures are rebuilt.

## Measured result

| Measure | Reduced | Full |
|---|---:|---:|
| Fixed-footprint geometric chord samples | 2,060 | 2,069 |
| Maximum previous inward chord error | 3.966 mm | 6.173 mm |
| Maximum final inward chord error | 0.0067 mm | 0.0056 mm |
| Shared shoulder normal stations | 64 | 56 |
| Maximum packed normal gap | 0.0105? | 0.0112? |
| Supported bonnet perimeter stations | 384/384 | 384/384 |
| Native vertex count | 43,276 ? 43,458 | 50,042 ? 50,188 |

The geometric survey covers the continuous crown between the bonnet gap and shoulder, excluding the deliberate fascia lip and panel boundaries. It retains the 0.20 mm convexity tolerance and requires more than 90% dent reduction. The preceding model fails four controls. The final native residual is below 0.007 mm.

The repair's coordinate map leaves the protected centre exactly unchanged. Changing the outer hood's bounding box changes the importer's position quantization; the largest decoded centre difference is 0.0232 mm. The test measures the original and final 16-bit cells, retains a 2 ?m excess-error gate, and separately asserts zero source-map movement. Both pass. Godot documents its position compression in [Mesh array compression](https://docs.godotengine.org/en/stable/classes/class_mesh.html#class-mesh-constant-array-flag-compress-attributes).

The 530 mm inlet width, 29 mm opening and approximately 39 mm tunnel depth remain. Both extractors remain recessed and physically open. Roof and rear native positions match exactly, as do the sampled lower sides. 36 complete decoded native mesh-array packets compare equal. Eight car configurations, canonical handling/simulation, three preceding authored modules and four unused native resources remain byte-exact: 17 protected files in total.

## Triangle cost

| Model | Before | Final | Change |
|---|---:|---:|---:|
| Assembled reduced source | 49,876 | 49,978 | +102 / +0.20% |
| Assembled full source | 80,760 | 80,672 | ?88 / ?0.11% |
| Production fixed/editable | 45,116 | 45,218 | +102 / +0.23% |

The original 50k/85k allocation remains unchanged. Source repair removes 340 buried hood-skirt triangles per tier. The native baker makes four existing diagonal repairs in the reduced tier, with zero packed-stage repairs and zero vertex fairing.

## Actual validation

| Check | Actual outcome |
|---|---|
| Native shape / normals / preservation | 170 checks, 0 failures |
| Independent convexity / perimeter | 8 checks, 0 failures |
| Allocation / contour contracts | 17/0 and 172/0 |
| Fitted hood / expanded attachment survey | 316/0 and 144/0; maximum 0.857 mm under 2 mm |
| All kits / physics / wash / driving | 1436/0, 3677/0, 1655/0, 72/0 |
| Production parser | 583 scripts, 0 failures |
| Prepared Challenger | 84 resources, 349 checks, 0 failures |
| Complete prepared inventory | 551 resources, 2267 checks, 0 failures |
| Compatibility / desktop Mobile opacity | 30/0 each |
| Actual Garage/race App | 13/0 each desktop renderer |

Each desktop renderer has 28 reduced-tier views, 14 full-tier views and eight reflection-sweep views. Prepared-view receipts require real cache restoration. The final vehicle/preview fence covers 26,807 stable inputs. Sixty-four image imports are verified. Six actual selection portraits passed their revision check against 25,924 stable producer inputs at render time; a later external identity update invalidates the current shared portrait revision. The live vehicle native files and its prepared model key remain current. No phone or FPS result is claimed.

## Commands, scope and retained controls

Actual root commands were `python docs/evidence/challenger-convex-fenders-2026-11-16/run_preparation.py`, `review_native.py`, `deliver.py`, `resume_delivery.py`, `final_tail.py`, `gpu_checks.py`, `final_images.py`, `checkpoint.py`, `finalize.py`, `run_retention.py` and `prune_working.py`, plus `python scripts/check_garage_selection_pictures.py`. Individual engine commands, inputs and outcomes are retained in the command receipts beside this report. Resumption scripts continue after retained failures; completed checks are not silently treated as planned passes.

The three authored sources are [the offline fender module](../scripts/challenger_convex_fenders.py), [the source converter](../scripts/prepare_challenger.py), and the revision key in [SuperRallyModel](../game/vehicle/super_rally_model.gd). The original downloaded blend is absent; conversion uses the retained measured `source-panels.npz` and component labels. The active native meshes and their actual dependent caches/images are regenerated.

The source-only patch applies and reverses byte-exactly. Private commit `8f4367aa0c519c4c59f6bec543f68ba05e66ef02` is retained in [a verified Git bundle](evidence/challenger-convex-fenders-2026-11-16/source-checkpoint.bundle), with [the patch](evidence/challenger-convex-fenders-2026-11-16/source-only.patch). No task staging or main-index edit was performed; concurrent work and its index state are preserved.

Retained rejections include the initial shoulder prototypes, a provisional source allocation mismatch, twelve inward bonnet-return normals, a fixture that counted only duplicated normal stations, and an unadjusted centre comparison that ignored import quantization. The source and native invariants now distinguish welded continuity and exact source positions from packed precision. The failed contour projection and 3.3 mm attachment mismatch led to actual-triangle seating; their original width, support and 2 mm fitting limits remain unchanged.

Concurrent camera, generated-version and Editor edits triggered input-fence rejections. Those receipts remain, and the relevant checks were repeated without relaxing the source pins. A later portrait revision mismatch led to a real header/portrait render and import. The final vehicle fence passes. The picture check passed immediately after its real rebuild, then failed again when external Editor work advanced the conservative header revision. Shared selection-portrait readiness remains unqualified; the current vehicle model key and native files still match the checked outputs. Global checks qualify their recorded source snapshots while unrelated Editor work continues.

Standard build retention completed at 26.83 GiB, leaving recent/protected/locked entries above the 20 GiB target. Its initial invocation yielded to an existing cleanup. Task-owned cleanup removed 831,024,662 bytes; no active pin was created. Final views, compressed native arrays, before/after metadata and the source bundle remain in the evidence directory.

Owner appearance review and physical-device acceptance remain. Physical-phone testing was not performed. No export, backend, deployment, owner-save or owner-process action was taken.
