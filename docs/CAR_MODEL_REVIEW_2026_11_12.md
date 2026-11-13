# Car model optimisation and refinement review — 12 November 2026

Further work is worthwhile. The best opportunities are removing redundant kart
morph data, compacting Hover's shadow vertices, and packing Rally/Forklift
buffers. Appearance work should focus on specific weak details and surface
joins while retaining the approved proportions. A uniform polygon reduction
would sacrifice detail without addressing the largest measured waste.

This task changes only review helpers and evidence. No production model,
material, prepared resource, simulation, setting or save was edited.

## Coverage and evidence

| ID | Work completed |
|---|---|
| CMR01 | All six current selectable models, including the distinct Challenger Super Rally. Stock/fitted, fixed/editable assemblies give 24 production construction cases. Six additional unbatched constructions locate authored components. |
| CMR02 | Count visible master triangles, surfaces, unique mesh buffer payloads, LOD-bearing surfaces, shadow-only geometry and morph data. Check actual prepared-base/module hits rather than assuming stored scenes are used. |
| CMR03 | Try the existing encoded-vertex packer in memory only. Check every ordered encoded triangle corner and LOD corner, native images, unchanged repeats and restoration controls on both desktop renderers. |
| CMR04 | Inspect front/rear/overhead diagnostic captures and the real `CarShowroom` studio in both renderers. Rank component-specific optimisation and appearance work. |

[Full inventories](evidence/car-model-review-2026-11-12/headless.json),
[summary and receipts](evidence/car-model-review-2026-11-12/summary.json),
[whole-car diagnostic contact sheet](evidence/car-model-review-2026-11-12/contact-sheet.png).
The review uses factory liveries and the approved production simple geometry.
The showroom captures use the actual studio and its glass/material setup;
the diagnostic lighting deliberately differs. These are direct component
views, not an actual App race, road biome or physical-device test. Some showroom
close views crop an extremity; the diagnostic views show complete silhouettes.

## Current measured costs

| Car | Visible master triangles | Visible surfaces | Unique mesh payload | Exact packing candidate saving |
|---|---:|---:|---:|---:|
| Rally | 39,756 | 51 | 1,840,810 B | 175,468 B / 9.53% |
| Kart | 33,656 | 44 | 2,030,152 B | 12,964 B / 0.64% |
| Forklift | 50,744 | 26 | 2,301,200 B | 197,132 B / 8.57% |
| Volt | 38,282 | 37 | 1,196,612 B | 3,160 B / 0.26% |
| Hover | 22,644 | 18 | 758,188 B | 25,236 B / 3.33% |
| Super Rally / Challenger | 45,389 | 44 | 1,575,158 B | 2,352 B / 0.15% |

Triangles count active visible master geometry before distance selection.
Payload includes raw vertex/attribute/index buffers, LOD indices, morph buffers
and shadow-only meshes, with each shared mesh counted once within each case.
It excludes materials, textures, engine bookkeeping, driver alignment and
reflection render targets. It is neither process RAM nor measured VRAM, APK
size or frame time. Savings are from an offline candidate, not delivered gains.
Shadow geometry is excluded from the visible triangle/surface columns.

All 24 production cases hit their prepared base in this review. Fitted Rally,
Kart, Forklift, Hover and Super Rally hit four modules each. Volt's fitted
path hit its base and constructed its selected changes through its own path;
its zero module hits are recorded without labelling them a cache failure.
Editable/fitted costs vary: the sampled Rally fit has 49,260 triangles/62
surfaces; Hover's has 29,188/43. One selected fit per vehicle does not establish
a worst-case catalogue budget.

## Recommended work, in order

