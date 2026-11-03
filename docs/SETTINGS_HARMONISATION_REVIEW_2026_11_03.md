# Pause and main-menu settings review — 2026-11-03

Evaluation only. Recommendation: use one settings interface and preference-saving path, opened from the main menu or above a paused race. Give both entry points the same driving categories, labels, values, Apply and category Reset behavior. Keep race lifecycle and account navigation separate.

## Scope and requirements

- SHR01: Inventory and compare the current options and their behavior.
- SHR02: Verify material persistence differences using disposable records.
- SHR03: Recommend a concrete shared interface and implementation sequence.
- R01/Q01: Preserve simulation, owner data/processes and concurrent changes; record actual evidence and limits.

No settings implementation was changed. Added files are this report, the evaluation probe `game/tests/review_settings_harmonisation.gd`, and evidence under `docs/evidence/settings-harmonisation-2026-11-03/`. No backend, deployment, device query/test, APK export, real account interaction or main Git index write was performed. Owner acceptance of the proposed design remains.

## What exists today

| Area | Main menu | Pause menu | Assessment |
|---|---|---|---|
| Controls | Buttons / Analog slider / Analog joystick; Show labels; Customize layout; keyboard reference | Buttons / Horizontal slider / Joystick only | Same three steering IDs, different names and presentation; missing label/layout access |
| Camera | Overhead / Follow car / Look ahead; Speed zoom; Zoom strength 0–50% | Same modes, toggle and range | Actual options already match; main uses cards and staged changes, pause uses immediate dropdowns |
| Ghosts | Off / Personal best lap / Personal best race | Same modes, only when a personal ghost node exists | Shared enum; contextual availability and opponent-ghost semantics need preserving |
| Audio | Saved Music / Vehicle / Interface levels, 0–100% | Sound: process-local Master bus mute | Different meanings and lifetimes; the largest semantic mismatch |
| Haptics | Steering Off / Light / Medium / Strong; Drift feedback | Absent | Useful during driving; should be shared |
| Graphics | Shadow quality; 3D resolution; anti-aliasing; Simpler car models | Absent | Could be shared with existing next-race behavior |
| Language | Installation-local selector; applies immediately | Absent | Reasonable to share if language refresh preserves the paused overlay |
| Help | Support diagnostics; tutorial replay; feature help | Separate driving-help page | Share driving information; keep tutorial launch outside active attempts |
| Account / Privacy / Licences | Available | Absent | Their absence is reasonable during racing; retain in main-menu navigation for the first slice |
| Development | Debug only; ad and purchase testing | Absent | Keep debug gating and main-menu-only placement |
| Saving | Draft across categories; Apply saves all drafts; Reset stages category defaults | Immediate live changes; camera/ghost/steering attempt writes; Sound is temporary | A single coherent contract matters as much as matching the list |

Sources: [main settings](../game/ui/settings_page.gd), [pause settings](../game/ui/race_pause_menu.gd), [camera definitions](../game/camera/camera_profile.gd), [ghost definitions](../game/race/personal_ghost_run.gd), [graphics policy](../game/presentation/graphics_preferences.gd).

The main-menu settings content has a fixed category panel and an Apply footer. Pause puts its settings in a scrolling drawer clamped to 340–470 logical units wide. At the reviewed 1280×720 and 960×540 sizes, Back and the saving explanation require scrolling. Expanding the option list inside this drawer would make navigation substantially longer. The existing main-menu row layouts also have wide minimum sizes, so embedding `SettingsPage` unchanged in the narrow drawer is unsuitable.

Main captures are the actual `SettingsPage` component mounted in a simple host, without the App shell. Pause captures use an actual Game and HUD. The probe pauses without capturing a frozen background, so these views demonstrate settings layout, not the production monochrome freeze effect.

## Confirmed behavior differences

### 1. Steering does not save through the correct store in cloud-style races

Pause steering writes through `hud.get_parent().rating_records`. The App deliberately sets this to null for cloud tracks and tutorial lessons while still passing `preference_records`. Garage free driving also passes the preference store separately. Camera and ghost setters correctly use `preference_records`.

The probe starts an actual Game with a valid preference store and no rating store. Changing pause steering to Horizontal slider updates the live controls, but reloading the saved profile still gives Buttons. Camera and ghost changes in that same fixture do persist. Supplying the local-rating store then allows steering to persist. This reproduces the store mismatch without making an online request or launching an actual cloud race.

On a failed local steering save, the live control remains Buttons while committed settings remain Joystick, and the UI reports `Could not save controls.` Camera and ghost have clearer session-only fallback wording. Share both the preference store and the error policy.

