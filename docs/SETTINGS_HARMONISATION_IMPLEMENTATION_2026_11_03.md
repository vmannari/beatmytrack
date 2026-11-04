# Shared pause and main-menu settings — 2026-11-03

Pause → Settings now opens the same `SettingsPage` used by the main menu, over the frozen race. Shared Controls, Camera, Ghosts, Audio, Haptics, Graphics and Language categories use the same labels, options, defaults and saving path. The compact pause menu remains the entry point for Resume, Restart, Help and Quit.

This implements the approved [review](SETTINGS_HARMONISATION_REVIEW_2026_11_03.md). No backend, competitive-rule, physics or account-storage contract changed.

## Requirements and resulting behavior

- SHI01: One shared settings page and commit path. Controls/Camera/Ghosts/Audio/Haptics/Graphics drafts persist between categories; Apply saves them together. Back discards unapplied drafts and returns to the pause menu. Reset affects its category; Controls reset no longer changes Haptics. Language retains its existing immediate, installation-local saving behavior.
- SHI02: Pause uses `preference_records`, including when `rating_records` is absent. Steering, labels, camera/zoom, steering/drift feedback and ordinary personal-ghost preferences update the active race after a successful commit. Failed Apply retains the prior saved/live settings and retryable drafts. No separate pause steering implementation remains.
- SHI03: Pause Audio now exposes the same saved Music, Vehicle and Interface sliders. Applying soundtrack preferences clears the legacy process-local Master mute, eliminating the hidden mute state. Record-player enable/playlist preferences retain their existing behavior.
- SHI04: The shared page has a full-area paused host, persistent Back/Apply, a category picker at smaller widths and stacked content at narrow widths. Main-menu settings gain the same responsive layout. Category changes start their content at the top. Main-only Account, Privacy, Help, Licences and debug Development remain outside the paused settings host.
- SHI05: Customize layout first applies settings, then opens the existing autosaving editor above the paused attempt. Done/Esc returns to refreshed settings and updates live controls. Failed editor saves prevent an external Resume and retain edits. Esc from settings returns to the pause menu; explicit Resume restores driving. External restart tears down the settings host and discards unapplied page drafts. Race shortcuts cannot retry, rewind or change camera behind settings.
- SHI06: Graphics save for the next newly prepared race and do not rebuild the current world. App marks opponent-ghost contexts on race entry/retry; saving personal ghost preferences does not replace the active opponent recording or mode. Unavailable/live-inapplicable personal ghosts have a translated next-race explanation.
- R01/Q01: Disposable records, unchanged canonical state/rules/record identity during settings interaction, task-scoped checkpoint and preserved concurrent work.

The existing page is the shared draft/commit implementation; no duplicate settings model or new save schema was introduced. The Game's presentation-only application method reads the successfully committed preference store without issuing another save or entering the simulation step.

## Changed sources

| Files | Purpose |
|---|---|
| `game/ui/settings_page.gd` | Shared context/section filtering, applied signal, responsive navigation/content, category-specific reset and retained dirty status |
| `game/ui/race_settings_overlay.gd` | New paused host, persistent navigation, nested layout editor and safe return/resume |
| `game/ui/race_pause_menu.gd` | Replace independent settings controls with the shared host and its lifecycle |
| `game/core/game.gd` | Apply saved presentation preferences; intercept settings keyboard navigation; clean up on resume/restart |
| `game/core/app.gd` | Two opponent-ghost context assignments at existing entry/retry boundaries |
| `game/soundtrack/audio_world.gd` | Remove legacy Master mute when applying named-bus preferences |
| `scripts/translations/settings_harmonisation.tsv`, twelve `.po` files and `messages.pot` | One new next-race ghost explanation, with authored translations |
| `game/tests/test_settings_harmonisation.gd` | New actual-Game/shared-page persistence, lifecycle and multilingual layout regression |
| `game/tests/test_camera_modes.gd` | Update UI assertions to the approved staging contract; retain explicit camera-setter/session-failure coverage |
| `game/tests/capture_camera_modes.gd`, `capture_personal_ghosts.gd` | Navigate the new shared Camera/Ghosts sections |
| This report, `AGENTS.md`, `DEVELOPMENT_STATUS.md` and task evidence | Delivery record and review checkpoint |

The earlier evaluation probe is historical evidence of the pre-change implementation, not a current regression suite; its old dropdown IDs are superseded by the new regression.

## Verification

Final results and source hashes are in [report.json](evidence/settings-harmonisation-implementation-2026-11-03/report.json). Native captures use the actual Game/HUD and shared settings, not a mockup. Main settings are also exercised through the retained full-App control-layout and graphics suites.

| Check | Actual outcome |
|---|---|
| Shared settings, headless initial run | 1,030 checks, 0 failures; before the additional editor-save/language/restart assertions |
| Shared settings, final native Compatibility | 1,069 checks, 0 failures, exit 0; 33 PNGs |
| Shared settings, final native desktop Mobile/Vulkan | 1,069 checks, 0 failures, exit 0; 33 PNGs |
| Retained camera behavior/framing/storage | 1,502 checks, 0 failures |
| Retained control layout and full-App editing | 407 checks, 0 failures, including the embedded synthetic 90-check input probe |
| Retained drift feedback | 45 checks, 0 failures |
| Retained graphics/storage/current-world lifecycle | 146 checks, 0 failures; separate coroutine/cache errors described below |
| Retained native pause/frozen-frame behavior | 17 checks, 0 failures; observer/cache shutdown findings described below |
| Scoped translation parsing/placeholders/authored row | Twelve catalogues and the new authored row checked successfully |

