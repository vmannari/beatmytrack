# First-use race graphics preparation — 5 November 2026

The approved work is to attribute expensive first-use graphics work and reduce it without sacrificing the existing presentation. The implemented candidate removes only proven unreachable shader block bodies before Godot prepares native programs. It preserves active calculations, public uniforms, material identities, the full covered preparation sequence, and the existing bounded shader caches. This is a small component optimization, not a solution to the entire previously measured 31.3-second graphics phase.

## Requirements and implementation

| ID | Requirement | Implementation/evidence |
|---|---|---|
| FUG01 | Attribute actual first-use work | Owned native capture of compile/link/draw/upload calls, correlated with actual App world/effect preparation groups and exact generated program sources. |
| FUG02 | Reduce expensive work without changing art | `game/track/surface_shader_pruning.gd`, called once per new fixed Compatibility source by `surface_shader_variants.gd`, before source interning. |
| FUG03 | Preserve readiness, reuse, bindings and bounds | Existing 64-source/prepared-key limits and signatures remain; cache hits bypass pruning. Dynamic `surface_preserve_branches` materials and other renderers keep the original path. |
| FUGQ01 | Validate pixels, rendering and opening laps | Same-scene original/candidate/restored-original comparisons, interleaved GPU measurements, source/binding/cache regressions and real App opening laps. Actual final results are recorded below. |

Only allowlisted global `const bool` names produced by the existing specialization pass are eligible. A leading false constant, or negated true constant, must guard a balanced braced body. Unknown/local/shadowed/macro-controlled names, non-braced statements, disjunctions, ternaries and bodies containing preprocessor directives retain their original text. Comments and quoted paths are masked with character offsets preserved. Conditions, `else` branches and declarations outside removed bodies remain unchanged. No driver-specific binary or native extension is shipped.

The existing shader-consolidation regression now compares its prior source contract after the approved inactive-body pass, while retaining binding, sharing, exact prepared-hit and cache-bound assertions. Separate parsing/scope tests cover the new transformation, including mismatched `icy_road`/`winter_snow` values and dynamic material fallback. The new `profile_first_use_graphics.gd` fixture requires an explicit output folder and uses private offline App records through the supplied runner.

## Attribution

The frozen Compatibility baseline captures 187 native programs with zero import attempts, failures or skipped compiles. Across the diagnostic App run, calls exceeding the 2 ms logging threshold account for 31.433 s of program linking, 1.310 s of shader compilation, 0.084 s of texture uploads and 0.070 s of the traced draw calls. These are whole-run totals, including menu initialization; they must not be substituted for a race-phase total. Native shader-source capture adds diagnostic overhead, and driver caches were not erased.

The first `CoveredDust0` preparation draw lasts 6.482 s, of which 6.101 s is traced linking and 0.204 s compilation. It triggers 27 distinct native program keys, including car weathering shaders and other work made visible by that preparation stage. Calling this a slow dust shader would misattribute the cost. The two most expensive individual links are weathering variants at about 1.03 and 1.01 s; their captured stage sources differ by the instancing define. This work remains.

Surface shaders also retain inactive biome branches after the existing constant-specialization pass. In the Pine trace, pruning removes `CUSTOM_RADIANCE_USED` from 24 captured surface programs while preserving the total program count. Merely suppressing the authored Winter radiance write did **not** provide a useful saving in a separate experiment: original median 9.798 s versus candidate 9.852 s for the visible six-material grid. That narrower candidate is rejected and its logs remain.

## Measurements and controls

Three interleaved A/B/B/A experiments use all six actual Pine surface materials on a visible grid, with fresh shared-sampler names per trial. Timings include shader allocation, two real draws and readback, after texture/common-pipeline warmup. They isolate fresh-source compiler work, not an erased-driver-cache launch or end-to-end race time.

| Run | Original samples, ms | Pruned samples, ms |
|---|---|---|
| `prune-fresh-abba` | 9837.750, 9642.798 | 9228.732, 9430.542 |
| `prune-fresh-repeat` | 9683.839, 9813.796 | 9023.161, 9107.100 |
| `final-fresh-abba` | 9898.166, 9616.957 | 8875.606, 9296.379 |

