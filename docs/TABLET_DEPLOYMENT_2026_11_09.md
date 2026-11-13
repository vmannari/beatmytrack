# Current update deployed to OnePlus Pad 2 — 2026-11-09

TDU01–TDU03: The owner requested tablet deployment. Build `0.3.0-creator.e3a31917e135b51d277fe5b6e8038d8a`
is installed on OPD2403, serial `f0ba474a`, replacing
`0.3.0-creator.f81f1e617b6c54213e17e5786f45875e`. It includes the current optimised assets,
classic Super Rally and corrected Kart cockpit/driver.

The pinned official Godot 4.7.2 ARM64 export is 362,384,565 bytes,
SHA-256 `a40fc8c93b8c1bb380b60f66a173fd005d41e8da1b58358f78d1aff773c55d0f`. All 9,075 archive entries
pass CRC validation, with ARM64 as the only native ABI. Complete prepared assets
(551 resources / 2267 checks), six native pictures / 157 source hashes, import,
startup, driving, catalogue and menu checks pass through `scripts/dev.ps1
-Action ExportAndroid -AndroidPreset "Android ARM64" -QuickValidation
-CommandTimeoutSeconds 1200` using private offline PC test storage and the
existing signing configuration.

The initial live export stopped at its asset gate while another task was
rewriting Electric modules and Garage templates; no failed/stale APK was installed.
After current validation passed, the source and assets were copied into an
isolated snapshot. The final export takes 509.844 seconds
and changes no audited source or asset files. Its build identity reproduces
exactly after snapshot/index preparation completes. Concurrent work and the
main Git index remain unchanged.

Installation uses `scripts/dev.ps1 -Action InstallAndroid` with `adb install -r`.
The original first-install timestamp and all **840
existing app-file hashes** remain exact before first launch. The previous APK
is retained privately for rollback. No uninstall, data clear or track sync occurs.
Installed and exported APK hashes match.

Actual startup reaches `APP_READY`, the app owns the foreground window and the filtered startup log contains no matched script/parse/fatal errors. A private tablet screenshot is retained under the task build directory. This is an
installation/startup smoke check; driving feel, sustained frame time, thermal
behaviour, memory and visual acceptance on the tablet remain owner checks.
Normal app startup retains its existing online behaviour. No PC saves or direct
backend/admin operation or backend deployment were performed.

[Deployment receipt](evidence/tablet-deploy-2026-11-09/deployment.json),
[export](evidence/tablet-deploy-2026-11-09/export-result.json),
[exact identity check](evidence/tablet-deploy-2026-11-09/identity-confirm.json),
[snapshot summary](evidence/tablet-deploy-2026-11-09/snapshot-summary.json).
Private app-file manifests, rollback APK and any account-bearing screenshots remain
under `build/tablet-deploy-2026-11-09`. The reviewable source-only checkpoint is
recorded alongside the public receipts.
