# Car/weathering shader linking experiment — 2026-11-05

The fixed-role shader prototype is retained as an experiment, not enabled in the game. Splitting wheels and trim into additional shaders increased whole-car first-use work. A narrower replacement of Compact's existing toon rear-trim shader preserves the number of shader families and shows a small native-link reduction, but the complete loading benefit is not established. The existing weathering implementation and prepared assets remain unchanged.

## What was tested

An owned frozen project, private profiles, Dummy audio and offline backend configuration isolate the tests from owner data. The pinned Windows Godot 4.7.2 Compatibility executable is identified in each runner. The native diagnostic captures actual driver inputs and link calls in the owned process; it does not import programs or skip compilation. Sources are hashed before and after each run. Desktop Compatibility results are not phone measurements.

The current implementation already shares one Burley shader and one toon shader. Weathering amount, accumulated dirt/snow, wetness, washing volumes and live painted liveries must remain dynamic. Clearcoat also contributes to wet surfaces even when the original paint has no clearcoat. Removing those features based on their initial values would change later appearance.

The default-car inventory finds Compact has Burley paint, front trim, rear trim and wheels, plus one toon rear-trim material. The other four cars use Burley weathering. The narrow prototype replaces only that existing toon family when every toon binding is non-wheel, non-livery rear trim. Mixed families fall back intact. It preserves uniform declarations, substitutes the inactive livery function with an identity function and fixes only the immutable wheel/rear role flags. The evidence helper is not a hardened production shader generator.

## Measurements

The initial fresh-source sweep renders the complete Compact, not an isolated material. Each trial changes only the internal washing-sampler identifier to obtain new driver source inputs; washing textures are rebound. This is a fresh-source experiment, not a cleared-driver-cache test. Two draws and a readback complete each measured trial.

| Policy | Shader sources | First / reverse-order sample |
|---|---:|---:|
| Existing shared shaders | 2 | 8.203 / 5.450 s |
| Separate wheel shader | 3 | 10.322 / 7.002 s |
| Separate livery-free shaders | 3 | 11.493 / 6.929 s |
| Separate fixed roles | 5 | 16.213 / 12.358 s |
| Replace toon rear-trim family | 2 | 5.024 / 5.334 s |

Early-to-late variation makes these exploratory pairs unsuitable for a speedup claim. They establish why broad specialization is counterproductive: smaller individual programs do not compensate for linking more programs.

Two further native series use warmups followed by ABBA and BAAB order. Each measured trial still links six Burley and six toon weathering programs. Across four measurements per version, median toon linking is 3.205 s before and 2.831 s with the prototype (373 ms, 11.7%). Median whole-car preparation is 5.879 to 5.677 s (202 ms, 3.4%). Unchanged Burley linking also varies: median 2.408 to 2.520 s. An earlier non-instrumented ABBA series regresses from a 6.057 s mean to 6.354 s, about 4.9%; that result is retained rather than discarded.

Actual-App runs use a test-only hook immediately after weathering configuration, before covered rendering. This avoids changing geometry source identities merely to test a shader. The hook exists only in the frozen project. Whole-run native attribution and per-entry timings are recorded in [summary.json](evidence/weathering-linking-2026-11-05/summary.json). Unchanged world/menu linking and adaptive draw grouping vary between processes; whole-run wall-time differences cannot be attributed entirely to the candidate.

| App run, in execution order | First Pine entry | Immediate re-entry | Toon links | Other links, excluding Burley |
|---|---:|---:|---:|---:|
| Original A | 67.577 s | 2.653 s | 2.680 s | 36.120 s |
| Candidate B | 53.632 s | 2.903 s | 2.344 s | 31.741 s |
| Candidate B | 64.590 s | 1.689 s | 2.609 s | 34.392 s |
| Original A | 55.277 s | 0.698 s | 2.382 s | 32.606 s |

Each process captures 187 programs, including six toon and six Burley weathering programs, with no imports, skipped compiles or native-hook failures. All four pass nine entry/retry assertions. Actual-App toon means are 2.531 s original and 2.477 s candidate: only 55 ms difference in these two samples per version, with overlapping ranges. This does not reproduce the isolated benchmark's apparent 373 ms reduction as a dependable race-loading gain. The much larger first-entry wall differences also accompany changes in unrelated links and draw grouping. The candidate is therefore not shipped. Broad fixed-role splitting is rejected; the narrow prototype remains available for future compiler/device investigation.

## Appearance and correctness

The original appearance series passes 109 checks with zero failures: 36 original/candidate/restored-original comparisons across three rear views, plain and patterned liveries, and clean, dirt, snow, wet, mixed and washed states. Every candidate and restored-control image is pixel-exact, and condition snapshots remain unchanged. Clean views deliberately force the finish to be installed, matching covered preparation. This is a targeted Compact comparison, not exhaustive kit, renderer or device acceptance.

The final image run adds positive visibility controls: temporarily marking only the changed material alters 311, 632 and 805 pixels in the three views. Its 112 assertions pass with zero failures; all 36 candidate/restored comparisons remain exact. This rules out an entirely hidden target material explaining the image equality. The debug colors are restored within the fixture and are never part of the candidate.

The corrected targeted native Pine run passes 12 assertions and completes one opening lap with zero contacts. Its pipeline monitor reports zero additional draw pipelines. However, the log retains countdown hitches up to 269.001 ms and a maximum observed driving frame of 132.414 ms. No matched first-lap control was run in this experiment, so their cause is not attributed to the candidate and smooth-frame acceptance is not claimed. This is another limitation on shipping the prototype, not a performance pass.