The six-sample combined medians are 9.749 s and 9.168 s, a 0.581 s / 6.0% component reduction. The final-code pair alone has medians 9.758 s and 9.086 s. The initial prototype's separate CPU pass over those six sources takes 75.5–130.8 ms (median 90.8 ms), and final pruning takes 98.4 ms, so this is not all net loading savings. Changed source hashes require fresh native cache entries; old shader binaries are not migrated.

The initial instrumented actual-App samples were 47.493 s original and 44.814 s prototype for first entry, then 0.311 and 0.216 s for retained re-entry. Unchanged car shaders and car construction also sped up between these runs. Therefore their 2.679-second difference is **not** claimed as an optimization benefit. The useful evidence is the controlled component comparison, exact images and lifecycle checks.

Both the prototype and production candidate have 15 pixel-exact views across Pine, Winter, Desert, Storm and Night City, with all restored-original controls exact. At 2560×1440, the final mean stage-median GPU times are below; shader counts and draw/primitive counts remain unchanged. This does not establish sustained driving FPS or phone performance.

| Biome | Original GPU, ms | Candidate GPU, ms |
|---|---:|---:|
| Pine | 1.0940 | 1.0935 |
| Winter | 1.0780 | 1.0755 |
| Desert | 1.2580 | 1.2615 |
| Storm | 1.2710 | 1.2790 |
| Night City | 1.2325 | 1.2340 |

The final native App capture has exactly the same 187 generated native program keys as the measured prototype, with zero imports, failures or skipped compiles. Its first entry is 44.096 s and retained re-entry 0.308 s, again observations rather than an end-to-end improvement claim. A final conservative multiple-declaration shadow guard passes 39 focused checks; all 29 generated surface sources across the five biomes remain byte-exact against the native-tested helper. Final pruning costs are Pine 98.393 ms, Winter 83.792 ms, Desert 69.458 ms, Storm 90.242 ms and Night City 101.168 ms, aggregated over each biome's unique source set.

## Commands, final validation and retained findings

Evidence and per-run source hashes are under [first-use-graphics-2026-11-05](evidence/first-use-graphics-2026-11-05). `frozen-project.json` records the owned source copy; static imported content is shared through recorded junctions. `run_check.py` uses the pinned Godot 4.7.2 executable, Dummy audio, private APPDATA/LOCALAPPDATA, an empty backend URL, bounded timeouts and before/after source receipts. Native GPU experiments run sequentially.

```powershell
python docs/evidence/first-use-graphics-2026-11-05/freeze_project.py
& 'C:/msys64/mingw64/bin/g++.exe' docs/evidence/first-use-graphics-2026-11-05/harness/program_probe.cpp -I .tools/godot-cpp-music/gdextension -std=c++17 -O2 -shared -static -lopengl32 -lbcrypt -lpsapi -o docs/evidence/first-use-graphics-2026-11-05/harness/program_probe.dll
python docs/evidence/first-use-graphics-2026-11-05/prepare_probe.py
python docs/evidence/first-use-graphics-2026-11-05/run_check.py pine-native-baseline res://tests/profile_first_use_graphics.gd --frozen --native --timeout 240
python docs/evidence/first-use-graphics-2026-11-05/candidate.py prune
python docs/evidence/first-use-graphics-2026-11-05/run_check.py pine-native-prune res://tests/profile_first_use_graphics.gd --frozen --native --timeout 240
python docs/evidence/first-use-graphics-2026-11-05/prepare_comparison.py
python docs/evidence/first-use-graphics-2026-11-05/run_check.py prune-pixels-fixed res://tests/review_first_use_comparison.gd --frozen --themes pine,winter,desert,storm,night_city --timeout 400
python docs/evidence/first-use-graphics-2026-11-05/run_check.py prune-fresh-abba res://tests/profile_first_use_comparison.gd --frozen --themes pine --timeout 300
python docs/evidence/first-use-graphics-2026-11-05/candidate.py radiance
python docs/evidence/first-use-graphics-2026-11-05/run_check.py radiance-fresh-abba res://tests/profile_first_use_comparison.gd --frozen --themes pine --timeout 300
python docs/evidence/first-use-graphics-2026-11-05/candidate.py prune
python docs/evidence/first-use-graphics-2026-11-05/run_check.py prune-fresh-repeat res://tests/profile_first_use_comparison.gd --frozen --themes pine --timeout 300
# Copy the reviewed shipping sources into the owned project before final tests.
python docs/evidence/first-use-graphics-2026-11-05/run_final.py
python docs/evidence/first-use-graphics-2026-11-05/finish_validation.py
python docs/evidence/first-use-graphics-2026-11-05/run_original_control.py
python docs/evidence/first-use-graphics-2026-11-05/analyze.py final-native
python docs/evidence/first-use-graphics-2026-11-05/summarize.py
python docs/evidence/first-use-graphics-2026-11-05/delivery_checks.py
python docs/evidence/first-use-graphics-2026-11-05/checkpoint.py
```

