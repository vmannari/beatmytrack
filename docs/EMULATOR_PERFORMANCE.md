# Pixel 9 loading performance — 2026-10-04

Requirements **R01/V05/Q01**. The owner reports extremely slow emulator track loads. The installed ARM64-only game was running through `libndk_translation.so` on the x86_64 Pixel 9 image. WHPX was usable and graphics already used the RTX 3090, so enabling hardware acceleration alone would not address the architecture mismatch.

Debug exports now include native x86_64 Godot and music libraries alongside ARM64. `scripts/build_music.ps1` accepts `-AndroidArch arm64` or `x86_64`, defaults to both, and retains the pinned godot-cpp/SCons/NDK toolchain. Both new music binaries have ELF64/x86-64 headers and 16 KB LOAD alignment. Android selects `primaryCpuAbi=x86_64`; startup and gameplay run without a matched GDExtension load error. Native source, canonical physics, road geometry and rules are unchanged.

The local `Pixel_9` AVD also now saves `hw.gpu.mode=host`, `hw.ramSize=4096`, `fastboot.forceColdBoot=yes`, `fastboot.forceFastBoot=no` and `fastboot.forceChosenSnapshotBoot=no`. Original configuration: ignored `.tools/emulator-performance/Pixel_9.config.before.ini`. The original config requested 2048 MB, although its running snapshot reported about 4 GB; this task does not attribute a measured gain to RAM alone. No wipe, uninstall, system-image replacement or user-data removal was performed.

## Actual measurements

The existing debug-only, read-only `menu_probe.json` measured Speedy → Knot → Speedy. Values are playable-selection readiness, not just button response. Backend forwarding was restored before the retained baseline; early connection-error runs were discarded. The first retained baseline could download missing documents; subsequent runs used retained documents. These are observed runs, not controlled statistical benchmarks isolating architecture, caches or host load.

| Operation | ARM64 through translation | Native x86_64, existing VM | Native x86_64, cold VM boot |
|---|---:|---:|---:|
| Race library index ready | 6096 ms | 2883 ms | 1023 ms |
| First Speedy selection | 7794 ms | 2384 ms | 1569 ms |
| Knot selection | 7503 ms | 2507 ms | 717 ms |
| Speedy selected again in memory | 102 ms | 27 ms | 8 ms |

Old race scene construction appeared about 43 seconds after the input command. Native construction appeared about 7 seconds after input, but that VM still stalled before displaying the race. Those estimates mix host and guest timestamps and are not exact visible-load measurements. After cold boot, an independent host-clock screenshot check found the actual Speedy countdown within **3.7 seconds** of the button command, at its first sample. This is an upper bound for that cached track, including screenshot/ADB overhead; it does not guarantee every first load takes four seconds.

A five-second native CPU sample before cold boot recorded 3309 samples with 73.89% attributed to `__vdso_clock_gettime`. This motivated the clean VM boot. It is a clue, not proof of a specific clock/snapshot defect. The attempted post-boot CPU sample failed to set a required Android property and produced no valid new comparison; its stale output was discarded. Performance-counter access was restored to `security.perf_harden=1`. No root or kernel setting was changed.

Evidence: [baseline report](evidence/emulator-performance-2026-10-04/arm64-menu.json), [native report](evidence/emulator-performance-2026-10-04/x86_64-menu.json), [cold-boot report](evidence/emulator-performance-2026-10-04/native-coldboot-menu.json), [CPU sample](evidence/emulator-performance-2026-10-04/clock-cpu-profile.txt), [host timing](evidence/emulator-performance-2026-10-04/native-coldboot-race-timing.json), [inspected race countdown](evidence/emulator-performance-2026-10-04/native-coldboot-first-change.png). Earlier files named `native-race`/`native-race-live` captured the previous menu during the stall and are not gameplay acceptance evidence.

## Commands and verification

Commands ran from the repository root with pinned Godot 4.7.2 and its matching Gradle template:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_music.ps1 -Platform android -AndroidArch x86_64
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestMusic
# Export retained the previously approved app-local debug ad-test CA via BMT_ADMOB_DEBUG_CA_DIR.
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 InstallAndroid -DeviceSerial emulator-5554
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 LaunchAndroid -DeviceSerial emulator-5554
```

Both x86_64 native targets build. Music **36**, focused export driving **72**, catalog **21**, menu **48** checks pass; import/startup/export/install pass. Three existing ObjectDB shutdown warnings occur in driving. PowerShell parser and scoped whitespace checks pass. APK ZIP inspection confirms Godot/music libraries for both ABIs and zero exported test resources. Full regression validation was not run.

Dedicated APK: `build/android/circuit01-emulator-native-debug.apk`, SHA-256 `06508A15E9EFABD6E6F63516A244BFA22EF6970BD9AA7133FEF4231EE9A6C369`. Initial installed baseline was the earlier local-trust AdMob APK. The new APK captures the workspace at export time; concurrent subsequent source changes are not claimed to be included.

ADB commands targeted `emulator-5554` exclusively: `reverse tcp:18181 tcp:18181`, scoped `logcat`, `dumpsys package`, `screencap`/`pull`, private diagnostic marker copy/cleanup, and `emu kill`. Explicit first cold launch used `emulator.exe -avd Pixel_9 -gpu host -memory 4096 -cores 4 -no-snapshot-load -no-snapshot-save`. The saved configuration was subsequently tested with ordinary `emulator.exe -avd Pixel_9`. No backend restart, migration or deployment occurred; `/readyz` reported schema `0012_test_drivers`. ADB resets during export invalidated forwarding in early runs; it was restored after export/VM restart.

Changed files: `scripts/build_music.ps1`, `game/export_presets.cfg`, `game/music/bmt_music.gdextension`, the two new `game/music/bin/*android.*.x86_64.so` binaries, this report, Android documentation, development status/phase notes and evidence. Local AVD configuration is machine-specific and excluded from the repository. A scoped Git checkpoint patch is under `build/checkpoints/emulator-performance-2026-10-04/`; unrelated working-tree changes are preserved.

Android's [ABI documentation](https://developer.android.com/ndk/guides/abis) explains selecting native libraries for the device, and its [hardware acceleration](https://developer.android.com/studio/run/emulator-acceleration) and [snapshot documentation](https://developer.android.com/studio/run/emulator-snapshots) describe graphics/VM acceleration and cold boot. The [emulator troubleshooting page](https://developer.android.com/studio/run/emulator-troubleshooting) also lists API 37 Google-service disruptions; this does not establish the cause of the separate AdMob failure.

One **AD06** preview retry after the normal saved-settings restart still returned SDK code 0, `Unable to obtain a JavascriptEngine`, after about 12 seconds. [Screenshot](evidence/emulator-performance-2026-10-04/ad-retest.png) and [scoped SDK log](evidence/emulator-performance-2026-10-04/ad-retest.log) are retained. No fullscreen ad, reward, spend or banked grant occurred. Show ads was restored to Off and checked in saved preferences. `docs/ADMOB_DEVELOPMENT.md` links this newer test.

Remaining acceptance: owner-driven longer sessions, uncached/complex tracks, restart consistency, music listening and AdMob fullscreen completion. The DN2103 was enumerated but **no physical-phone installation or device test was performed**. Emulator performance is not physical-phone performance acceptance. Probes are removed and the saved Show ads setting remains Off.
