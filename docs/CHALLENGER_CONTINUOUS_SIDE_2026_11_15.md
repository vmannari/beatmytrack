# Challenger sides follow one continuous shoulder

The owner marks the shoulder from the rear quarter through the door to the nose, asks for simpler side surfaces, and then supplies a clean rendered Challenger reference. The painted side now uses one longitudinal surface chart on both sides. The old independent folds and return shading no longer determine the visible shoulder.

Evidence: [challenger-continuous-side-2026-11-15](evidence/challenger-continuous-side-2026-11-15/). Final prepared views are retained under `final/`; prototype views are not the final acceptance.

## Geometry change

`scripts/challenger_side_surface.py` defines one natural cubic shoulder-height curve and broad width controls measured from the immutable factory source. The lower panel is one crowned cubic section joining the sill to the shoulder. A small rounded transition leads into the upper wing. Positions and shading tangents use the same chart across the door and quarter-panel boundaries.

The converter applies the change offline after the existing factory reduction. Original Y/Z coordinates, upper-body attachments and bonnet fit remain. A height-based transition protects the bonnet edge without introducing a fold in the width mapping. The original roof, upper pillars, openings, front lower fascia, wheel locations and handling are retained. There is no new runtime vertex deformation or painted cover strip.

Source returns that collapse onto the outer sheet lose their redundant/inward triangles. Shading on retained transition returns is oriented to the actual new triangle. Side markers and the existing flush door/handle/fuel markings are fitted to the final skin. The native bonnet marking and full bonnet geometry stay unchanged.

| Assembly | Before | Final |
|---|---:|---:|
| Raw reduced stock | 49,584 | 48,572 |
| Raw full stock | 83,522 | 82,332 |
| Production reduced fixed | 42,130 | 41,118 |
| Production reduced editable | 42,128 | 41,116 |

Both raw allocations stay inside the existing 50k/85k limits. The existing two-triangle fixed/editable spoiler-recipe difference remains. This is a surface-quality change, not an FPS or device-performance claim.

The maximum X movement, including original inner returns projected onto the sheet, is about 103.8 mm. The earlier factory-restoration sub-millimetre side-distance guarantee is superseded by this newly requested side reshaping. It is not presented as an unchanged side mesh. The original overall bounds, complete bonnet arrays and protected upper-body vertices have independent retained controls.

## Independent native checks

The native triangle survey passes **28 checks / 0 failures** and rejects the task-start model **28/6**. It samples interpolated native normals through actual triangle intersections, rather than comparing the converter with itself.

Three tracks at the shoulder and 25 mm above/below it each have all 413 physical surface hits in both quality tiers. At 10 mm longitudinal spacing:

| Maximum native normal step | Before | Final |
|---|---:|---:|
| Full | 62.24 degrees | 4.97 degrees |
| Reduced | 61.30 degrees | 8.77 degrees |

Final 95th-percentile steps across the tracks are below 0.88 degrees. No visible-size triangle has inward shading. All 1,528/full and 1,082/reduced protected upper-body vertex positions remain. The complete bonnet position, normal and index arrays match exactly. Overall bounds remain within 1 micrometre of the baseline. Orthographic side coverage changes at one of 43,200 probes in each tier; the silhouette/wheel-opening check retains its original fixed tolerance.

The accepted native pipeline also passes allocation **17/0**, contours **172/0**, fitted-bonnet checks **316/0**, all fitted Challenger modules **1436/0**, physics/replay **3677/0**, wash **1655/0**, driving **72/0** and production parser **573/0**. Prepared opacity passes **30/0 per desktop renderer**. Actual App Garage selection and local race assertions pass **13/0 per renderer**.

Each renderer has 22 final reduced-model views and six full-model close views. Their model-path receipts show actual production base/Garage cache hits, `prepared=true` and `candidate=false`. See the final [reference-angle view](evidence/challenger-continuous-side-2026-11-15/final/views-final/gl_compatibility/simple/white-reference-side.png), [front quarter](evidence/challenger-continuous-side-2026-11-15/final/views-final/gl_compatibility/simple/white-front-quarter.png) and [side profile](evidence/challenger-continuous-side-2026-11-15/final/views-final/gl_compatibility/simple/white-right.png).

