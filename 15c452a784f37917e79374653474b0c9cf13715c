# Kart driver refinement and working steering — 2026-11-12

KDP01–KDP04 implement the owner's request to review the kart driver's size, posture and helmet, refine the finish toward the project's AAA ambition, and rotate the steering wheel while turning. These are production model/presentation changes. AAA appearance acceptance remains an owner/device judgment.

| Requirement | Result |
| --- | --- |
| KDP01 — believable size and posture | Retain the established 0.42 authoring scale, supported 44-degree torso and upright forward-facing head. The approximately 250 mm helmet width stays within 2% of the preceding head. Rebuild the continuous torso/legs separately from the sleeves; curved sleeves use a lower, less splayed elbow pole and fitted cuffs. Original boot soles and pedal contact remain. |
| KDP02 — helmet and garment finish | Replace the 401-triangle printed head/face/helmet with the original native shell, real opaque visor, aperture returns, lining, vents and visor hardware. No photographic helmet imagery remains. Matte slate cloth, charcoal cuffs/gloves, controlled shoulder colour and a quieter fitted centre seam retain the restrained art direction. |
| KDP03 — steering and hands | Rotate the wheel about its inclined local shaft, up to 36 degrees each way, using the actual presented steering state. Six offline poses interpolate sleeves and gloves; the hands remain within 1.5 mm of their corresponding rigidly rotated grip positions at all tested intermediate inputs. Move the wheel and neutral hand reach 45 mm toward the driver for fairing clearance. No canonical handling/input/replay change. |
| KDP04 — integrated models and evidence | Preserve the wheel transform through batching and every prepared scene. Live wheel/driver shadows replace their former frozen contribution to the stock body shadow. Include morph storage in the existing conservative cache byte accounting. Rebuild prepared models and native menu photographs with source and revision checks. |

The final driver contains **12,048 triangles, six native material surfaces and six steering poses**, compared with 8,717 triangles/seven materials before this task. The stronger helmet and moving sleeves increase rendering work; no device FPS or performance improvement is claimed. The native compressed resource is approximately 0.89 MB. Unused dense reconstruction vertices are compacted before the native body is published.

Native views: [body](evidence/kart-driver-polish-2026-11-12/after-body.png), [side](evidence/kart-driver-polish-2026-11-12/after-side-right.png), [left steering](evidence/kart-driver-polish-2026-11-12/steering-direct-cockpit--1.0.png), [right steering](evidence/kart-driver-polish-2026-11-12/steering-direct-cockpit-1.0.png). These are actual engine captures of the production geometry. Earlier drafts remain described by their command logs; draft screenshots sharing a filename are superseded by the final captures.

## Verification and retained findings

The final direct steering/finish matrix passes **130/0 in Compatibility and 130/0 in desktop Vulkan Mobile**. It checks finite geometry/normals, native materials, outward helmet crown, both-hand interpolation, per-instance pose isolation, original boot soles, static torso/leg vertices, front-wheel behavior, exact centering and live articulated shadows. The independent bidirectional triangle-edge sweep passes **270/0**, covering every hood and side-pod style in both quality tiers at five steering positions. Actual back-pad/shell checks pass **286/0**; pedal/pan/hand checks pass **27/0**, retaining all nine pedal samples per foot/tier with approximately 1.017 mm maximum sole clearance. The direct retained driver suite passes **59/0**, and driving passes **72/0**.

The unchanged washing fixture initially reports **54/1** because it copies the first production material binding onto a synthetic one-surface patch. The new helmet makes that first binding a different surface index. Its fixture now explicitly binds surface zero of its own one-surface test mesh; the underside/exterior assertions and all wash thresholds remain. Corrected result: **54/0**. The original fixture is retained under `before/`.

Early drafts expose an inward-facing helmet crown, broad sleeve influence reaching the thighs, and stretched webbing in the previously merged torso/sleeve mesh. Numerical grip checks alone did not detect those appearance defects. Correcting the crown winding, rebuilding torso/legs without the sleeves, and authoring continuous curved sleeves removes them. A larger elbow splay fails the original upper-body width assertion; the lower elbow pole passes that unchanged gate. The initial wheel location fails 28/270 turning-clearance checks; the 45 mm reach correction passes all 270 without moving or reducing any fairing. A native-bake cleanup initially has an indentation error; it is corrected and rebaked before final verification. Process-stop races and the engine's existing Windows certificate-store diagnostic are retained in logs.

