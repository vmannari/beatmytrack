# Rivalry entry and race loading investigation — 12 November 2026

RLI01–RLI06: controlled offline reproduction, podium draw ablations, persistent shader-cache controls, per-batch native rendering boundaries, repeated construction attribution and bounded evidence/cleanup. Production runtime sources, rendering defaults, canonical physics and player data were not changed.

The strongest new finding is an ineffective repeated contact-outline cache when prepared model meshes are recreated: Vulkan reads 57 mesh surfaces again, taking 4.85 seconds on the repeat. Holding the existing prepared PackedScene resource keeps mesh IDs stable, makes the unchanged cache hit in 0.34 ms, and produces the exact same hull bytes. Total repeat loading in that control falls from 8.79 to 3.71 seconds. This is a diagnostic retention experiment, not a shipping fix or a proven global memory policy.

## What the experiments establish

Rivalry's large first-entry delay is dominated by the first native draw of its 3D podium, followed by synchronous feature-script loading. Three car widgets are constructed in roughly 0.16 seconds; building them is not the multi-second cost. One rendered podium view retains almost the whole initial delay. Reusing the same private application's shader cache across a fresh process removes most of that draw stall. This points to first-use native renderer/driver program preparation; these tests do not intercept current GL compile/link calls, so they do not assign exact percentages to a specific driver API.

Race loading contains several different costs: lazy script/resource graph loading, first-use world/material drawing, final effect drawing, and a separate repeated vehicle-configuration delay observed on Vulkan. The finer outline/readback probes identify that last cost below. World packing is measured separately in microseconds; a `cache` status label does not identify packing as the cause of a rendering stall.

## Conditions and interpretation

Pinned official Godot 4.7.2, Windows/i7-11700K/RTX 3090, native 1280×720 windows offscreen, Dummy audio, music disabled, private APPDATA/LOCALAPPDATA, explicit disabled backend. GPU probes run sequentially. The prior full private project and imports were reused; runtime script comparison against live source differed only at generated build identity. The measured asset revisions remain pinned to that copy. Timers/observers are injected only into this disposable copy, plus explicitly recorded in-memory timing annotations for contact-outline construction. Every completed run records an unchanged before/after disk-project digest; the contact probe separately records original-file and in-memory annotated source hashes.

Optional Garage background warming is suppressed to isolate these paths. Consequently, repeated mesh lifetime is measured without an unrelated Garage view keeping resources alive. Ordinary navigation/optional retention may mask or alter this cache miss; these durations do not mean every normal race repeat takes nine seconds. The retained-scene control deliberately holds one existing stock Rally PackedScene across two races, without changing mesh data, outline calculation, cache key or lookup conditions. The scene is released after the probe. The reported 1,313,542-byte immediate Godot static-allocation delta is not full process/GPU memory qualification.

Cold means a fresh private application/shader-cache directory, with project imports and uncontrolled OS/driver state already present. Restart controls reuse exactly the same profile. First and second entry inside a process distinguish retained views/worlds. Single fresh-profile ablations are causal diagnostics, not statistical renderer/quality benchmarks. Turning off podium views, sky use, rim light or shadows changes the diagnostic picture and is not proposed as a shipping visual change.

## Rivalry entry

| Run | Entry | Ready ms | Feature loads ms | Page construction ms | Largest native render interval ms |
| --- | --- | --- | --- | --- | --- |
| rivalry-gl-3 | 0 | 13382.3 | 1995.5 | 161.3 | 10992.7 |
| rivalry-gl-3 | 1 | 98.8 | — | 0.0 | 8.1 |
| rivalry-gl-none | 0 | 2758.6 | 2274.5 | 186.1 | 99.2 |
| rivalry-gl-none | 1 | 94.1 | — | 0.0 | 8.1 |
| rivalry-gl-one | 0 | 13019.2 | 2220.6 | 177.3 | 10422.0 |
| rivalry-gl-one | 1 | 85.1 | — | 0.0 | 8.0 |
| rivalry-gl-warm | 0 | 2896.8 | 2040.0 | 175.2 | 495.8 |
| rivalry-gl-warm | 1 | 77.5 | — | 0.0 | 8.2 |
| rivalry-mobile | 0 | 5631.0 | 2670.0 | 728.8 | 2038.0 |
| rivalry-mobile | 1 | 76.0 | — | 0.0 | 2.1 |
| rivalry-no-rim | 0 | 14839.9 | 2335.4 | 455.7 | 11441.5 |
| rivalry-no-rim | 1 | 103.6 | — | 0.0 | 23.2 |
| rivalry-no-shadows | 0 | 13822.6 | 2330.5 | 396.1 | 10651.5 |
| rivalry-no-shadows | 1 | 129.7 | — | 0.0 | 21.2 |
| rivalry-no-sky | 0 | 17936.0 | 2478.1 | 660.2 | 14065.2 |
| rivalry-no-sky | 1 | 152.0 | — | 0.0 | 43.2 |

