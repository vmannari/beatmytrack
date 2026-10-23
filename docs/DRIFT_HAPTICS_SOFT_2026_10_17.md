# Lighter drift haptics (2026-10-17)

DH03 / DH01-DH02 / G01 / R01 / Q01: the owner finds the deployed drift feedback too strong. Halve requested amplitude at every speed/slip combination: the existing curve changes from0.18-0.45 to0.09-0.225 before the same speed multiplier. Keep20ms pulses, at most10Hz, slip thresholds, all silence/reset gates and the independent saved Settings switch. Steering-button feedback and canonical driving/replay remain unchanged. The OnePlus exposes AMPLITUDE_CONTROL; perceived strength still requires owner review.

Runtime change: `game/platform/drift_haptics.gd` (one amplitude expression). The existing `game/tests/test_drift_haptics.gd` upper bound is tightened to the new maximum. No UI, persistence schema, platform worker or physics changes.

The phone was confirmed to run the previous verified APK6c923b95 before building. Its retained frozen sources were cloned and only the drift expression/test bound changed. Newer unrelated working-tree features were not added to this phone build. The root working tree receives the same amplitude fix, preserving concurrent work.

Actual pinned Godot4.7.2 checks pass on this isolated build: haptics45, driving72, catalog21, menus41, import and desktop APP_READY. QuickValidation was used; no full-regression-suite pass is claimed. Haptics coverage retains the actual simulation parity, saved toggle, lifecycle gates and bounded slow-worker checks.

Installed and SHA-256 matched on OnePlus DN2103: `639ffeaefd2e1214338bb00c1f76a0dc849eebba1b2768e2f454bc365516a977`. Client build: `0.3.0-creator.8f604613b7102e1820c1ac3d98c7294a`. `adb install --no-streaming -r` retains data. Both progress files and all123 track/cache files are exact before first launch, retaining14 saved drafts. Private complete file/old-APK backups remain under `build/drift-haptics-soft-2026-10-17/protected-before`. Actual Android launch Status ok/APP_READY and no captured script/parse/fatal errors are verified; a native capture is retained. No automated phone driving or subjective feel pass is claimed.

Actual commands used a disposable workspace APPDATA and process-only Git trust for the exact snapshot:

```powershell
python build/drift-haptics-soft-2026-10-17/freeze.py
powershell -NoProfile -ExecutionPolicy Bypass -File build/drift-haptics-soft-2026-10-17/snapshot/scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_drift_haptics.gd -CommandTimeoutSeconds 150
powershell -NoProfile -ExecutionPolicy Bypass -File build/drift-haptics-soft-2026-10-17/snapshot/scripts/dev.ps1 -Action ExportAndroid -QuickValidation -CommandTimeoutSeconds 600
python build/drift-haptics-soft-2026-10-17/phone.py backup
python build/drift-haptics-soft-2026-10-17/phone.py install
python build/drift-haptics-soft-2026-10-17/phone.py verify
python build/drift-haptics-soft-2026-10-17/phone.py forward
python build/drift-haptics-soft-2026-10-17/phone.py launch
```

The existing PC service is reused via USB reverse routing; no service is started or deployed. All evidence, hashes and the task-only checkpoint are recorded in `evidence/drift-haptics-soft-2026-10-17/report.json`. Remaining acceptance: the owner's actual phone feel. No backend changes, FPS claim or physical driving sweep.
