# Obsolete asset export cleanup — 2026-11-03

The Android export now excludes **46 superseded vehicle mesh banks and 16 superseded challenge poster images**, retaining their source files and historical tests. Paired content ZIPs from one frozen source copy shrink from **343,325,170 bytes / 327.42 MiB** to **227,698,571 bytes / 217.15 MiB**: **110.27 MiB / 33.68% smaller content export**. This is a measured content ZIP result, not a rebuilt APK size or an architecture change.

## Requirements and changes

- OAC01: Exclude only the obsolete model/poster revisions identified by the preceding review and freshly rechecked against the frozen source.
- OAC02: Retain all active dynamic banks, five current challenge posters, previews, legal texts and existing export settings.
- OAC03: Compare paired actual exports, inspect generated indexes semantically, and exercise compiled-package resources and model construction.

`game/export_presets.cfg` appends 62 explicit exclusions to the existing 61 filters. Each bank has its own exact directory pattern; each poster has an explicit filename. The native ConfigFile parser confirms the final filter is readable. Include filters, script export mode, package identity, signing configuration and **both ARM64 and x86_64 architectures remain as they were**. No source asset was removed, recompressed, rescaled or rebaked.

`scripts/obsolete_export_assets.json` records the exact exclusion list, all 11 retained banks and all five retained posters. `scripts/verify_obsolete_asset_export.py` compares actual before/after ZIPs and fails on unexpected removals, additions, content changes, invalid CRCs, missing current banks/posters or unexpected generated-index changes. `scripts/check_exported_asset_runtime.gd` is an external test harness and is not shipped. The read-only size analyzer now excludes export-filter names from its runtime-reference text while still hashing the preset; naming an obsolete asset in an exclusion does not make it a runtime dependency.

## Results

| Check | Actual result |
| --- | --- |
| Fresh reference scan | 680 runtime files, 20,271 binary resource headers; no uses of excluded revisions |
| Source catalog regression before export | 21 checks, 0 failures |
| Retained licences regression | 520 checks, 0 failures |
| Control export | 23,787 entries; successful pinned-engine export |
| Clean export | 8,205 entries; successful pinned-engine export |
| Removed entries | Exactly 15,582 expected obsolete bank/poster/import entries |
| Retained content | All 8,203 non-index entries byte-identical |
| Class registry | All 218 declarations identical; serialization order differs |
| UID registry | All retained mappings identical; only the 16 excluded poster mappings removed |
| ZIP integrity | Every entry CRC passes in both archives |
| Packed runtime control | 11,019 checks, 0 failures |
| Packed runtime cleaned | 11,019 checks, 0 failures |
| Paired runtime comparison | All 516 model/simulation metrics identical |

The runtime harness loads **5,242 retained resources directly from the compiled content package**, including active meshes/scenes, Garage and livery preview images. It creates all five current cars in detailed/simple form, exercises every supported category/option, builds Garage models, forces the ordinary constructor fallback, advances each car's simulation for 600 ticks, and reads the five current challenge posters and legal texts. Both runs record 2 prepared-base hits, 104 prepared-kit hits and 5 Garage-template hits; fallback behavior and all geometry counts match the control. This is resource/model/simulation smoke coverage, not five completed races or native Android device acceptance.

The ZIP payload removed is 112,244,336 bytes; total ZIP reduction is 115,626,599 bytes, including per-entry headers/index/compression differences. This explains why the measured content-ZIP reduction differs from the preceding review's 108.55 MiB estimate based on the older November 2 APK. These current content exports exclude native engine libraries and are not comparable directly to a whole APK's percentage reduction.

Control ZIP SHA-256: `b73a7546a367ff9a0fe9e5b2d4514e3797f205f8a832fccfb7197cbc2b8d292c`.

Clean ZIP SHA-256: `ae89671ec9a6959f329472cee49a1d36b3380e8056cb2772ce0b1f8e7d4f4f5a`.

## Commands and isolation

Sources and imported caches were copied into `build/obsolete-asset-cleanup-2026-11-03/project`; no links to the main game or owner user directory were used. The snapshot omits top-level Android build working files, music working files, temporary/docs folders and recordings, and copies only imported/class/UID caches from `.godot`. Both exports use exactly this same snapshot; only the copied export preset differs. Thus the comparison isolates the 62 new exclusions, rather than claiming the frozen ZIP is the complete current owner's APK. The native extension DLLs and owner import cache remain untouched.

