# Driving camera options — 2026-10-03

The owner requests two alternative views for driving comparisons: delayed rotation with the car from a slightly lower angle, and a fixed-world view showing more road in the direction of travel. This authorizes selectable camera rotation/pitch experiments under V01; the original Overhead view remains the default and calibration baseline. V03 covers Settings/pause access, V05 the presentation/canonical boundary, and V04/Q01 retain owner/physical-device acceptance.

## Behavior and controls

| Choice | Pitch | Rotation | Look-ahead |
|---|---|---|---|
| Overhead | 56° | Fixed world yaw, 18° | Velocity × 0.22 s + 1.5 m forward, capped at 7 m |
| Follow car | 48° | Car heading, smoothly delayed, capped at 60°/s | Original bounded look-ahead |
| Look ahead | 56° | Fixed world yaw, 18° | Velocity × 0.4 s + 2 m forward, capped at 9 m |

Follow-car rotation eases over the shortest arc at 3.5/s, with a hard **60°/s** speed limit. Large heading gaps no longer produce proportionally faster camera rotation; a 180° correction takes at least three seconds, plus final easing. Look-ahead smooths its offset separately at **2/s** (about 0.35 seconds for half an offset change), while normal car-position tracking retains its existing 9/s response. These are initial feel values for owner testing. Look-ahead uses actual travel velocity with a small heading bias, includes reverse motion, and recenters gradually when stopped. Both views remain orthographic and overhead, without a horizon. Whole-scene baseline extent is 35/1.15 m at low speed or with Speed zoom off; enabled speed zoom adds a bounded pullback described below. HUD, mesh and collision scale are unchanged. Restart, mode switches and rewind snapshots reset translation, yaw, look-ahead and zoom together; these explicit discontinuities bypass ordinary smoothing/rate limits.

Open **Settings → Camera**, select a view and **Apply settings**. During racing or creator practice, use **Pause → Settings → Camera** to change it immediately, or press **C** to cycle Overhead → Follow car → Look ahead. Race changes retain the attempt and save the preference when a local store is available. A failed write reports that the view applies to the current race; it retains the previous committed preference. Settings selection/reset stages until Apply. Reset camera preserves controls; Reset controls preserves the camera.

`camera_mode` is an optional allowlisted enum in the existing local records schema 2; missing values default to Overhead. `camera_speed_zoom` is an optional boolean, defaulting to enabled. `camera_speed_zoom_strength` is an optional finite number from 0.0 to 0.5, defaulting to 0.30; the current stronger pullback is described in the 2026-10-08 section below. Camera preferences use a separate local-store reference from track ratings so authenticated/backend races also load/save them. Physics 0.49, rules v16, compiler 20, replay data and record partitions were unchanged by the original camera task. The blueprint camera/reference files remain historical calibration specifications; the explicit owner overrides are recorded in AGENTS.md.

## Changed files

- `game/camera/camera_profile.gd`, `follow_camera.gd`: isolated view profiles and delayed yaw response.
- `game/core/game.gd`, `app.gd`: preference injection, race switching and C shortcut.
- `game/ui/settings_page.gd`, `race_pause_menu.gd`: staged camera choices, scoped reset and immediate race dropdown.
- `game/persistence/local_records.gd`: optional camera-mode validation and existing atomic persistence.
- `game/tests/test_camera_modes.gd`, `capture_camera_modes.gd`, `capture_settings.gd`: camera/frame/persistence/lifecycle checks and comparison evidence, with generated `.uid` files for new scripts.
- `scripts/dev.ps1`: TestCameraModes/CaptureCameraModes entrypoints and camera checks in full Validate.
- `AGENTS.md`, this file, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`: owner override and actual verification record.

## Initial implementation commands and outcomes

All engine actions used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the pinned `4.7.2.stable.official.ed1daf0bf`; the Godot PATH alias was not used.

| Action/arguments | Actual result |
|---|---|
| `-Action CheckScript -ScriptPath res://core/game.gd` | Exit 0 |
| `-Action TestCameraModes` | Final 1,131 checks, 0 failures; initial 1,129 also pass |
| `-Action TestScript -ScriptPath res://tests/test_camera_shake.gd` | 7 checks, 0 failures |
| `-Action TestRecords` | 54 checks, 0 failures |
| `-Action CaptureSettings` | 181 checks, 0 failures; twelve three-size Settings captures |
| `-Action TestRewind` | 57 checks, 0 failures |
| `-Action CapturePause` | 17 checks, 0 failures, including frozen overlay/resume |
| `-Action TestMenus` | 48 checks, 0 failures |
| `-Action Import` | Exit 0; emits pre-existing Target SDK/build-tools fallback notice |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 252 scripts, 0 failures |
| `-Action CaptureCameraModes` | Final exit 0; nine comparison, three delayed-turn and two pause-selector captures |
| `-Action Doctor` | Pinned engine/templates found; DN2103 attached |

