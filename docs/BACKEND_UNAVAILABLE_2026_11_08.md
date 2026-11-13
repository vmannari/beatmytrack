# Backend unavailable feedback — 2026-11-08

## Requirements and changes

- BU01: Explain unreachable backend during startup and sign-in. `game/backend/account_controller.gd` tracks service unavailability for transport failures and HTTP 5xx, including HTML proxy failures decoded as `INVALID_RESPONSE`. Account rejection and incorrect service responses retain their separate reasons. The existing transport message remains; HTTP 5xx receives a temporary-unavailability message.
- BU02: Preserve actionable failures on retry. `refresh_options()` now retains and reports failures from saved-session restoration and `/me`, instead of clearing the message after bootstrap succeeds. Connection errors from Google/development sign-in also expose Retry connection. Successful retry clears the outage state. Retry account-removal results now emit the existing removal event.
- BU03: Make the reason visible. `game/ui/account_panel.gd` shows a Service unavailable heading and accent-colored reason above provider controls, hides the ordinary sign-in promotional subtitle during an outage, and retains Retry connection and Play as guest. Two new strings are supplied in all twelve `game/localization/*.po` catalogues and `messages.pot`.
- BU04: `game/tests/test_backend_unavailable.gd` covers a real localhost refused connection, six startup failure shapes, saved-session preservation, both provider entry points, restoration/profile retry failures, recovery, distinct account rejection and first-time sign-in. All other backend responses are offline fixtures; credentials are invented and never saved.

## Actual validation

Pinned standard engine: `C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe` (`4.7.2.stable.official.ed1daf0bf`). Each command uses its own `APPDATA` under `build/backend-unreachable-2026-11-08/` and an empty `BMT_API_URL`. No owner profile is used.

Commands, appended to the pinned executable:

```powershell
--headless --path game --script res://tests/test_backend_unavailable.gd
--path game --rendering-method gl_compatibility --script res://tests/test_backend_unavailable.gd -- '--output=C:/Codes/Godot/Beat my track/build/backend-unreachable-2026-11-08/captures'
--path game --rendering-method mobile --script res://tests/test_backend_unavailable.gd -- '--output=C:/Codes/Godot/Beat my track/build/backend-unreachable-2026-11-08/captures-mobile'
--headless --path game --script res://tests/test_login_draft_terms.gd
```

Headless outage regression: **37 checks, zero failures**. Native Compatibility and desktop Mobile outage regressions: **39 checks, zero failures each**, including two saved native captures per renderer. Existing draft-terms regression: **31 checks, zero failures**. Total: **146 checks, zero failures**.

The repository localization extractor recognizes both new messages; its PO parser/validator checked just these new messages in all twelve catalogues: **24 translations, zero errors**. This is scoped validation, not a claim that the existing whole catalogue passes. `git diff --check` on the two runtime sources and new regression passed.

Reviewed native [compact outage capture](../build/backend-unreachable-2026-11-08/captures/outage-960.png) and [desktop capture](../build/backend-unreachable-2026-11-08/captures/outage-1280.png). Window dimensions are physical pixels; layout checks use the actual logical viewport rectangle.

Initial regression attempts retained these findings: checking provider position while the fixture was signed in tested an intentionally hidden provider; comparing physical window height to logical card bounds falsely reported overflow; an unquoted screenshot output argument containing spaces failed to save. Fixtures/commands were corrected without removing assertions. A redundant promotional subtitle was also hidden during outages. Windows root-certificate-store diagnostics occur in these isolated runs; no public backend or real provider is contacted.

Task-only source checkpoint: [patch](../build/backend-unreachable-2026-11-08/task-only.patch), based on task-start file copies, preserves existing concurrent edits. No root index staging or commit.

## Limits and acceptance

Client reload/rebuild is required. Physical-device testing was not performed; no attachment query, APK build/install, owner process restart/save edit, deployment or live backend request was performed. A controlled loopback request exercises the actual HTTP failure path; server outages and recovery use fixtures. Owner/device appearance acceptance remains. Saved-session preservation is checked when bootstrap cannot reach the backend; existing credential-rotation safety rules are unchanged.