1. **Split static helmet geometry from the kart's steering mesh.** The driver
   contains 908,760 bytes of six-pose morph data. Its four helmet surfaces have
   identical positions, normals and tangents in every pose, yet account for
   **495,720 bytes (484.1 KiB)** of that data. They can be investigated as static
   surfaces while sleeves/gloves keep their six poses and live shadows. This
   identifies redundant payload equal to 24.4% of this stock kart's total mesh
   payload. Keeping the existing six material surfaces need not increase the
   surface count; actual draw/binding costs still require implementation tests.
   The suit also has only 714 moving position vertices out of 2,468, but splitting
   that continuous cloth requires more care to avoid seams or extra draws.
   Preserve accepted anatomy, back support, soles, grips, reach and steering.
   [Per-surface evidence](evidence/car-model-review-2026-11-12/driver-components.json).
2. **Remove unreachable Hover shadow vertices during offline baking.** The
   stock body shadow proxy retains 13,499 vertices referenced by neither its
   master indices nor any LOD: **161,988 bytes (158.2 KiB)** of positions. This
   alone is 21.4% of the whole case's mesh payload. Rebuild the index remap and
   compact the source vertex blocks while retaining every used shadow corner,
   bounds and articulated fan/rudder frames. This is a measured removal
   opportunity, not yet a native-tested compaction implementation. Do not add
   it to the packing saving: the candidate sets can overlap.
3. **Apply encoded packing to final Rally and Forklift meshes offline.** The
   in-memory candidates save about **171.4 KiB** and **192.5 KiB** respectively.
   All ordered encoded attributes and LOD corners match; final tested images
   and restoration controls are byte-exact in both renderers. Run packing after
   fixed-part batching and before final bake publication. Keep the existing
   source/identity guards, metadata, material ownership and live handles.
   These candidates reduce storage/transfer payload, not triangles or draws.
4. **Design selective distance detail where it buys visible work.** Forklift's
   three largest visible prepared groups account for 33,676 triangles (66.4%).
   They include combined parts, so decompose them by original component before
   reducing samples; retain fork tips, mast/chain separation and body silhouette.
   Challenger's source body paint alone has 14,034 triangles, and the prepared
   largest group has 16,754. Preserve the recently improved optics, grille,
   spokes, hood and glazing joins. Ordinary packing offers this car little.
   All stock models already contain LODs; propose refinements to those levels,
   with native near/race comparisons, rather than claiming LOD is missing.

## Appearance review

These are art judgements from the retained native captures, not newly proved
geometry defects. Each proposed change needs its own before/after comparison.

| Car | Specific refinement worth trying | Preserve |
|---|---|---|
| Rally | Flat grey headlamp faces are a weak focal detail beside the newer cars. Give lenses/reflectors restrained depth and tonal separation; soften block-like mirror edges and review tyre shoulder shading. [Close view](evidence/car-model-review-2026-11-12/compact-showroom-mobile-front.png). | Boxy hatch identity, cream/blue finish, clean panel contours and current silhouette. |
| Kart | Smooth the visible sleeve/torso transitions and reduce the contrast between faceted cloth and the smoother helmet. Review engine/exhaust material separation before adding fine geometry. [Close view](evidence/car-model-review-2026-11-12/kart-showroom-mobile-front.png). | The recently accepted pose, continuous suit, pedal/seat fit and animated hands. |
| Forklift | Several wheel-arch/tyre edges and broad frame faces remain visibly faceted at close range. Use targeted normals/bevel work on exposed edges; retain industrial thickness and readable chains. [Close view](evidence/car-model-review-2026-11-12/forklift-showroom-mobile-front.png). | Fork profile, mast alignment, guard structure and established kit shapes. |
| Volt | Door/handle/hood outlines become dotted at some distances; lamp-strip/bumper joins deserve a continuity pass. Inspect clearance, sampling, normals and pixel coverage before assigning a cause. The studio views retain some fine edge breakup even without the diagnostic directional shadows. [Close view](evidence/car-model-review-2026-11-12/electric-showroom-mobile-front.png). | Fastback canopy curvature, flush sides, existing roof/glass identity and proportions. |
| Hover | Fan cage/duct/rudder intersections are visually busy; improve edge continuity and separation. The black canopy is visually broad and plain: a restrained rim/roughness treatment may add depth. [Rear view](evidence/car-model-review-2026-11-12/hovercraft-showroom-mobile-rear.png). | Skirt layering, rounded boat silhouette, opaque canopy and live fans/rudders. |
| Challenger | Strong highlights still expose abrupt bonnet/fender and pillar transitions; assess local normal continuity and paint response. Rear-panel perimeter and tyre shoulders merit close inspection. Keep the improved manufactured details; avoid another general density increase. [Front](evidence/car-model-review-2026-11-12/super_rally-showroom-mobile-front.png), [rear](evidence/car-model-review-2026-11-12/super_rally-showroom-mobile-rear.png). | Supplied exterior proportions, flush contours, restrained bonnet, opaque windows and no interior. |

