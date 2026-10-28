# Memory drift investigation — 26 October 2026

The repeatable growth has three causes: a native road-blending leak, Godot's headless accessibility queue, and retained measurement dictionaries. The native leak is fixed and the soak now streams its measurements. A fresh 20-cycle windowed Create/Settings control has a **132-byte warm static-memory range**, with constant objects, nodes and resources. The pinned engine remains unchanged; its headless queue issue remains open.

## Native leak and fix

The pinned godot-cpp bindings' `Dictionary::operator=(Dictionary &&)` constructs over its destination without destroying its previous value. `Blend::load` assigns a temporary dictionary into each default-constructed `BlendPiece.settings`. That loses an empty Dictionary's **128-byte** private allocation on every piece.

Native allocation tracing finds **33 surviving dictionaries per editor entry: 4,224 bytes**. Between visits 8 and 18, outstanding allocations at that site rise from **199 to 529**. With the fix they remain **1 to 1**, both headless and windowed. Each CRT allocation is 144 bytes including the engine's 16-byte header; Godot's static counter counts the 128 requested bytes.

The isolated binding reproduction confirms the mechanism: 1,000 copy assignments grow by **0 bytes**; 1,000 move assignments grow by **128,000 bytes**, twice each. The application workaround first binds the incoming settings to a const local Dictionary, then uses the releasing copy assignment. It changes `native/track_geometry/road_geometry.hpp`, without modifying the SDK, simulation or geometry calculations.

The regression exercises the actual native blend loader independently of drawing and mesh allocation:

| Pieces per preparation | Calls | Original growth | Fixed growth |
|---:|---:|---:|---:|
| 0 | 200 | 0 B | 0 B |
| 1 | 200 | 25,600 B | 0 B |
| 7 | 200 | 179,200 B | 0 B |
| 33 | 200 | 844,800 B | 0 B |

The original library fails three unchanged memory assertions. The fixed library passes all ten assertions in the same isolated project, and nine in the main project, where the explicit extension-loading assertion is unnecessary. Windows, Android arm64 and Android x86_64 libraries were rebuilt from the corrected header. Their debug symbols and source mappings remain in `build/symbols/<binary SHA256>/`. Windows uses a new content-addressed DLL, leaving loaded generations available to existing owner processes.

## Large headless steps

