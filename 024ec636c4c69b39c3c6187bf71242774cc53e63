# Restore visible header car crossfade (2026-10-27)

HCF01: Restore a visibly staged car-picture crossfade. HCF02: Keep current equipped livery/kit caching, the stationary slot and the existing 0.24-second normal duration. HCF03/R01/Q01: Preserve rapid-selection, input/save, navigation, ownership and cleanup guards; retain the reproduction and a task-only checkpoint.

The original stock-picture suite still passes 556 checks, but it only requires alpha to remain between zero and one. A new actual-App case captures a saved equipped Compact livery and cowl/splitwing kit, switches away and back using the cache, then injects a 350ms main-thread stall. The task-start code presents the new car at roughly 93% opacity on the next frame: there is almost no visible crossfade left. The stronger unchanged-runtime regression fails one of 566 checks. This is a controlled slow-frame reproduction, not a trace of the owner's session.

`game/ui/profile_car.gd` now pauses the existing tween and steps it once per UI frame with at most 1/30 second of progress. Normal frames retain the 0.24s cubic crossfade; slow frames extend the blend so the outgoing image remains visible. Both images stay in their fixed slot. Processing stops when settled, hidden, resized or detached; a rapid sequence still resolves to the latest requested cached texture with at most two picture controls. No new rendering world, image capture, model or timer is introduced by the crossfade.

The retained `game/tests/test_header_car_icon_transition.gd` adds a real equipped-cache case and requires at least three presented intermediate frames with incoming alpha between 0.05 and 0.85 and outgoing alpha at least 0.15. It retains all original assertions, verifies the exact equipped endpoint and no extra model capture, and saves native start/middle/finished frames. Its fixture restores only its own isolated saved appearance before the original navigation tests.

Actual commands use the pinned Godot 4.7.2 runner with `APPDATA` and `LOCALAPPDATA` redirected to `build/header-crossfade-restore-appdata`. Each native run sets `BMT_HEADER_ICON_OUTPUT` to a distinct `res://../docs/evidence/header-crossfade-restore-2026-10-27/` subdirectory so historical evidence is preserved:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -Graphical -RenderingMethod mobile -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_header_car_icon_transition.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 180
```

Final Compatibility and desktop Mobile each pass 566 checks. In Compatibility, incoming alpha after the forced stall starts at 0.361 instead of 0.928, and all seven sampled frames retain a clear blend. Actual headless/parser counts, native alpha samples, logs, source hashes and scoped-patch checks are recorded in [the evidence report](evidence/header-crossfade-restore-2026-10-27/report.json). Only the profile-picture widget and its regression change at runtime/test level; App, appearance-cache service, dropdown, assets, model factory, camera, simulation and concurrent work remain unchanged by this task.

Review [the visible intermediate blend](evidence/header-crossfade-restore-2026-10-27/final-review/gl_compatibility/equipped-fade-middle.png) and the corresponding start/finished frames. Reload is required. Owner/device motion and frame-time acceptance remain. No physical-device attachment check or device test, APK, authentication/purchase, owner-save/live mutation, deployment, staging, commit, merge or owner-process restart was performed.
