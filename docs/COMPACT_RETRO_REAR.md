# Compact retro rear and American plate ? 2026-10-11

The owner's rear reference retains the fictional boxy compact, two-tone palette and mature cel-shaded style. The later American plate request changes the plate aspect/style while retaining BMT 01. Actual geometry changes apply to the shared Garage/driving model; gameplay camera, physics, collision, wheelbase, wheel radius, car scale and saved livery contracts are unchanged.

| Requirement | Implementation |
| --- | --- |
| CG19 rear lamps |Clusters moved to extreme rear corners, within1.2% of shell width. Single black housing per side; amber/red/white stack, rounded matching inset boundaries, shallow embedded backs and tiny non-emissive optical highlights. Live red brake response retained. |
| CG20 tailgate |Thin closed panel seam, horizontal waist crease, three restrained paint-derived tonal planes. Slightly larger handle sits in a14mm pressed steel pocket with matte beveled surround. Fittings sample actual emitted pocket triangles to avoid crossing them. |
| CG21 bumper |Height0.26 to0.2288m,12% reduction, keeping the upper body join at0.60m. Chunky black plastic, shaped upper bevel and36mm deep plate pocket. Bevel stations match every existing bumper station. |
| CG22 exhaust |Two horizontally aligned open pipes on vehicle right, x0.470/0.605, y0.310m, just below bumper. Sixteen radial segments, dark barrels/inner walls/backing and restrained metal rims. Static geometry shares one assembly for batching. |
| CG23 rear glass/wiper |Original tinted glass/outer window shape retained; glass inset widens rubber seal. Two broad blue-grey native diagonal shapes, no extra reflection capture/texture/shader. Visible pivot, shaped arm and separate blade. |
| CG24 American plate |2:1 plate0.412x0.206m, rounded slim navy border/cream face, larger flat BMT 01 lettering, small fictional BEAT MY TRACK header/red rule/two fixings. All inside the bumper; centre y0.4856. Existing OFL Barlow Condensed SemiBold. |
| CG25 body/lower finish |Matte rear material and livery-aware tonal bands, thin inside-corner contours, dark lower valance. Slimmer bumper raises its lower edge31.2mm to expose more of original rear tyres; original wheel/tread geometry remains. |

Changed files: game/vehicle/compact_rear_design.gd/uid (new scoped builder), compact_detail.gd (rear delegation/tile sampling), compact_coachwork.gd (handle pocket, rear finish, bumper), compact_glazing.gd (rear seal inset), car_visual.gd (remove old straight rear wiper); game/tests/test_compact_rear_detail.gd and test_compact_front_join.gd; three native rear resources, their manifest.json/PROVENANCE.md; DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md, licenses/ASSETS.md, this document and evidence. SHA-256 audit confirms47other native resources exact;50total710173bytes. The original source image contributes design direction only.

Performance decisions: flat ink geometry instead of extruded text;20triangle rounded plate layers, height-dependent lamp sampling/one row for tiny highlights, simple lower/crease planes, cached immutable fitting meshes and shared fixed exhaust batch. No new runtime dependency, texture, shader or light. Final65batched submissions/104762triangles/85129vertices, compared with prior50/102320/78832. The new rear therefore adds2442triangles (2.4%) and15submissions; its extra materials define matte tonal planes, lettering and glass/lens highlights. Existing optimization retains exact final-model triangle attributes/material roles and six rendered images. Local eight-build warm median control186.984ms/optimized103.718ms during concurrent checks is not phone or whole-app performance acceptance.

Commands ran from workspace through powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1, pinned Godot4.7.2.stable.official.ed1daf0bf:

| Arguments | Actual outcome |
| --- | --- |
| -Action Import |Final exit0; native imports/class metadata current |
| -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd |50meshes710173bytes, exit0 |
| -Action TestScript -ScriptPath res://tests/test_compact_rear_detail.gd -Graphical |Final175checks, zero failures; physical corner placement, lens fit/symmetry/braking, US ratio/header/flat ink, bumper height/pocket, actual pressed handle, tailgate, aligned open exhausts, window/wiper and eight actual Garage captures |
| -Action TestScript -ScriptPath res://tests/test_compact_model_optimization.gd |Final73checks, zero failures; exact all-five-car triangle/material attributes, independent paint/wheel transforms |
| -Action TestScript -ScriptPath res://tests/test_compact_surface_quality.gd -TestArgument '--phase=optimized-batched' -Graphical |Final238checks, zero failures; original lips/repaired shoulder normals/six exact pixel comparisons;65meshes104762triangles85129vertices |
| -Action TestScript -ScriptPath res://tests/test_compact_front_join.gd -Graphical |3031checks, zero failures; original body/hood joins; original rear profile with explicit shallow handle displacement |
| -Action TestScript -ScriptPath res://tests/test_compact_joints.gd -Graphical |368checks, zero failures; rear/cabin/roof/window fits |
| -Action TestScript -ScriptPath res://tests/test_garage_studio.gd -Graphical |80checks, zero failures; all50source/bake arrays/UV/paint/glass/wheels. Last observation before doubling bevel stations:65meshes104570triangles84553vertices; construction365.794ms, Compatibility RTX3090 SubViewport CPUmedian0.796ms/GPUmedian0.156ms with GPU95th2.310ms. Other local work was concurrent; not device performance acceptance. |
| -Action TestScript -ScriptPath res://tests/test_garage_livery.gd -Graphical |115checks, zero failures; preview/save/reset/driving paint |
| -Action TestVehicleBatch |35checks, zero failures; bounds/triangles/wheels/brakes (before final bevel station correction) |
| -Action TestHeadlights |81checks, zero failures; functional lighting. One run printed51ObjectDB leaked-at-exit warning; no failed assertions. |
| -Action TestSuspension |59checks, zero failures |
| -Action TestScript -ScriptPath res://tests/test_script_parse.gd |505scripts, zero failures |
| Python native SHA-256 audit |Three explicitly revised rear resources;47exact |
| Android SDK adb.exe devices -l |DN2103/PRQKU4U4PREQNRWG attached |

