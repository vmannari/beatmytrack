# Five-car refinement and buffer optimisation — 12 November 2026

The reviewed improvements are implemented for Rally, Kart, Forklift, Volt and
Hover. Native model/picture authoring for Challenger is excluded. Concurrent
Challenger and kart-driver updates were preserved rather than restored to older
copies.

[Before/after pictures](evidence/car-model-refinement-2026-11-12/before-after.png),
[measurements and command receipts](evidence/car-model-refinement-2026-11-12/summary.json).

## Changes

| ID | Delivered change | Main sources |
|---|---|---|
| CMI01 | Split the kart's four invariant helmet surfaces from its two deforming suit/glove surfaces. Remove 495,720 bytes of redundant six-pose data; retain all helmet attributes, finishes, attachment and live shadow. Filter cloth normals while copying the original encoded rest/pose position blocks exactly. | `kart_driver.gd`, `racing_car_models.gd`, `tests/support/kart_driver_finish.gd`, native `driver.res` / `helmet_static.res` |
| CMI02 | Deeper Rally reflectors, dark optical rings and a clearer lens replace the flat grey lamp appearance. Analytical mirror normals and smoother tyre shoulders retain the body/tyre dimensions. Forklift arch normals become continuous around the existing profile, without adding production triangles. Kart cast-metal/exhaust finishes are better separated. | `compact_front_lamps.gd`, `compact_headlamp.gdshader`, `compact_coachwork.gd`, `compact_detail.gd`, `forklift_model.gd`, `kart_model.gd` |
| CMI03 | Volt's bonnet, door and handle contours become flush strips fitted to the actual rendered backing triangles. Their 0.8 mm offset avoids analytical curves sinking through the lower-density surface. Contours do not cast self-shadows. | `electric_reference_mesh.gd`, `electric_reference_body.gd`, `electric_reference_details.gd` |
| CMI04 | Hover's six-spoke fan guards and separated rolled rims reduce visual clutter; a restrained satin canopy frame adds definition. Compact the body shadow's unused position buffer and fix its producer so unused vertices do not return. | `hovercraft_sport_drive.gd`, `hovercraft_sport_hull.gd`, `tests/bake_hovercraft_art.gd`, native shadow resource |
| CMI05 | Pack final Rally/Forklift encoded vertex streams after batching and LOD generation. Keep master corners, attributes, bounds, LOD policy, articulation and mutable finishes. Integrate this into stock/module/Garage/header bakes. Refresh the five cars' native pictures, 245 livery previews, news photos and guarded prepared assets. | `tests/support/car_model_buffers.gd`, `tests/support/car_refinement_lods.gd`, scoped bake tools and generated resources |

The static helmet remains under `TomkartDriver`; steering changes the gloves and
sleeves while the helmet stays fixed. Body shadow baking excludes descendants
of a morphing mesh so the helmet retains its own live silhouette. The upstream
driver producer also uses the split operation, preserving subsequent authoring.

The packer performs no runtime simplification. Fresh mesh identities and cleared
embedded material identifiers prevent successive quality bakes from aliasing
different meshes when scenes are saved. Deep scene reads and raw mesh copies
retain the encoded data without decoding and re-encoding it.

## Measured production stock models

These use the same inventory function as the preceding review. Unique raw mesh
buffers include master vertices/attributes/indices, LOD indices, morph data and
shadow meshes. Shared meshes count once per car. This is not process RAM,
measured VRAM, package size or FPS.

| Car | Visible triangles | Before buffers | Current buffers | Net change |
|---|---:|---:|---:|---:|
| Rally | 40,396 | 1,840,810 B | 1,681,786 B | −159,024 B / −8.64% |
| Kart | 34,088 | 2,030,152 B | 1,608,108 B | −422,044 B / −20.79% |
| Forklift | 50,744 | 2,301,200 B | 2,103,984 B | −197,216 B / −8.57% |
| Volt | 38,746 | 1,196,612 B | 1,218,696 B | +22,084 B / +1.85% |
| Hover | 22,548 | 758,188 B | 592,620 B | −165,568 B / −21.84% |

Rally's optics add 640 triangles; Volt's denser fitted contours add 464. Forklift
keeps its existing production triangle count. Hover removes 96 visible guard
triangles. Existing car LOD thresholds remain. No blanket reduction was applied.

Kart's final count includes a concurrent cloth update from 33,656 to 34,088
triangles. The exact contribution established by this task is the 495,720-byte
helmet morph removal. Its initial pinned conversion passed 98 checks, including
byte-exact rest and all steering-pose positions; the concurrent newer suit was
then preserved and independently checked for fit, interpolation and cache use.
The final net row should not be treated as an isolated timing or cloth-quality
comparison.

The original Hover shadow retained 13,499 unused vertices / 161,988 bytes of
positions. Its initial compaction retained every used corner exactly. The final
proxy is regenerated for the revised guards, has 1,196 triangles, and contains
only referenced positions.

## Verification

Pinned engine: `4.7.2.stable.official.ed1daf0bf`. Native tests use desktop
Compatibility and Vulkan Mobile on the RTX 3090. Vulkan Mobile here is a desktop
renderer, not an Android device test. All runs use private profiles, dummy audio
and an empty backend URL/auth key.

