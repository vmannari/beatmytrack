# Alternative race-loading implementations — 2026-11-06

Investigation only. The strongest near-term candidate is a persistent checkpoint-layout artifact. For the larger graphics delay, investigate selective native variant preparation and the effectiveness of the engine's existing binary cache before another shader rewrite. These are separate opportunities: avoiding CPU reconstruction does not remove driver linking.

This review includes the current checkpoint memoization/LRU, selected Free Race/Daily/Rivalry CPU worker, Daily read overlap, shared graphics preparation, scenery retention, surface pruning and deferred startup pictures. Those improvements already exist and are not proposed again. The weathering specialization experiment remains rejected. No shipping code or renderer was changed.

## New component evidence

An owned frozen copy of the current project runs the existing checkpoint builder on three fixtures. The probe writes its exact numeric layout, clears both track-held and process-local layouts, then measures the actual geometry/version key, file read/decode and installation through `TrackSession._configure()`. Five reads follow each write. It uses object-disabled `bytes_to_var`, compares reserialized bytes exactly and checks the installed session. This is a feasibility experiment, not a production cache or its corruption validator.

| Fixture | Fresh layout build | Payload | Median key + read/decode + install |
|---|---:|---:|---:|
| Star | 3.633 s | 159,200 bytes | 19.030 ms |
| Over and Under | 97.664 ms | 11,316 bytes | 8.095 ms |
| Knot | 187.557 ms | 15,420 bytes | 20.090 ms |

Star samples span 17.978–20.314 ms; generating its geometry/version digest accounts for approximately 16–18 ms. Writes take 0.906–0.980 ms across the three fixtures. All 45 assertions pass and the run's sources remain stable. Track compilation is outside these numbers. The files were just written and may be served from the OS cache; there is no cold-storage, process-restart, Android, total-race or production-validation-overhead measurement. The approximate 3.6-second Star component opportunity applies when the current process cache would miss but a valid persistent artifact exists. It does not apply to every race or to already-prepared selected tracks.

Evidence: [probe](evidence/race-loading-alternatives-2026-11-06/probe_layout_artifact.gd), [measurements](evidence/race-loading-alternatives-2026-11-06/layout-artifact-fixed.json), [run receipt](evidence/race-loading-alternatives-2026-11-06/layout-artifact-fixed-receipt.json). The first invocation used an obsolete two-argument `bytes_to_var` signature and failed parsing; its original log/receipt remain. The corrected run uses the one-argument object-disabled decoder. The offline root certificate-store warning also remains recorded.

## Ranked implementations

### 1. Persist exact checkpoint layouts — best immediate candidate

Keep the current in-memory LRU and add a bounded local artifact underneath it. On a miss, derive the exact key, validate/load an artifact on the selected CPU worker, and publish the existing numeric layout. On a genuine miss, use the unchanged builder and atomically persist its result. Thus returning to a track after restarting the app can avoid reconstruction.

The artifact needs a format version, actual geometry digest, checkpoint/notice/rules versions, relevant compiler/native-source identity and numeric precision/platform guards. Start conservatively on invalidation. Validate file size before allocating, field types/counts, finite values and cross-field/index consistency; prohibit object decoding. Truncated, corrupt, unknown or mismatched files must fall back to the builder. Keep writes atomic, disk retention separately bounded and decoded memory inside the existing allowance. Never treat local cache data as server authority or change competitive rules/results identities.

Before shipping: compare all prepared fields and gate decisions with fresh construction; exercise restart, mutation, corruption, interrupted write, cancellation and pressure; repeat the existing coverage, hairpin, shortcut and canonical replay controls. The current worker already gives this feature an insertion point immediately before `session._configure(track)`.

### 2. Prepare only needed native shader variants — most interesting graphics experiment

The pinned engine initializes every base variant for a new shader version. Its bind path compiles missing specializations synchronously; the queued alternative is disabled. It also already saves and loads binary programs, including a save after a new specialization. Consequently a second generic binary cache would duplicate existing machinery. [Pinned engine implementation](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/drivers/gles3/shader_gles3.cpp), [bind path](https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/drivers/gles3/shader_gles3.h).

Proposed engine experiment: allocate variant records lazily, enumerate the exact shader/pass/specialization combinations required by the selected race, and prepare those under the loading cover. Keep the same GLSL, materials and rendering equations. This could remove unused compilation work rather than add more material shader families. It requires an engine preparation API and matching export templates; it is not a GDScript switch or an implemented optimization.

First collect every compile and every program use, including fast calls. Existing slow-call traces do not prove which compiled programs are unused. Compare a first-ever run with no cache, a second process using the same cache, and a new profile control. Attribute source-generation, compile/link, cache-import, upload and first-draw costs separately. Record cache hits, misses/rejections, key churn, program counts and retained memory. Do not assume the previous fresh-profile timings describe a user's normal restart.

A manifest must cover shadows/depth, transparent and opaque passes, instancing, AA, all light contexts, bridge/ghost/damage/particle variants and weathering/livery transitions. An omitted variant could simply reappear as an opening-lap hitch. Keep a fallback for unexpected content and require completed native captures and driving validation before releasing the cover. No numerical saving is established for this proposal.

### 3. Queue compilation within the existing graphics context