Camera checks cover 30/60/120 fps yaw response, ±179° wrap, snap/shake recovery, reverse/stopped/18/55 m/s travel, four headings, ground/4 m bridge elevations, and 960×540/1280×720/1600×720 framing. They exercise atomic reload, invalid values, write failure, real pause selection, C cycling, restart retention, unchanged canonical state/gates and unchanged record keys. Settings captures exercise actual touch actions, staged Apply, category switching, reset isolation and saved camera reload. These checks establish local behavior and bounds; they do not constitute a complete camera-driven lap or physical-device acceptance.

Desktop evidence is in [evidence/camera-options-2026-10-03](evidence/camera-options-2026-10-03). Comparison captures use the same Over and under fixture/car pose and seeded 22 m/s presentation state; turn frames hold position and change heading by 90° to show delay. They are diagnostic presentation captures, not scored races. Selected comparison, delayed-turn, compact/wide and Settings/pause captures were visually inspected. A scoped patch checkpoint is retained alongside the evidence; the shared workspace already contains substantial unrelated changes, so no mixed-workspace commit was made.

## Remaining acceptance and limits

Owner driving acceptance remains for rotation delay, lower-angle readability, look-ahead strength and comfort through tight hairpins/drifts/bridges. DN2103 was attached, but no Android export/install, device driving, device GPU/frame-time or thermal test was performed. No backend/service deployment, full Validate or full replay/regression gate was run for this presentation change. Headless camera integration exits 0 with an ObjectDB leak warning (four instances initially, three in the final run); graphical captures and the existing rewind/pause checks exit cleanly.

## Owner motion correction — 2026-10-03

The owner reports excessive Follow-car rotation and then requests slower Look-ahead movement relative to the car. V01/V05 authorize both presentation corrections; V04/Q01 still require owner/device acceptance. Changed files for this follow-up are `game/camera/camera_profile.gd`, `follow_camera.gd`, `game/tests/test_camera_modes.gd`, `capture_camera_modes.gd`, this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`. The original menus, selection/persistence, Overhead settings and canonical contracts are retained.

The reproduced 175° heading change peaked at **578–604°/s** across 30/60/120 fps. The new per-frame shortest-arc clamp permits at most elapsed time × 60°/s and still eases toward alignment. Look-ahead has an independent filtered offset, so changing travel direction/accelerating/decelerating/stopping moves the framing more gently around the car, with the usual position response preserved. Both filtered states reset on existing snap paths.

Actual commands used the same pinned `scripts/dev.ps1` entrypoint:

| Action/arguments | Result |
|---|---|
| `-Action TestCameraModes` before the cap | 1,150 checks, 16 failures, reproducing excessive yaw speed |
| `-Action TestCameraModes` first cap pass | 1,150 checks, one convergence-deadline failure; all cap checks pass |
| `-Action TestCameraModes` after convergence check correction | 1,151 checks, 0 failures |
| `-Action TestCameraModes` after slower offset | **1,269 checks, 0 failures**; existing three-instance shutdown leak warning |
| `-Action TestScript -ScriptPath res://tests/test_camera_shake.gd` | Final 7 checks, 0 failures |
| `-Action TestRewind` | Final 57 checks, 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | Final 254 scripts, 0 failures; earlier cap-only run 252 passes |
| `-Action CaptureCameraModes` | Final exit 0: nine comparisons, five limited-yaw frames, four delayed-offset frames, two pause-selector captures |
| `-Action Doctor` | Matching engine/templates, DN2103 attached |

