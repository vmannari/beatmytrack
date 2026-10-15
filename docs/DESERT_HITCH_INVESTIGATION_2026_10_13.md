# Phone desert hitch investigation — 2026-10-13

Owner request: investigate the real first-desert hitch from [the physical-phone performance test](BIOME_PHONE_TEST_2026_10_13.md). Requirements RH08 exact phone attribution, RH09 bounded offline system tracing, RH10 preserve records/cache/approved rendering and parallel tire work; Q01/V05/G01/R01. **2026-10-14 follow-up: matching first-use Mali shader compilation is captured. Preparing the actual hazard meshes under the loading cover removes the recorded route166 stall in the tested cold pass. Separate cold-start compilation stalls remain; this is not a general hitch-free claim.**

## Evidence narrowed so far

The original reference APK has SHA-256 `0C586B9FEE603ED948DE56D92ED8FADF5E808D8BD627CABE9FBD2D90C8E9AFB8`, pinned Godot4.7.2, DN2103/Mali-G77 GLES Compatibility. The original event independently records791.423ms actual presentation,808.617ms between game observations,787.983ms between render signals and1.840ms current process callbacks. This is render-boundary wall time, not GPU execution time.

- Synchronous condition save, recovery callback and cloud local IO do not account for this event; their measured times are zero and the surrounding condition-save count stays5.
- All64 retained preceding frames already have `weathering_installed=true`, over1,056.532ms of retained prehistory. It is not the immediate first weathering-material bind seen in the separate owner's PC capture. The concurrent RH05–RH07 covered material-preparation fix is preserved, but not asserted to fix this phone event; it is not in the frozen APK.
- Scene resources stay428 across the retained before/event/after frames. Draw calls rise187→188 around the event. This is a first-visible-rendering lead, not identification of a particular shader, effect, buffer upload or UI draw; monitors can lag.
- The exact phone document was read privately and compiled with the pinned engine. Its canonical hash exactly matches `3c4040753a9955a17cab387bd18b5a1bb0912d361e6a1d7501ce71d95cfcbe75`. Route points160–170, including the event's164→166 transition, are outside its one bridge with zero bridge height. There are three authored jump objects. A bridge-layer crossing does not explain this location. The track document and startup screenshot remain private build artifacts, not checkpoint content.
- Desert's occasional rattlesnake cue uses preloaded audio, not a newly appearing snake mesh. Its4–10s first cue and later12–24s gaps are presentation-only timing; no event-time audio/native stack was captured, so this does not exclude an audio/OS wait.

The new structured [original-event analysis](evidence/desert-hitch-2026-10-13/original-event-analysis.json) records these facts. First-use shader/driver work remains plausible, as do GPU/driver waits and OS scheduling; none is proven. Compatibility's zero pipeline counters cannot exclude shader compilation. [Godot documents the Compatibility first-visible-frame preparation approach](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html); its modern renderer precompilation system does not apply to GLES Compatibility.

## Historical 2026-10-13 trace attempts and blockers