Where supported, `KHR_parallel_shader_compile` supplies completion polling and a compiler-thread hint. It does not guarantee that a driver obeys the hint or that every call is nonblocking. [Khronos specification](https://registry.khronos.org/OpenGL/extensions/KHR/KHR_parallel_shader_compile.txt).

An engine state machine could submit a bounded number of exact programs, poll completion across frames, and defer status/reflection/use until ready. This could overlap compilation with independent CPU/I/O and reduce UI stalls without the previous separate compiler process. Actual support and benefit on the tablet remain untested. Merely raising a compiler-thread setting while immediately waiting for results will not provide the intended overlap.

Preserve cancellation/generation guards, maintain one bounded queue, and measure total elapsed time as well as responsiveness and peak memory. One driver call can still exceed a frame budget. Actual covered draws remain necessary to expose deferred first-use work. The prior separate-process prototype consumed 162.027 MiB and still had 221–235 ms first-draw frames, failing its memory/frame gates; it is not a ready alternative. [Prior native experiment](NATIVE_SHADER_PREPARATION_2026_10_28.md).

### 4. Move remaining checkpoint lane/crossing arithmetic into the native library

This targets first-ever cache misses, including newly published or edited tracks, where a persistent layout does not help. Batch ordered packed-array calculations in the existing native library, avoiding per-point GDScript/native boundary calls. Preserve sample counts, tie-breaking, floating-point order, complete road/kerb coverage and shortcut rules.

The optimized Star builder still takes about 3.6 seconds in the new probe. That is the component available to attack, not a promised native saving. Native acceleration and persistent artifacts complement each other, but disk reuse is the less invasive first implementation. Require full field equality and canonical replay on all supported build targets; no sampling reduction or relaxed rule is acceptable.

### 5. Store final immutable scenery artifacts

Road arrays already have disk artifacts; complete scenery currently has a process-local `PackedScene` cache. Persisting deterministic world mesh/instance/material descriptions could avoid rebuilding scenery after restart. Clone mutable per-race buffers and lease/reset materials exactly as current retention does. Hash track content, theme, deterministic seed, builder sources and quality inputs; preserve every object, material and transform.

Measure CPU world construction separately before selecting this work. The historical 31.3-second Pine graphics/effects interval contains driver preparation, so saving a scene cannot be credited with removing it. Disk loading also creates upload costs and still needs native preparation. Downloading large prepared worlds from the backend trades computation for network/storage and adds a format/rollout contract; local artifacts or bundled built-in scenes are the simpler first experiment. No backend change is proposed as part of this investigation.

### 6. Evaluate Mobile/Vulkan as a separate renderer branch

Godot's Mobile/Forward+ pipeline preparation and shader baker do not apply to Compatibility. Baking intermediate shaders also cannot package universally reusable final GPU pipelines. Compatibility still requires visible preparation draws. [Godot guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

The earlier desktop study measured Pine first entry at 43.005 s Compatibility versus 22.813 s Mobile, but Winter re-entry was worse with Mobile. Those are historical desktop samples, not a current controlled tablet comparison. This direction has a potentially large architectural upside and the broadest appearance/driver/power/memory risk. Keep it separate from shipping until matched visuals, complete opening laps, thermals, memory, suspend/resume and fallback behavior pass on intended devices. The Nov5 tablet deployment was a startup smoke test, not this acceptance.

## Responsiveness and scheduling

`App._feature_resource()` still uses synchronous `load()`; `_start_race()` resolves the heavy race feature before invoking its entry method. A small loading-cover entry point followed by threaded feature/scene loading could improve immediate feedback and overlap resource I/O. Poll readiness before retrieving the resource: Godot's threaded getter can otherwise block. [Background-loading documentation](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

A future prepared-race object should expose separate immutable-identity, CPU-layout, presentation-resource, native-graphics and authorization readiness. Join them at installation, retain tick zero/full countdown, and reject stale account/navigation/car/track/day/week results. Current selected-worker and Daily-read overlap already implement part of this. Further overlap is useful only where independent work remains; do not speculate limited-attempt tickets while browsing. Moving all graphics warming into the menu can move the stall rather than reduce work and is unsuitable without the native improvements above.

Do not release the loading cover early, lower rendering quality, remove checkpoints, substitute a visibly simpler shader, or raise memory budgets to manufacture a lower load time. Shader-role splitting already increased compilation work; the narrow weathering replacement did not demonstrate a dependable full-race benefit. [Weathering experiment](WEATHERING_LINKING_2026_11_05.md).

## Recommended order and acceptance

1. Implement guarded persistent layouts, using the existing worker and memory cache.
2. Audit actual native variant usage and same-profile binary-cache effectiveness; choose selective preparation based on measured unused work.
3. If supported and still necessary, prototype bounded in-context asynchronous compilation.
4. Use native checkpoint arithmetic for first-ever misses; pursue scenery artifacts or a renderer branch only when their separate costs justify them.

Report first-ever entry, same-profile process restart, warm re-entry after settled menu eviction and existing-Game retry separately. Also report maximum loading/countdown/driving frames, peak memory and image equality. Historical measurements are context, not new end-to-end speedup claims. The prototype demonstrates round-trip feasibility only; it is not installed in the game.

Commands: run `freeze_project.py`, copy `probe_layout_artifact.gd` into that owned project's `tests` folder, then run `python docs/evidence/race-loading-alternatives-2026-11-06/run_check.py layout-artifact-fixed res://tests/probe_layout_artifact.gd --frozen --headless --timeout 180`. The runner records engine identity, private profile, command, output and pre/post source hashes. Shared imported/static resources are recorded in the freeze manifest.

No device query/test, APK/export, owner-save/process change, live/backend request, deployment, runtime modification or main-index write. Concurrent work and the installed tablet build are preserved.

`closeout.py` checks the accepted counts/source stability, retains the initial parse failure and records matching hashes for eight reviewed production files. The [summary](evidence/race-loading-alternatives-2026-11-06/summary.json) and [task-only patch](evidence/race-loading-alternatives-2026-11-06/task.patch) retain the investigation; `checkpoint.py` verifies forward/reverse application and exact content in an owned directory without writing the main Git index.