The zero-view control still constructs all three actual widgets/models, but disables their viewport updates. One-view keeps only the first-ranked viewport active. Remaining UI/composite work still draws. Individual lighting toggles retain the original rig construction and alter use afterward; they did not demonstrate a robust first-entry improvement. They do not prove that every underlying resource was absent from the driver's work.

The native draw boundary uses RenderingServer.frame_pre_draw/frame_post_draw. It measures CPU wall time spent in native frame submission/rendering and associated waits, not pure GPU execution time. Camera fitting/page layout are timed independently. A single native call can exceed the script-side scheduling budget, so spreading three widget constructions across frames cannot by itself guarantee responsive first rendering.

## Race loading

| Run | Entry | Ready ms | Feature loads ms | Road stage ms | Game construction ms | World draw stage ms | Final finish ms | Draw batches |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| race-gl-cold | 0 | 48924.4 | 4906.2 | 4045.8 | 6668.5 | 25696.5 | 7556.5 | 28 |
| race-gl-cold | 1 | 423.9 | — | 0.0 | 113.8 | 55.7 | 216.0 | 3 |
| race-gl-outline | 0 | 22101.7 | 7108.3 | 163.7 | 4119.2 | 4101.5 | 6504.3 | 34 |
| race-gl-outline | 1 | 2974.5 | — | 0.0 | 156.3 | 287.3 | 2476.2 | 3 |
| race-gl-warm | 0 | 13354.5 | 6243.3 | 182.3 | 4056.1 | 1667.3 | 1146.4 | 28 |
| race-gl-warm | 1 | 536.5 | — | 0.0 | 177.7 | 65.2 | 252.3 | 3 |
| race-mobile-contact | 0 | 38640.7 | 6191.2 | 205.0 | 27429.7 | 1227.1 | 3328.3 | 15 |
| race-mobile-contact | 1 | 13798.3 | — | 0.0 | 10212.5 | 387.8 | 3009.2 | 3 |
| race-mobile-detail | 1 | 18958.6 | — | 0.0 | 11589.6 | 457.5 | 6673.1 | 3 |
| race-mobile-outline | 0 | 40904.5 | 6360.9 | 171.4 | 26592.3 | 3791.9 | 3754.7 | 34 |
| race-mobile-outline | 1 | 8793.8 | — | 0.1 | 6511.9 | 303.8 | 1890.0 | 3 |
| race-mobile-retained | 0 | 41571.2 | 7497.2 | 244.1 | 26589.1 | 3363.9 | 3684.8 | 34 |
| race-mobile-retained | 1 | 3712.8 | — | 0.1 | 1621.5 | 68.5 | 1915.9 | 1 |
| race-mobile | 0 | 61347.6 | 7218.2 | 5602.4 | 37797.8 | 3769.6 | 6848.2 | 34 |
| race-mobile | 1 | 10011.0 | — | 0.0 | 7774.3 | 249.4 | 1869.2 | 3 |

Feature-load totals are restricted to the entry timer's begin/ready markers and cover the App's real lazy resources, including the editor memory-policy dependency. Observer phase/frame/helper aggregates may also include pre-entry and post-exit work and must not be added as exclusive slices of that timer. The standalone probe deliberately avoids preloading game classes before App starts. This exposes script parsing/loading that broader typed test fixtures can warm before their race timer. In-memory outline-detail setup loads that one class before the race and should be used for local function attribution, rather than a cold script-load comparison. Race process-restart controls reuse disk road data as well as shader caches; the separate road/draw stages show both effects.

Graphics preparation's `context`, `geometry_key` and `_material_key` CPU timers are inclusive/nested; do not add them together. Material hashing/context scans must be distinguished from the much longer native draw waits. A batch key describes the script's grouping; it is not a count of actual native shader programs.