The first cap pass exposed a test timing assumption: a capped large turn needs its full bounded rotation time plus final easing. The convergence check now allows four seconds, retains its alignment threshold and additionally checks monotonic approach/no overshoot; none of the speed-limit assertions were removed or relaxed. New checks cover both turn directions, frame rates, uneven/zero/negative render deltas, bounded offset interpolation, gradual direction changes, unchanged position response and stale-offset recovery on snap.

Updated desktop captures are in [motion-correction](evidence/camera-options-2026-10-03/motion-correction); the earlier uncapped evidence is retained. Follow-car and Look-ahead turn sequences were visually inspected. The turn fixtures hold position and change car heading/velocity at one tick to expose camera response; they are diagnostic captures, not complete raced laps. `motion-correction/camera-motion.patch` is a scoped checkpoint against the pre-correction shared workspace, checked with `git apply --reverse --check`; no mixed-workspace commit was made. Actual patch preparation and whitespace checks use Python `difflib` and `git diff --check`.

No Android export/install/device driving or phone performance measurement, backend/service action, full Validate or complete replay gate was performed. Owner acceptance of the 60°/s maximum and gentler Look-ahead response remains.

## Speed-dependent pullback — 2026-10-03

The original 12% bound in this historical section is superseded by the owner's stronger, configurable pullback below.

The owner additionally requests a slight camera pullback at faster speeds. This explicitly authorizes dynamic whole-scene magnification under V01, with V03 covering the comparison controls and V04/V05/Q01 retaining visibility, presentation-only behavior and physical-device acceptance. Speed zoom defaults **On** and works with Overhead, Follow car and Look ahead. Set **Settings → Camera → Speed zoom** and Apply, or use the immediate **Pause → Settings → Speed zoom** switch. The preference survives a new race/relaunch and camera-mode changes. Reset camera restores Speed zoom On; Reset controls preserves it. Disabling while driving eases back to the baseline view.

Speed zoom uses actual planar speed magnitude, including reverse driving. The desired pullback is zero through **30 km/h**, follows a smoothstep curve up to **160 km/h**, and stops at **12% more linear visible world extent**. A separate **1.5/s** exponential response eases acceleration/braking changes (about 0.46 seconds halfway toward a fixed zoom target). Orthographic extent changes from about **30.43 m to 34.09 m**, while camera height/distance also increases proportionally with pitch/yaw retained. Car projected dimensions remain at least **89.3%** of the baseline, with HUD/physical dimensions unchanged. No runtime networking, physics, timing, replay or record-partition change is involved.

Follow-up changed files: `game/camera/camera_profile.gd`, `follow_camera.gd`, `game/core/game.gd`, `game/persistence/local_records.gd`, `game/ui/settings_page.gd`, `race_pause_menu.gd`, `game/tests/test_camera_modes.gd`, `capture_camera_modes.gd`, `capture_settings.gd`, `AGENTS.md`, this document, `DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md`.

Actual actions used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` with the pinned engine:

| Action/arguments | Actual result |
|---|---|
| `-Action TestCameraModes` | **1,332 checks, 0 failures**; existing four-instance shutdown leak warning |
| `-Action CaptureSettings` | **190 checks, 0 failures**, including actual touch staging, Apply/reload, scoped reset and three-size toggle captures |
| `-Action CaptureCameraModes` | Exit 0; **31 captures**, including eight same-fast-pose zoom On/Off comparisons and three easing frames |
| `-Action TestRecords` | 54 checks, 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_camera_shake.gd` | 7 checks, 0 failures |
| `-Action TestRewind` | 57 checks, 0 failures |
| `-Action CapturePause` | 17 checks, 0 failures, including frozen overlay behavior |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 257 scripts, 0 failures |
| `-Action Doctor` | Matching engine/templates, DN2103 attached |

