# Challenger sides and nose simplified and faired (2026-11-14)

The painted shell contained duplicate vertices from triangle-by-triangle export,
plus separate local surface corrections along the wing, door and rear quarter.
Those corrections retained small changes in the reflected shoulder line. The
paint was already one material batch; reducing its duplicate storage and internal
triangles offers a larger loading benefit than merging material nodes.

CSS01 replaces the narrow patched shoulder band with one constrained chart per
side and a common longitudinally faired profile. CSS02 welds coincident shell
vertices and reduces the joined geometry while retaining the crease, apertures,
roof and upper pillars. CSS03 filters exterior tangents within their original
curvature domain and seats the flush outlines on the final reduced paint.
CSS04 refreshes the prepared game assets and pictures and verifies the native
result, cosmetic modules, physics and actual Garage/race path.

## Measured result

| Measurement | Before | After | Reduction |
|---|---:|---:|---:|
| Reduced-detail assembled car | 49,968 triangles | 45,150 triangles | 9.64% |
| Full-detail assembled car | 84,924 triangles | 77,204 triangles | 9.09% |
| Reduced-detail painted shell | 16,890 triangles | 12,072 triangles | 28.53% |
| Full-detail painted shell | 25,751 triangles | 18,031 triangles | 29.98% |
| Reduced-detail paint raw buffers | 1,722,780 bytes | 306,384 bytes | 82.22% |
| Full-detail paint raw buffers | 2,781,108 bytes | 449,146 bytes | 83.85% |
| Reduced-detail paint native file | 1,723,424 bytes | 307,028 bytes | 82.18% |
| Full-detail paint native file | 2,781,752 bytes | 449,792 bytes | 83.83% |

The paint remains one surface per quality tier; the conversion retains its 22
material/articulation batches. These measurements describe mesh streams and
native files, rather than process RAM or complete race-loading time. The smaller
indexed payload reduces the car data that must be read and uploaded. No device
loading-time, FPS, thermal or AAA-quality claim is made.

Independent native sections measure **24.75% less aggregate reflection-normal
jitter** along the sampled shoulder traces. Maximum sampled surface displacement
is 6.65 mm; the additional local vertex fairing is limited to 1 mm. Complete
shoulder coverage, exterior extrema within 10 micrometres, every original roof
and upper-pillar vertex, and exact bonnet positions/topology pass. The sharp
reference crease, original nose taper, rounded front corners and 14 cm lead
remain. All eight car configurations and the runtime Challenger model source
are byte-exact against task start; the measured handling tune remains 198 km/h.

Current native comparisons:

- [Original side](evidence/challenger-surface-simplification-2026-11-14/garage-before/gl_compatibility/white-side.png)
  and [simplified side](evidence/challenger-surface-simplification-2026-11-14/garage-final/gl_compatibility/white-side.png).
- [Original front quarter](evidence/challenger-surface-simplification-2026-11-14/garage-before/gl_compatibility/red-reference.png)
  and [simplified front quarter](evidence/challenger-surface-simplification-2026-11-14/garage-final/gl_compatibility/red-reference.png).
- [Current Vulkan front quarter](evidence/challenger-surface-simplification-2026-11-14/garage-final/mobile/white-opposite.png).

## Changes and publication

`scripts/challenger_shell_geometry.py` performs offline chart replacement,
feature-constrained reduction, curvature-aware normal filtering and outline
fitting. `scripts/prepare_challenger.py` constructs the common shoulder before
the existing shared nose transforms and reduces the joined shell afterward. It
records the resulting counts in each tier's conversion provenance.
`game/tests/bake_challenger_hellcat.gd` accepts an optional private destination.
The default bake destination and runtime construction API remain compatible.

The source-fenced Blender conversion completes both tiers using the retained
measured CC-BY source, with its original attribution and license unchanged.
Private native candidates are compared before publication. The accepted write
contains only the two paint resources, two contour resources and two provenance
manifests. **Forty other native mesh resources and the bonnet profile remain
byte-exact.** Their decoded geometry also passes 120 independent comparisons.
No handling, camera or other vehicle model source was authored by this pass.

## Verification

Pinned Godot 4.7.2 and Blender 4.5.15 run with private test profiles and an empty
backend URL. Assertions in the existing project fixtures are unchanged.