## Contact outline and repeated configuration

| Run | Phase | VehicleAudio.configure ms | VisibleContactAudio.configure ms | Outline hits | Misses | Mesh surface reads | Surface-read total ms | Worst read ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| race-gl-outline | race-0 | 46.6 | 17.6 | 0 | 1 | 57 | 2.3 | 0.7 |
| race-gl-outline | race-1 | 25.4 | 20.8 | 0 | 1 | 57 | 2.9 | 0.9 |
| race-mobile-contact | race-0 | 1229.7 | — | 0 | 0 | 0 | 0.0 | 0.0 |
| race-mobile-contact | race-1 | 7643.2 | — | 0 | 0 | 0 | 0.0 | 0.0 |
| race-mobile-detail | race-0 | 8904.5 | — | 0 | 0 | 0 | 0.0 | 0.0 |
| race-mobile-detail | race-1 | 8764.6 | — | 0 | 0 | 0 | 0.0 | 0.0 |
| race-mobile-outline | race-0 | 6201.9 | 6169.7 | 0 | 1 | 57 | 6145.9 | 311.9 |
| race-mobile-outline | race-1 | 4881.1 | 4875.2 | 0 | 1 | 57 | 4850.6 | 199.6 |
| race-mobile-retained | race-0 | 4884.9 | 4842.8 | 0 | 1 | 57 | 4819.3 | 204.4 |
| race-mobile-retained | race-1 | 6.2 | 0.3 | 1 | 0 | 0 | 0.0 | 0.0 |

The normal contact-outline routine reads rendered mesh arrays with surface_get_arrays and builds a convex hull for presentation contact audio. This is outside canonical simulation. Its bounded cache key includes mesh object identities and transforms. The detailed traces retain key hashes, mesh IDs, pose hashes and hull hashes, allowing repeated misses and actual geometry equality to be checked without changing the cache condition. Surface-read timing includes native readback/synchronisation, not merely numeric hull calculation. The test keeps the original algorithm, cache lookup, eviction and output; it adds only timers/metadata before any race is constructed.

For the stock Rally control, all 57 mesh IDs changed between ordinary race instances; pose hashes were identical, both lookups missed, and both hull hashes were `375508ad217875f9483d22f7d8b7e3c86c4ae358202b5dd7ccdfd758b9d08d4f`. Retaining the source PackedScene made IDs, poses and the entire cache key stable. The second lookup hit and returned that same hull hash with zero surface reads. On OpenGL the corresponding reads cost only about 2–3 ms, so this particular repeated readback issue is much more consequential in the observed Vulkan runs. It does not establish a general renderer speed comparison.

Source locations: `game/vehicle/visible_contact_audio.gd:13` constructs the key and outline; line32 reads the surfaces. `game/vehicle/vehicle_audio.gd:133` calls this work from audio configuration. `game/vehicle/modular_car_base.gd:35` loads the prepared scene into a local reference; this path has no bounded retained PackedScene cache. The existing stock-simple path also bypasses the older fitted/full rest-pose cache. The control establishes a concrete resource-lifetime cause without replacing the outline with a guessed shape or changing canonical contacts.

## Largest world-draw batches

### race-gl-cold

| Draw wait ms | Material descriptions | Representative nodes |
| --- | --- | --- |
| 2475.1 | ShaderMaterial:res://assets/vehicles/modular_car_bases_v1/compact_simple_fixed.scn::Shader_glkl0; ShaderMaterial:res://vehicle/compact_headlamp.gdshader; StandardMaterial3D | PreparedNode_34; PreparedNode_32; RearPlateHeaderRule; FrontLampLenses; RaceShadowProxy; RaceShadowProxy |
| 2122.3 | ShaderMaterial: | @MeshInstance3D@237 |
| 1688.1 | ShaderMaterial: | @MeshInstance3D@238 |
| 1646.7 | ShaderMaterial: | @MeshInstance3D@305; @MeshInstance3D@304 |
| 1572.6 | ShaderMaterial: | @MeshInstance3D@265; @MeshInstance3D@264 |

Measured CPU helpers: {"_material_key": {"calls": 1980, "max_us": 543, "total_us": 30382}, "context": {"calls": 57, "max_us": 2007, "total_us": 56513}, "geometry_key": {"calls": 853, "max_us": 560, "total_us": 47720}}.

