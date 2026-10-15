# Phone game and drivable tracks — 2026-10-14

Owner request: deploy the game and tracks to the phone and make sure the tracks can be driven. Requirements **PD01–PD03/R01/V05/Q01** cover the pinned game installation, validated track delivery and actual phone driving checks.

The fresh Godot 4.7.2 Android debug APK is installed on the physical OnePlus DN2103 (`PRQKU4U4PREQNRWG`) with existing app data retained. Its installed SHA-256 matches the frozen APK: `145424136d3a53cf2793de59d32a1115c9573c0572a4619c651688cd78e3d221`. Quick export validation passed import/APP_READY, Driving72, Catalog21 and Menus48. The exact APK, commands and private device artifacts are retained under `build/phone-drive-deploy-2026-10-14/`.

The earlier nine-track transfer had copied outdated recovered documents. Eight lacked the start line required by the current Test drive action, and some road chains were incomplete. The current 27-track public cache already contains repaired, published versions of those same tracks. This deployment uses those existing immutable documents, with matching track IDs, instead of inventing new routes or changing the PC originals. All27 documents pass the current schema, closed-road-route/start-line checks and native compilation. The collection contains17 Grass,3 Night,4 Desert,2 Winter and1 Storm tracks; lap lengths range209.8–727.7m.

Nine matching saved drafts were replaced on the phone with those current versions. Every old phone copy was backed up under the transaction recorded in `deployment.json`; every staged and installed file hash matches the validated source snapshot. The complete27-track collection was also transferred to the original server-scoped offline cache, publishing its merged index only after all documents were installed and hash-verified. Existing unrelated phone files and tracks were retained. The actual normal saved-draft Test drive workflow started all9 tracks successfully in an isolated desktop application using the phone snapshot, with zero failures.

USB forwarding to the healthy existing PC API was restored with `adb reverse tcp:18181 tcp:18181`. Backend builds, migrations, publication writes and competitive submissions are outside this phone deployment. The six retired v1–v4 PC files are retained and are not newly converted or shipped.

The owner then requested that the remaining tracks not be tested. Testing stopped after14 successful phone driving checks covering all five biomes, with1448.7m driven in total (69.7–125.6m per track). The remaining13 tracks were delivered and structurally validated but were not driven on the phone. The existing debug-only driver started the installed documents through the game's unscored practice path with normal graphics settings. Each completed check required nonzero simulation, more than5m of movement, speed above1km/h, zero paused frames and no script/parse/shader fatal error. All14 retained passes meet those conditions. The first Infinity run paused after56.6m; that interrupted run is retained separately and is not counted as a pass. Its unchanged repeat passed123.6m with zero paused frames. These short checks do not establish full-lap completion, physical multitouch acceptance, phone FPS improvements or long-run thermal performance.

Both protected local-record files, including cosmetic condition, were restored byte-for-byte from the second run's pre-test backup. All diagnostic markers and exact temporary ADB staging files were removed, and normal launch returned Status:ok. The game was returned to Guest mode for ordinary use; no remaining track test was started. The private `driving-summary.json` and `driving-restoration.json` record the14 passes,13 untested tracks and exact restored hashes.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action InstallAndroid -DeviceSerial PRQKU4U4PREQNRWG
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/prepare_phone_drive_deploy_20261014.gd -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File build/phone-drive-deploy-2026-10-14/deploy.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sync-phone-offline-tracks.ps1 -DeviceSerial PRQKU4U4PREQNRWG -SourceCachePath "$env:APPDATA/Circuit01Lab/cloud/166f57396bcc750da426bf322777f9361f3815cbbf3c091202d7f10ede7e2573" -Output build/phone-drive-deploy-2026-10-14/offline
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/check_phone_saved_buttons_20261014.gd -CommandTimeoutSeconds 240
python -u build/phone-drive-deploy-2026-10-14/check_driving.py
```

The task-only GDScript helpers were removed from the export project after use; their source remains in the private deployment folder. An initial external-script invocation was rejected by the dev entry point, and a sandboxed Godot invocation could not write its user log. Neither changed the phone. The first inspection then exposed the incomplete older Blind spot chain; the final inspection validated the already-repaired published versions without weakening route checks. Runtime game source, source maps, canonical contracts and the main Git index/HEAD are preserved.
