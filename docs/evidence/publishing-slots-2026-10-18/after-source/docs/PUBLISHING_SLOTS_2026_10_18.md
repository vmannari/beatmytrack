# Publishing slots and stable draft status — 2026-10-18

PSL01: A failed or unchanged publication no longer rebuilds the Load track card on every idle queue pass. The lifecycle emits its change signal when persisted presentation state changes; polling deadlines alone and identical queued responses stay quiet. Ten idle passes retain the exact same bottom controls and gallery nodes, including after a quota rejection. This removes the repeated rescans that alternately removed and restored Retry.

PSL02: Publish and Retry read the current authenticated `/me/entitlements` slot count before saving new publication intent or sending content/retry requests. Zero, unavailable, malformed or account-switched ownership cannot start an operation. Cached ownership controls the editor and draft buttons, but a fresh server read protects each actual submission. Account and server scopes fence the cached count. Concurrent clicks on the same draft share an in-flight guard. Existing acknowledged requests continue their original status processing; an uncertain upload retains its existing identity.

PSL03: Creating a track, including Save as new track, checks slots and shows **No publishing slots left** when appropriate: “You can build, save and test drive in the editor. Add a slot in Store to publish this track and race it for records.” The editor remains usable after dismissal. The saved draft card disables Publish and offers **Add slots** to open Store. Its failed publication and test lap stay saved; an unavailable Retry is hidden. Opening Load track refreshes ownership, so returning after adding a slot restores the existing request's explicit Retry. Ordinary racing on published tracks is unchanged.

PSL04/G01/R01/Q01: Recovery reuses the original server publication ID and saved lap evidence, including after restarting the lifecycle. No publication, purchase or entitlement mutation was performed against a live account. The server's existing final slot validation remains authoritative if another device consumes the last slot during publication; this change does not reserve slots or modify the backend.

Runtime changes: `game/backend/track_lifecycle.gd`, `game/ui/draft_browser.gd`, `game/core/app.gd`, and `game/ui/fault_dialog.gd`. The new `game/tests/test_publishing_slots.gd` and UID exercise actual local journals, counted fixture requests, restart recovery, identical status polls, stale ownership, real app creation, and retained controls. The existing `test_local_draft_publication.gd` fixture now supplies the required ownership read without changing its trajectory, identity or privacy assertions.

Pinned Godot 4.7.2 results:

| Check | Result | Evidence log |
| --- | --- | --- |
| Slot flow, headless | 40 checks, 0 failures | `logs/headless-final2.log` |
| Slot flow, native Compatibility | 44 checks, 0 failures | `logs/compatibility-final.log` |
| Slot flow, desktop Mobile renderer | 44 checks, 0 failures | `logs/mobile-final.log` |
| Existing local publication / actual driven creator lap | 31 checks, 0 failures; 2605 ticks / 436 samples | `logs/local-publication.log` |
| Existing application navigation/editor/racing | 140 checks, 0 failures | `logs/app.log` |
| Existing live publication notice | 72 checks, 0 failures | `logs/publication-notice.log` |
| Final project parser | 868 scripts, 0 failures | `logs/parser-final.log` |
| Scoped whitespace check | Passed | `git diff --check` |

Native views were reviewed in the actual app at 960×540, 1280×720 and 1600×720. The narrow page uses its existing scroll container. [1280 draft card](evidence/publishing-slots-2026-10-18/compatibility/no-slots-1280x720.png), [960 actions after scrolling](evidence/publishing-slots-2026-10-18/compatibility/no-slots-960x540.png), [creation warning](evidence/publishing-slots-2026-10-18/compatibility/creation-notice.png), and [desktop Mobile card](evidence/publishing-slots-2026-10-18/mobile/no-slots-1280x720.png) use disposable fixtures, not the owner's track or account. The new test's small synthetic trajectory tests transport/preservation only; the existing 31-check regression separately drives and saves a real ordered creator lap.

Actual invocations used `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` from the repository root. Each process set `APPDATA` and `LOCALAPPDATA` to its dedicated directory under `build/publishing-slots-2026-10-18`. Arguments were:

```powershell
-Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence=C:/Codes/Godot/Beat my track/docs/evidence/publishing-slots-2026-10-18/mobile' -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_local_draft_publication.gd -CommandTimeoutSeconds 180
-Action TestApp -CommandTimeoutSeconds 300
-Action TestScript -ScriptPath res://tests/test_publication_notice.gd -CommandTimeoutSeconds 180
-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
git diff --check -- game/backend/track_lifecycle.gd game/ui/draft_browser.gd game/core/app.gd game/ui/fault_dialog.gd game/tests/test_local_draft_publication.gd game/tests/test_publishing_slots.gd
```

Initial attempts remain in the logs: sandboxed Godot could not read the Windows certificate store, so isolated local tests ran with approved execution outside that restriction; no certificate or trust configuration changed. The first new fixture used an unexpanded `res://../` storage directory, then seven-value trajectory rows instead of the required eight. Later native checks exposed an incorrectly sized standalone fixture: its captures omitted the bottom card. The fixture now mounts the browser in the real app and asserts that Add slots is inside the viewport, after scrolling when applicable. A final extra draft used unsupported hyphens in its ID; it now uses a valid underscore ID, so the stale-ownership test reaches the actual submission guard. No runtime invariant was weakened.

Before/after source snapshots, [machine-readable results](evidence/publishing-slots-2026-10-18/report.json), and a [task-only review patch](evidence/publishing-slots-2026-10-18/task-only.patch) are retained. The checkpoint excludes the concurrent `_view_publication_notification` storage correction and preserves other workspace work. Owner appearance and actual account/device workflow acceptance remain. No phone attachment check or physical-device test, APK/export/install, live publication, backend mutation or deployment was performed.