### race-gl-warm

| Draw wait ms | Material descriptions | Representative nodes |
| --- | --- | --- |
| 134.4 | ShaderMaterial:res://assets/vehicles/modular_car_bases_v1/compact_simple_fixed.scn::Shader_glkl0; ShaderMaterial:res://vehicle/compact_headlamp.gdshader; StandardMaterial3D | PreparedNode_34; PreparedNode_32; RearPlateHeaderRule; FrontLampLenses; RaceShadowProxy; RaceShadowProxy |
| 103.3 | ShaderMaterial: | @MeshInstance3D@238 |
| 103.0 | StandardMaterial3D | LowCover |
| 85.3 | StandardMaterial3D | @MeshInstance3D@307; @MeshInstance3D@306 |
| 82.4 | ShaderMaterial: | @MeshInstance3D@305; @MeshInstance3D@304 |

Measured CPU helpers: {"_material_key": {"calls": 1980, "max_us": 1021, "total_us": 45072}, "context": {"calls": 57, "max_us": 2166, "total_us": 83184}, "geometry_key": {"calls": 853, "max_us": 1066, "total_us": 71225}}.

### race-mobile

| Draw wait ms | Material descriptions | Representative nodes |
| --- | --- | --- |
| 498.3 | ShaderMaterial: | @MeshInstance3D@238 |
| 147.7 | ShaderMaterial: | @MeshInstance3D@237 |
| 126.5 | ShaderMaterial:res://track/contact_shadow.gdshader | CarContactShadow |
| 125.3 |  | Mud1; Spray1 |
| 124.6 | StandardMaterial3D | PreparedNode_35 |

Measured CPU helpers: {"_material_key": {"calls": 1980, "max_us": 934, "total_us": 48188}, "context": {"calls": 69, "max_us": 3439, "total_us": 108943}, "geometry_key": {"calls": 853, "max_us": 985, "total_us": 74676}}.

### race-gl-outline

| Draw wait ms | Material descriptions | Representative nodes |
| --- | --- | --- |
| 169.2 | ShaderMaterial:res://assets/vehicles/modular_car_bases_v1/compact_simple_fixed.scn::Shader_glkl0 | RaceShadowProxy |
| 145.0 | StandardMaterial3D | PreparedNode_35 |
| 142.1 | ShaderMaterial:res://vehicle/window_reflection.gdshader | PreparedNode_26 |
| 141.8 | StandardMaterial3D | LowCover |
| 141.8 | StandardMaterial3D | @MeshInstance3D@307; @MeshInstance3D@306 |

Measured CPU helpers: {"_material_key": {"calls": 1980, "max_us": 675, "total_us": 38757}, "context": {"calls": 69, "max_us": 2093, "total_us": 87952}, "geometry_key": {"calls": 853, "max_us": 763, "total_us": 60198}}.

### race-mobile-outline