The older test's exact triangle/material counts and retained photographic-helmet assertions are updated to the expressly requested new native model. They are superseded by explicit native material, finite/outward geometry, scale, physical fit and motion checks. Physical support, material-independent paint isolation, floor/height, upper-body width, attribution and articulation assertions remain.

## Sources and reproduction

`scripts/prepare_kart_driver_bindings.py` reuses the established pose generator and supplied tomkart archive to reconstruct the continuous body without fused sleeves. `game/tests/bake_kart_driver_polish.gd` simplifies the body offline, retains the original soles/seam, authors the curved sleeves/native helmet and six equal-topology poses, and saves the immutable native mesh. `kart_steering.gd`, `car_visual.gd`, `kart_model.gd`, batching, racing shadow preparation and conservative resource accounting integrate it. The source driver remains attributed to tomkart under CC BY 4.0 in Settings → Licences; original Beat my track helmet and sleeve geometry are recorded separately in the notices.

```powershell
python scripts/prepare_kart_driver_bindings.py
python scripts/run_kart_driver_polish.py final-native-bake-v2 res://tests/bake_kart_driver_polish.gd --headless
python scripts/run_kart_driver_polish.py final-steering-gl res://tests/test_kart_driver_polish.gd --rendering-method gl_compatibility
python scripts/run_kart_driver_polish.py steering-mobile res://tests/test_kart_driver_polish.gd --rendering-method mobile
python scripts/run_kart_driver_polish.py final-clearance res://tests/test_kart_steering_clearance.gd --headless
python scripts/run_kart_driver_polish.py continuous-body-cockpit res://tests/test_kart_driver_cockpit.gd --headless -- --shipping
python scripts/run_kart_driver_polish.py final-contact-proof res://tests/test_kart_driver_contact.gd --headless -- --shipping
python scripts/rebuild_kart_driver_polish.py
```

The runner pins `4.7.2.stable.official.ed1daf0bf`, uses the crash-dialog wrapper, Dummy audio and a private offline Windows profile. It does not read or edit owner saves. The evidence directory retains actual commands, durations, logs, exit/error receipts, numerical measurements and task-start sources. The source-only checkpoint and final integration outcomes are recorded alongside them.

No device query/test, APK export/install, backend request, deployment, owner-process restart or main-index write is performed. Relaunch/reload is required to see the revised native resources. Owner appearance and real-device input, thermal and frame-time acceptance remain.

## Final integration receipts

Both actual App runs pass **25/0**, including steering changes through `Game._present_frame`, exact centering, the current canonical kart tune and matching Garage/direct geometry at **33,656 visible triangles**. Actual prepared hits pass the new steering suite **131/0 each desktop renderer** and the retained driver suite **76/0 each**. Every kart module/ghost comparison passes **1,160/0**. Production parsing passes **555 scripts / zero failures**; washing passes **1,655/0** in addition to the corrected **54/0** surface fixture.

The final prepared library passes **551 resources / 2,267 checks / zero failures**. The picture audit passes **six exact native images / 158 current source hashes**. The refresh initially rejects 13 concurrently rewritten Challenger native inputs. Their authored revision happens to stay unchanged, so the repair also checks the changed native-input paths and rebuilds the Super Rally consumers explicitly, rather than relying solely on the revision key. The [repair receipt](evidence/kart-driver-polish-2026-11-12/repair-source-receipt.json) records **20,995 stable inputs** and no drift. Unchanged car revisions are reused without restamping their geometry. All 49 kart livery photographs and the kart catalogue/news/header/Garage images are refreshed. Four unrelated catalogue rerenders are retained as evidence and their original PNGs restored; **21 unrelated PNGs remain byte exact**. Three changed Super Rally pictures belong to the concurrent Challenger work and are preserved.

The live editor import exits zero but records three extension hot-copy failures against existing `~*.dll` paths. That attempt is retained as a failed import receipt; it is not called a clean import. Production parsing, resource inspection and both actual runtime renderer tests load successfully without those extension errors. No owner process or loaded DLL is stopped or replaced. Native first-draw hitches remain in the App logs; no smooth-frame-time claim is made.

The [25-file source-only checkpoint](evidence/kart-driver-polish-2026-11-12/source-only.patch) passes strict reverse checking in the live workspace and byte-exact forward/reverse application in an owned miniature repository. The [receipt](evidence/kart-driver-polish-2026-11-12/source-checkpoint-receipt.json) verifies the untouched main index, all eight task-start car configurations and the unchanged seat/driver integration source. It records a harmless final blank-line style observation rather than claiming a clean whitespace check. Native resources, generated scenes, build metadata and concurrent work are excluded from this source patch; their final inputs and output hashes are retained separately.
