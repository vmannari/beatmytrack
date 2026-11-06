# Native shader usage investigation — 2026-11-06

The strongest result is the Pine first-emission/opening-lap run: **124 of 187 newly linked program variants (66.3%) never issued a draw**. Their native `glLinkProgram` calls consumed **26.867 seconds of 30.425 seconds total linking (88.3%)**. This identifies a substantial selective-compilation opportunity; it does not demonstrate a 26.9-second loading reduction.

“Unused” here means not observed drawing in the tested scenario, not unnecessary for every car, camera, graphics setting or track. These are compiled GPU program variants, not 124 redundant shader files.

## Clean Pine result

The frozen desktop Compatibility run exercised preparation, all-emitter first use and a complete AI opening lap. There were no program-binary imports, so imported aliases cannot conceal usage of the linked sources. One program existing before instrumentation is excluded. Both probe controls pass: binding alone does not count as drawing; an actual fast array draw does.

| Family | Linked variants | Never drawn | Linking spent on never-drawn variants |
|---|---:|---:|---:|
| World surface | 30 | 20 | 6.630 s |
| Car weathering, Burley | 6 | 4 | 1.587 s |
| Car weathering, toon | 6 | 4 | 1.962 s |
| Other engine/material programs | 145 | 96 | 16.688 s |
| Total | 187 | 124 | 26.867 s |

120 of the 124 never-drawn variants have the captured default full-feature signature: `DISABLE_REFLECTION_PROBE`, `USE_RADIANCE_MAP`, `BASE_PASS`, `APPLY_TONEMAPPING`, without specific `DISABLE_LIGHT_*` definitions. Those 120 account for 26.370 seconds. This is a source-signature classification, not proof that every such variant can be suppressed safely.

Each weathering shader has four undrawn default variants (ordinary/instanced color and ordinary/instanced depth). Actual rendering uses more specific variants. This points toward avoiding eager default variants in engine preparation, rather than splitting the car shader into more source files; the earlier fixed-role split did not establish a dependable gain.

All 187 variants were linked by readiness. No previously undrawn variant became used after readiness, and no new source was linked during first emission and the opening lap. The fixture passed **13 checks, zero failures**, with one completed lap and zero contacts. Native instrumentation observed 1,177,816 draw calls including its one positive-control draw; zero capture failures or context mismatches. Source receipts show no source changes during the run. This is one measured desktop run, not a device or driver-cold performance claim.

## Broader five-theme screening

The actual-App sequence visited Pine, Winter, Desert, Storm and Night, with two entries and retry checks for each; **41 checks, zero failures**. It linked 490 distinct source variants. After matching known exported/imported binary identities, **237 source variants had no attributed draw**, accounting for 53.663 of 74.449 seconds of linking. 232 of these match the default full-feature signature.

These broader counts are **provisional screening results**: 385 binary imports occurred, of which 134 were correlated to captured sources and 251 were not. An uncorrelated import could represent a linked source subsequently used under a different program identity. Do not present 237 as a proven globally unused total. Two preexisting programs are also outside source attribution. The separate Pine lap above avoids this ambiguity entirely.

| First entry in sequence | New linked variants | No attributed draw through sequence | Associated linking time |
|---|---:|---:|---:|
| Pine | 187 | 124 | 26.148 s |
| Winter | 84 | 41 | 8.745 s |
| Desert | 37 | 24 | 5.578 s |
| Storm | 56 | 20 | 5.407 s |
| Night | 126 | 28 | 7.785 s |

These are incremental costs in one process, not five independent cold starts. Every second entry added zero source links. There is correspondingly little source-linking benefit to recover on those warm entries.

## Method and limits

The evidence-only native extension captures exact linked shader sources and counts all nonzero GLES3 draw calls, including offscreen, depth/shadow, instanced and particle work. Merely binding a program for uniform setup does not count. Deleted program records survive and reused GL identifiers get new records. The official pinned engine source audit identifies four execution entry points (`glDrawArrays`, `glDrawArraysInstanced`, `glDrawElements`, `glDrawElementsInstanced`), all instrumented; `glDrawBuffers` configures targets and is not a draw. Program link timing excludes the probe's source capture/hash/file writes, and excludes shader-front-end compilation. Instrumentation can still perturb the overall run, so wall time is not a production benchmark.

The probe only observes original driver calls; it does not skip compilation, replace shaders or alter production preparation. Its two tiny control programs are excluded from program totals. The native extension is loaded only in the owned frozen test project. Desktop engine identity, commands, private profiles and pre/post source hashes are retained in receipts.

Retained preliminary findings: an initial C++ control build failed due to overloaded function deduction, and a pilot used the earlier DLL; that pilot is not the accepted control run. The pre-correlation five-theme run is retained separately. The final v3 probe records binary-source aliases, but does not resolve all imports. A sandbox network restriction required a read-only official-source fetch outside the sandbox. No acceptance thresholds were relaxed.

## Next implementation experiment

Prototype lazy creation of the expensive default engine variants while retaining compilation of the exact variants needed by existing preparation draws. Preserve an on-demand fallback for every valid feature combination. Compare native before/after first-entry wall time, total linking, countdown/driving stalls and exact images. Cover every theme, car/material family, lighting mode, particles, camera and supported renderer before accepting a change. The measured undrawn link time is an opportunity ceiling, not a promised saving: engine dependencies, fallback compilation and scheduling can change the result.

Production sources, assets and shader settings are unchanged. No device query/test, APK, owner-save/process change, backend request, deployment or main-index write.

## Reproduction and evidence

- [Accepted Pine analysis](evidence/shader-usage-2026-11-06/pine-lap-analysis.json), [log](evidence/shader-usage-2026-11-06/pine-lap.log), [receipt](evidence/shader-usage-2026-11-06/pine-lap-receipt.json).
- [Five-theme screening](evidence/shader-usage-2026-11-06/themes-accounted-analysis.json), [receipt](evidence/shader-usage-2026-11-06/themes-accounted-receipt.json).
- [Native probe](evidence/shader-usage-2026-11-06/harness/program_probe.cpp), [v3 build identity](evidence/shader-usage-2026-11-06/build-v3.json), [engine draw audit](evidence/shader-usage-2026-11-06/engine-draw-audit.json).
- Run `python docs/evidence/shader-usage-2026-11-06/run_check.py pine-lap res://tests/profile_usage_lap.gd --frozen --native --timeout 180 --first-emission --theme=pine`, then `python docs/evidence/shader-usage-2026-11-06/analyze.py pine-lap`. The frozen fixture and native extension must first be prepared using the retained freeze/build scripts and fixture source. Run native GPU scenarios serially.
