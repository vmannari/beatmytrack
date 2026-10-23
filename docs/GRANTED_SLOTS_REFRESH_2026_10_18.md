# Studio-granted publishing slots — 2026-10-18

The owner reported that granting Ville five slots in Studio still left track publication blocked. Read-only authenticated Studio directory/support requests confirmed five real slots on the Google account, zero simulated slots and an unrestricted account. The corresponding PC profile contains saved, ready creator laps without publication IDs. No grant, entitlement adjustment or live publication was performed during this investigation.

## Cause and correction

SGR01: An open editor or draft page could retain its earlier zero-slot result indefinitely. The app also rejected an explicit Publish action from that cached zero before reaching the lifecycle's authoritative fresh check. Returning from Studio now refreshes ownership while Create or Load track is active. A foreground, blocked creation page rechecks at most once a minute. Other menus, racing and background screens add no polling. Concurrent ownership reads share one request, with the existing account/server scope checks retained.

SGR02: Updated ownership emits the existing presentation change only when the balance changes. The editor's Publish action or the existing failed publication's Retry becomes available. An unchanged refresh retains the original controls and gallery. A resolved slot failure reads “Ready to retry publication.” Its saved failure, proof and server request identity remain unchanged until the player's explicit action. The actual app Publish action reaches the existing fresh server check even when its earlier cached balance was zero.

G01/R01: Current server ownership remains authoritative before upload and Retry. Invalid, unavailable, account-switched and stale ownership tests remain. Refreshing ownership never submits a publication or automatically retries one. Ordinary racing, Studio grants, billing, track data and physics are unchanged.

Runtime files: `game/backend/track_lifecycle.gd`, `game/core/app.gd`, `game/ui/draft_browser.gd`. Regression coverage extends `game/tests/test_publishing_slots.gd` using disposable accounts, libraries, saved lap files and counted transport fixtures.

## Actual validation

The added regression first reproduced four failures on the pre-change runtime: duplicate concurrent reads, failure to restore draft Retry after focus return, failure to restore editor Publish and absence of a bounded visible-page refresh. Final results are 55 headless checks, 61 native Compatibility checks, 61 desktop Mobile-renderer checks and 890 parser scripts, all passing. Receipts are recorded in `evidence/granted-slots-refresh-2026-10-18/logs/`.

The existing actual-driven local publication regression passes 31 checks, with 2605 creator ticks and 436 trajectory samples. The broader app run completes 140 checks with 11 editor-gesture failures. Its exact failure list matches the previously retained pre-task newspaper baseline; `app-baseline-comparison.json` records the comparison. These failures are retained and no assertions were weakened.

All Godot runs use the pinned 4.7.2 engine through `scripts/dev.ps1`. Each sets `APPDATA` and `LOCALAPPDATA` to its own workspace directory under `build/granted-slots-refresh-2026-10-18/`. Actual argument sets:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence=C:/Codes/Godot/Beat my track/docs/evidence/granted-slots-refresh-2026-10-18/compatibility' -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_publishing_slots.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence=C:/Codes/Godot/Beat my track/docs/evidence/granted-slots-refresh-2026-10-18/mobile' -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_local_draft_publication.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 120
git diff --check -- game/backend/track_lifecycle.gd game/core/app.gd game/ui/draft_browser.gd game/tests/test_publishing_slots.gd
```

Initial limitations and corrections are retained: sandboxed Godot could not access the Windows certificate store, so isolated tests used approved execution. The read-only diagnostic's first sandboxed cloud-authentication attempt was restricted; approved execution reused existing project authentication without printing credentials. The first local-profile comparison looked under the guest library; the corrected comparison uses the existing account-scoped player library. An additional app-action fixture initially saved after recording its proof, allowing the existing author stamp to change the fingerprint. Saving the fixture before recording preserves the exact-version invariant and the final app-action assertion passes.

Native captures show the existing zero-slot card, restored Retry and enabled editor Publish in both desktop renderers. `before/`, `task-only.patch` and `checkpoint.json` retain a scoped source checkpoint independent of concurrent workspace work.

The running older PC process can refresh immediately by reopening Create → Load track. The automatic focus/visible-page correction requires restarting into the updated source. Owner workflow acceptance remains. No phone attachment check or device test, APK/export/install, account mutation, live publication or backend deployment was performed.