Intermediate fixes: analytical handle overlays initially crossed the native pocket interpolation; sampling emitted steel triangles and using matte rear finish corrected that. Half-density upper bevel sampling intersected the rounded bumper; matching all96native stations removed corner striping. These are appearance fixes, not relaxed tolerances. Old rear-glass array equality is replaced by the explicit larger-seal contract/source-bake equality; rear profile checks subtract the requested handle deformation and keep0.2mm tolerance elsewhere. A concurrent unrelated WinterSnowWind constant edit temporarily prevented livery/Import compilation; its owner corrected it before passing reruns. No Winter files are included in this change.

Evidence: [rear](evidence/compact-rear-reference-2026-10-11/garage-rear.png), [close American plate](evidence/compact-rear-reference-2026-10-11/garage-rear-close.png), [left](evidence/compact-rear-reference-2026-10-11/garage-rear-left.png), [right](evidence/compact-rear-reference-2026-10-11/garage-rear-right.png), [side](evidence/compact-rear-reference-2026-10-11/garage-side.png), [braking](evidence/compact-rear-reference-2026-10-11/garage-rear-braking.png), [paint preview](evidence/compact-rear-reference-2026-10-11/garage-rear-livery.png). Baseline/source snapshots, hash audit, build samples and exact optimization views share this directory. Scoped Git-format checkpoint scoped-change.patch is reverse-apply/whitespace checked, leaving unrelated working changes alone.

Remaining acceptance: owner rear/plate styling review and phone rendering/frame pacing. DN2103 is attached but no device test was performed. No APK export/install, full Validate/game reproduction, canonical physics change, backend or production deployment. Restart/rebuild the client to load revised source/native geometry.

## CG26: remove rear-window stripes ? 2026-10-11

The owner removes both decorative diagonal glass reflection shapes. game/vehicle/compact_rear_design.gd now builds only the existing wiper/pivot in its rear-window detail method; the original dark glass/shader and rubber seal remain. Existing game/tests/test_compact_rear_detail.gd updates the superseded positive stripe assertion to require no stripe nodes and saves new captures separately. Runtime deletion removes192triangles and the dedicated stripe material; no native rebake or new test is needed for this small visual correction.

Actual command: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_rear_detail.gd -Graphical, pinned Godot4.7.2.stable.official.ed1daf0bf. Result175checks/zero failures; rear, both corners, upper rear, close rear, side, braking and alternate-paint previews saved. Python SHA-256 audit confirms all50native resources unchanged/710173bytes. Manifest/provenance, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md updated; scoped-change.patch is reverse-apply/whitespace checked. No phone test, APK export/install, physics/backend/deployment work performed. Owner visual review remains.

[Updated close rear](evidence/compact-clear-rear-window-2026-10-11/garage-rear-close.png) and [updated corner](evidence/compact-clear-rear-window-2026-10-11/garage-rear-left.png). Baseline, audit and scoped checkpoint are under evidence/compact-clear-rear-window-2026-10-11.

## CG27: remove the black line below the rear window ? 2026-10-11

Removed the single decorative horizontal seam call in game/vehicle/car_visual.gd below the rear glass. This clears the cream hatch panel; window rubber seal, wiper and actual blue tailgate seam remain. No new geometry, materials or tests added. Existing game/tests/test_compact_rear_detail.gd only changes its capture output folder to retain separate evidence.

Actual command: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_compact_rear_detail.gd -Graphical, pinned Godot4.7.2.stable.official.ed1daf0bf. Result175checks, zero failures; eight actual Garage rear/corner/side/braking/livery views saved. Native screenshot inspection confirms line removal. Python SHA-256 check confirms all50native mesh files match their manifest/710173bytes. Scoped diff whitespace and reverse-apply checks pass. No phone test, APK export/install, physics/backend/deployment or full Validate performed. Owner visual review remains.

Changed files: car_visual.gd, existing capture fixture, DEVELOPMENT_STATUS.md, docs/PHASE_0_PLAN.md and this document/evidence. [Updated close rear](evidence/compact-rear-window-line-2026-10-11/garage-rear-close.png); baseline and task-only scoped-change.patch share that folder.