| Check | Actual final outcome |
|---|---:|
| Complete stock/fitted/module/ghost matrices, both quality tiers | Rally 1,443; Kart 1,160; Forklift 1,726; Volt 1,936; Hover 1,292 — **7,557 checks / zero failures** |
| Scoped prepared resource preflight | **468 resources / 1,925 checks / zero failures** |
| Native Garage picture provenance | **Five images / 157 current source hashes** |
| Current direct / actual prepared integration | **42/0 and 128/0**, including actual prepared-base hits and no remaining profitable Rally/Forklift encoded duplicates |
| Actual Kart Garage/race | **25/0 per desktop renderer**, matching 34,088-triangle cars and live steering through `Game` |
| Native prepared steering | **98/0 per desktop renderer** |
| Current pedal/contact, cockpit/back support, moving steering clearance | **27/0, 286/0, 270/0** |
| Actual native washing, persistence, appearance and App input | **1,675/0** in Compatibility |
| Wash surface/underside fixture | **54/0** |
| Driving / personal ghosts | **72/0 and 38/0** |
| Production script compilation | **553 scripts / zero failures** |
| Current inventory | **54/0**, with all five production stock bases hit |

Twenty final native model views per renderer are retained under `final/`, along
with actual App pictures. The final scoped refresh has a 20,534-input source
receipt with zero changed inputs and stable geometry revisions. After the
serialization correction, the affected Rally/Forklift outputs were rebuilt and
the scoped strict gates repeated. The original main index and all eight car
configuration controls were exact at that qualification. During the later
13 November handoff audit, the index no longer matched task start; this task
did not stage or restore it. Historical passing receipts do not certify a
subsequently changing checkout.

Principal commands, with full arguments/logs in the receipts:

```powershell
python scripts/run_model_refinement.py split-driver res://tests/bake_model_refinement_driver.gd --headless
python scripts/refresh_model_refinement.py --art-only
python scripts/refresh_model_refinement.py
python scripts/refresh_model_refinement.py --vehicles=compact,forklift
python scripts/run_model_refinement.py modules-compact res://tests/test_modular_car_assets.gd --headless -- --vehicle=compact --all-kits
# The same complete module matrix ran for kart, forklift, electric and hovercraft.
python scripts/run_model_refinement.py live-prepared-qualified res://tests/test_model_refinement_live.gd --headless -- --prepared
python scripts/summarise_model_refinement.py
```

## Retained findings and source boundaries

The first source refresh detected concurrent Challenger source/mesh changes;
the second rejected a concurrent kart `driver.res` update. Both rejections and
their exact inputs are retained. The latest driver is still a two-surface
steering mesh, and its pedal/cockpit/moving-clearance checks pass. No concurrent
source or geometry was rolled back.

An initial shared-cache metadata helper attempted to refresh Challenger scene
signatures and stopped on the kit key layout. Completed base entries were
checked for unchanged geometry, material, transform and LOD signatures. That
helper was removed; subsequent pipelines explicitly exclude Challenger. No
Challenger model source, native exterior geometry, finish, tuning or PNG was
authored by this task. The before/after Challenger pixel gate remains unmet
because its source and meshes changed concurrently. Its failed comparison is
retained rather than represented as an unchanged image control.

The full six-car asset/picture gates remain available with their original
default scope. Explicit five-car filters qualify the requested work; they do
not certify the concurrently edited Challenger or a whole-checkout release.
Protected picture revisions are retained when excluded. A compare-and-swap
check prevents the photo baker from overwriting concurrent provenance/picture
updates.

The native wash fixture initially looked up its action before progressive
Garage entry finished. It now waits for the real interaction gate and uses the
page's bound Wash button; the original input/persistence/visibility assertions
remain, with an added action-presence check. Initial null-action/failure logs
and teardown diagnostics remain. The broader historical parser still encounters
an unchanged menu test with an obsolete `_start_race` override; the production
parser passes. Initial driver normal re-encoding, backing-node name lookup,
prepared-cache fixture gating, partial-steering weight fixture, launcher and
scene alias failures are retained with their corrections.

Low free disk space caused one draft image save to fail. Only disposable caches
from these review runs were cleared. Duplicate prior-review pin manifests were
consolidated into byte-verified base/delta recipes in
`car-model-review-2026-11-12/source-pins-bundle.json.gz`; original logical hashes
and reconstruction information remain. No owner files were deleted. One invalid
runner invocation started an isolated private App; only that owned process was
stopped. The known Windows certificate-store diagnostic is retained throughout.

## Handoff audit — 13 November 2026

The final read-only handoff audit found later edits to Kart, Forklift, Garage,
Rivalry and Challenger inputs since the qualified refresh. All eight vehicle
configuration controls still match task start. See
[`handoff-source-audit.json`](evidence/car-model-refinement-2026-11-12/handoff-source-audit.json).
The passing results above certify the recorded snapshot, not the current
changing checkout. A new stable-source five-car refresh and focused qualification
are required before release, followed by a fresh-launch visual review and
physical-device memory/frame-time/thermal testing. Challenger remains excluded
from this task's model authoring.

The source-only checkpoint contains 47 current source snapshots and a
reverse-checked patch for the 13 runtime files with independently captured
task-start bytes. Tool/test snapshots without independent baselines are labelled
as current snapshots; they do not establish a complete task-only diff.
The runtime patch also includes any later edits to those files and must not be
treated as an isolated task patch. Generated binaries and Challenger model
source are excluded. No root staging,
commit, merge, owner-process restart, owner-save edit, device query/test, APK,
backend request or deployment was performed. A fresh game launch and owner art
acceptance remain; physical-device memory, frame-time and thermal qualification
were not performed. No AAA finish or FPS improvement is claimed.
