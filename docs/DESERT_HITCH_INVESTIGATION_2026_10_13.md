# Phone desert hitch investigation — 2026-10-13

Owner request: investigate the real first-desert hitch from [the physical-phone performance test](BIOME_PHONE_TEST_2026_10_13.md). Requirements RH08 exact phone attribution, RH09 bounded offline system tracing, RH10 preserve records/cache/approved rendering and parallel tire work; Q01/V05/G01/R01. **Cause and fix remain unconfirmed. A valid new driving trace is waiting for physical phone unlock.**

## Evidence narrowed so far

The frozen installed APK is unchanged: SHA-256 `0C586B9FEE603ED948DE56D92ED8FADF5E808D8BD627CABE9FBD2D90C8E9AFB8`, pinned Godot4.7.2, DN2103/Mali-G77 GLES Compatibility. The original event independently records791.423ms actual presentation,808.617ms between game observations,787.983ms between render signals and1.840ms current process callbacks. This is render-boundary wall time, not GPU execution time.

- Synchronous condition save, recovery callback and cloud local IO do not account for this event; their measured times are zero and the surrounding condition-save count stays5.
- All64 retained preceding frames already have `weathering_installed=true`, over1,056.532ms of retained prehistory. It is not the immediate first weathering-material bind seen in the separate owner's PC capture. The concurrent RH05–RH07 covered material-preparation fix is preserved, but not asserted to fix this phone event; it is not in the frozen APK.
- Scene resources stay428 across the retained before/event/after frames. Draw calls rise187→188 around the event. This is a first-visible-rendering lead, not identification of a particular shader, effect, buffer upload or UI draw; monitors can lag.
- The exact phone document was read privately and compiled with the pinned engine. Its canonical hash exactly matches `3c4040753a9955a17cab387bd18b5a1bb0912d361e6a1d7501ce71d95cfcbe75`. Route points160–170, including the event's164→166 transition, are outside its one bridge with zero bridge height. There are three authored jump objects. A bridge-layer crossing does not explain this location. The track document and startup screenshot remain private build artifacts, not checkpoint content.
- Desert's occasional rattlesnake cue uses preloaded audio, not a newly appearing snake mesh. Its4–10s first cue and later12–24s gaps are presentation-only timing; no event-time audio/native stack was captured, so this does not exclude an audio/OS wait.

The new structured [original-event analysis](evidence/desert-hitch-2026-10-13/original-event-analysis.json) records these facts. First-use shader/driver work remains plausible, as do GPU/driver waits and OS scheduling; none is proven. Compatibility's zero pipeline counters cannot exclude shader compilation. [Godot documents the Compatibility first-visible-frame preparation approach](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html); its modern renderer precompilation system does not apply to GLES Compatibility.

## Prepared trace and actual blockers

`scripts/trace-desert-phone.ps1` runs the same explicit unscored local debug probe with original graphics/camera/dust/tire budgets. It captures bounded Perfetto CPU scheduling/frequency/idle, graphics/view/synchronization annotations, frame timeline and Godot-tag logs. Optional99Hz native stack sampling is scoped to the game package. Analysis uses the official local trace processor; no trace is uploaded to a website/service and no runtime dependency is added. System trace binaries/raw logcat remain in `build/desert-hitch-2026-10-13`, outside the source checkpoint. [Perfetto configuration/CLI](https://perfetto.dev/docs/reference/perfetto-cli), [local analysis](https://perfetto.dev/docs/getting-started/command-line-analysis) and [v25 CPU sampling schema](https://raw.githubusercontent.com/google/perfetto/v25.0/protos/perfetto/config/profiling/perf_event_config.proto) support this workflow.

The phone rebooted since the prior successful test: its uptime is minutes instead of the earlier long uptime, its clock now reads2026-10-13 rather than2025-01-26, and it is behind the keyguard again. No reboot/clock/security change was issued by this task. Normal Power/Wake/dismiss commands did not clear `mIsShowing=true`/`mInputRestricted=true`; the owner was asked to physically unlock it.

A later device query reported `device still authorizing` and `run-as: unknown package` during another device-state change. Further device writes were stopped. This does not identify who changed the device or a cause for the original driving hitch. The three successful before/after record-restoration comparisons precede that change; current package/marker availability cannot be certified until the phone is usable again.

Actual attempts:

1. `-Mode Warm -RunName warm-01 -Seconds 60`: Perfetto could not read a pushed `/data/local/tmp` config after dropping privileges (Android permission error13). Original records restored. The config now uses supported stdin delivery; no Android security setting was changed.
2. `warm-02`: system trace started, but the race never reached readiness; deadline ended the attempt. A roughly67MB startup-only trace was retained, not treated as a driving/hitch sample. Its app CPU sample count was zero; `android_log_num_failed=1` limits the logs. This does not establish that native sampling is unavailable during an actual race.
3. `warm-03 -NoCpuStacks`: likewise no race readiness behind the lock screen. Startup/locked trace retained separately; log failure1 and nine negative timestamps were reported by the parser. No driving/root-cause result is claimed.

The final helper refuses a locked-phone start before touching backups, waits for actual race readiness before starting the system trace, records the exact app PID, and preserves original local records. `ColdPair` is prepared to move only the known app-private disposable shader-cache directory aside, run cold and newly primed samples, and restore the original directory. This cold comparison has **not been executed**. Generated cache is retained under a task-owned diagnostic name; original cache is never deleted. No cache movement occurred in the warm attempts.

## Actual verification and outstanding work

Commands use `powershell -NoProfile -ExecutionPolicy Bypass`, pinned `scripts/dev.ps1` for engine work and permitted ADB/normal tool-cache access.

- `scripts/dev.ps1 TestScript -ScriptPath res://tests/inspect_desert_hitch.gd`: completed; exact original hash/route geometry/bridge check printed. Read-only track analysis, not a full gameplay regression.
- PowerShell parser for `scripts/trace-desert-phone.ps1`: zero errors. The final readiness guard/cold restoration paths remain to be exercised on an unlocked phone.
- All three attempted trace groups restored both original local-record files with identical before/after SHA-256 hashes. Diagnostic markers were removed and normal app launch requested. No new APK, runtime renderer/physics, tire geometry/sampling, condition values, backend deployment or competitive request was changed.
- On-device Perfetto v25.0; official Windows trace processor v58.2 `add693d8b338ba9599dbcbc3e300b1ab8c000897`, downloaded solely as a development analysis tool. Source/license stays with its official launcher under task-owned build tools; its verified native download cache is outside the export root.

Remaining: physical unlock, valid same-build warm/cold/primed traces, correlate a recovered event with its render thread scheduling/native stack and first-visible effect/buffer context, then make and validate an attributable fix. The existing PC material-preparation fix requires its separate owner/device acceptance and is not overwritten. No new phone performance/root-cause pass, full Validate, speculative visual quality reduction, live score write or production deployment is claimed.

Scoped checkpoint/evidence: `build/desert-hitch-2026-10-13/checkpoint-repo` and `docs/evidence/desert-hitch-2026-10-13/{checkpoint.json,task-only.patch}`. It includes only this task's trace/geometry helpers, report, scoped status notes and nonprivate evidence; shared runtime/parallel work, raw system traces, private fixture/menu image and downloaded binaries are excluded. Main Git index/HEAD remain unchanged.