References: [pause steering](../game/ui/race_pause_menu.gd#L259), [App race setup](../game/core/app.gd#L4770), [camera/ghost setters](../game/core/game.gd#L965).

### 2. Pause Sound mute overrides the saved audio sliders

Pause calls `AudioServer.set_bus_mute(0, ...)` and does not save a setting. Main-menu audio changes the Music, Vehicle, Impacts and Interface buses through `GameSoundtrack.apply_settings`; it does not clear Master mute.

The probe disables pause Sound, reapplies valid nonzero saved audio levels through the actual soundtrack settings function, and confirms Master remains muted. There is no main-menu control representing this state. Source inspection also shows no Sound restoration when the pause menu closes; this can therefore carry into the rest of the running session. Restarting the process does not restore a saved mute preference because none is written.

Recommendation: replace the pause Sound switch with the same three saved volume controls. If a quick global mute is wanted later, expose it consistently in both menus using a single saved preference. Do not create a second independent mute state. Handle the legacy process-local mute explicitly when adopting the shared audio controls.

References: [pause audio](../game/ui/race_pause_menu.gd#L166), [saved audio UI](../game/ui/settings_page.gd#L517), [audio application](../game/soundtrack/audio_world.gd#L113).

### 3. Apply and live application are separate concerns

Main-menu Apply saves all drafts together and updates audio; the next Game reads camera, graphics and drift preferences at construction, and the App installs the saved touch layout, label visibility and steering feedback. Simply mounting that page above an existing race would save values without updating every live recipient.

Pause currently changes the live camera, zoom, ghost and touch layout directly, with camera-strength drag writes deferred until release. The simulation tree is not paused: Game owns its explicit `paused` flag. This allows UI operation while driving input and canonical simulation remain stopped. The harmonised interface must retain this pause model.

Main Customize layout currently applies drafts and calls an App handler that hides the shell and returns to Settings. Its editor has debounced autosaving. It cannot be wired into pause using that handler unchanged: it needs a paused-race return destination and must restore input only when the player resumes.

## Proposed experience

Keep the familiar small pause menu with Resume, Restart, Settings, Help and Quit. Selecting Settings opens a larger overlay over the still-paused race, using the main-menu settings visual language and shared content. Back returns to the pause menu; it does not resume or leave the race. Keep Back and Apply visible while category contents scroll. At narrow widths, use a category selector or category-list/detail navigation rather than squeezing the existing two columns into the drawer.

Use this shared order for driving preferences: **Controls, Camera, Ghosts, Audio, Haptics, Graphics**. Language can remain available in both once its refresh behavior is verified. Main-menu-only account/privacy/licences/development links follow the shared driving categories. Pause Help remains reachable separately.

Use identical text for the same values: **Analog slider**, **Analog joystick**, **Audio**, **Ghosts**, **Zoom strength**. Retain all current IDs, defaults, camera ranges and platform graphics restrictions.

For the first implementation, adopt the existing main-menu staging model in both places:

1. Editing changes drafts. Moving between categories retains those drafts.
2. Apply commits all drafts once through the preference store. After a successful commit, update audio and the supported live race preferences while remaining paused.
3. Back without Apply discards the current drafts. Reset stages defaults for the selected category; it does not silently reset another category.
4. A failed commit keeps the prior live and saved values, preserves the retryable drafts, and displays a concise save error.
5. Graphics remain saved for the next newly prepared race; no active-world rebuild or promise that every retry recreates that world.

This deliberately replaces the pause menu's immediate-save behavior. Do not combine unsaved drafts with silently persisted pause dropdowns. Live preview with rollback could be added later if useful; it is not required for the initial harmonisation.

Customize layout is the explicit exception unless its autosave behavior is redesigned: Apply first, then open the existing editor as a nested paused-race overlay with its current autosave contract. Done/Back must return to the same settings context and leave the attempt paused. Do not pretend those editor changes are cancellable drafts.

Ghosts need an explicit context adapter. App installs Rivalry/challenge opponent recordings into the same ghost presentation machinery and can override the initial mode to Race or Off. Reusing personal-best labels must not misrepresent an opponent recording, change the selected competitive target or overwrite unrelated personal preferences. Preserve the existing availability rules first; inspect these modes as part of implementation acceptance.

## Suggested implementation sequence

1. Extract a preference draft/commit helper shared by both entry points, with typed field handling, existing validation and one storage owner. Correct steering's rating-store dependency as part of that work. Keep all backend and canonical rules unchanged.
2. Extract/reuse the six driving section builders and their captions. Add a presentation-only race settings application method for camera/zoom, touch layout/labels, steering/drift feedback and valid ghost visibility. Resolve Master mute in the audio path.
3. Add the larger paused settings host, persistent navigation/actions and nested layout-editor return. Retain the normal compact pause drawer.
4. Add next-race Graphics and optional Language after the core live settings work. Keep account changes, tutorial replay and development tools outside an active attempt.

Priority is Audio and steering persistence first, missing Controls/Haptics second, and larger shared layout third. A copy of the current main-menu page alone would not resolve live application or return navigation.

## Implementation acceptance gates

- Both entry points expose the same shared keys, options, ranges, defaults and selected values after reload.
- Apply/Reset/Back behave consistently across categories, including failed saves and unrelated preference preservation. Reset controls must not unexpectedly reset Haptics; the current `_reset()` controls branch also changes steering haptics and should be made category-specific during extraction.
- Local races, cloud-style races, Daily, Rivalry, challenges, editor tests and Garage free drive use the correct preference owner and only supported ghost controls. Include the no-rating-store fixture.
- Applying live controls releases held touches and does not resume the race. Opening settings, layout editing, resize, Esc and focus loss must not advance canonical ticks, consume a resume or create a retry.
- Graphics maintain platform AA/resolution restrictions, apply at the existing world-preparation boundary and leave current meshes/world intact.
- Audio changes remain audible on resume, survive profile reload and never leave a hidden Master mute. Verify with real audio output separately; this review tests bus state.
- Native 960×540 and 1280×720 layouts, keyboard focus and the existing twelve shipped locales fit; Apply and Back remain reachable. Physical-device touch and haptic acceptance still required.

## Actual verification and limitations

The review probe completed **30 checks, 0 failures** on desktop Compatibility, exit 0 on the direct wrapped run. Fourteen native PNGs cover the actual main settings component (five categories at two sizes) and pause settings top/bottom at both sizes. The probe verifies staged main audio, saved audio application, live/saved cloud-style and local-style steering, camera and ghost persistence, failed steering saves, hidden Master mute and unchanged canonical state/input blocking. Assertions that reproduce current defects are successful observations, not claims that the defects have been fixed.

First command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/review_settings_harmonisation.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
```

That launch produced observations with 30/0 and images, but its outer command returned exit 1 and the runner log lacked the final assertion line. It also reported denied access to the default user log. It is not counted as a clean runner pass. The dev entry point regenerated build metadata; this review restored its own generated identity/project version from `build/logs/ExportAndroid-6248/client-build-identity.json`, whose ID exactly matched the project version read before the launch, after checking the current ID still matched this review's generated ID. Concurrent source edits were retained.

Final command, using the pinned executable, process-tree crash-dialog wrapper, disposable records and a workspace log:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --audio-driver Dummy --log-file 'C:\Codes\Godot\Beat my track\docs\evidence\settings-harmonisation-2026-11-03\compatibility.log' --script res://tests/review_settings_harmonisation.gd
```

The final run reported `SETTINGS_REVIEW: 30 checks, 0 failures` and exit 0. Root-certificate-store and shader-cache-write errors remain in its log; no clean-environment-log claim is made. No account/network requests were initiated by the probe. The failed-save fixture intentionally uses a nonexistent child folder. Audio output was Dummy, so this confirms bus state, not listening quality. No Mobile renderer, phone/device, live cloud attempt, sustained performance, multilingual fit or full regression validation was performed. These are evaluation limits, not passed acceptance gates.

Evidence: [observations](evidence/settings-harmonisation-2026-11-03/gl_compatibility/observations.json), [final log](evidence/settings-harmonisation-2026-11-03/compatibility.log), [main Controls](evidence/settings-harmonisation-2026-11-03/gl_compatibility/main-component-controls-1280.png), [main Audio](evidence/settings-harmonisation-2026-11-03/gl_compatibility/main-component-audio-1280.png), [pause top](evidence/settings-harmonisation-2026-11-03/gl_compatibility/pause-top-1280.png), [pause bottom at 960](evidence/settings-harmonisation-2026-11-03/gl_compatibility/pause-bottom-960.png).

Review checkpoint: [task-only patch](evidence/settings-harmonisation-2026-11-03/review.patch) adds only this report and the probe; [manifest](evidence/settings-harmonisation-2026-11-03/report.json) records their hashes and the current reviewed sources. `git apply --reverse --check docs/evidence/settings-harmonisation-2026-11-03/review.patch` passes without applying it. `git diff --exit-code -- game/ui/settings_page.gd game/ui/race_pause_menu.gd` also exits 0. Evidence images/logs remain separate artifacts; nothing is staged or committed.
