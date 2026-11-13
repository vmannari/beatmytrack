# Super Wash — 2026-10-28

Garage → Wash now offers **Super Wash** beside Test drive and the existing manual Wash action. One press immediately clears all cosmetic deposits on the selected car and saves the result locally. The action is free pending the owner's later ad integration.

| Requirement | Delivered behaviour |
| --- | --- |
| SW01 | Clear primary dirt/snow, slow dirt/snow, mud, smudges, wetness, aged grime, wash masks and recoat history across the whole car, including wheels and underside. Restore original clean materials and the top **Shiny. For now.** grade immediately. |
| SW02 | Stop manual-wash gestures, preserve paint/parts and other cars, save through the existing condition path, retain customisation access and existing wash-achievement handling. Newer local race wear is synchronised before cleaning; hidden/outgoing controls cannot run it. |
| SW03 | No ad, simulated ad, account reward, SDK, backend or economy change. The dedicated callback documents the future rewarded-completion boundary and the need to recheck owner/car identity at that time. |
| Q01 | Actual mouse clicks, all six cars, exact condition fields/voxels, repeat action, local reload, late race wear, visibility/section guards, three viewport sizes and native before/after views. |

Changed files: `game/ui/garage_page.gd`; new `game/tests/test_super_wash.gd` and UID; one authored row in `scripts/translations/super_wash.tsv`; the matching single message appended to `messages.pot` and all twelve PO catalogues. Existing tests and concurrent sources are preserved. Evidence includes an independently forward/reverse-checked source-only patch without staging or committing the main index.

| Actual validation | Result |
| --- | --- |
| Super Wash, headless | 162 checks, 0 failures |
| Super Wash, native Compatibility | 176 checks, 0 failures; 14 captures |
| Super Wash, native desktop Mobile | 176 checks, 0 failures; 14 captures |
| Existing easier manual washing | 48 checks, 0 failures |
| Existing gradual scrubbing/ageing | 428 checks, 0 failures |
| Owned localization rule check | All 12 catalogues pass |
| Garage script check-only | Exit 0 |

Native captures were inspected, including the dirty/clean Compact and the 960×540 Mobile layout. All four bottom actions fit at 960×540, 1280×720 and 1600×720. Native Mobile here uses the desktop Vulkan renderer; this is not Android/device evidence.

The Super Wash runs also log a concurrent `VehicleCustomisation.valid` error at line 60: an untyped conditional array is assigned to `Array[String]`. The original headless run and both native runs retain those errors despite all owned assertions passing. This work does not modify the concurrent kart-customisation source, and does not claim an error-free whole application. The sandbox reports an inaccessible Windows certificate store in runtime tests; no network is used. The first localization command mistakenly passed whole catalogues to a one-message scope and reported unrelated entries as obsolete; the retained checker scopes both inputs and passes all twelve languages. No assertion was weakened.

Commands run from the repository root:

```powershell
python docs/evidence/super-wash-2026-10-28/update_catalogues.py
python docs/evidence/super-wash-2026-10-28/run_validation.py --mode gl_compatibility
python docs/evidence/super-wash-2026-10-28/run_validation.py --mode mobile
python docs/evidence/super-wash-2026-10-28/run_validation.py --test test_garage_wash_easier
python docs/evidence/super-wash-2026-10-28/run_validation.py --test test_gentle_scrubbing
python docs/evidence/super-wash-2026-10-28/check_localization.py
```

The first headless run used the pinned console executable directly with `--headless --path game --script res://tests/test_super_wash.gd`, with workspace-only APPDATA and an empty BMT_API_URL; its log is `headless.log`. The same executable ran `--headless --path game --check-only --script res://ui/garage_page.gd`; log `parse.log`. The reusable runner isolates APPDATA/LOCALAPPDATA and bounds each test to 240 seconds without rebuilding generated identities.

Reload/rebuild and owner appearance/input acceptance remain. No device attachment query or physical-device test, APK, real auth/purchase, deployment, owner-save mutation, owner-process restart, main-index staging, commit or merge was performed. Ad integration remains future work as requested.
