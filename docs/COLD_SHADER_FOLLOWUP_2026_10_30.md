# Cold shader compilation follow-up — 30 October 2026

The cold loading stall is real, but this investigation does not produce a safe production fix. The new results rule out a simple reduction in the background compiler's batch size as a way to satisfy the current memory budget. No game or engine runtime source was changed.

## Cause and renderer

The game uses Godot's Compatibility renderer. Its [official guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) says that its modern pipeline-precompilation mechanism does not apply to Compatibility; visible loading-time draws are the documented way to prepare shaders. The current game already performs covered preparation draws.

The earlier [native trace and prototype](NATIVE_SHADER_PREPARATION_2026_10_28.md) found that 5.116 seconds of a 5.207-second cold race frame overlapped compilation and linking. A new [analysis of that archived trace](evidence/cold-race-variant-2026-10-30/link-frames.json) finds 24 link calls overlapping the frame; the longest whole call took 867.530 ms. These measurements are from the earlier desktop project snapshot, not a new current-tree race run. Individual driver calls can exceed a frame budget, so merely yielding between application batches cannot guarantee responsive loading.

## Program inventory

The archived Compact Garage capture contains 192 distinct full vertex/fragment pairs, all still distinct after normalizing and sorting the unconditional preamble definitions. The inventory contains 23 vertex bodies, 25 fragment bodies and 155 distinct preambles: render and lighting permutations contribute substantially to the total. This is a source inventory, not proof of where the driver spends time or that individual features can safely be removed. It does not describe every car or current Android behavior.

The [inventory script](evidence/cold-shader-followup-2026-10-30/garage_shader_inventory_20261030.py) checks the archived job checksums and produces the [recorded output](evidence/cold-shader-followup-2026-10-30/inventory-output.txt). The job archive SHA-256 is `475efa1fd189b6365e9473f1ab967ef32ec6a5947ff5ba19fcd800c03027e453`.

## Helper process memory controls

The earlier actual-App experiment imported all 192 matching binaries, but retained 221–235 ms first-draw frames and peaked at 162 MiB worker commit, above the existing 96 MiB optional-work budget. The follow-up tests the same evidence-only worker with fresh result directories and smaller job batches. The captured jobs identify an RTX 3090, NVIDIA 616.92 and a matching forward-compatible OpenGL context. Driver and OS caches were not cleared.

| Diagnostic case | Peak process commit | Runs |
| --- | ---: | ---: |
| Context only, same context and compiler hint | 46.51–46.58 MiB | 3 |
| Smallest archived job, 4,312 bytes | 103.59–103.75 MiB | 3 |
| One largest-by-source-size job | 110.1 MiB | 1 |
| Four largest-by-source-size jobs | 113.6 MiB | 1 |
| Sixteen largest-by-source-size jobs | 144.4 MiB | 1 |

Every compilation completed successfully and reused zero helper result files. The approximately 57 MiB difference between context-only and the smallest-job control includes compilation, linking, driver and binary-output work; it is not an isolated allocation. Source size is not proof of worst-case memory. These are Windows process-commit measurements, not Android PSS or combined application and GPU memory. Since even the smallest sampled job exceeds the optional budget on this desktop, recycling the same worker between small batches is insufficient. It also does not address the first-draw failure.

Raw [small-job controls](evidence/cold-shader-followup-2026-10-30/small-control-summary.json), [batch controls](evidence/cold-shader-followup-2026-10-30/batch-summary.json), logs and source are preserved with this report. The retained worker executable SHA-256 was `534a8083a53cf3fde58c8392b80ec1126ae126b7b117e3016a0bb3219c3362f0`; runners use the previously captured `build/native-shader-preparation-2026-10-28/programs/jobs-context` jobs and worker, and create fresh task-specific directories under `tmp`. The context-only probe uses the same `shader_job.hpp` context, identity and compiler-thread hint as that worker. No physical device was tested.

## Next engine experiment

The [pinned Godot source](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/drivers/gles3/shader_gles3.cpp) initializes every default-mask variant on a cache miss. Its [bind path](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/drivers/gles3/shader_gles3.h) can compile a missing specialization. An independently built, diagnostic engine could test initializing empty variant maps and compiling requested variants on first bind. This is a hypothesis, not a proven improvement: it may reduce work before a loading frame but shift hitches to later effects, lighting, shadows or gameplay.

Use a separate engine identity and fresh private cache. The stock cache loader eagerly installs cached programs, and the existing miss path may rewrite the growing cache on each new specialization; it also needs a transform-feedback cache-policy audit. Measure fresh and repeat loads, cache writes, all first real draws and input frame times. Verify visual output, late effects, cancellation, context loss, failed compilation, replay compatibility, and combined memory before considering integration. Do not use sparse experimental cache files with the owner's stock engine profile. A smaller-footprint worker that also prepares representative first-draw state is another possible research direction, but must meet both the frame and combined-memory gates.