The Mobile full close-up and Mobile App processes finish successfully, but their broad source fences reject concurrent Garage statistics/page edits. Compiled dependency routes for those changed UI files are empty; the model inputs remain exact throughout those runs. The original broad rejection receipts and separate model-scope qualifications remain. This qualifies the car, not whole-UI stability. Cold native runs have substantial waits; there is no loading-time claim.

## Publication and consumer scope

The source-only checkpoint contains exactly three production sources: the new side helper, its integration into `challenger_exterior_geometry.py`, and the converter's updated description. The native baker, Challenger runtime builder, configurations and physics sources are not authored by this task. The patch applies/reverses byte-exactly in a private Git repository without staging the shared index.

Native publication verifies the task-start model/configuration controls and final converter inputs, writes a 48-file allowlist, and publishes its manifest last with rollback. Forty-seven file hashes change in the regenerated package; the numerical bonnet equality is checked separately from container bytes. Four unused legacy hood files remain untouched. Coarse recipes, 49 livery previews, bases, kits, Garage, header/art and the Challenger catalogue photograph are refreshed from source.

The first scoped prepared check catches a stale shared Compact header template, **349/2**. That template is rebuilt from its current source. A concurrent temporary car-iteration stage and its later removal invalidate an intermediate model-key generation, so the Challenger consumers are actually rebuilt against the current inputs. No native/prepared metadata is restamped to bypass a stale gate.

The final Challenger scope passes **84 resources / 349 checks / 0 failures**, plus its native picture provenance and the current 28-source workshop. Concurrent Forklift detail outputs change the broad input map; the compiled dependency router assigns those changed inputs to Forklift, with no Challenger route. The retained reconciliation verifies unchanged consumed Challenger inputs, its exact model key and a stable final source snapshot.

The broad preflight is **not** claimed clean: the later full check records **551 resources / 2267 checks / 109 findings**, concerning the concurrent Forklift consumers' source maps. Earlier transient five-car findings and intermediate rejected fences remain in their logs. This task leaves that separate work intact.

## Review history and limits

An initial private prototype retained stale tangent-array lengths after changing the vertex count; engine diagnostics reject that mesh construction. Clearing the unused paint tangent stream corrects the prototype. No such prototype is published.

The first shape preview opens the bonnet attachment. Protecting its original height boundary closes that gap while retaining the continuous shoulder. The geometry survey then catches transformed return normals facing inward; these are corrected on the actual new triangles without moving the protected geometry or weakening the checks. The final native bake, rather than the prototype override, supplies the published result.

The supplied later reference guides the clean panel flow and restrained taper. It does not constitute a photogrammetric or AAA-certification measurement. Final images are actual engine captures with no diagnostic shading override. Owner appearance acceptance and physical-device qualification remain separate.

Principal reproducible commands, using the pinned local Blender/Godot and private offline profiles:

```text
python docs/evidence/challenger-continuous-side-2026-11-15/run_preparation.py
python docs/evidence/challenger-continuous-side-2026-11-15/run_check.py native-final res://tests/bake_challenger_hellcat.gd --headless --audio-driver Dummy -- --source=res://../build/challenger-continuous-side-2026-11-15/converted/ --dest=res://../build/challenger-continuous-side-2026-11-15/native/
build/tools/blender-4.5.15-windows-x64/blender.exe --background --factory-startup --disable-autoexec --python-exit-code 1 --python docs/evidence/challenger-continuous-side-2026-11-15/check_side.py -- native-quality-final
python docs/evidence/challenger-continuous-side-2026-11-15/publish.py
python docs/evidence/challenger-continuous-side-2026-11-15/guarded_assets.py
python docs/evidence/challenger-continuous-side-2026-11-15/finalise_assets.py
python docs/evidence/challenger-continuous-side-2026-11-15/gpu_checks.py
```

The wrappers retain actual commands, exit codes, logs, source pins and private-profile locations. The final picture refresh is bound to its then-current showroom sources; later concurrent showroom edits can invalidate that provenance independently of the unchanged model. `final-state.json` retains 108 artifacts and records the exact live native publication, three-source checkpoint, four legacy controls, 58 current texture imports and accepted 1-picture/173-source and 28-source workshop checks at retention. Standard build retention completes, reducing 32.36 to 32.17 GiB; recent/protected/locked output remains above the standard target. Its receipt is retained; no task pin is created.

No device query/test, export, backend operation, deployment, owner-save modification, owner-process restart or main-index staging is performed. Reload an already-running game to load the new resources.
