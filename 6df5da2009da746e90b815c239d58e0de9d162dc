# Runtime item 4 implementation and native preparation proof

28 October 2026. Implements the independently safe portions of the [approved plan](COLD_RENDER_IMPROVEMENT_PLAN_2026_10_27.md) and tests its native architecture in the actual App. **Garage warming no longer runs through the engine's draw callback, and Compact rear construction now yields between fitting groups.** The compiler-process prototype successfully imports every captured program and preserves the tested picture, but fails the first-draw and memory gates. It remains diagnostic code outside the game; no unsupported executable hook or helper process is selected by production.

The [report and command receipts](evidence/native-shader-preparation-2026-10-28/report.json) retain passing controls, original failures, source hashes, native images and remaining work. No effort estimates are included.

## Runtime changes

| Requirement | Implemented behavior |
| --- | --- |
| NSP01 | `game/ui/garage_preloaded_studio.gd` replaces its asynchronous `_draw()` helper with `_warm_frame()`. An explicit setup-complete flag and the existing permission/warming gates protect submission. Canvas redraw, resize and construction no longer trigger optional warming. Original handoff, held geometry restoration, reflections and live sampling remain. |
| NSP02 | `game/vehicle/compact_rear_design.gd` accepts the existing optional cooperative callback and checks it between lamps, tailgate, bumper, plate, window and exhaust. `compact_detail.gd` awaits that construction. Calls without a callback still complete synchronously. A failed checkpoint stops later groups. No geometry formula, material choice or simulation source changes. |
| NSP03 | Refresh the seven native Garage rest resources so their strict author-source guards match the builders. The resources include current concurrent Electric authoring; that geometry is not an authored change of this task. Existing picture assets are not regenerated for scheduling-only changes. |
| NSP04 | Evidence-only native worker/probe serializes exact generated stages, link bindings, transform-feedback settings and implementation identity; compiles in an owned separate process; validates and imports program binaries into actual Godot rendering. Both GL context profile and flags are included after the initial rejection diagnosis. |
| NSP05 | Time actual native API calls and correlate their UTC intervals with complete per-load race-frame intervals. The formerly unattributed Star outlier is now assigned to compilation/linking rather than world packing. |
| R01 / Q01 | Original negative controls, new scheduling/cancellation/array regressions, actual App adoption/input, retained lifecycle and installation checks, artifact provenance and a source-only review checkpoint. |

The three runtime source edits are presentation scheduling. The installed engine, renderer selection, canonical simulation, car tuning/rules, server contracts and save formats are not changed by this task.

## Safe improvements and validation

The callback regression reproduces **16 checks / 5 failures** using the exact original studio source reloaded only inside the owned test process. The fixed source passes **16/0 Compatibility and 16/0 headless**. It checks actual redraw/resize events, explicit interruption/resume, adoption, restored visibility/culling, reflections and sampling. The matched old/new scheduling pictures differ at one pixel by one byte, with mean absolute RGBA byte difference `0.0000005946`; this is not claimed as byte-exact rendering.

The Compact probe identifies a **50.945 ms rear-detail slice**, with a second instrumented control at **61.512 ms**. Lamps, tailgate and first plate work contribute approximately 16–17 ms each in that second control. Adding the six cooperative boundaries reduces the observed full-car maximum to **16.483 ms**; the simplified model still has a **17.036 ms snapshot slice**. These are desktop headless construction observations, not phone frame-time bounds or a statistically paired speedup. Individual native/font/mesh operations still exceed the four-millisecond soft budget.

The new rear regression goes from **14/6 on the original builder to 14/0 headless and 14/0 Compatibility**. It compares exact full/simple arrays, transforms, render flags, node counts and paint declarations, and confirms that cancellation stops subsequent fitting groups. Retained all-car cooperative construction passes **21 checks**. Actual cooperative race installation passes **1,598 checks** across themes and interruption cases, including tick-zero, countdown, recording and readiness barriers. Its deliberately injected deadline produces the expected timeout warning. Actual App passes **141 checks**, the parser passes **1,359 scripts**, and the preferred `scripts/dev.ps1 -Action CheckScript` exits zero. The preferred call's recorded project/build-identity hashes are unchanged.

The retained Garage lifecycle control passes **400 native checks**, using an evidence-only timing adapter for the shared App's already-existing asynchronous fallback. All original assertions remain: the control waits for the actual live view, and monitors the decoded asset throughout CPU construction rather than demanding retention after the view has deliberately released it. Prepared adoption and partially warmed handoff retain their original checks.

The seven-car native geometry/finish control passes **28 checks** when unset shader parameters are compared with their declared renderer defaults. This preserves shader-code, geometry, articulation, material-value and isolation comparisons; serialized default values are otherwise compared to `null`. An explicit wrong-glass control still fails the two relevant assertions. Original raw comparisons remain recorded with four failures, reproduced with the old builders in an isolated native-template control; an attempted frame-settle adjustment does not cure that representation mismatch. The dummy renderer cannot resolve the Compact's colour default and its adjusted control retains two failures. No blanket clean headless prepared-finish result is claimed, and no original production fixture is edited.

## Native prototype: what works

The actual App/Compact Garage uses **192 captured native programs**, not merely one program per geometry group. The source inventory is about 23.3 MB before compression; jobs are streamed individually from disk in this diagnostic harness. It is not a production bounded-queue implementation.

