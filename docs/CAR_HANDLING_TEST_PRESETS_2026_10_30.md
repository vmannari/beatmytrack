# Car handling experiments — 2026-10-30

HT01: Keep the accepted Compact handling intact. HT02: Offer five distinct handling experiments for each of the five other active cars. HT03: Make them quick to compare from the race view. HT04: Keep experimental results and creator validation out of canonical records.

## Research and design

[Nintendo's Mario Kart 8 Deluxe beginner guide](https://www.nintendo.com/jp/ichikara/aabpa/index_en.html) describes drifting, visible feedback and optional driving assists. [Activision's Crash Team Racing Nitro-Fueled tips](https://support.activision.com/crash-team-racing/articles/crash-team-racing-nitro-fueled-gameplay-tips) describe power slides and timed boosts. [EA's Need for Speed Unbound tuning overview](https://forums.ea.com/discussions/need-for-speed-unbound-discussion-en/under-the-hood-show-up-and-show-off/9398276) offers steering sensitivity and grip-to-drift adjustment; its [later handling update](https://forums.ea.com/discussions/need-for-speed-unbound-discussion-en/vol-6-0-1-head-to-head---patch-notes/9385397) emphasizes progressive grip loss and smoother transitions. These are design references, not measurements or reproductions of those games. The experiments use this game's existing input and physics model; they do not add drift boosts or automatic steering.

Each car has separately authored **Stable**, **Agile**, **Flow**, **Slide** and **Loose** settings, ranging from greater stability and steering responsiveness to more lateral movement. The exact steering, grip and recovery settings are in `game/vehicle/handling_test_presets.gd`. Engine, brakes, speed limits, collision dimensions and vehicle-specific controls remain those of the original car. The Hovercraft uses its own thrust damping and yaw tuning. The baseline resources and Compact remain unchanged.

In eligible race and editor-practice views, the dropdown contains the current handling and five experiments. A change restarts the attempt. Experimental runs are practice: they cannot save personal bests, upload a result, spend ticket-based rewind credits or validate a creator track. An already-issued race ticket is retired on entering an experiment. Returning to current handling restarts again; a fresh online race must be entered to obtain a new ticket. Rivalry, challenge and tutorial races do not expose the selector, protecting their issued contracts and limited attempts.

## Verification and limits

Pinned Godot 4.7.2 stable `ed1daf0bf`, isolated APPDATA/LOCALAPPDATA, offline:

- `--headless --path game --script res://tests/test_handling_test_presets.gd`: 15,167 checks, zero failures. All 25 candidates have distinct sampled trajectories, finite state, exact repeated simulation and recovery after release in the sampled maneuver; Compact and baselines match their existing snapshots. Sampled peak slip ranges from 4.7–12.2° for Pickup, 5.2–14.5° for Kart, 17.3–24.7° for Forklift, 4.9–29.2° for Electric and 29.2–72.6° for Hovercraft. These are controlled simulation samples, not a claim of enjoyable driving or complete track coverage.
- `--headless --path game --script res://tests/test_handling_test_integration.gd`: 16 checks, zero failures, covering selection, restart, countdown visibility, Compact and competitive restrictions, rewind and creator validation.
- `--headless --path game --script res://tests/test_handling_test_app.gd`: four checks, zero failures, covering ticket retirement, practice results, personal bests and upload queue.
- `--headless --path game --script res://tests/test_handling.gd`: 88 checks, zero failures, including existing deterministic replays.
- `--headless --path game --script res://tests/test_driving.gd`: 72 checks, zero failures, including input, restart and replay.
- `--headless --path game --script res://tests/test_handling_test_selector.gd`: 23 checks, zero failures for the HUD choices and selection signal.
- `--path game --rendering-method gl_compatibility --script res://tests/capture_handling_test_race.gd`: actual Electric race views at 960×540 and 1280×720, zero failures. Mouse input opens the dropdown and selects a preset at each size; the attempt restarts as practice. [960×540 open dropdown](evidence/car-handling-test-presets-2026-10-30/race-open-960x540.png), [1280×720 race](evidence/car-handling-test-presets-2026-10-30/race-1280x720.png). The capture used isolated APPDATA/LOCALAPPDATA and `BMT_HANDLING_TEST_CAPTURE` pointing to its output directory. It logged race hitches.

The isolated Windows runs reported a root certificate-store warning; the preset test also reported resources still in use at exit. No network was required for these tests. Human driving-feel acceptance and physical-device input/performance remain open; no device test was performed. No backend deployment, APK, owner-save mutation or process restart was performed.