| Check | Actual result |
|---|---:|
| Native fairing, coverage and roof controls | 47 / 0 failures |
| Existing reference crease and optical carrier | 1,848 / 0 |
| Existing native nose-plan sections | 3,912 / 0 |
| Rounded corner retention | 20 / 0 |
| Measured bonnet and fit | 252 / 0 |
| Every fitted cosmetic option | 316 / 0 |
| Prepared base/module equivalence | 1,438 / 0 |
| Prepared physics/replay controls | 3,677 / 0 |
| Washing | 1,655 / 0 |
| Production script parsing | 562 / 0 |
| Prepared opacity, contacts and budgets, each desktop renderer | 30 / 0 |
| Actual App Garage/race, each desktop renderer | 13 / 0 |
| Native showroom review | Eight final views per renderer |
| Challenger livery pictures | 49 actual captures |
| Imported Challenger pictures | 53 source MD5s current; zero editor diagnostics |
| Final complete prepared-asset preflight | 551 resources / 2,267 checks / 0 failures |
| Final catalogue provenance | Six exact native images / 168 current source hashes |

The final Vulkan App fixture passes thirteen assertions and emits two ObjectDB
instance warnings and one resource-in-use diagnostic at shutdown. The preceding
Vulkan run exits without those diagnostics. Both command receipts are retained.

The first scoped prepared refresh passes 84 resources / 349 checks and its
447-input source fence. A later full-project check catches 551 source-receipt
findings after refreshing livery previews: the existing provenance tree treats
those pictures as shared inputs. Runtime keys and geometry checks still pass.
All dependent prepared scenes and catalogue bindings are therefore rebuilt
after the final livery outputs, without changing the dependency rules or
restamping old scenes. The final 21,973-input source fence is stable, all 551
resources pass their 2,267 checks, and all six catalogue bindings validate.
The other vehicles' model sources and native meshes were preserved; their
dependent prepared scenes were regenerated to carry current provenance.
Final handoff receipts are recorded alongside the report.

## Retained diagnostics and limits

Early private drafts that recomputed paint tangents from face normals, extended
the shoulder chart through the nose termination, or reduced the roof were
rejected after native comparison. The final algorithm preserves the dense
authored curvature field, fixes the roof vertices and leaves the nose termination
in its existing geometry domain. An early width diagnostic compared fairing to
the old unfiltered field; its unsuccessful targets are retained as diagnostics.
The final acceptance measures native coverage, bounded shape change, retained
features and reflection variation. Existing nose/crease/bonnet assertions retain
their original bounds.

One fitted-part run reports 316 passing assertions but is rejected by its source
fence because it overlapped the build-identity refresh. Its stable repeat passes.
The native comparison initially exposes the changed marker projection; restoring
the original marker-fitting domain corrects it and all 120 controls pass. A first
fixture also assumed every old native resource had a UID; existing resources
without one are now handled explicitly. Original commands and findings remain
available in the evidence folder.

Owner appearance acceptance and physical-device loading measurements remain.
No device query/test, APK/export, backend request, deployment, owner-save/process
change or main-index staging was performed. The shared index changed concurrently
and was preserved. Temporary output remains disposable under the owner retention
policy; concise receipts and the relevant native comparisons are retained.

Automatic approval review rejected the path-checked removal of redundant draft
PNG captures, reporting only "blocked by policy". Those captures remain in the
evidence folder as a documented cleanup exception.

The active build pin is removed and the prescribed retention cleanup is applied.
Its receipt reports 22.70 GiB remaining, with no eligible entries; recent,
protected or locked output keeps the total above the 20 GiB target. No disposable
profiles, caches or complete project copies were moved into permanent evidence.

## Reproduction and evidence

```powershell
python docs/evidence/challenger-surface-simplification-2026-11-14/run_preparation.py
python docs/evidence/challenger-surface-simplification-2026-11-14/refresh_all_prepared.py
python scripts/check_garage_previews.py
```

These commands use the accepted native assets already in the checkout. Private
conversion and publication are separate guarded stages. After retention removes
the disposable section data, run `export_shell.gd` through `run_check.py` with
`--before` and `--candidate` to reconstruct the two native section exports before
running `native_acceptance.py`.

The evidence folder contains the source and publication fences, actual command
receipts, mesh measurements, native sections, rejection diagnostics and a checked
source-only patch. The [28-file checkpoint](evidence/challenger-surface-simplification-2026-11-14/source-checkpoint.json)
applies and reverses byte-exactly, passes whitespace checks and leaves the shared
index unchanged during verification. Its AGENTS baseline preserves concurrent
entries. Generated native resources and pictures are recorded separately from
that source checkpoint.