| Draw wait ms | Material descriptions | Representative nodes |
| --- | --- | --- |
| 144.3 | ShaderMaterial: [source=res://track/creator_road.gdshader] | @MeshInstance3D@305; @MeshInstance3D@304 |
| 138.8 | ShaderMaterial: [source=res://track/ground.gdshader] | @MeshInstance3D@237 |
| 136.8 | ShaderMaterial:res://vehicle/compact_tire.gdshader | PreparedNode_0; PreparedNode_0 |
| 127.9 | ShaderMaterial: [source=res://track/terrain.gdshader] | @MeshInstance3D@238 |
| 120.3 | StandardMaterial3D | LowCover |

Measured CPU helpers: {"_material_key": {"calls": 1980, "max_us": 2331, "total_us": 45062}, "context": {"calls": 69, "max_us": 2444, "total_us": 97099}, "geometry_key": {"calls": 853, "max_us": 2408, "total_us": 69109}}.

## Limits, failures and next implementation targets

The first instrumented Rivalry run retains a two-object/one-resource shutdown finding. Releasing the local App script and draining the soundtrack node after measurement removes that finding in subsequent runs. A contact-probe anchor check rejected an ambiguous reset anchor before applying its annotations; that attempt remains rejected. One instrumented Vulkan cold race hit the original `Preparing start…` loading deadline; it remains a failed run and is not counted as successful cold readiness. The deadline was not increased or disabled. Raw failed logs/receipts are retained alongside successful controls.

The sandbox's certificate-store diagnostic is retained; offline configuration prevents network testing. Timers/metadata add observation overhead, other owner processes were not stopped, and the differing cold durations are not a controlled renderer speedup claim. The older native GL trace in [NATIVE_SHADER_PREPARATION_2026_10_28.md](NATIVE_SHADER_PREPARATION_2026_10_28.md) identified compile/link calls in an earlier build; it corroborates the mechanism but is not substituted for current API-level measurements.

Priorities for a subsequent implementation: (1) add bounded, version/geometry-fenced prepared-model retention or exact prepared CPU outlines, preserving current pose/fit validation, invalidation and memory-pressure eviction; qualify every car/fitted shape and contact invariant, (2) reduce or prepare first-use podium/world native graphics in an appropriate validated render context, preserving exact appearance and real completion, (3) reduce the synchronous feature dependency graph and move genuinely independent CPU/file work behind existing lifecycle guards. World packing, car triangle reduction and serializing the three podium widgets are not supported as the leading fix by these measurements. Existing view/world retention and persistent shader caching already provide large repeat-entry gains. The retention control also changes other resource/draw reuse, so the entire wall-time difference must not be assigned exclusively to the outline function.

| Run | Native exit | Unchanged project | Diagnostics |
| --- | --- | --- | --- |
| race-gl-cold-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| race-gl-outline-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| race-gl-warm-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| race-mobile-contact-receipt | 1 | True | ERROR: Failed to read the root certificate store.; DEEP_FAIL exact outline anchor 	reset() |
| race-mobile-detail-receipt | 1 | True | ERROR: Failed to read the root certificate store.; WARNING: Race preparation timed out at stage: Preparing start…; DEEP_FAIL race installed |
| race-mobile-outline-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| race-mobile-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| race-mobile-retained-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-gl-3-receipt | 0 | True | ERROR: Failed to read the root certificate store.; WARNING: 2 ObjectDB instances were leaked at exit (run with `--verbose` for details).; ERROR: 1 resources still in use at exit (run with --verbose for details). |
| rivalry-gl-none-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-gl-one-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-gl-warm-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-mobile-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-no-rim-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-no-shadows-receipt | 0 | True | ERROR: Failed to read the root certificate store. |
| rivalry-no-sky-receipt | 0 | True | ERROR: Failed to read the root certificate store. |

## Artifacts, source scope and retention

New source: `game/tests/profile_deep_loading.gd`, `scripts/investigate_loading.py` and `scripts/analyze_loading_investigation.py`. No shipping runtime file was edited. Exact instrumentation anchors, private-copy original/instrumented hashes, process commands, data, failures and project digests are in [the evidence directory](evidence/loading-investigation-2026-11-12/). The machine-readable conclusions are in `summary.json`. Frames are compacted to slow intervals plus exact per-phase render totals; event markers and original measurement rows remain. Selected baseline/diagnostic pictures are retained. Both task-owned build directories, including the full private project, shader caches and test profiles, were removed at completion under the owner retention policy. `cleanup.json` records disposition and the mandatory build-cleaner receipt. Other recent/protected build work remains above the 20 GiB target. The four-file source-only checkpoint records hashes and reverse-apply validation without changing the main index.

Reproduction requires preparing a fresh coherent private copy at the path declared in the runner (the existing prepare/freeze profile helpers provide this), verifying all prepared-asset contracts, then running `python scripts/investigate_loading.py instrument` and `python scripts/investigate_loading.py run NAME --case rivalry|race --renderer gl_compatibility|mobile`. Use `--profile NAME` for a persistent-cache pair, `--podium 0|1|3` for podium controls, `--lighting no_sky|no_rim|no_shadows` for visual diagnostics, `--contact` for the additional in-memory contact timers, and `--retain-scene` for the stock Rally resource-lifetime control. Exact actually executed configurations are recorded in `run-configurations.json`. Do not run concurrent GPU probes. Source snapshots are intentionally not permanent evidence.

No device query/test, APK/export, live service request, deployment, owner-save edit, owner-process change, production renderer/default change or main-index write was performed. Release, uncontended repeats, real signed-in network entry and Android driver/frame/input qualification remain separate.
