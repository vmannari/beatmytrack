# Stable Create biome layout — 2026-10-25

Grass and Winter changed the page height because the selected description's wrapped height determined the summary panel's minimum. At a 1360×720 window Grass made the summary 135 logical units high while the other choices used 118. At 1280×720 Winter shrank it from 135 to 118. The biome cards and Create Track action moved with it.

`game/core/app.gd` now reserves the tallest of all five translated descriptions at the available width. It includes the effective font and fallback line height and line spacing. Measurements are cached by width, locale and font metrics. Selection still updates the existing controls, and resizing can reclaim space when every description fits on one line.

| Requirement | Verification |
| --- | --- |
| CBH01 | Grass, Winter and the other three choices share identical card, summary and Create Track rectangles at each window size. |
| CBH02 | Existing selection regression: 82/82 Compatibility; retained nodes/focus, touch, cached return, fresh draft and latest-biome creation remain. |
| R01 | Existing App regression: 141/141 headless. No simulation, biome content, artwork or selection authority changes. |
| Q01 | Whole-project parser: 1181 scripts, zero failures. Final English Compatibility/Mobile and Finnish/Japanese Compatibility receipts each cover 24 selections with stable rectangles and fully fitting descriptions. Native before/after screenshots are in the evidence folder. No device test was performed. |

The capture script is `game/tests/capture_create_biome_height.gd` with its generated UID. It uses fresh local data and disables the backend. `--source` reloads the exact saved task-start App only in the capture process's memory, preserving concurrent source edits. The capture compares 1280×720, 960×540, 1360×720 and 1600×720 windows. The smaller window retains the application's existing 1280×720 logical canvas.

Actual commands used the pinned Godot 4.7.2 engine through `scripts/dev.ps1`. `APPDATA` was redirected under `build/create-biome-height-2026-10-25` for every run. The evidence runner records the native capture modes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/create-biome-height-2026-10-25/run-capture.ps1 -Mode before
powershell -NoProfile -ExecutionPolicy Bypass -File build/create-biome-height-2026-10-25/run-capture.ps1 -Mode final
powershell -NoProfile -ExecutionPolicy Bypass -File build/create-biome-height-2026-10-25/run-capture.ps1 -Mode mobile
powershell -NoProfile -ExecutionPolicy Bypass -File build/create-biome-height-2026-10-25/run-capture.ps1 -Mode fi
powershell -NoProfile -ExecutionPolicy Bypass -File build/create-biome-height-2026-10-25/run-capture.ps1 -Mode ja
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_biome_selection_latency.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--out=res://../docs/evidence/create-biome-height-2026-10-25/retained-selection'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_app.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
python docs/evidence/create-biome-height-2026-10-25/audit.py
git apply --reverse --check docs/evidence/create-biome-height-2026-10-25/checkpoint.patch
```

Initial captures using paragraph height alone, and then a standalone Label, reserved 47/49 units where the effective fallback font required 57. Their geometry receipts remain. The final sizing includes the effective font height in both calculation and cache identity. The sandboxed first native launch could not read Windows runtime resources; subsequent launches used the approved runtime access. Initial fresh-profile Mobile/Finnish/Japanese captures exceeded the capture-only 20-second startup allowance; it was changed to 60 seconds. Existing regression assertions were retained.

See [the generated report](evidence/create-biome-height-2026-10-25/report.json) for final renderer/language geometry results and hashes, and [the scoped checkpoint](evidence/create-biome-height-2026-10-25/checkpoint.patch) for only this task's source changes. Native comparison images include [original Grass](evidence/create-biome-height-2026-10-25/before/1360x720-pine.png), [final Grass](evidence/create-biome-height-2026-10-25/final/1360x720-pine.png), [original Winter](evidence/create-biome-height-2026-10-25/before/1280x720-winter.png) and [final Winter](evidence/create-biome-height-2026-10-25/final/1280x720-winter.png).

Reload the client to use the change. Owner appearance and physical-device touch acceptance remain. Phone attachment was not checked. No APK, device interaction, deployment, live account mutation or owner-process restart was performed. Concurrent work was preserved.
