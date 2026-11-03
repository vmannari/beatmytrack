# Pause and main-menu settings review — 3 November 2026

Evaluation only. Recommendation: use one settings model and reusable category controls, with a race presenter that applies supported changes to the paused game. Keep the compact pause landing menu, but give Settings enough room for the same categories, terminology, values and Apply/reset behavior as the main menu.

## Requirements and scope

- PSM01: Compare the actual pause and main-menu settings, including persistence and runtime effects.
- PSM02: Identify justified context differences and accidental drift.
- PSM03: Propose a bounded harmonisation and its acceptance checks.

Runtime sources, player data and export settings were not intentionally changed. This task adds this review document. The existing development test entry point also regenerated `game/core/build_identity.gd`; that file already had concurrent changes and was not restored or included in the review checkpoint. No device query/test, APK, backend/live access, deployment, owner-process change or main-index write was performed.

## Current comparison

| Area | Main settings | Pause settings | Recommendation |
| --- | --- | --- | --- |
| Camera | Three named views, descriptions, Speed zoom, 0–50% strength | Same shared camera choices and strength; dropdown instead of cards | Reuse category controls and wording; apply to the current camera while paused |
| Ghosts | Personal best lap, best race, Off | Same personal modes, only when a ghost presenter exists | Keep availability contextual; distinguish personal recordings from Rivalry/challenge opponents |
| Audio | Saved Music, Vehicle and Interface sliders | One session-only Sound switch mutes Master | Expose the same three saved sliders in both; resolve existing Master mute when replacing the switch |
| Controls | Steering method, control labels, layout customisation, keyboard reference | Steering method only | Share steering, labels and reference; support layout editing through a pause-safe return route |
| Haptics | Off/Light/Medium/Strong steering feedback and drift feedback switch | Absent | Expose both and update current touch/drift feedback on Apply |
| Graphics | Shadow quality, 3D resolution, anti-aliasing, simpler models | Absent | Expose the same choices with an explicit deferred-effect notice |
| Language | Immediate language picker | Absent | Reasonable to retain outside the driving subset initially; parity can follow with verified locale refresh |
| Account, privacy, licences, development | Full management and service actions; development debug-gated | Absent | Keep management in main settings for the first slice; preserve existing access routes |
| Help | Tutorials and feature help, diagnostic report | Separate driving-help page | Keep quick driving help in pause; tutorial navigation needs its own lifecycle handling |
| Saving | Draft across categories, explicit Apply; per-category staged reset | Immediate camera/zoom/ghost/steering effects and attempted saves; no Apply/reset | Adopt the existing staged Apply model in both settings surfaces |

Sources: `game/ui/settings_page.gd:44`, `:83`, `:210`, `:282`, `:377`, `:447`, `:502`, `:517`, `:548`, `:627`, `:652`; `game/ui/race_pause_menu.gd:164`.

## Findings that affect harmonisation

### PSM-F01 — Steering uses the wrong persistence dependency

The pause steering callback writes through `game.rating_records` (`race_pause_menu.gd:255`). App intentionally sets that to null for cloud tracks and tutorials, while assigning `preference_records` independently (`app.gd:4770`). Camera and ghost setters already use `preference_records` (`game.gd:965`, `:1007`). Consequently a steering choice can change the current touch layout without saving on cloud tracks, even though other driving preferences save there. There is no success/status update for that path. Use the same preference store for all settings, independently of rating eligibility.

This is established by source inspection; it was not reproduced in a completed runtime test during this review.

### PSM-F02 — The two audio surfaces control different layers

Pause Sound changes `AudioServer` bus 0, immediately and without persistence (`race_pause_menu.gd:166`). Main Apply changes the Music, Vehicle, Impacts and Interface buses through `GameSoundtrack.apply_settings` (`soundtrack/audio_world.gd:113`). It does not clear Master mute. Therefore the app can return to main settings with nonzero volume sliders while Master remains muted. Turning Sound on also cannot override a child bus deliberately set to zero.

Use the existing saved channel preferences for parity. A new saved master-volume preference would be a separate product addition; this review does not require one. A migration of the current session mute state must be deliberate when the old switch is removed.

### PSM-F03 — Opponent ghosts are a different context

Rivalry and challenge race installation replaces `ghost_mode` and `ghost_bests` with the selected opponent's race recording (`app.gd:4802`; retry does likewise). The generic pause dropdown still offers personal lap/race choices, and `set_ghost_mode` writes the personal global default. Choosing a lap in a race-only opponent context can select a mode with no recording and change an unrelated saved preference.

Recommendation: personal modes use the saved personal preference; an opponent context gets an explicitly labelled opponent visibility control scoped to that attempt. Do not substitute an opponent recording or overwrite the personal default merely to make the two menus look identical.

### PSM-F04 — Graphics need truthful timing

