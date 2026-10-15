# Compact front grille — 2026-10-14

Owner requirements CGR01–CGR04: improve the actual compact's grille toward the AAA quality target through believable construction, fitted geometry, retained local condition and bounded cost. V04–V06/G01/R01/Q01 apply.

The five flat strips over a solid fascia are replaced by a recessed fabricated assembly. Painted steel and dark fascia have the same rounded cooling aperture. A closed satin surround follows the actual nose bow; five capped, chamfered louvers have 46mm returns. Behind the air gaps are two mounting ribs, cooling headers, 24 folded radiator fins and an opaque rear closure. Four small bevelled screw heads sit on the surround's side rails, with recessed slots. Graphite, muted metal and satin edging retain the fictional four-lamp compact's restrained finish.

The surround stays inside ±281mm, clearing the inner headlight envelopes and fitting between bumper and hood. The assembly has more than130mm of real depth. Original tyres, wheel pivots, kit frames, saved paint/livery IDs, wash coordinates, camera controls, reflections and canonical behavior are retained. Three immutable meshes serve full/simple models. Only these three material roles receive `compact_grille_finish` metadata so the existing condition shader treats them as front/body surfaces. Other finish eligibility/deposition functions remain unchanged. Clean reset and prepared-car restoration retain original materials and condition bindings.

Runtime changes: `game/vehicle/compact_grille.gd` and UID; front fittings in `compact_detail.gd`, shared aperture in `compact_coachwork.gd`, scoped material eligibility in `vehicle_weathering.gd`, and kit-photo cache revision in `game/ui/compact_kit_thumbnail.gd`. Native changes: v3 `front_coachwork.res`, simple `compact/front_coachwork_simple.res`, `compact_shadow_0.res`, manifests/provenance. The other **49 full and49 simple coachwork resources and24 shadow resources remain hash-exact** against task-start files. Full coachwork remains50 resources /**713,196 bytes**. Every surface is original authored geometry; no external mesh, texture, service or reference-image pixels are added.

Offline photographs show the revised actual car: **43 kit cards per renderer**, retaining the16-image cache and1,260 prepared part meshes, plus **49 compact livery photos**. Other cars' livery photos are outside the scoped bake. Existing lossless/mipmapped imports remain. Bake tools add `--photos-only`, `--compact-front-only` and `--vehicle=compact` to avoid rewriting unrelated assets. New native capture/geometry scripts and task evidence complete the change.

Actual commands use pinned Godot **4.7.2.stable.official.ed1daf0bf** through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`. Graphical runs select `-Graphical -RenderingMethod gl_compatibility` or `-Graphical -RenderingMethod mobile -RenderingDriver vulkan`. Captures use a direct production showroom; existing app tests use isolated storage/API-disabled fixtures.

| Actual command / script | Actual outcome |
| --- | --- |
| `-Action Import` | Pass: native photos and script UIDs imported. |
| `bake_compact_coachwork.gd` | Pass:50 meshes /713,196bytes; only front coachwork changes. |
| `bake_racing_car_models.gd --compact-front-only` | Pass: compact body shadow/front refreshed; other cars/wheel shadows retained. |
| `bake_compact_kit_previews.gd --photos-only`, both renderers |43 +43 actual-model photos; prepared part meshes retained. |
| `bake_livery_previews.gd --vehicle=compact`, Compatibility |49 actual-model photos. |
| `test_compact_grille.gd` | **179 checks, zero failures**: actual rays through steel/fascia/slat gaps and into radiator closure, closed welded parts, winding/normals, clearances, source/bake parity, shared geometry, condition/reset and prepared-material restoration. |
| `test_expanded_compact_catalog.gd` | **1,543 checks, zero failures**: exact prepared part data, all13,000 combinations per sampling level, retained wash/roll behavior and actual maximum combination. |
| `test_racing_car_models.gd` | **75 checks, zero failures**, detailed/simple geometry, batching, independent wheels and five simple shadow casters. |
| `test_vehicle_weathering.gd` | **820 checks, zero failures**, existing condition behavior. |
| `test_incremental_compact_kits.gd`, both renderers | **346 +346 checks, zero failures**, independent selections retain car, pivots, paint and condition. |
| `test_garage_reflections.gd`, both renderers | **25 +25 checks, zero failures**, real floor/deck reflection pixels and retained lifecycle. |
| `capture_compact_grille.gd`, both renderers | Eight final native views each; seven matching original views each retained. |
| `test_script_parse.gd` | **742 scripts, zero failures** in the final shared workspace (earlier run735). |
| Asset receipt / scoped whitespace / reverse-apply checkpoint | Pass; receipt and patch below. |

The grille has **1,454 triangles**. Stock compact is **105,374 detailed /40,950 simple** visible triangles (previous104,558 /39,594). Catalog maxima are **169,730 detailed /65,934 simple**, below170,000. Detailed/simple visible submissions are52; simple stock shadows remain five casters /2,172triangles. These are engine geometry/work counts, not phone FPS measurements.

Inspected native evidence: [original close-up](evidence/compact-grille-2026-10-14/before/gl_compatibility/grille-detail.png), [revised close-up](evidence/compact-grille-2026-10-14/after/gl_compatibility/grille-detail.png), [Mobile close-up](evidence/compact-grille-2026-10-14/after/mobile/grille-detail.png), [opposite angle](evidence/compact-grille-2026-10-14/after/gl_compatibility/grille-left.png), [whole-car angle](evidence/compact-grille-2026-10-14/after/gl_compatibility/front-quarter.png), [fitted car](evidence/compact-grille-2026-10-14/after/mobile/fitted-front.png), [local condition](evidence/compact-grille-2026-10-14/after/gl_compatibility/grille-dirty.png). Inspection poses do not change shipping camera controls. [Asset receipt/catalog bounds](evidence/compact-grille-2026-10-14/asset-receipt.json) and [task-only binary/text checkpoint](evidence/compact-grille-2026-10-14/scoped-change.patch) preserve unrelated work.

Initial sandbox Windows-log access failed; normal-access rerun succeeded. Development checks caught mixed fascia UV format and a conditional typed-array assignment, both corrected before the successful bake. First visual inspection caught incomplete cooling-mesh assembly from the append helper; explicit original faces restore the radiator. Initial condition checks exposed the existing rear-trim-only eligibility rule; grille-only metadata fixes it. An initial full simple bake reserialized unrelated shadows; exact task-start files were restored, and final narrow bake/receipt verifies scope. No failing invariant was weakened.

No physical-phone test, Android export/install, backend action, deployment, full Validate or physics merge regression was performed. Owner style/close-up review and physical-phone appearance/frame-pacing acceptance remain. AAA is the requested target, not an automated certification. Restart/rebuild the client to load the new native resources/photos.