Every Godot invocation uses `scripts/run_no_crash_dialog.py` and the exact pinned `4.7.2.stable.official.ed1daf0bf` console executable. Actual full command arrays and timings are recorded in the evidence run JSONs. Representative commands, with `$task` set to the absolute task build directory and process-local `APPDATA` set to a directory within it:

```powershell
# Control used the original copied preset; final export uses the cleaned preset.
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path "$task/project" --log-file "$task/clean-fixed-export-engine.log" --editor --export-pack 'Android Debug' "$task/clean-fixed.zip"
python scripts/verify_obsolete_asset_export.py --before "$task/baseline.zip" --after "$task/clean-fixed.zip" --project "$task/project" --output "$task/export-comparison.json"
# The empty directory prevents physical game-source/asset fallback outside the ZIP.
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path "$task/empty-runtime" --main-pack "$task/clean-fixed.zip" --log-file "$task/runtime-after-engine.log" --script 'C:/Codes/Godot/Beat my track/scripts/check_exported_asset_runtime.gd' -- "$task/runtime-inputs.json" "$task/runtime-after.json"
```

The runtime input list is generated from retained bank `.res`/`.scn` files and Garage/livery/kit-preview import sidecars, plus the five current poster paths and current legal texts. `FileAccess.file_exists("res://vehicle/car_visual.gd")` is asserted false in both packed runs, proving there is no physical source fallback. The compiled `.gdc` scripts and resources are read from their exported remaps.

## Findings retained and limitations

The initial explanatory preset comment incorrectly used `#`. Godot ConfigFile requires a semicolon comment; the first cleaned export reported a missing `exclude_filter` and was interrupted. The corrected preset passes a native `ConfigFile.load`/filter/architecture check, and the final export contains none of the excluded revisions. The invalid attempt's log is retained under the task build directory; it is not counted as a pass.

The first strict byte comparison flagged the class and UID caches. Both were then fully decoded: all class declaration dictionaries are equal, every retained UID maps to its exact original path, no UID was added, and only the 16 old poster UIDs disappeared. The comparator enforces these facts instead of ignoring index files. The first finding remains in `export-comparison-first.json` under the task build directory.

Both packed **Android** content ZIPs report the same missing Windows track-geometry DLL when opened with the Windows editor executable. The content ZIP does not carry the APK's platform library installation. Model/resource/simulation smoke checks pass, but this is not a native Android extension run. The source catalog test uses the copied Windows library and passes. The environment's root certificate-store error also appears in control and final runs; no live network was used. Both content exports report the same embedded-editor ICU advisory; the pinned matching templates remain required for a real APK.

An auxiliary relative-pack-path probe could not open its pack and attempted to save editor settings outside the workspace; the sandbox denied that write. The final compared runtime runs use absolute pack paths and isolated `APPDATA`.

Concurrent off-road surface and Garage thumbnail-studio work changed `track/native_track.gd`, `ui/garage_thumbnail_studio.gd`, `project.godot` and `core/build_identity.gd` after the frozen snapshot. Those changes are preserved, not folded into the paired artifact claims. Final current-runtime text has no excluded asset references. No production rendering, physics, schema or save code was changed by this cleanup.

No APK/AAB was built or installed, no device attachment query/test was performed, and there was no backend/live access, deployment, owner game/save/process change or main-index write. Owner/device acceptance and a normal subsequent APK rebuild remain. Current art quality is retained through byte-exact resources; no visual change or new screenshot is claimed.

## Evidence and review checkpoint

- [Summary and limitations](evidence/obsolete-asset-cleanup-2026-11-03/report.json)
- [Exact export comparison](evidence/obsolete-asset-cleanup-2026-11-03/export-comparison.json)
- [Control runtime results](evidence/obsolete-asset-cleanup-2026-11-03/runtime-before.json) and [cleaned runtime results](evidence/obsolete-asset-cleanup-2026-11-03/runtime-after.json)
- Actual source checks/logs/run commands and source snapshot information are alongside those reports. Full export logs, reference hashes, content ZIPs and the task-only forward/reverse-checked patch are under `build/obsolete-asset-cleanup-2026-11-03/`.