The first worker context uses the same visible GL version/vendor strings but different context flags. Godot rejects all 192 binaries. The native error explicitly reports an incompatible driver/hardware combination. Querying the contexts identifies the difference: both use core profile 1, while Godot has `GL_CONTEXT_FLAGS=1` and the original worker has zero. Matching the forward-compatible context and including those values in binary identity fixes the rejection: **192 imports, zero misses/fallbacks, 384 main-process shader compilations bypassed**.

The first matched-context control reproduces the original 1168 × 362 Garage image with **zero changed pixels**. The later combined-tree render after the safe code/resource changes differs at four pixels, maximum byte difference ten and mean `0.0000473`, below the retained Garage first-entry mean-byte allowance of `0.01`. That later comparison includes concurrent author/source context and is not presented as exact pixels or all-car visual certification.

An independent private loopback queue supplies timestamped inputs while the worker compiles. Real Godot viewport mouse press/release events operate a diagnostic native Button. The full compiler control acknowledges **263/263**, with maximum paired delay **39.341 ms**. Sequence numbers are checked. This exercises queued dispatch and actual controls, not physical mouse/touch hardware. The earlier Windows-message probe receives no acknowledgements and is explicitly superseded. No input or message is delivered to an owner window.

The full compile takes roughly **25.5 seconds** in the matching worker control. Its main menu keeps a p99 frame around **17.1 ms**, but process launch introduces an approximately 61–63 ms outlier. Individual main-process binary installs take at most **3.487–4.090 ms** in the two full controls. The diagnostic path additionally performs synchronous source/key/file validation, so those values are not the complete service cost.

## Why it is not enabled

The approved plan requires the complete path to meet responsiveness and memory limits before engine integration. The full test fails both:

- The original capture's largest warming frame is **1.673 seconds**. Binaries reduce it to **221–235 ms**, but imported programs still cause expensive first real draws and multiple installs share a frame. Native `glDrawElements` calls retain tens of milliseconds. Finishing the link is not equivalent to finishing all first-use driver work.
- The matched full compiler reaches **169,897,984 bytes / 162.027 MiB of committed process memory** and about 164 MiB peak working set. This is Windows process accounting, not Android PSS or complete graphics memory. The compiler alone exceeds the existing **96 MiB optional-work budget**, before the decoded assets or Garage world. Cached validation uses much less memory, but does not establish a bounded first compilation.

There is consequently **no production engine API, compiler service, budgeted program installer or lifecycle integration in this patch**. The address/function-table interceptor is restricted to an SHA256-pinned owned diagnostic process and is never a shipping integration. The current task does not certify runtime 10/10.

The next viable native prototype must execute representative first-draw state in the worker—including vertex formats, framebuffer/MSAA, texture/sampler formats and uniform/UBO bindings—before retrieving its binary. It must also bound compiler workspace within the total optional allowance, move decoding/hash/file work off the render thread, and install at most one ready program per allowed frame. A single over-budget driver call remains a failed gate, not something a timer can interrupt. Only after those controls pass should the pinned engine expose a supported preparation API and the Garage/race readiness state machines consume it. Android context/binary support, lifecycle, combined PSS/graphics memory and real input remain separate acceptance gates. The previous desktop Mobile result is insufficient to select a renderer switch.

## Race outlier attribution

A fresh owned Compatibility process repeats Star with **10 correctness checks / zero failures**. The first load is **42.058 seconds** with a **5.206896-second frame**. The union of timed native spans covers **5.116490 seconds / 98.264%** of that frame: `glLinkProgram` accounts for **4.951587 seconds**, and `glCompileShader` for **164.903 ms**. The next large recorded frames are similarly dominated by those calls. The broad `cache` status remained active while this renderer work ran; it was not evidence that packing consumed five seconds.

World packing is **5.146 ms** and the repeat's instantiation **1.114 ms** in that trace. The repeat's peak frame is **34.417 ms**. This supports the native preparation direction and closes the attribution gap; it does not claim that the new CPU checkpoints remove cold shader compilation. Raw intervals and the overlap calculation are archived.

## Scope, retained findings and acceptance

Source-only task scope is the three runtime files, two new regression entrypoints, documentation/status entries and evidence. Seven regenerated `.scn` derivatives are recorded separately; they are excluded from the source checkpoint because their current author context includes concurrent Electric work. Re-run the recorded native baker against the target author context after applying the source checkpoint. No owner car-author source is overwritten or rolled back.

The shared App's account layout and Electric coachwork change during this task. The latter invalidates every prepared car's broad source guard; the first affected native control reports seven cache misses. Subsequent resources use the current authors. Those changes and generated project identity are not attributed to this task. This is not an immutable whole-tree release result.

Other retained attempts include the initial dummy-carousel expectation, continuous input that correctly prevented idle warming, the initial inaccessible inspection path, initial raw/default-value comparisons, stale baseline-template assertions, two 240-second owned fixture timeouts, corrected directory/globalization and shell-quoting attempts, and a denied Windows CIM query which stops no process. Script-error detection now ends owned test children promptly. Known sandbox root-certificate errors remain. No failure or acceptance target is silently removed from the evidence.

Reload/rebuild is required for the runtime edits. **No physical-device attachment query/test, APK/AAB, real authentication/purchase, owner-save/live service mutation, deployment, owner-process restart or main-index staging/commit/merge was performed.** The native architecture remains experimental; Android/device acceptance and the failed native frame/memory gates are outstanding.
