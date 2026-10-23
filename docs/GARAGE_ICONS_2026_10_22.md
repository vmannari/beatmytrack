# Garage icon silhouette refinement — 2026-10-22

GAI01: replace the thin, toy-like Garage glyphs with more substantial original artwork. GAI02: make all seven destinations read as one family at the actual sidebar size. GAI03: retain the existing navigation, gold/navy state contrast, alignment, touch targets and bounded texture cache. R01/Q01: check native presentation and preserve a reviewable task-only source patch. AAA is the owner's quality target; these checks do not substitute for their visual acceptance.

`game/ui/garage_mode_icons.gd` now draws a head-on Compact, broad studio brush with a quieter ferrule, water drop with an open reflection and clean glint, forged spanner with an open jaw/socket, solid musical notes, championship cup with a punched star and folded newspaper with distinct print blocks. Filled silhouettes, deliberate transparent cutouts and related proportions replace the earlier predominantly rounded outlines. The source remains original editable SVG inside GDScript, rasterized once per key at the existing 256-pixel size with mipmaps. The seven-key cache and tint inheritance remain. No image generation, downloaded art, font icon pack, dependency, new shader or additional texture allocation per icon was introduced.

`game/ui/garage_page.gd::_build_rail` changes only the icon width from 36 to 40 logical units relative to the saved pre-task source. The existing 60-unit rail, 60/52-unit targets, centred layout, state margins and navigation remain. Native views include the four-button car browser and all six selected-car destinations, including active yellow icons.

The existing `game/tests/test_garage_sidebar.gd` was used unchanged with the API disabled and disposable workspace records. No new test was added for this reversible artwork change. Results:

| Actual check | Result |
|---|---|
| Original sidebar, native Compatibility | 426 checks, 0 failures |
| First artwork iteration, native Compatibility | 426 checks, 0 failures |
| Final sidebar, headless | 415 checks, 0 failures |
| Final sidebar, native Compatibility | 426 checks, 0 failures |
| Final sidebar, desktop Mobile/Vulkan | 426 checks, 0 failures |
| Project script parser | 919 scripts, 0 failures |
| Scoped source whitespace check | Passed |

Both native runs cover 960×540, 1280×720 and 1600×720, equal target dimensions, mouse/touch navigation, fixed rail positions, retained showroom/car and no car-condition record writes. Desktop Mobile is a Windows Vulkan renderer check, not Android execution. Native final views were inspected at their real size, including the smallest selected-car layout.

Actual commands used Godot `4.7.2.stable.official.ed1daf0bf` through the existing `scripts/dev.ps1` entry point and `build/run_garage_sidebar.ps1`, which scopes APPDATA to the workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer gl_compatibility -Evidence res://../docs/evidence/garage-icons-2026-10-22/before/native
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer gl_compatibility -Evidence res://../docs/evidence/garage-icons-2026-10-22/iteration-1
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer gl_compatibility -Evidence res://../docs/evidence/garage-icons-2026-10-22/final/gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Evidence res://../docs/evidence/garage-icons-2026-10-22/final/headless
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Script res://tests/test_script_parse.gd
powershell -NoProfile -ExecutionPolicy Bypass -File build/run_garage_sidebar.ps1 -Renderer mobile -Evidence res://../docs/evidence/garage-icons-2026-10-22/final/mobile
git diff --check -- game/ui/garage_mode_icons.gd game/ui/garage_page.gd
```

The first sandboxed native launch reported Windows certificate-store access errors and was interrupted; it is not counted as passed. The same local command subsequently passed with approved native access. One outer PowerShell profile printed its existing execution-policy warning; the explicitly invoked `-NoProfile`/process-only Bypass runner still completed. An initial duplicate-target patch was rejected before source changes and then applied correctly. In visual review, the first turntable icon resembled a camera, so the final design uses unmistakable musical notes; the brush was also widened to balance the other silhouettes. All initial and final native views remain in evidence.

Evidence is under `docs/evidence/garage-icons-2026-10-22/`: saved pre-task working sources, before/iteration/final screenshots, layout receipts, exact runner snapshot, raw run logs, final source hashes and `task.patch`. The patch is relative to the saved working sources, preserving pre-existing Garage and other workspace changes. It is a source checkpoint, not a commit of the shared dirty repository.

The local client needs a reload/restart to display the revised source. Owner appearance acceptance and physical-device readability remain. No phone attachment check or device test was performed. No APK/export/install, backend/account mutation or deployment was performed.
