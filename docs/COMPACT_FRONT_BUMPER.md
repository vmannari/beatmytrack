# Compact front bumper follows the body - 2026-10-10

Requirements: CG10 (owner's overhead reference: front bumper must follow the body's shape), CG01-CG09/V06/R01/Q01. This changes the actual shared fictional Compact car in Garage and driving.

The previous front bumper used a straight central face and independently rounded rectangular corners. Its outline did not follow the bowed front skin. The new path samples that actual front face, both cubic corner profiles and the short side returns, then offsets outward by85mm. It uses matching8/24/40/24/8 stations to preserve the nose/corner/side transitions. Its rounded section is92mm deep rather than120mm, while the existing176mm height and vertical placement remain. The inside edge embeds approximately7mm into the steel, giving a flush fit. Front cap vertices now match all24 shell section samples exactly. The rear bumper remains unchanged.

The two amber bumper inserts move onto the new front curve, rotate with its local tangent and have embedded backs; their previous placements would float ahead of the revised bumper. Their widths/heights and amber finish are retained. Canonical car dimensions/collision, handling, race acceptance, wheel transforms, saved paint, Garage/driving cameras, other vehicles and earlier body/window/door/mirror repairs are untouched.

Changed files: `game/vehicle/compact_coachwork.gd` (body-derived front bumper, section/caps/mount parameter), `compact_detail.gd` (insert placement), `game/assets/vehicles/compact_coachwork_v3/rounded_front_bumper.res`, manifest and provenance; new `game/tests/test_compact_front_bumper.gd` and UID; previous `test_compact_front_join.gd` excludes the deliberately changed bumper from its old-v2 equality set; this documentation and scoped status/plan/license entries. The prior geometry assertions keep their original tolerances and37 unaffected mirror/rear/cabin/roof/glass arrays still compare exactly. [Task-only binary/text Git checkpoint](evidence/compact-front-bumper-2026-10-10/scoped-change.patch) preserves earlier and unrelated workspace work.

Only **one of50 native resources changes**; the other49 hashes remain exact, including the rear bumper. Final original v3 assets total **723722bytes**. Manifest pins actual SHA-256 hashes and sizes. No external mesh/texture, generated bitmap, user-reference pixels or runtime service is added; native geometry remains originally authored and fictional.

Actual engine commands use pinned Godot **4.7.2.stable.official.ed1daf0bf** through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with normal Windows engine log/certificate access. Actual-app fixtures disable API requests and use isolated records/library/cloud paths.

| Actual command | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd` | **50 meshes /723722bytes**, exit0 |
| `-Action TestScript -ScriptPath res://tests/test_compact_front_bumper.gd -Graphical` | **2992 checks, zero failures**: actual baked contour/body projection, symmetry/front bow, finite unit normals, bidirectional cap/shell joins, actual insert rotation/attachment and five native Garage views |
| `-Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical` | **75 checks, zero failures**: all50 source/bake arrays exact, paint/materials, finite UV geometry, studio/driving glass isolation, wheels and batching |
| `-Action TestVehicleBatch` | **35 checks, zero failures**: exact all-car source/batched geometry and bounds; Compact985parts ->48meshes/97472triangles |
| `-Action TestScript -ScriptPath res://tests/test_compact_front_join.gd -Graphical` | **115 checks, zero failures**: previous front seams/normals/tangents and37 unaffected old-v2 array comparisons |
| `-Action TestScript -ScriptPath res://tests/test_compact_side_profile.gd -Graphical` | **252 checks, zero failures**, actual matching glass rails/seals, door/pillar/frame and wheel-arch clearance retained |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **484 scripts, zero failures** in the current shared workspace |
| Python SHA-256 comparison to captured v3 manifest | Only `rounded_front_bumper.res` changed;49resources exact |
| `C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe devices -l` | OPD2403 OnePlus Pad2/f0ba474a attached; **no phone attached** |
| Scoped whitespace/reverse-apply checkpoint checks | Pass |

Measured actual outer-contour distance to the sampled shell is **0.084999718-0.085013755m** (85mm within0.014mm sampling error). The bumper front bows **83.079mm** from its centre to approximatelyx=0.65m, following the bowed nose. Actual front cap/shell vertices match in both directions within the retained0.2mm tolerance.

Native evidence inspected: [overhead front](evidence/compact-front-bumper-2026-10-10/front-overhead-1280.png), [left angle](evidence/compact-front-bumper-2026-10-10/front-left-1280.png), [right angle](evidence/compact-front-bumper-2026-10-10/front-right-1280.png), [low front](evidence/compact-front-bumper-2026-10-10/front-low-1280.png), [Garage](evidence/compact-front-bumper-2026-10-10/garage-1280.png). Close-up fixture camera targets do not alter shipping camera controls/projection.

Final Compact:97472triangles/48batched meshes/68748UVvertices. One desktop studio construction observation282.631ms; RTX3090 Compatibility SubViewport CPUmedian0.708ms/GPUmedian0.211ms during concurrent graphical checks. These are desktop observations, not phone/whole-app performance or AAA acceptance. No physical-device test, Android export/install, full Validate, physics regression, backend deployment or production action was performed. Remaining acceptance: owner bumper-fit review and tablet/phone presentation/performance. Restart/rebuild the client to load the changed native resource.
