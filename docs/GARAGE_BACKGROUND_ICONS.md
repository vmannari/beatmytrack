# Garage shared background and rail icons

Owner request, 2026-10-12. GC13: remove Garage's page background so the shared menu picture shows through. GC14: improve side-menu icons. Preserve GC06-GC12/CW13/CW15/CW16/V06/G01/R01/Q01.

Removed GaragePage's full-page opaque navy draw and its redraw hook. The existing general `MenuBackdrop` picture now shows behind the left rail, gaps and action-row surround. The central 3D workshop, actual cars and turnable pedestal remain as established by the preceding owner requests.

The Garage rail has original 64-unit vector artwork: a front-view car for browsing, a paintbrush for Customise, a droplet with bubbles for Care, and a wrench for Tuning. Stroke weight, restrained translucent fills, 38px optical size and 3x rasterisation/mipmaps match the Race rail. Normal/hover/focus/pressed icon colours remain legible on the dark and yellow buttons. Tooltips/actions stay the same. No new player-facing label, dependency or bitmap art is added; paint/condition/storage, racing/handling/scoring and backend behavior are unchanged.

Files: `game/ui/garage_page.gd`, new `game/ui/garage_mode_icons.gd` (+UID), and `game/tests/test_garage_carousel.gd` (optional evidence destination only, with all existing assertions retained). Documentation: this file, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands on pinned `4.7.2.stable.official.ed1daf0bf`, with isolated test records:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/garage-background-icons-2026-10-12'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_carousel.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument '--evidence-root=res://../docs/evidence/garage-background-icons-2026-10-12/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
python build/checkpoint_garage_background_icons.py
```

Results: Compatibility **157 checks**, Mobile/Vulkan **157 checks**, both zero failures; import passes. Existing tests cover actual touch/card confirmation, keyboard/focus navigation, per-car local paint/dirt, wash exit/persistence, frozen 3D cards and fixed-room pedestal rotation. Thirty-two fresh captures cover browsing/selection/Customise/Care/Tuning at 960x540, 1280x720, 1600x720 and a turned pose on both desktop renderers; historical capture folders are preserved. Inspected [Customise](evidence/garage-background-icons-2026-10-12/customise-1280.png), [Care](evidence/garage-background-icons-2026-10-12/care-960.png), [browsing](evidence/garage-background-icons-2026-10-12/cars-1280.png) and matching Mobile captures. The general backdrop is visibly exposed beneath the rail and below the selected-car controls.

Task-only two-commit checkpoint: `build/garage_background_icons/checkpoint-repo`. Scoped patch, hashes, before sources and actual logs: `docs/evidence/garage-background-icons-2026-10-12`. Main branch/index and concurrent work are preserved.

Doctor reported no attached Android devices. No phone test, Android export/install, full Validate, physics regression/merge, backend operation or deployment was performed. Owner visual/icon-recognition review and physical-device readability remain open. Restart the local game to load these changes.