The final targeted total is 160 assertions with zero failures: 112 image/state/visibility, 36 actual-App entry/retry and 12 opening-lap checks. The earlier 109 image assertions remain separate. Twelve completed process receipts have stable sources and no script/shader errors; the incomplete initial lap run is explicitly excluded. [Delivery checks](evidence/weathering-linking-2026-11-05/delivery-checks.json) verify these counts, the actual visible-pixel controls, the three unchanged shipping weathering/livery sources and byte-exact restoration of the owned Game file.

Production code has no new execution path, so this experiment does not require rebuilding or invalidating the prepared car library. Shipping a weathering-source edit would require honoring existing dependency/provenance guards and validating the corresponding assets; those guards have not been bypassed.

## Reproduction and evidence

All experiment helpers, original source copies, timing JSON, native jobs, image pairs and process receipts are under [the evidence directory](evidence/weathering-linking-2026-11-05/). `freeze_project.py` creates an owned project; the harness GDScript files are copied to its `tests` folder. Native instrumentation uses the same diagnostic source as the preceding first-use graphics study, with its extension pointing to this task's DLL. It is never loaded by shipping code.

```powershell
python docs/evidence/weathering-linking-2026-11-05/freeze_project.py
# Copy harness/*.gd to the owned project's tests directory.
python docs/evidence/weathering-linking-2026-11-05/run_check.py roles res://tests/profile_weathering_roles.gd --frozen --headless
python docs/evidence/weathering-linking-2026-11-05/run_check.py candidates-gl res://tests/profile_weathering_candidates.gd --frozen
$env:BMT_WEATHERING_POLICIES = 'warmup,baseline,toon_rear,toon_rear,baseline'
python docs/evidence/weathering-linking-2026-11-05/run_check.py rear-abba res://tests/profile_weathering_candidates.gd --frozen
$env:BMT_WEATHERING_POLICIES = 'warmup,warmup,baseline,toon_rear,toon_rear,baseline'
python docs/evidence/weathering-linking-2026-11-05/run_check.py rear-native-abba res://tests/profile_weathering_candidates.gd --frozen --native
$env:BMT_WEATHERING_POLICIES = 'warmup,warmup,toon_rear,baseline,baseline,toon_rear'
python docs/evidence/weathering-linking-2026-11-05/run_check.py rear-native-baab res://tests/profile_weathering_candidates.gd --frozen --native
Remove-Item Env:BMT_WEATHERING_POLICIES
python docs/evidence/weathering-linking-2026-11-05/analyze_native.py rear-native-abba
python docs/evidence/weathering-linking-2026-11-05/analyze_native.py rear-native-baab
python docs/evidence/weathering-linking-2026-11-05/app_candidate.py before
python docs/evidence/weathering-linking-2026-11-05/run_check.py app-baseline res://tests/profile_first_use_graphics.gd --frozen --native --timeout 240
python docs/evidence/weathering-linking-2026-11-05/app_candidate.py candidate
python docs/evidence/weathering-linking-2026-11-05/run_check.py app-candidate res://tests/profile_first_use_graphics.gd --frozen --native --timeout 240
python docs/evidence/weathering-linking-2026-11-05/run_check.py app-candidate-repeat res://tests/profile_first_use_graphics.gd --frozen --native --timeout 240
python docs/evidence/weathering-linking-2026-11-05/app_candidate.py before
python docs/evidence/weathering-linking-2026-11-05/run_check.py app-baseline-repeat res://tests/profile_first_use_graphics.gd --frozen --native --timeout 240
python docs/evidence/weathering-linking-2026-11-05/finish_validation.py
python docs/evidence/weathering-linking-2026-11-05/summarize.py
python docs/evidence/weathering-linking-2026-11-05/delivery_checks.py
python docs/evidence/weathering-linking-2026-11-05/update_trackers.py
python docs/evidence/weathering-linking-2026-11-05/checkpoint.py
```

`finish_validation.py` copies the final fixture, runs `rear-pixels-visible`, enables the owned candidate hook for `candidate-pine-final` with `--first-emission --theme=pine`, and restores the archived Game file byte-for-byte in a `finally` block. `--lap-only` repeats just the corrected targeted lap. Earlier baseline control restoration normalized text line endings; the restoration helper now copies original bytes. No shipping source was rewritten. The runner retains the offline environment's root certificate-store errors in both original and candidate logs; these are not shader compilation errors or evidence of backend requests.

The initial `candidate-pine-lap` invocation is excluded. Python argument abbreviation consumed `--theme=pine` as the runner's `--themes` option, so the native fixture began the broader suite. It exceeded 240 seconds; sandbox process cleanup returned Access denied and the subsequent 20-second wait raised `TimeoutExpired` before a final receipt could be written. Exact command lines and the frozen-project path verified the task-owned wrapper/console/engine tree; escalated cleanup stopped only those three processes. The first identity check did not terminate anything because a single PowerShell result did not expose the expected Count; the corrected array check did. This is recorded in [initial-lap-failure.json](evidence/weathering-linking-2026-11-05/initial-lap-failure.json), alongside the raw incomplete log and initial orchestration result. `allow_abbrev=False` now forwards the exact Pine option. The corrected run has a distinct label; no partial initial assertions count toward acceptance.

No device query/test, APK/export, owner-save/process change, live/backend request, deployment or main-index write. No new runtime shader, visual-quality reduction, particle reduction, gameplay, checkpoint or shortcut change. Concurrent workspace work and the previous surface-pruning optimization are preserved. No total-loading, cold-driver, startup, steady-GPU or phone speedup is claimed.

The [task-only patch](evidence/weathering-linking-2026-11-05/task.patch) and its [forward/reverse/content verification](evidence/weathering-linking-2026-11-05/checkpoint.json) retain the experiment and report without staging the main index. Raw native jobs, images and process receipts remain in the evidence directory.
