# Tracks, touch targets and racing performance — 2026-09-18

Requirements: R01, G01, T01–T04 (local creator files), V03/V05 (touch/readability), Q01 (physical-device performance). Owner confirmed the Android app runs, requested their PC tracks, larger touch areas than the button art, and smoother racing.

## Tracks transferred

Copied and SHA256-verified 50 primary JSON files from the PC's `Circuit01Lab/tracks` folder to the installed debug app's private `files/tracks`: 19 saved documents and 31 work-in-progress documents. The phone had no tracks folder before this transfer. Each file was staged, written to a temporary file as the app user, renamed into place, and compared with the PC hash. PC files and the phone's records/settings were preserved.

The 13 current-format saved circuits are Blind spot, Knot, Over and under, Speedy, Curvy, Silmukka, Sightseeing, Ellipse, Ajorata, Lonkero, Easy night, Spiral and Ringroad. Six old v1–v4 documents were copied unchanged for preservation; the current editor does not support those retired formats. All 31 WIP files use v5. No player track content was bundled into the APK.

[Transfer manifest](evidence/mobile-followup/transferred-tracks.json). This is a one-time USB transfer, not cloud synchronization.

## Input and rendering changes

- `game/ui/touch_controls.gd`: mobile artwork is 15% larger on top of the existing size preference. Separate invisible targets extend 42 logical units sideways, 48 above and 72 below the artwork, clipped to the screen. Neighboring targets meet at their center midpoint without overlapping. Central HUD space remains outside driving targets. Existing multi-finger, drag-out and cancellation semantics are retained.
- `game/project.godot`: mobile 3D render scale is 0.667 (about 1600×720 on this phone); the 2D HUD stays at native resolution. The camera framing, world geometry, 2x MSAA and canonical 120 Hz simulation are unchanged.
- `game/track/terrain.gdshader`: skip detail evaluation for surface layers whose weight is exactly zero; nonzero contributions retain the same equations.
- `game/core/game.gd`: only request debug-map redraws while the debug map is visible.
- `game/vehicle/skid_trails.gd`: replace 240 separate mark meshes/materials with one fixed-size MultiMesh, preserving per-mark color/alpha, bridge-aware poses and bounded trail lifetime. CPU-side bounded pose/color arrays support headless verification; graphical checks also verify the uploaded values.
- `game/vehicle/visual_geometry.gd`, `car_visual.gd`: combine static sibling parts only when material, shadow setting and vertex-array layout agree. Body suspension, wheel spin and steering parents remain independent. Compact mesh count falls 137→23; pickup 89→17; classic 77→15; Formula 78→14; kart 92→20, with all original triangle counts and bounds retained.
- `game/diagnostics/mobile_race_probe.gd`, `game/core/app.gd`: explicitly enabled debug probe, guarded by a local `user://mobile_probe.json` marker. Runs unscored AI practice, compares native/75%/native resolution, waits five seconds per stage before collecting twenty seconds of frames, and saves local diagnostics. No network or canonical simulation I/O is added.
- `game/tests/test_mobile_controls.gd`, `test_vehicle_batch.gd`, `test_soil.gd`, `scripts/dev.ps1`: dedicated target/batching tests and development actions.

## Actual verification

All project commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with pinned Godot 4.7.2. Device: DN2103, Android 13, ARM Mali-G77 MC9, Compatibility renderer, 2400×1080 landscape output.