The existing exact fixed-magnification assertions are retained with Speed zoom explicitly disabled. New checks cover baseline preservation at low speed, monotonic coverage and upper bound, projected-car readability, reverse travel, gentle acceleration/braking and stopping, 30/60/120 fps equivalence, zero/negative render deltas, smooth opt-out, snap recovery, saved/off defaults, invalid types, pause toggle and failed persistence. Camera-mode/race-state checks continue to pass. This is the owner-requested extension to the constant-framing contract, not removal of calibration coverage.

Final desktop evidence is in [speed-zoom](evidence/camera-options-2026-10-03/speed-zoom), including three copied Camera-settings screenshots. On/Off comparisons, the compact/wide views, Settings and pause switch were visually inspected. Comparison pairs use the same car position/heading and seeded 55 m/s velocity; their only camera difference is Speed zoom. These are diagnostic presentation captures, not scored laps. A task-scoped `speed-zoom/camera-speed-zoom.patch` checkpoint is retained and checked with `git apply --reverse --check`; substantial unrelated workspace edits remain outside it. No mixed-workspace commit was made.

Owner feel/readability acceptance remains for zoom amount and easing during actual driving. DN2103 was attached, but no Android export/install/device driving, physical-device performance/thermal measurement, full Validate/replay gate or backend/service deployment was performed.

## Stronger configurable speed zoom — 2026-10-08

The owner requests a stronger speed-dependent zoom and configurable effect strength. Requirements: **V01** whole-scene camera framing, **V03** Settings/pause controls, **V05** presentation/canonical separation, and **V04/Q01** visual/device acceptance and verification. This supersedes the previous 12% maximum for enabled speed zoom; the 1.15x low-speed/disabled calibration remains available.

The default maximum pullback is now **30% extra linear world coverage**, 2.5 times the previous effect. **Settings → Camera → Zoom strength** offers **0–50% in 1% steps**, staged until **Apply settings**. **Pause → Settings → Zoom strength** applies to the current race immediately and saves on drag release; keyboard changes also save. Previewing a drag does not write the records file for every movement. The numeric label updates with the slider. Turning Speed zoom off disables the slider while retaining its strength. Reset camera stages On/30%; Reset controls preserves the camera settings.

The existing 30–160 km/h smoothstep and 1.5/s easing are retained for all three views, including reverse travel. The default full-speed extent is **39.57 m** rather than the old 34.09 m, from the calibrated 30.43 m baseline. At the selectable 50% bound it is 45.65 m. Projected car dimensions are approximately 76.9% of the fixed view at the default maximum and 66.7% at the strongest maximum. Changing strength eases from the current view; it does not reset camera state. Runtime values are clamped to the finite range; invalid persisted types, nonfinite numbers and out-of-range values are rejected by the schema-2 atomic store. Missing strength in existing profiles defaults to 30%, with no player-file rewrite or schema-version bump.

Changed files:

