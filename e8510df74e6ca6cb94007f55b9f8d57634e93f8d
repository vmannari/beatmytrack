# Garage kart and saved appearance recovery (2026-10-28)

The owner's Windows game log identifies two actual startup failures: `kart_model.gd` could not preload the then-missing `kart_kits.gd`, and the new per-car customisation validator assigned an untyped conditional array to `Array[String]`. The latter appears 43 times in the observed log, including local save loading and attempts to save downloaded appearances. It can therefore make every car appear to have lost its customisations while preventing sync from restoring them.

The kart dependency was already present when this task inspected the workspace. An interim untyped-array correction was also present. This task makes the validator explicitly typed: create one `Array[String]`, populate it through `assign` or `append`, and reuse it for the four categories. The current kart implementation, model, catalogue and customisation choices are preserved. A fresh process is required; the existing owner's process was not restarted.

| Requirement | Result |
| --- | --- |
| GARC01 | Verify the existing kart dependency and actual six-car Garage. The fitted kart has visible geometry, four retained wheels, an exact saved appearance and a ready carousel photograph. |
| GARC02 | Eliminate the conditional-array runtime failure. Validate specific and unspecified vehicle IDs, save all six liveries plus Compact/kart parts together, and reload exact values. Wrong-car and unsupported kits remain rejected. |
| GARC03 | Recover missing local appearance fields through the existing sync implementation, using an in-process read-only server fixture. Every design commits and survives reload; repeated recovery makes zero PUT requests. No owner save or live backend is changed. |

Runtime change: `game/vehicle/vehicle_customisation.gd`. New regression and UID: `game/tests/test_garage_appearance_recovery.gd`. The runner and source checkpoint are in `docs/evidence/garage-appearance-recovery-2026-10-28/`. Existing model files and tests remain unchanged by this task.

Actual commands use the pinned Godot 4.7.2 through `scripts/dev.ps1`, a workspace-local `APPDATA`, an empty backend URL and no owner session:

```text
python docs/evidence/garage-appearance-recovery-2026-10-28/run_checks.py recovery-headless-local test_garage_appearance_recovery.gd headless
python docs/evidence/garage-appearance-recovery-2026-10-28/run_checks.py records-local test_records.gd headless
python docs/evidence/garage-appearance-recovery-2026-10-28/run_checks.py sync-local test_sticker_appearance_sync.gd headless
python docs/evidence/garage-appearance-recovery-2026-10-28/run_checks.py recovery-compatibility test_garage_appearance_recovery.gd gl_compatibility
python docs/evidence/garage-appearance-recovery-2026-10-28/build_checkpoint.py
```

| Actual run | Checks | Failures |
| --- | ---: | ---: |
| New recovery regression, headless actual App | 70 | 0 |
| Existing records regression | 54 | 0 |
| Existing current-car appearance-sync regression | 54 | 0 |
| New recovery regression, native Compatibility | 83 | 0 |
| Total | 261 | 0 |

The native run saves six screenshots. The [kart view](evidence/garage-appearance-recovery-2026-10-28/recovery-compatibility/kart.png) and [Compact view](evidence/garage-appearance-recovery-2026-10-28/recovery-compatibility/compact.png) were visually inspected. The native run exits cleanly with no script or engine errors; the tested runtime hashes remain unchanged throughout all passing runs. Initial sandbox attempts fail before executing assertions because Godot cannot access the Windows root certificate store; their original logs remain, and the passing local runs have the required access.

The [machine report](evidence/garage-appearance-recovery-2026-10-28/report.json) records source hashes, actual commands, results and limits. The scoped source patch uses the task's captured baseline and excludes all pre-existing kart implementation and other concurrent work. It is checked forward and backward and round-tripped in a disposable workspace folder, without staging or committing the main index.

The live account's restoration is not claimed: no live appearance GET/PUT, authentication, owner save edit, session edit, or owner-process restart was performed. The log shows the original failure in the download/save path; the fixture proves that this path can now persist existing online designs without uploading defaults. Restart/reload, ordinary signed-in sync and owner confirmation of the original designs remain. No physical-device attachment query or device test, APK, deployment or merge was performed. Desktop Mobile was not rerun for this validation-only correction.
