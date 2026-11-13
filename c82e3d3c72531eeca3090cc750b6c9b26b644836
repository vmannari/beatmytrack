# Loading uses the new logo (2026-10-29)

ML03: The initial startup splash now uses the same clean artwork as the menu. `game/assets/menu/boot_logo.png` is rendered directly from the shared `logo.svg`, including the matching B/stacked-text height. The existing 640x225 transparent canvas is retained; the vector artwork fits at 640x191 and is centered vertically. Supersampling and Lanczos reduction smooth the edges. Godot's early splash supports PNG only ([official documentation](https://docs.godotengine.org/en/4.5/classes/class_projectsettings.html#class-projectsettings-property-application-boot-splash-image)); it does not load an imported SVG texture at that stage.

Race-loading and startup-restoration panels already instantiate `MenuBrand`, so they already share `logo.svg`. No runtime script or project setting needs changing. [Startup artwork](../game/assets/menu/boot_logo.png) and [actual race-loading capture](evidence/loading-logo-svg-2026-10-29/after/gl_compatibility/loading-1280x720.png).

ML04: New `game/tests/bake_boot_logo.gd` provides the repeatable SVG-to-splash bake. The existing `capture_owner_brand.gd` calls that same bake instead of restoring the retired bitmap, and accepts the existing `BMT_MENU_LOGO_OUTPUT` override so new captures do not overwrite historical evidence.

R01: The bake exited successfully: 640x225 RGBA output, used rectangle (1,17,639,191), error 0. The unchanged App loaded successfully in the existing owner-brand capture utility. Four native Compatibility screenshots cover menu and race loading at 1280x720 and 960x540, with clean exit. The artwork was visually inspected. No new automated test was added for this asset-only follow-up. These are actual loading-panel captures; the PNG preview is the splash asset, not an operating-system capture of the earliest boot frame. Prior both-renderer menu/logo results remain in `MENU_LOGO_SVG_2026_10_29.md` and were not rerun as new results.

Commands run from the repository root, with normal local access for Windows certificate initialization:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/loading-logo-svg-2026-10-29/run.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/loading-logo-svg-2026-10-29/run.ps1 -ScriptPath res://tests/capture_owner_brand.gd -Renderer gl_compatibility
git apply --reverse --check docs/evidence/loading-logo-svg-2026-10-29/source.patch
```

The runner uses pinned `scripts/dev.ps1`, isolated APPDATA/LOCALAPPDATA and disposable App records with an empty API URL. Generated build metadata is restored only while its values belong to the run. Q01: The binary-inclusive task-baseline [checkpoint](evidence/loading-logo-svg-2026-10-29/source.patch) passes working-tree reverse and isolated forward/reverse byte comparisons. [Report, commands and hashes](evidence/loading-logo-svg-2026-10-29/report.json). The previous SVG, menu component, splash settings and splash import configuration remain exact. A concurrent build changed only the generated project version during capture; that identity is preserved.

The splash derives from the existing owner-supplied identity through the previously authored SVG; no new font, third-party artwork or dependency is introduced. Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query, APK, live/backend write, real authentication/purchase, owner-save mutation, owner-process restart, deployment or main-index staging/commit/merge was performed. Concurrent work is preserved.