- `game/camera/camera_profile.gd`, `follow_camera.gd`: shared default/bound and per-camera strength, independent of the selected view.
- `game/core/game.gd`: preference loading and session-preview/commit API.
- `game/persistence/local_records.gd`: optional numeric preference validation in the existing schema.
- `game/ui/settings_page.gd`, `race_pause_menu.gd`: percentage controls, staged/reset behavior and pause persistence.
- `game/tests/test_camera_modes.gd`, `capture_settings.gd`, `capture_camera_modes.gd`: updated bounds, actual Settings touch input, persistence/failure/drag checks and four-strength captures.
- `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, this document: owner override, commands, evidence and limits.

Actual commands used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and pinned **4.7.2.stable.official.ed1daf0bf**, with `APPDATA=build/camera-strength-user`. Graphical camera capture also set `BMT_CAMERA_EVIDENCE` to `docs/evidence/camera-strength-2026-10-08/camera`. Successful runtime checks used Windows certificate-store access outside the sandbox.

| Action/arguments | Actual final result |
|---|---|
| `-Action TestCameraModes` | **1,499 checks, 0 failures**; 29 ObjectDB instances reported at shutdown |
| `-Action CaptureSettings` | **278 checks, 0 failures**; three-size captures and real touch adjustment/staging/reload/reset/failure coverage |
| `-Action CaptureCameraModes` | Exit 0; **39 captures**, including 0/12/30/50% comparisons, easing and pause controls |
| `-Action TestRecords` | 54 checks, 0 failures |
| `-Action TestRewind` | 57 checks, 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_camera_shake.gd` | 7 checks, 0 failures |
| `-Action TestApp` | 99 checks, 0 failures |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | 360 scripts, 0 failures |
| `git diff --check -- <task files>` | Passed; existing CRLF normalization notices only |

Camera coverage retains exact disabled/slow calibration and canonical state/gate/record-key assertions. It checks monotonic zoom through the selected strength, all views, ground/bridge car visibility in four headings at maximum strength, the overhead angle, reverse travel, 30/60/120 fps easing, smooth adjustment/opt-out, zero/negative deltas, snaps, invalid runtime/persisted values, mode/restart retention and committed-preference rollback. Settings checks prove a reachable 52-pixel slider at 960×540/1280×720/1600×720 and actual input through `Input.parse_input_event`; this uses the engine's touch-to-mouse input path ([official Input documentation](https://docs.godotengine.org/en/stable/classes/class_input.html)).

Initial sandbox runs failed on user-data/certificate-store access. The first implementation run exposed a nonexistent `HSlider.is_dragging` call and a float32 boundary comparison; explicit drag signals and an exact clamp assertion plus the established camera-size tolerance correct them. The first Settings run had three failures: directly pushing synthetic touch to the viewport bypassed the slider's input-emulation path, and later size fixtures incorrectly expected the untouched default after a saved preference change. The final test uses actual engine input and checks the current preference. The first simultaneous graphical capture was visually invalid because window focus loss paused the race; the final camera capture ran with one graphical window and all retained comparison/pause images were rechecked. No failed invariant was removed to hide a runtime defect.

Evidence: [desktop Settings](evidence/camera-strength-2026-10-08/settings/settings-camera-1280x720.png), [compact Settings](evidence/camera-strength-2026-10-08/settings/settings-camera-960x540.png), [compact pause](evidence/camera-strength-2026-10-08/camera/pause-camera-960x540.png), and same-pose compact [old 12%](evidence/camera-strength-2026-10-08/camera/look_ahead-fast-12-percent-960x540.png), [new 30%](evidence/camera-strength-2026-10-08/camera/look_ahead-fast-30-percent-960x540.png), [maximum 50%](evidence/camera-strength-2026-10-08/camera/look_ahead-fast-50-percent-960x540.png). These use a stationary presentation pose with seeded 55 m/s speed, not scored laps. Settings size captures after the preference exercise show its saved 22% value. Selected desktop/compact and pause/comparison images were inspected. Task-start sources, logs, hashes and a reverse-checkable scoped Git patch are retained in the evidence folder; unrelated workspace changes are excluded.

Physics **0.53**, rules **v20**, track/compiler data and player record partitions remain unchanged. No backend/deployment action, Android export/install, phone test, phone attachment check, full Validate or complete replay gate was performed. Owner driving acceptance remains for the default amount, maximum car readability, easing through braking/hairpins/bridges, and phone frame pacing/thermal behavior. The camera test's 29-instance shutdown warning remains a limitation; graphical Settings/camera captures and the other focused checks exit cleanly.
