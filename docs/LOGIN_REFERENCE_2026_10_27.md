# Login reference update — 2026-10-27

LR01: Match the supplied alpine/right-card composition, yellow wordmark, large heading, compact flagged language choice, white Google action and underlined guest action.

LR02: Retain the existing Google/development controllers, deferred guest navigation, provider cancellation/retry, name/country setup, account management and privacy destination.

LR03: Following the owner's explicit instruction to use the draft during development, show an unchecked agreement control with an in-game reader and Save a copy. LR04: Fit the existing account states and all twelve languages. R01/Q01: Preserve concurrent work and retain actual checks, screenshots and a task-only patch.

The existing alpine bitmap is unchanged; only its dark overlay is reduced. The welcome card sits on the right in landscape and centers in portrait. Additional provider/status/profile controls use a wider, denser card. Longer translated welcome copy reduces typography and padding without scrolling the login card. The original Google button remains its default elsewhere; this screen opts into the full-width variant using the existing Google G and Google Sans. The new monogram and checkbox outlines are authored SVG paths, with no generated bitmap or third-party asset added. Language flags reuse the existing licensed country artwork. Ten new interface messages have directly authored translations in all twelve catalogues, with 120 checked placeholder pairs. The generated source/English inventories are refreshed using the existing extractor, including current concurrent source literals; this does not claim full translation coverage elsewhere.

The bundled `game/legal/terms-draft-2026-10-25-r6.txt` is byte-identical to `docs/legal/TERMS_DRAFT.md`: SHA256 `614271fdf37ae82467c985a6a3dc85118a38b0ebeb6bd3334d55934258a8f69b`. Its reader preserves the draft warning, version, unresolved publisher fields and all nineteen sections, supports selection/scrolling, and saves the original bytes. The agreement row is development-only (`OS.is_debug_build()`); it gates Google, development and guest actions while unsigned. Reading/closing the document does not check the box. Acceptance is local to the current login panel, resets when that panel is rebuilt, and is neither persisted nor sent to the backend. Existing signed-in account management remains available. This prototype does not implement a production/account-bound terms record. The legal draft remains English; surrounding controls are translated.

Actual verification with the pinned Godot 4.7.2 standard console engine:

| Check | Result |
| --- | --- |
| Original native layout diagnostic | 763 checks, 4 failures; long-error overflow already present |
| Final native Compatibility layout | 1,643 checks, zero failures; 72 screenshots |
| Final desktop Mobile renderer layout | 1,643 checks, zero failures; 72 screenshots |
| Draft reader/gate/copy, Compatibility | 17 checks, zero failures |
| Expanded draft checks, desktop Mobile | 19 checks, zero failures; includes keyboard Space |
| Existing native localization | 62 checks, zero failures |
| Localization Python tooling | 14 tests pass |
| Existing App regression | 141 checks, zero failures |
| Final imports and source whitespace | Completed; existing CRLF normalization notice retained |

The layout diagnostic retains the original four window sizes and nine account states, plus retained error/resize checks. Its optional `--locales` sweep adds twelve languages at 1280×720, 960×540 and 800×1000. It checks controls in the card's own window; independent popup/tooltip windows have separate coordinates and are verified separately. This corrects two intermediate diagnostic false positives without relaxing card containment. The agreement fixture dispatches real mouse input, checks disabled actions, opens/closes the reader, saves an exact copy into a fresh fixture directory, checks both allowed routes and cancellation, and adds focused keyboard input in its final revision. No provider request is made.

Actual commands from the repository root (native runs required sandbox elevation because the initial engine log could not open under `user://`):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& ./scripts/dev.ps1 -Action Import
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_sign_in_fit.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--output=C:/Codes/Godot/Beat my track/docs/evidence/login-reference-2026-10-27/native','--locales')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_login_draft_terms.gd -Graphical -RenderingMethod gl_compatibility -TestArgument @('--output=C:/Codes/Godot/Beat my track/docs/evidence/login-reference-2026-10-27/terms-native')
python scripts/localization.py extract
python scripts/test_localization.py
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_sign_in_fit.gd -Graphical -RenderingMethod mobile -TestArgument @('--output=C:/Codes/Godot/Beat my track/docs/evidence/login-reference-2026-10-27/mobile','--locales')
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_login_draft_terms.gd -Graphical -RenderingMethod mobile
& ./scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_localization.gd
& ./scripts/dev.ps1 -Action TestApp
python docs/evidence/login-reference-2026-10-27/audit_catalogue.py
git diff --check -- game/core/app.gd game/ui/account_panel.gd game/ui/account_backdrop.gd game/ui/google_sign_in_button.gd game/ui/language_picker.gd
```

Initial/intermediate logs remain. They include the original four overflows, wider setup/error/translation overflows corrected by the compact layout, a new SVG requiring import before preload, a deferred fit on a detached node corrected by a tree guard, the reader fixture initially searching before accounting for popup reparenting, and an outer PowerShell array arriving as one comma-containing argument. The final direct script invocation passes an actual array and captures all 72 views. The initial localization tooling inventory failure also reproduced with task-start owned UI sources substituted only in process memory (20 pre-existing missing source keys); the normal extractor refresh now passes all fourteen tests. These attempts are not counted as final passes.

Views: [English welcome](evidence/login-reference-2026-10-27/native/google-1280x720.png), [French narrow view](evidence/login-reference-2026-10-27/native/locale-fr-960x540.png), [Japanese portrait](evidence/login-reference-2026-10-27/native/locale-ja-800x1000.png), [draft reader](evidence/login-reference-2026-10-27/terms-native/draft-terms-reader.png), [desktop Mobile](evidence/login-reference-2026-10-27/mobile/google-1280x720.png). Raw logs, task-start sources, source hashes and the review patch are under `docs/evidence/login-reference-2026-10-27/`.

Reload the project/client to see the new screen. Owner appearance, wording and Android touch acceptance remain. No device attachment check or physical-device test was performed; desktop Mobile is a desktop renderer. No APK, deployment, real sign-in/purchase, owner-save/backend mutation, owner-process restart or main-index staging/commit/merge was performed. Concurrent source changes and runner-generated build identity files are excluded from the task patch.
