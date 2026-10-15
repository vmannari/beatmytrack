# Desert bank and deeper-sand sound — 2026-10-14

The owner reports Grass-style “thud-thud-thud” sounds in Desert and requests a sound appropriate to deeper sand. DSND01 removes hard concrete kerb feedback from Desert; DSND02 adds a fuller continuous sand response; DSND03 preserves existing Grass kerbs, car sounds, lifecycle, bounds and canonical driving. Existing SND12/SND13, G01/R01 and Q01 remain applicable.

The fault had two paths: `VehicleAudio._observe_surfaces()` dispatched the shared chassis entry thud over raised Desert bank geometry, and `present()` fed that geometry into the repeating `kerb_roll` loop. Desert now clears/excludes both paths. Actual crashes, scraping, gear changes and landings keep their original behavior.

The existing four-wheel surface query additionally measures presentation-only `sand_depth`: compacted road is zero, shoulders are half-depth, and loose sand or a raised sand-bank contact is full-depth per wheel. Ground banks are excluded on decks. Depth is reset and copied through the existing same-callback weathering contact reuse; there are no extra surface queries or canonical state fields. Existing sand loops smoothly add rolling body and soft spray with a small downward tone change, while granular stone detail becomes quieter. The compacted road mix and other biomes retain their previous gains and pitch.

No sound asset or source recording is added or remastered: all **118 vehicle-bank files remain SHA-256 exact**. The original **23 players**, six event slots and 24 MiB stream-cache cap remain. No physics, handling, camera, tire marks, dust, local condition, scoring, backend, export or deployment change is included.

## Actual validation

Run from the repository using the pinned 4.7.2 engine through `scripts/dev.ps1`; `build/run_desert_soft_sand.ps1` isolates APPDATA and retains logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Renderer gl_compatibility -Baseline -Capture
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Renderer gl_compatibility -Capture
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Renderer mobile -Capture
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Headless -Check test_desert_audio
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Headless -Check test_grass_kerb_audio
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Check test_racing_render_audio_regression
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Headless -Check test_continuous_desert_audio
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_desert_soft_sand.ps1 -Headless -Check test_script_parse
python build/review_desert_soft_sand.py
python build/checkpoint_desert_soft_sand.py
```

- Baseline: 25 checks pass, reproducing an entry thud and hard bank rumble for all five cars. Recorded hard-rumble peak is 0.5104 linear.
- Final dedicated test: **72 Compatibility + 72 Mobile/Vulkan checks**, zero failures, both processes exit cleanly. Covers all five cars, raised-bank riding, actual canonical crossings with coarse presentation, exact driving snapshots, loose terrain, theme changes, shared contacts, deck/air/roll/water/blocked/countdown/pause/rewind and retained actual crash dispatch.
- Original Desert: **25** checks; Grass kerbs: **76**; continuous Desert: **28**; native vehicle bank/lifecycle/canonical regression: **1469**. All pass. The original Grass Game callback still dispatches two crossing bumps and a 0.6012 rumble peak.
- Project parser: **758 scripts**, zero failures, clean exit. Scoped patch whitespace check passes.
- Both final native mixer recordings have exactly zero hard kerb audio, exactly silent final pause, no clipping or gaps in measured steady sand segments. The sand mix is **12.89–14.35 dB below the engine** in the controlled road/bank/loose-sand segments; bank/deep sand carries more energy than the compacted road. Full output peaks are −13.68/−13.89 dBFS. These are desktop digital measurements.

## Listening artifacts and limitations

[Before: full vehicle audition](evidence/desert-soft-sand-2026-10-14/before/gl_compatibility/driving.wav) · [After: full vehicle audition](evidence/desert-soft-sand-2026-10-14/after/gl_compatibility/driving.wav) · [After: isolated sand](evidence/desert-soft-sand-2026-10-14/after/gl_compatibility/sand.wav) · [Vulkan after](evidence/desert-soft-sand-2026-10-14/after/mobile/driving.wav) · [Numerical audio report](evidence/desert-soft-sand-2026-10-14/audio-review.json).

The controlled audition holds 18 m/s: road 0–2 s, bank 2–5 s, road 5–6 s, loose sand 6–9 s, stop at 9 s and pause at 10 s. Fixed contact placement isolates the sounds; the separate automated tests execute actual vehicle simulation and crossing callbacks. This is not a phone or subjective listening acceptance claim.

Initial restricted native startup could not read the Windows certificate store; the process was stopped by the launcher, then the automatically approved native run passed. An initial headless vehicle test failed its playback-pause assertion because ordinary headless players are disabled; the existing graphical regression wrapper exercises real playback and retains the original assertion, passing all 1469 checks. The first blend's bank energy was marginally below road energy, so that failed measurement and both recordings are retained under `first-blend/`; the final blend passes the same assertion. A diagnostic inline Python command hit PowerShell quoting and produced no measurement; the checked Python file replaces it. Initial attempts are not counted as passes.

Changed runtime: `game/vehicle/vehicle_audio.gd`, `game/vehicle/surface_audio_model.gd`. Added dedicated test: `game/tests/test_desert_soft_sand_audio.gd`. Supporting runner/review/checkpoint live in `build/`; instructions, development status and plan have the scoped follow-up. The isolated two-commit Git checkpoint and task-only patch preserve the main repository index/branch and pre-existing work.

No phone test, APK, deployment or performance claim. Owner listening and physical-phone speaker/headphone balance remain acceptance checks.
