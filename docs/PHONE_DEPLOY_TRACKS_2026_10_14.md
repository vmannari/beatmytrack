Follow-up: the owner clarified that the full27 published tracks belong in **Free Race**. That catalog/service repair and actual phone Winter/Desert race launches are recorded in [Free Race phone catalog acceptance](FREE_RACE_PHONE_CATALOG_2026_10_14.md); the nine saved drafts below are the earlier, separate deployment.

# Phone deployment with saved tracks — 2026-10-14

The owner requested deployment to the phone with the tracks. **PD01/R01/V05/Q01**: the current APK is installed on DN2103, nine readable saved tracks are hash-verified, and the actual Guest **Create → Load Track** browser shows **9 drafts**. The app is left open in that browser. No race was started.

Installed/frozen APK SHA-256: `D53DE74D7C2047447DA1D837EFD1B8EB0B4374494B39D830EB705C7322CD4B6B`. Pinned Godot4.7.2 `ed1daf0bf`; physical OnePlus DN2103/Mali-G77 MC9, Android13, Compatibility/GLES3.2. Install returned Success, launch returned Status:ok, actual process logs contain APP_READY, and the visible menus were inspected.

The top-level PC folder contains six primary JSON files in retired creator-track-v1–v4 formats. The actual `TrackLibrary` cannot read them. Its saved-library recovery path instead returns nine valid v5 committed backup documents, all with valid race routes: eight Grass and one Desert, including the original Desert test route. Those exact bytes were copied into an isolated deployment snapshot and sent as ordinary `.json` saved documents. No source/PC track was changed, no editor WIP or profile/authentication store was transferred, and no new Winter document was fabricated. Six retired-format files remain on the PC and require a separate migration before they can appear in the current game.

Every staging and installed track SHA matches its source snapshot. There were no pre-existing phone track files to replace; the transfer retains the established backup-before-replacement and atomic per-file rename behavior. Existing phone records/cosmetics and app data were retained through `install -r`. Temporary staging files and the task-only inspection script were removed; its source remains in the ignored deployment folder for review.

The initial sign-in screen reported an unreachable game service. The existing PC service on127.0.0.1:18181 returned healthy. Restoring `adb reverse tcp:18181 tcp:18181` and relaunching removed that connection message. Guest navigation and the nine-track browser were then verified. No backend build/restart/migration/deployment, account sign-in, score upload or production action was performed. This connection uses the current USB/ADB forwarding; reconnecting/restarting ADB can require restoring it.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/inspect_phone_deploy_20261014.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File build/phone-deploy-tracks-2026-10-14/deploy.ps1
adb -s PRQKU4U4PREQNRWG reverse tcp:18181 tcp:18181
```

The inspection script existed only for the read-only library snapshot and was subsequently removed from `game/tests`. It and the deploy script, exact APK, source snapshots, installed-file manifest, launch logs, check logs and actual screenshots remain privately under `build/phone-deploy-tracks-2026-10-14/`. The initial deployment manifest reader nested the JSON array incorrectly and failed before any phone change; corrected reader completed successfully.

Quick validation passed pinned import/APP_READY, Driving72, Catalog21 and Menus48. No runtime game code was changed for deployment; full Validate and fresh FPS/hitch/thermal driving tests were not run. The earlier tire-stall evidence remains scoped to its earlier tested APK. Six retired-format source files, owner driving/visual review and broader phone acceptance remain separate work. [Deployment evidence](evidence/phone-deploy-tracks-2026-10-14/deployment.json) contains the actual installed hashes and checks; private track contents/screenshots stay outside that manifest.

The deployment-only review checkpoint is `build/phone-deploy-tracks-2026-10-14/checkpoint-repo`; its [manifest](evidence/phone-deploy-tracks-2026-10-14/checkpoint.json) records the scoped documentation/evidence commit. Main Git index/HEAD and parallel source work were not changed by this deployment task.