Graphics and simpler models are read during Game setup (`game.gd:182`, `:251`). Retry reuses the Game node (`app.gd:5439` onward); `restart()` does not rebuild the graphics/model configuration. Adding the controls to pause alone would not apply them on Restart.

For the first slice retain deferred application and say “Applies when you leave and start another race.” If “next attempt, including Restart” is desired, implementing safe reconfiguration is additional work. Preserve platform AA filtering and resolution caps from the existing graphics controls.

### PSM-F05 — Shared controls need a wider race settings surface

The current pause drawer clamps to 340–470 logical units (`race_pause_menu.gd:57`). Main settings have a 292-unit category sidebar plus wider content rows. Directly mounting the unchanged main page in the drawer would not fit. Pause Sound and Steering also lack the explicit 52-unit minimum already used by camera/ghost controls and main settings; actual current hit-target sizes were not measured here.

Retain the compact Resume/Restart/Settings/Help/Quit landing drawer. Open Settings in a larger overlay over the frozen race, using shared rows/cards with a compact category navigation at narrow widths. Keep Back/Apply reachable independently of content scrolling. Test actual geometry before choosing final dimensions.

## Recommended implementation contract

1. Share draft creation, validation, category resets and atomic preference saving. Keep the existing settings keys/defaults and unrelated data. Avoid duplicating option lists and save callbacks in two UI scripts.
2. Reuse category content for Controls, Camera, Graphics, Ghosts, Audio and Haptics. Use the main menu's terminology, including “Analog slider” and “Analog joystick.” Adapt layout to available space rather than copying the full main-menu shell.
3. Keep a race-specific presenter separate from the settings view. After a successful Apply, update camera mode/zoom, touch layout/labels/haptic strength, drift-feedback enablement, audio buses and the applicable ghost view. Do not launch App/account navigation or recreate the race to edit preferences.
4. Use staged edits in both menus. Apply commits all edited categories, and category Reset changes only the draft. Opening Settings, switching categories and applying keep the race paused. Back returns to pause; define explicit discard/keep-editing behavior for dirty drafts. Closing pause must use the same draft-exit policy.
5. Preserve atomic save failure recovery. Keep drafts for retry and report the failure; ensure runtime state agrees with the chosen Apply policy. Current camera setters intentionally allow session changes after failed saving, so changing this behavior needs regression coverage. If live previews are added later, snapshot/restore them on discard and failure.
6. Layout customisation must return to the same paused settings category and retain race/ticket/countdown state. Existing main customisation calls Apply before opening its editor (`settings_page.gd:674`); preserve or explicitly redesign that commit boundary.

Suggested order: fix persistence/audio consistency; extract shared preference handling and categories; add the pause settings shell and live presenter; then integrate layout editing and contextual opponent ghosts. No backend or competitive-contract change is needed for the proposed presentation/settings slice.

## Verification and remaining acceptance

Source inspection covered both UI builders, Game camera/ghost setters, race installation/retry, touch layout assignment, graphics policy, soundtrack bus application and `LocalRecords.save_records` rollback. Save rollback already exists in `local_records.gd:109`, `:162`; it should be reused rather than replaced.

Actual regression attempt, with isolated APPDATA and crash-dialog suppression around the development entry point:

```powershell
$env:APPDATA = Join-Path (Get-Location).Path 'build/pause-settings-review-2026-11-03/appdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$env:BMT_API_URL = ''
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_camera_modes.gd -CommandTimeoutSeconds 180
```

The pinned engine reported `4.7.2.stable.official.ed1daf0bf`. The command exited 1 with `Failed to read the root certificate store` and `Access denied`, without the camera suite's completion/count line. This is an unsuccessful test attempt, not a regression pass. Log: `build/logs/TestScript-29072/test-script.log`. No fresh runtime captures were produced; historical images were not treated as current verification. No runtime/UI implementation was made.

Required checks for implementation:

- Both surfaces show equal committed values; changes persist in both directions after reopening/reloading. Include cloud/local tracks and a missing preference store.
- Apply/reset/discard and failed writes preserve unrelated settings and explicit runtime consistency. Verify slider drags do not write every intermediate value.
- Pausing/settings/layout editing never advance simulation ticks, countdowns, tickets, attempts or rewind state; Resume releases any stale touch ownership.
- Verify camera, labels, steering, both haptics and audio actually update in the existing Game, while graphics follow their declared timing.
- Distinguish personal, missing-recording and opponent ghosts; retain the selected opponent and personal default as appropriate.
- Native Compatibility and desktop Mobile captures at 960×540, 1280×720 and a wider landscape size, plus supported long translations. Check 52-unit targets, focus, dropdown bounds, scroll access, fixed actions and no overlapping panels. Physical-device touch/performance and owner appearance acceptance remain.

No passing runtime-test, current screenshot, phone-performance or implemented-harmonisation claim is made by this review.