The four large allocations in a traced **246,080-byte** jump are Godot's `HashSet<ObjectID>` buffers for `SceneTree::accessibility_change_queue`. The queue receives updates even on a display without accessibility support. Node removal erases its ID only when accessibility is supported; headless has no such support. Its queued IDs therefore outlive the freed nodes. This follows the pinned engine's [queue insertion and processing](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/main/scene_tree.cpp#L225) and [node entry/exit handling](https://github.com/godotengine/godot/blob/ed1daf0bf/scene/main/node.cpp#L176).

A minimal editor loop adds **290 dead IDs per visit** in headless mode. The windowed counterpart keeps **zero dead IDs**. A standalone reproduction creates and frees 10,000 ordinary Nodes, explicitly requesting an accessibility update on each: headless grows from **107,216,328 to 107,708,808 bytes**. The equivalent control without the update settles at **107,217,368 bytes**. The windowed update reproduction settles at **89,179,480 bytes**.

The native allocation probe reads queue size, live/dead ID counts and buffer sizes in an owned fixture process. Its layout inspection is specific to the pinned official Windows engine, SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. It patches only that newly launched fixture's import table for allocation tracing; no engine file or owner process is patched.

An [engine-side proposal](evidence/memory-drift-2026-10-26/engine-accessibility-proposed.patch) guards new queue insertions when accessibility is unsupported. It has **not** been compiled or applied. The game contains no private-memory queue workaround and does not disable accessibility for users. An upstream or locally rebuilt engine correction needs its own accessibility and headless regression validation.

## Fresh lifecycle measurements

Every App control writes an explicit empty backend URL in its own profile, then asserts the client's empty origin before cycling. Samples are streamed, without retaining history. The following warm samples are visits **4–19**, all measured after returning to Settings:

| Run | Completed visits | Warm objects / nodes / resources | Raw static range | Range after subtracting measured queue storage |
|---|---:|---|---:|---:|
| Original native library, headless | 24 | 3,128 / 270 / 662 | 247,580 B | 63,380 B |
| Fixed native library, headless | 20 | 3,128 / 270 / 662 | 184,220 B | 20 B |
| Fixed native library, windowed Compatibility | 20 | 3,029 / 270 / 662 | **132 B** | **132 B** |

The original queue-adjusted change is **15 × 4,224 + 20 bytes**. The fixed headless run retains the engine queue steps while removing the linear native growth. Native snapshots have **zero dropped allocation records**. These are scoped lifecycle observations, not hundreds of independent functional assertions.

These counters measure Godot allocations. Android PSS, process private bytes, graphics residency and thermal behavior need separate device measurements. Concurrent owner changes to App, previews and cars were preserved; absolute memory totals across different runs are not presented as a paired product saving.

## Measurement and isolation corrections

The previous soak retained every nested measurement Dictionary in `samples`. Recreating its frozen row shape produces **651,824 bytes** of growth between retained samples 15 and 198. Keeping only the current row/JSON encoding leaves a bounded **2,488 bytes** in the separate control. The harness now writes JSONL per visit, releases each row on return and writes a small final summary. It records object counts as well as nodes and resources, and waits for the existing seven-image Garage readiness condition before asserting it.

The earlier isolation assumption was also wrong: an empty `BMT_API_URL` can disappear on Windows, restoring AccountController's debug localhost default. Some earlier probes therefore included public discovery reads. New controls use an explicit offline `backend.cfg`; the shipping soak refuses to run outside a profile under `build/`, so it cannot overwrite an owner's backend configuration. It clears the environment override and asserts empty origin/unconfigured state before cycling. No real authentication, purchase or live mutation was used.

The historical **9,125,820-byte** delta remains preserved. Its raw samples are unchanged. This investigation establishes the mechanisms and fresh controlled results; it does not claim an exact byte-for-byte reconciliation of that older mixed run or a new 200-cycle acceptance result. The earlier [runtime fixes report](RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md) and its machine-readable evidence now carry the isolation correction and follow-up link.

## Validation and retained failures

- Native road scalar parity: **115 checks, 0 failures**, including all five themes and the bridge fixture.
- Native winter/raster/compiler parity: **482 checks, 0 failures**. Only report destinations changed in the owned copies of these suites.
- Updated full race/results/editor/practice/pressure soak: **3 cycles, 14 checks, 0 failures**; JSONL and summary output inspected.
- Whole-project parser: **1,318 scripts, 0 failures**. Pinned editor import completes. Its isolated profile reports unavailable Android build-tools; NDK compilation of both libraries succeeds, without an APK/export claim.
- Allocation probe self-test: **200,000** allocate/free iterations in **529 ms**, with a known 4,096-byte payload present while held and absent after release.

Initial instrumentation errors and two superseded profiler runs remain in the evidence. The early profiler used tombstones without deletion compaction, making lookups increasingly expensive; one diagnostic editor deadline and an interrupted windowed run are not clean acceptance passes. The final probe uses backward-shift deletion. Godot logs retain the sandbox root-certificate-store error. Final validation logs have no script errors or leaked-object shutdown findings.

Commands, source/binary hashes, compressed raw allocation snapshots, final probe source, counters, original failures and limits are in [the evidence report](evidence/memory-drift-2026-10-26/report.json) and [commands](evidence/memory-drift-2026-10-26/commands.txt). A task-only binary patch is checked forward and backward against an isolated baseline without staging or changing the main Git index.

The client needs a reload/rebuild to use the new native library. Headless engine correction, a fresh long full-lifecycle run and Android memory acceptance remain. No physical-device attachment check/test, APK, deployment, root staging/commit/merge or owner-process restart was performed.
