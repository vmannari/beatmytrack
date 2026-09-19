# Illustrated menu art — 2026-09-14

The owner rejected the procedural menu graphics and supplied a detailed cel-shaded vehicle illustration. This follow-up addresses V02/V03/G03: believable vehicle proportions, precise ink contours, deliberate colour planes and polished menu presentation.

Home and Garage now use one original illustrated fictional compact, with detailed wheels, glass/interior, body seams, lights and restrained cream/blue paint. A quiet studio backdrop replaces the procedural roadside and workshop scenes. The full vehicle keeps its proportions at standard and wide landscape ratios. The Home heading uses one line, the repeated car tag is removed, and secondary shortcuts are 48 logical pixels high to leave the tyres clear of the controls. Shortcut descriptions remain tooltips. Garage's circuit shortcut names the selected track and five-lap format.

`MenuStage` is now a static 2D Control drawing a texture. It creates no 3D scene, camera, lights or car meshes. Wide screens preserve the same vehicle scale and extend the empty background. The texture is imported losslessly at native dimensions with mipmaps for stable reduction. The selected biome remains visible in the circuit information; the hero illustration is shared across biomes.

## Asset and provenance

- Workspace asset: `game/assets/menu/compact_illustration_v1.png`, 1672×941 PNG.
- SHA-256: `BBDBA87BF42B41EFAFF8EC2E98D355125590AEA04EC343C1A330522D1DBDD8B0`.
- Generated with the built-in `image_gen` tool using the exact [saved prompt](ILLUSTRATED_MENU_PROMPT.md). No CLI/API fallback, credentials or runtime network calls are used.
- Original generated source is preserved under the Codex generated-images directory. The project consumes its own copied file, with no dependency on that directory.
- The owner's branded pickup image is a style reference only. The runtime artwork uses a fictional compact; the supplied image is not shipped.
- This is menu illustration. The driving car mesh, camera, physics and track geometry are not changed by this follow-up. The illustration does not imply that a matching detailed 3D vehicle asset has been authored.

## Changed files

`game/ui/menu_stage.gd`, `menu_feature.gd`, `game/core/app.gd`, the PNG and import settings, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, `docs/PREMIUM_MENUS.md`, this document, the saved prompt and `licenses/ASSETS.md`. Updated evidence is in `docs/evidence/illustrated-menus/`.

## Actual verification

Commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1` and the pinned `4.7.2.stable.official.ed1daf0bf` engine.

- `Import`: passed, including the new texture and mipmap settings. The existing missing Android build-tools warning remains.
- `CheckScript -ScriptPath res://ui/menu_stage.gd`: passed.
- `TestApp`: 84 checks, zero failures, covering menu navigation, editor round trips, library selection and race/results flow.
- `CaptureMenus`: 250 checks, zero failures. Actual Godot screenshots cover Home/Garage plus the existing Tracks/Settings/Results flow at 1280×720, 960×540 and 1600×720. Viewport-dispatched navigation, fixed action bounds and results retry passed. Final artwork review checked complete tyres/roof/body, aspect ratio, crisp linework, readable controls and a seamless wide backdrop.
- `git diff --check`: passed for the isolated menu follow-up.

The existing capture harness redirects records and tracks to disposable directories. Results and returning-player screens use the explicitly marked 108.816-second fixture against 109.000 seconds; these are not claimed driven records. No full physics regression was run for this image/presentation replacement. The menu follow-up is isolated on `menu/illustrated-20260914`, based on the preceding menu checkpoint `9fe0353`, while concurrent handling/editor work in the main workspace is preserved.

## Review evidence and remaining acceptance

[Home](evidence/illustrated-menus/home-first-1280x720.png) · [Garage](evidence/illustrated-menus/garage-1280x720.png) · [Compact Home](evidence/illustrated-menus/home-first-960x540.png) · [Wide Home](evidence/illustrated-menus/home-first-1600x720.png) · [Capture log](evidence/illustrated-menus/capture-log.txt) · [Manifest](evidence/illustrated-menus/manifest.json).

Owner visual acceptance remains open. No phone attachment check, physical-phone test or Android export was performed in this follow-up. Compact desktop output retains the project's 1280×720 logical layout and does not establish device readability, touch reach or thermal performance. The runtime still uses its existing gameplay car mesh; this change specifically replaces the rejected menu hero graphics.