- `TestMobileControls`: 555 checks, zero failures. Covers 1280/1600-wide layouts, desktop/mobile artwork sizing, three scale settings, both handedness modes, outside-art presses, disjoint targets, central HUD exclusion, simultaneous fingers, cancellation and drag-out.
- `TestBridgeHUD`: 91 checks, zero failures.
- `TestSoil`: 113 checks, zero failures; `CaptureSoil`: 115 checks, zero failures and real graphical captures. Initial tests exposed the headless renderer's unavailable GPU readback and the Compatibility renderer's 8-bit instance-color quantization; final assertions retain CPU alpha/pose checks and add graphical upload checks with one-channel-step tolerance.
- `TestVehicleBatch`: 30 graphical checks, zero failures across five cars: retained triangles/bounds, reduced submissions, independent rolling wheels, responding brake material and comparison captures. Initial batching lost non-indexed triangles when mixed with indexed surfaces; the failed tests caught this and the final grouping separates incompatible array layouts. A subsequent unsupported mesh-format API call was corrected before the successful build.
- `CaptureCars`: 120 checks, zero failures on the intermediate batching implementation. This does not supersede the stricter final geometry checks above.
- `DeployAndroid -QuickValidation`: final import/startup plus 70 driving, 18 catalog and 11 menu checks passed, APK signed/verified, `adb install -r` returned `Success`, launcher returned `Status: ok`. Existing app data survived the updates.
- The prior full-suite app-navigation failure remains recorded in [the first deployment report](ANDROID_DEPLOYMENT_2026_09_18.md). Full validation was not claimed as passed here; no physics change or merge was performed.

ADB commands used `run-as`, `push`, `sha256sum`, `am force-stop`, launcher intents, process logs, `screencap`/`pull` and `dumpsys SurfaceFlinger --latency`. Package files were written through `run-as`; only the explicitly created debug-probe marker is removed after profiling. `gfxinfo` was inspected but its Android UI-thread histogram is not treated as a Godot rendering measurement.

## Device measurements

The initial uncontrolled live racing sample contained 126 presentation timestamps: median 16.84 ms, p95 33.81 ms, maximum 286.23 ms. It establishes uneven pacing but is not a matched before/after benchmark.

The first repeatable native/75%/native AI practice run, after touch/terrain/debug redraw changes but before tire/car batching, measured median frame times 21.80 / 16.82 / 21.81 ms and p95 23.96 / 21.50 / 23.84 ms. Native repeat agreement supports rendering resolution as a material contributor. Physics monitor medians were 1.60–2.11 ms. This is an inference from device measurements, not a GPU hardware-counter trace.

[First repeatable probe](evidence/mobile-followup/probe-before-batching.json), [initial sample](evidence/mobile-followup/initial-frame-sample.json), [mobile controls](evidence/mobile-followup/controls-device.png), [batched trail capture](evidence/mobile-followup/batched-trails.png), [compact geometry comparison](evidence/mobile-followup/batch-compact.png).

Remaining acceptance: owner judgment of thumb reach and slide feel, extended thermal/frame-pacing runs, heavier creator tracks and other devices. A short starter-circuit probe does not establish a universal locked 60 fps claim. At the mobile render resolution, 3D detail is somewhat softer; UI text remains native-resolution.

Logs and before-file snapshots are under ignored `build/mobile-followup/`. A scoped review checkpoint is kept separately from the already extensively modified main workspace.

The later native/75%/native batched-model run measured 36.14 / 22.04 / 37.72 ms medians. These longer-session results motivated the final 0.667 mobile scale; they also show why the early short test alone was insufficient. The phone's thermal-service snapshot reported status 0, GPU/CPU about 59 degrees C and battery about 39 degrees C. This snapshot does not prove the absence of device frequency limiting. See [later run](evidence/mobile-followup/probe-native-vs-75-batched.json) and [thermal snapshot](evidence/mobile-followup/thermal-snapshot.txt).

Final 0.667-scale on/off/on batching comparison: median **16.86 / 16.91 / 16.78 ms**, p95 **20.07 / 19.55 / 19.89 ms**, maxima **44.01 / 31.28 / 29.66 ms**. Mesh batching reduced frame draw calls from 792 to 290–291 but did not materially improve frame pacing by itself at this scale. Resolution reduction is the demonstrated pacing improvement. Occasional frame misses remain; no locked-60-fps claim is made. [Final probe](evidence/mobile-followup/probe-final.json).

Final APK SHA256: E2BB69908A65D17F4D899CF635227BD6024E4F7EAFBE4FC4CFC7E5713FB3545F. The debug marker was removed and the app relaunched normally after the probe. Owner records were retained; the phone visibly loads the copied Curvy circuit. Final TestSuspension: 13 checks, zero failures.

Final on-device library check displays 14 circuits: the 13 copied current-format tracks plus Starter Circuit. [Phone library screenshot](evidence/mobile-followup/tracks-device.png). The app was left in the normal Play/library screen, with automatic profiling disabled.