Each native settings run checks seven categories in all twelve locales at **1280×720, 960×540 and 540×960**, including Back/Apply bounds and horizontal overflow. The focused regression also covers no-rating-store persistence, mixed-category Apply, failed writes, category Reset, nested editor saves/failures, immediate language selection, hidden Master mute, opponent ghost preservation, focus loss, keyboard shortcuts, unrelated preferences and exact paused canonical state/rules/record partition.

Selected views: [wide Controls](evidence/settings-harmonisation-implementation-2026-11-03/Windows-gl_compatibility/pause-controls-1280-en.png), [compact Audio](evidence/settings-harmonisation-implementation-2026-11-03/Windows-gl_compatibility/pause-audio-960-en.png), [portrait Controls](evidence/settings-harmonisation-implementation-2026-11-03/Windows-gl_compatibility/pause-controls-540-en.png), [Korean compact Controls](evidence/settings-harmonisation-implementation-2026-11-03/Windows-gl_compatibility/pause-controls-960-ko.png), [Mobile Controls](evidence/settings-harmonisation-implementation-2026-11-03/Windows-mobile/pause-controls-1280-en.png).

## Commands and environment findings

All Godot launches used pinned `4.7.2.stable.official.ed1daf0bf` via `python scripts/run_no_crash_dialog.py --`. The direct wrapped executable avoids the normal dev entry point's unrelated build-identity regeneration. No owner game/editor process was restarted. Representative final command:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path game --rendering-method gl_compatibility --audio-driver Dummy --log-file 'C:\Codes\Godot\Beat my track\docs\evidence\settings-harmonisation-implementation-2026-11-03\compatibility.log' --script res://tests/test_settings_harmonisation.gd
```

Mobile uses `--rendering-method mobile --rendering-driver vulkan` with `mobile.log`; headless uses `--headless`. Console redirection used for final graphical runs is retained separately. The retained camera/control-layout/drift/graphics suites were run headless from copies under `evidence/.../runners/`, replacing only their `user://` fixture strings with disposable workspace paths. Their assertions are unchanged apart from the approved camera UI contract update in the actual camera suite. Initial direct camera execution failed to write its default `user://` fixture and aborted its coroutine; the owned test session was interrupted. The redirected rerun passed 1,502/0. A read-only CIM process lookup was denied; no owner process was acted on.

Native pause used `res://tests/test_pause_menu.gd -- evidence=res://../docs/evidence/settings-harmonisation-implementation-2026-11-03/pause`. The complete parser used `res://tests/test_script_parse.gd`; it checked 1,707 scripts and returned its failure flag. Failures were in `test_menu_quality.gd`, `test_metadata_race_preparation.gd`, and the historical `tests/fixtures/parking_hall_before/garage_page.gd` (with a dependent App compile error). The first two override an older `_start_race` signature; both failures reproduce against the saved **task-before App**, and its signature is byte-for-byte unchanged. The Garage fixture calls a missing `_build_wash_requirement` helper. These fixtures were not changed or excluded to make the scan pass. Baseline runners/logs and [signature comparison](evidence/settings-harmonisation-implementation-2026-11-03/parser-baseline.json) are retained.

The global translation authoring helper also rejects unrelated `track_editor_review_fixes.tsv` row 1: that file uses literal tab separators instead of the compiler's pipe format. The task's one-row authoring file and all twelve corresponding PO messages pass scoped checks. The unrelated authoring file was preserved.

Certificate-store and denied shader/road-cache writes occur under the sandbox. Initial native settings testing also had the existing race-hitch observer attempt denied `user://diagnostics` writes and leave two ObjectDB instances/one resource at shutdown. The final focused fixture disables that optional observer before constructing Game; final focused Compatibility and Mobile runs have no script-error/leak findings. The unchanged native pause suite still reports the observer/cache shutdown findings after its 17/0 assertions. The retained graphics suite returns exit 0 with 146/0 assertions but also logs the existing Garage `_warm_frame()` resume-after-destruction error and a denied road-cache write. These are not clean-environment-log passes and remain in the evidence.

## Checkpoint and remaining acceptance

[Task-only patch](evidence/settings-harmonisation-implementation-2026-11-03/implementation.patch) and source-hash receipts are generated against saved task-before sources, with documentation and locale hunks isolated from concurrent additions. Forward and reverse application/content checks use a disposable tree; the main index is untouched. No tests were weakened or failing fixtures excluded from the broad parser.

Checkpoint command: `python docs/evidence/settings-harmonisation-implementation-2026-11-03/build_checkpoint.py`. It runs `git apply --check`, apply, reverse-check and reverse-apply with a disposable `--directory` prefix and compares every resulting source. Review evidence/logs/screenshots are retained separately from the source patch.

Reload/rebuild the current client to see the changes. Owner appearance review and physical-device touch, haptic feel, listening and sustained performance acceptance remain. Dummy audio verifies routing/bus state, not listening quality. Live authenticated race/account/purchase flows were not exercised; opponent handling is checked with isolated actual-Game state and the existing App entry/retry assignments. No phone/device query/test, APK/export, live/backend mutation, deployment, owner-save change or main-index staging/commit/merge was performed. Concurrent work remains intact.