Final native validation passes 37 focused checks per desktop renderer, 141 retained shader-sharing/binding/cache checks per renderer, 30 image/control checks and 9 actual-App entry/retry checks. Final hardening passes 39 focused headless checks and 29 byte-exact source comparisons. Compatibility opening-lap/emission/cancellation coverage passes 123 checks; desktop Mobile passes 133. Each completes five actual opening laps with zero contacts. The observed maximum driving-frame times are 17.478 ms and 13.340 ms respectively, not a sustained/device performance claim. Mobile's Desert lap records one additional draw pipeline, as in the prior shared-graphics investigation; no zero-pipeline opening-lap claim is made. Other observed opening laps record zero.

The accepted final runs total 719 assertions with zero failures. `delivery-checks.json` requires positive counts, five zero-contact laps per renderer, all 15 exact images/controls, stable per-run sources and no script/shader errors. It also verifies that the original world/effect/shared-preparation sources and both road shader includes remain byte-exact: only the two named runtime GDScript files implement the change.

The independent task-start generator produces the expected focused regression: 39 checks with one failure because it retains the inactive radiance write. The current generator passes 39/0. The controlled original run restores the candidate bytes exactly afterward; it is recorded separately from accepted runs.

The initial comparison fixture failed its exact source anchor because copied Windows text used CRLF; normalization repairs the fixture without changing shaders or assertions. The first CPU probe used a nonexistent `shaders/` subdirectory and printed empty-source errors despite exit 0; it is rejected, with the corrected explicit-existence-check run retained. Root certificate-store startup errors recur in the offline environment. Original and prototype App native traces both report two ObjectDB instances and one resource at exit. These logs are retained rather than called clean runs.

The first Compatibility lap invocation lacked the frozen copy of `backend/tests/fixtures/verified_oval.json`: it ran zero checks and is rejected despite exit 0. The initial Mobile invocation passes 103 loading/cancellation checks but omits the required `--first-emission` option, so it establishes no emission or lap coverage. Corrected runs explicitly enable the option. Delivery validation requires five completed zero-contact laps per renderer and positive assertion counts. The runner now rejects `SCRIPT ERROR`/`SHADER ERROR` output even when Godot returns zero.

The broad prototype is evidence-only and intentionally superseded by the conservative production helper. The rejected radiance-only experiment used a snow-based shortcut and was exercised only on Pine; production uses actual proven constants, with a regression for independently varied snow/ice flags. No prototype parser, diagnostic DLL, conditional-radiance shader edit or native hook is enabled in shipping runtime code.

## Scope and remaining acceptance

No camera, artwork, texture, mesh, scenery population, particle quantity, shadow quality, antialiasing, checkpoint, physics or shortcut rule changes. No phone/device query or test, APK/export, owner-save/process change, live/backend request, deployment or main-index write. Concurrent loading, checkpoint, prepared-asset and shared-graphics changes are preserved. Reload/rebuild, owner appearance acceptance and actual-device latency/memory/first-lap acceptance remain. No total-race-loading, cold-driver-cache, startup, phone or 60 FPS improvement is claimed.

The [task-only patch](evidence/first-use-graphics-2026-11-05/task.patch) and [forward/reverse/content verification](evidence/first-use-graphics-2026-11-05/checkpoint.json) leave the main Git index untouched. The large remaining first-use delay is native program linking, particularly vehicle/weathering variants; further major gains need a separately measured engine/compiler approach that also passes first-draw and memory limits.