## Commands and outcomes

Pinned Godot: `4.7.2.stable.official.ed1daf0bf`. Native tests used the desktop
RTX 3090 in Compatibility and Vulkan Mobile. Vulkan Mobile here is a desktop
renderer test, not an Android device test. Each run has a private profile,
dummy audio and an empty backend URL/auth key.

```powershell
python docs/evidence/car-model-review-2026-11-12/run.py headless
python docs/evidence/car-model-review-2026-11-12/run.py gl_compatibility
python docs/evidence/car-model-review-2026-11-12/run.py mobile
python docs/evidence/car-model-review-2026-11-12/run.py headless --components
python docs/evidence/car-model-review-2026-11-12/run.py gl_compatibility --showroom
python docs/evidence/car-model-review-2026-11-12/run.py mobile --showroom
python docs/evidence/car-model-review-2026-11-12/summarise.py
```

Final inventory: **124 checks, zero failures**. Final native comparison:
**154/0 per desktop renderer**. Total **432/0**. An additional 18 actual-studio
captures per renderer and driver surface inspection complete without script
errors. The summariser reconciles both native stock inventories against the
headless counts and verifies final result/receipt gates.

The initial harness incorrectly called an ArrayMesh-only method on a primitive
and treated packed morph storage as an array of buffers. Both harness errors
are retained in initial/second logs and corrected. The first launcher cleanup
was denied by the sandbox; the verified owned process tree was stopped through
an approved scoped command. The runner now holds the engine directly so it can
stop only its own process. No owner process was stopped. A Pillow contact-sheet
attempt found the package unavailable; built-in System.Drawing produced the
retained contact sheet instead.

The first complete Vulkan pass retained **136 checks/two failures** for Rally's
first view: candidate and restored-original comparisons both differed. The
original/candidate comparison changed 18 pixels by at most 2/255. The final
harness adds first-use settling and an unchanged-original repeat gate, retaining
the exact original/candidate/restoration assertions; both final renderers pass
154/0. The first images/results remain separately archived. Every engine run
retains the Windows root-certificate-store diagnostic; no backend was used.

## Source boundaries and remaining qualification

Concurrent work rebuilt prepared resources during the review, and later changed
`project.godot` and `build_identity.gd`. Each run retains full before/after input
hashes and its command/exit receipt. Earlier changes were mainly Electric and
Hover kit resources; final receipts identify their exact paths. Model source
and the production stock counts/payloads agree across the three inventories.
These separate sampled runs do **not** certify one frozen whole-checkout release
or all prepared resources. The main index is exact within every recorded run.
No concurrent changes were reverted or replaced by this task.

The task's authored files are this report and the review helpers/evidence in
`docs/evidence/car-model-review-2026-11-12/`. Source helpers are outside the game
export root. The source-only review patch and artifact hash manifest are retained
there. The existing optimisation pass is acknowledged; its earlier draw/packing
savings are not claimed again as new gains.

No device attachment query/test, APK/export, deployment, owner-save edit or
backend request was performed. No performance/FPS, AAA finish or owner appearance
acceptance is claimed. Implementing the candidates requires integrated prepared
bakes, fitted/ghost/wash/steering checks and native image controls; real device
memory/frame-time and owner appearance acceptance remain.
