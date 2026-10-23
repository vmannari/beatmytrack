# Drift haptics phone deployment (2026-10-17)

DHD01 / DH01-DH02 / G01 / R01 / Q01: the owner requested deployment of the new drift haptics to the phone. Pinned Godot 4.7.2 built an isolated snapshot of the current local client. No runtime source edits were made for deployment.

Installed and SHA-256 matched on the connected OnePlus DN2103: `6c923b953acaced8433407f46fa83f8494a1892b7fba474b7cc1ad75d4575d45`. Build ID: `0.3.0-creator.027b283f3387e2c3bd02a38aade74e47`. The APK contains the exported drift-haptics script. Replacement installation used `adb install --no-streaming -r`, with no uninstall or data clear.

Before installation, the app was stopped and its files plus previous APK backed up privately under `build/drift-phone-deploy-2026-10-17/protected-before`. Before first launch, both progress files and all 123 track/cache files matched their original hashes, preserving 14 saved drafts. The largest retained cache index contains 20 entries; this is not a full-library count. No tracks were replaced or removed.

Actual frozen-source checks passed: drift haptics45, driving72, catalog21, menu/preferences41, initial editor import and desktop APP_READY startup. QuickValidation ran these deployment checks; no full regression-suite pass is claimed. The frozen runtime source hashes were checked after export. Android launch returned Status ok and the app emitted APP_READY with no captured script/parse/fatal errors. The native startup capture is retained. Receipts are retained in `evidence/drift-phone-deploy-2026-10-17/`.

The prior local-service USB forwarding was checked and restored only when the existing PC service was already listening. See `usb-forward.json` for the actual outcome; no service was started or deployed.

Actual commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
python build/drift-phone-deploy-2026-10-17/freeze.py
# Build commands used APPDATA=build/drift-phone-deploy-2026-10-17/profile,
# with process-only safe.directory for the exact snapshot path.
powershell -NoProfile -ExecutionPolicy Bypass -File build/drift-phone-deploy-2026-10-17/snapshot/scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File build/drift-phone-deploy-2026-10-17/snapshot/scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_drift_haptics.gd -CommandTimeoutSeconds 150
powershell -NoProfile -ExecutionPolicy Bypass -File build/drift-phone-deploy-2026-10-17/snapshot/scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
python build/drift-phone-deploy-2026-10-17/phone.py backup
python build/drift-phone-deploy-2026-10-17/phone.py install
python build/drift-phone-deploy-2026-10-17/phone.py verify
python build/drift-phone-deploy-2026-10-17/phone.py forward
python build/drift-phone-deploy-2026-10-17/phone.py launch
# Wake the sleeping screen through normal Android keyguard handling, then observe:
python build/drift-phone-deploy-2026-10-17/phone.py observe
```

Initial attempts stopped before deployment because native Git rejected the sandbox-owned snapshot, the clean snapshot had not yet generated its class cache, and its Android source template was absent. Exact-path process-only Git trust, initial import and copying the existing hash-pinned template resolved these setup issues. Checks were not weakened. The template hash is enforced by the existing export script. Initial parse output is retained separately.

After installation, an initial host-to-phone forward attempt collided with the listening PC service. Correct phone-to-PC `adb reverse` restored the existing service route. The first launch then remained paused behind the sleeping lockscreen, with Android reporting NotificationShade focus and a dreaming lockscreen. No phone data or credentials were changed to resolve this; the owner was asked to unlock the phone for startup verification.

The app is deployed and launched. Drift feedback remains an independent saved switch under Settings > Haptics. No phone driving sweep or physical vibration-feel acceptance was performed; that remains for the owner. No backend mutation/deployment or phone performance claim. Evidence, source hashes and installation receipts: `evidence/drift-phone-deploy-2026-10-17/report.json`.