`scripts/trace-desert-phone.ps1` runs the same explicit unscored local debug probe with original graphics/camera/dust/tire budgets. It captures bounded Perfetto CPU scheduling/frequency/idle, graphics/view/synchronization annotations, frame timeline and Godot-tag logs. Optional99Hz native stack sampling is scoped to the game package. Analysis uses the official local trace processor; no trace is uploaded to a website/service and no runtime dependency is added. System trace binaries/raw logcat remain in `build/desert-hitch-2026-10-13`, outside the source checkpoint. [Perfetto configuration/CLI](https://perfetto.dev/docs/reference/perfetto-cli), [local analysis](https://perfetto.dev/docs/getting-started/command-line-analysis) and [v25 CPU sampling schema](https://raw.githubusercontent.com/google/perfetto/v25.0/protos/perfetto/config/profiling/perf_event_config.proto) support this workflow.

The phone rebooted since the prior successful test: its uptime is minutes instead of the earlier long uptime, its clock now reads2026-10-13 rather than2025-01-26, and it is behind the keyguard again. No reboot/clock/security change was issued by this task. Normal Power/Wake/dismiss commands did not clear `mIsShowing=true`/`mInputRestricted=true`; the owner was asked to physically unlock it.

A later device query reported `device still authorizing` and `run-as: unknown package` during another device-state change. Further device writes were stopped. This does not identify who changed the device or a cause for the original driving hitch. The three successful before/after record-restoration comparisons precede that change; current package/marker availability cannot be certified until the phone is usable again.

Actual attempts:

1. `-Mode Warm -RunName warm-01 -Seconds 60`: Perfetto could not read a pushed `/data/local/tmp` config after dropping privileges (Android permission error13). Original records restored. The config now uses supported stdin delivery; no Android security setting was changed.
2. `warm-02`: system trace started, but the race never reached readiness; deadline ended the attempt. A roughly67MB startup-only trace was retained, not treated as a driving/hitch sample. Its app CPU sample count was zero; `android_log_num_failed=1` limits the logs. This does not establish that native sampling is unavailable during an actual race.
3. `warm-03 -NoCpuStacks`: likewise no race readiness behind the lock screen. Startup/locked trace retained separately; log failure1 and nine negative timestamps were reported by the parser. No driving/root-cause result is claimed.

The final helper refuses a locked-phone start before touching backups, waits for actual race readiness before starting the system trace, records the exact app PID, and preserves original local records. `ColdPair` is prepared to move only the known app-private disposable shader-cache directory aside, run cold and newly primed samples, and restore the original directory. This cold comparison has **not been executed**. Generated cache is retained under a task-owned diagnostic name; original cache is never deleted. No cache movement occurred in the warm attempts.

## Verification at the end of 2026-10-13

Commands use `powershell -NoProfile -ExecutionPolicy Bypass`, pinned `scripts/dev.ps1` for engine work and permitted ADB/normal tool-cache access.

- `scripts/dev.ps1 TestScript -ScriptPath res://tests/inspect_desert_hitch.gd`: completed; exact original hash/route geometry/bridge check printed. Read-only track analysis, not a full gameplay regression.
- PowerShell parser for `scripts/trace-desert-phone.ps1`: zero errors. The final readiness guard/cold restoration paths remain to be exercised on an unlocked phone.
- All three attempted trace groups restored both original local-record files with identical before/after SHA-256 hashes. Diagnostic markers were removed and normal app launch requested. No new APK, runtime renderer/physics, tire geometry/sampling, condition values, backend deployment or competitive request was changed.
- On-device Perfetto v25.0; official Windows trace processor v58.2 `add693d8b338ba9599dbcbc3e300b1ab8c000897`, downloaded solely as a development analysis tool. Source/license stays with its official launcher under task-owned build tools; its verified native download cache is outside the export root.

At the end of 2026-10-13, the remaining work was physical unlock and valid warm/cold/primed traces. The following section records that subsequent work. The original PC preparation implementation remains intact.

Scoped checkpoint/evidence: `build/desert-hitch-2026-10-13/checkpoint-repo` and `docs/evidence/desert-hitch-2026-10-13/{checkpoint.json,task-only.patch}`. It includes only this task's trace/geometry helpers, report, scoped status notes and nonprivate evidence; shared runtime/parallel work, raw system traces, private fixture/menu image and downloaded binaries are excluded. Main Git index/HEAD remain unchanged.

## Unlocked phone, native attribution and hazard preparation — 2026-10-14

The owner replied ready. ADB authorization and normal Wake/dismiss succeeded, but the game package was absent. The exact archived reference APK was reinstalled; its installed hash was independently verified. No uninstall, app-data clearing, phone reset, security change or clock change was issued by this task. This is a **fresh-install reproduction**, not recovery of the former player condition/cache. Both record files were initially absent. The original private track fixture was supplied through the existing unscored debug probe's `document_path`, without creating a player draft or requesting any competitive ticket. Every captured header retains the exact original canonical track hash and physics/rules.

`fresh-04` recovered **993.837ms at tick2316/route166**, the same tick/location and speed as the original. The first 64 preceding weathering-installed flags remain true. Its 120s/64MiB ring trace overwrote early scheduling and stack intern tables: the matching game/log event is valid, but that binary cannot attribute its CPU interval. This failed retention check is preserved, not treated as a native pass.

The helper now records75s for a60s workload, separates64MiB stack/process/log metadata from a256MiB kernel buffer, and uses discard buffers to preserve the beginning. It waits for actual race readiness, records the exact PID and filters analysis by PID rather than assuming a retained process name. Raw traces stay local under ignored `build/`; no upload or shipping dependency is added. A trace is an instrumented diagnostic, not a phone FPS benchmark. [Perfetto's CPU profiling documentation](https://perfetto.dev/docs/getting-started/cpu-profiling) describes the native sample source.

Actual completed groups:

| APK/group | Cold matching-location event | Worst measured cold frame | Worst measured primed frame |
| --- | ---: | ---: | ---: |
| Reference / `cold-pair-05` |170.234ms, tick2315/route166 |2335.367ms |51.427ms |
| Bridge/finish preparation / `prepared-06` |1060.243ms, tick2315/route166 |1061.006ms |53.579ms |
| Hazard preparation / `hazards-07` |No frame above25ms in ticks2250–2390 |976.059ms elsewhere |63.576ms |

Each stage samples60s after5s warmup, uses actual normal graphics (2400×1080 window,0.667 world scale,2x MSAA, original shadows/dust/trails/camera), and completes with zero paused frames. The final cold and primed stages drive510.26m and533.06m respectively. These are game-observed frame intervals, not independently sampled display cadence. The primed result includes occasional missed refreshes and is not called smooth at every refresh. Fresh install and broader concurrent source changes prevent a clean isolated whole-build speedup comparison.

Native attribution is now direct: in the `cold-pair-05` matching170.234ms interval, its render thread runs165.182ms and spends only0.784ms runnable but unscheduled; sampled stacks include **`cmpbe_v2_compile_multiple_shaders` in `/vendor/lib64/egl/mt6893/libGLES_mali.so`**. The `prepared-06` one-second recurrence likewise contains that compiler symbol, with360.905ms of render-thread CPU and765.221ms in its worker while the render thread sleeps. This supports first-use driver shader compilation rather than a one-second CPU scheduling starvation or measured condition save. CPU state durations across threads overlap; never sum them as elapsed GPU time.

`prepared-06` reports weathering prepared/installed and a successful covered draw of all three bridge meshes. Its recorded dust/tyre active masks stay15, with no newly allocated deck emitter and no jump height/roll transition at the matching event. The new post-event frustum context identifies exactly one new candidate: render item9, the third actual jump mesh, using the unchanged `res://track/hazard.gdshader`. The canonical track has three jump objects. Frustum candidates alone are not proof of GPU visibility, but the matching compiler event, single draw increase and subsequent targeted preparation test support this first-visible hazard path. Bridge preparation alone did not fix it.

The fix adds a preparation group to the actual hazard meshes and submits them through the existing covered draw, using the shared original cull-margin preparation/restoration. It reuses the exact mesh/material/transform/shadow/layer data; the camera, condition, shader source, artwork and physics stay unchanged. A separate group helper retains the parallel bridge API and counts independently. Temporary cull margins are restored even after deletion/cancellation; ordinary racing retains its original culling and draw budgets. Hazard groups remain persistent in the existing bounded prepared-world cache. No new geometry/material cache or permanent render population is added. The live logger observes covered hazard draw/count without storing condition or inputs.

Changed runtime files: `game/track/hazard_visual.gd`, `game/track/bridge_render_preparation.gd`, `game/core/app.gd`, `game/core/game.gd`, and the observational `game/diagnostics/race_hitch_monitor.gd`. New regression: `game/tests/test_hazard_render_preparation.gd` (+UID). Analysis/helper changes are `scripts/analyze-desert-hitch-trace.py` and `scripts/trace-desert-phone.ps1`. Tire geometry, shader, pressure, sampling, ring and visibility code were not edited; parallel tire work continues to take precedence.

The intermediate preparation APK is SHA-256 `173FAFCA6CC0656640533CA022F74C5DAA6813F6EBD67180E63B3DDD97D8444E`. The final installed APK is `0B5C404558FF86B37AC1417B93769514655ED7ED8D142B5663C393938A4D8F3F`, frozen at `build/desert-hitch-2026-10-13/hazards-07/installed.apk`. Both installed hashes were checked on the device. Source hashes taken after export are retained privately; they are not proof that unrelated parallel files never changed during export. These builds include the contemporary parallel work, not just this fix.

Final actual checks: normal covered loading27, hitch monitor45, hazard preparation16 Compatibility /16 Mobile-Vulkan /15 headless. Both graphical hazard pairs restore byte-exact pixels. The tests retain full360-tick countdown/tick0, exact existing saved condition, original mesh/material/pose/shadow/layers, hidden-node handling and deleted-node cancellation. Both exports pass pinned import, APP_READY, Driving72, Catalog21 and Menus48. Full Validate was not run; canonical contracts were not changed.

Initial test failures are retained in command evidence: wrong condition property name; editor-practice launch intentionally skipping countdown; expecting an absent condition entry to remain absent despite the ordinary restart's initial save. The fixture now uses a real existing disposable condition and the normal race launch; assertions remain strict. One intermediate run encountered the parallel prepared-car node-name error and passed on the final rerun. A typed empty-array conditional failed the headless path; the shared workspace now initializes typed arrays explicitly. The unrelated car-cache work and parallel bridge correction are preserved, not claimed as this task's fixes.

Records restore their original **absence**, verified before normal launch, for all four new groups. Both cold/primed groups move the original known shader-cache directory aside and restore it; the last two restore every original cache-file SHA exactly. The initial group's restored cache size matches but did not yet collect per-file hashes. Private fixture/markers and record backups are removed; normal app launch is restored. Generated diagnostic caches remain under three explicitly owned names for offline follow-up; the active original cache is retained.

Trace limits remain explicit: system buffers report zero overwrites for the final groups, but1–3 discarded chunks and the `ftrace_setup_errors=51` notice occur. The matching event's scheduling coverage is complete; its cited native samples unwind successfully. Other samples report a small number of invalid map/ELF/unwind errors. This is statistical CPU attribution, not a full GPU execution trace or proof of every compiler intern operation.

**Remaining cold-start path:** `hazards-07` still records974.903ms at tick86/route3, with Mali compiler stacks. Its trail cursor changes4→12, and the next sampled context identifies the first tire MultiMesh candidate. This is a separate first-draw lead; it is not asserted that the tire ring size, drawing optimisation or shader artwork is defective. Several earlier200–568ms and one later402ms cold events also remain. The final primed pass has no100ms event. Preparing these additional first-use resources while retaining the parallel tire renderer needs a separately attributable pass; no general elimination of cold-start hitches or owner/device quality acceptance is claimed.

Actual trace/analysis commands:

```powershell
scripts/trace-desert-phone.ps1 -Mode Warm -RunName fresh-04 -Seconds 60 -DocumentFile build/desert-hitch-2026-10-13/original-desert-document.json
scripts/trace-desert-phone.ps1 -Mode ColdPair -RunName cold-pair-05 -Seconds 60 -DocumentFile build/desert-hitch-2026-10-13/original-desert-document.json
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_render_preparation.gd -Graphical
scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
scripts/trace-desert-phone.ps1 -Mode ColdPair -RunName prepared-06 -Seconds 60 -DocumentFile build/desert-hitch-2026-10-13/original-desert-document.json
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_hazard_render_preparation.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_hazard_render_preparation.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_hazard_render_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_over_under_loading.gd -Graphical
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_hitch_monitor.gd
scripts/trace-desert-phone.ps1 -Mode ColdPair -RunName hazards-07 -Seconds 60 -DocumentFile build/desert-hitch-2026-10-13/original-desert-document.json
python scripts/analyze-desert-hitch-trace.py build/desert-hitch-2026-10-13/prepared-06/cold.pftrace docs/evidence/desert-hitch-2026-10-13/prepared-06 --stage cold --tick 2315
python scripts/analyze-desert-hitch-trace.py build/desert-hitch-2026-10-13/hazards-07/cold.pftrace docs/evidence/desert-hitch-2026-10-13/hazards-07 --stage cold --tick 86 --label remaining-first-use
```

Device install uses `adb -s PRQKU4U4PREQNRWG install -r` on each exact frozen APK. Structured analyses, game captures, commands, source-scoped patch, pixel pairs and restoration evidence remain under `docs/evidence/desert-hitch-2026-10-13/`. Raw system trace/logcat, APKs and the private track fixture remain under ignored build paths. No backend/score write, production deployment or shared-main Git commit was made by this task; other threads continued changing/committing the shared workspace.

The final follow-up review checkpoint is `build/desert-hitch-2026-10-13/checkpoint-2026-10-14`, with [its manifest](evidence/desert-hitch-2026-10-13/checkpoint-followup.json) and [task-only patch](evidence/desert-hitch-2026-10-13/task-only-followup.patch). Concurrent runtime is baseline context; only the captured hazard preparation/observation hunks enter the task change. Whitespace and reverse-patch checks pass. The earlier checkpoint remains as the historical blocked-investigation artifact.

Follow-up2026-10-14: the owner requested the remaining first tire draw fix. Its actual covered-draw implementation, exact preservation checks and installed-APK cold/primed phone results are recorded in [First tire draw phone stall](TIRE_FIRST_DRAW_HITCH_2026_10_14.md). The preceding measurements remain historical; other startup hitches remain separately scoped.
