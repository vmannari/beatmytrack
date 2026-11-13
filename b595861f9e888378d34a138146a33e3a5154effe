# Smooth vector menu logo (2026-10-29)

ML01: The shared menu logo now uses [logo.svg](../game/assets/menu/logo.svg), reconstructed as clean paths from the owner's existing PNG. The swept gold B, stacked italic lettering and gold MY are retained. Lettering is outlined; the SVG has no embedded image, external font or linked asset. Lossless import, mipmaps and explicit linear mipmap filtering keep the small header smooth. Godot rasterizes the SVG at import; this is a vector source with a filtered runtime texture, as described in the [Godot image import documentation](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_images.html).

ML02: "Same length" is implemented as matching the full height of the adjacent two-line text. Both visible layers start at y=8 and end at y=528, a measured 520-pixel span. The B keeps its own horizontal proportions. Independent native SVG layer measurements are in [alignment.json](evidence/menu-logo-svg-2026-10-29/alignment.json).

Changed runtime files: `game/ui/menu_brand.gd`, `game/assets/menu/logo.svg` and its `.import` settings. The brand takes its region from the SVG dimensions and retains the existing layout minimum, aspect ratio behavior, input transparency and caller-controlled padding. The shared component also updates sign-in, restoration and race-loading branding. The original PNG and boot splash remain available; the historical capture helper still uses the PNG.

R01: Actual App captures passed at 1280x720, 960x540 and 1920x1080 on desktop Compatibility and Mobile renderers. Each renderer saved ten views: menu, sign-in and race loading at three sizes, plus an enlarged detail. [Menu](evidence/menu-logo-svg-2026-10-29/after/gl_compatibility/menu-1280x720.png), [detail](evidence/menu-logo-svg-2026-10-29/after/gl_compatibility/logo-detail.png), [small Mobile-renderer view](evidence/menu-logo-svg-2026-10-29/after/mobile/menu-960x540.png), [sign-in](evidence/menu-logo-svg-2026-10-29/after/gl_compatibility/account-960x540.png). These use disposable records and an empty API override. The empty track list is the offline fixture.

Existing `test_menu_presentation.gd` passed **41 checks, zero failures**, headless. Existing `capture_sign_in_fit.gd` passed **867 checks, zero failures**, native Compatibility, covering four window sizes and nine account states. No regression invariant was changed and no new automated test was added for this artwork change. The new `capture_menu_logo_svg.gd` is a capture utility.

Commands actually run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/menu-logo-svg-2026-10-29/run.ps1 -Phase before -Renderer gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/menu-logo-svg-2026-10-29/run.ps1 -Action Import -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/menu-logo-svg-2026-10-29/run.ps1 -Phase after -Renderer gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/menu-logo-svg-2026-10-29/run.ps1 -Phase after -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/menu-logo-svg-2026-10-29/run.ps1 -ScriptPath res://tests/test_menu_presentation.gd -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/menu-logo-svg-2026-10-29/run.ps1 -ScriptPath res://tests/capture_sign_in_fit.gd -Renderer gl_compatibility
```

The runner uses the pinned `scripts/dev.ps1`, isolated APPDATA/LOCALAPPDATA, disposable records and an empty API URL. It restores generated build metadata only while those values still belong to its run. Sandboxed startup/import attempts failed Windows certificate-store access; the same native checks passed with normal local access. One outer shell emitted a profile execution-policy warning, without changing system policy.

The main-project editor import failed opening the temporary copy of the existing native geometry DLL. The SVG was therefore imported with the exact pinned Godot 4.7.2 executable in `build/menu-logo-svg-review/import`, a minimal project containing only the SVG and its settings. Its generated `.ctex`/`.md5` were copied to the matching main-project cache, and the actual App subsequently rendered the asset on both renderers. The successful isolated import used task-specific editor profiles. An initial isolated sandbox attempt also reported denied editor-settings writes; no owner settings were changed. This is not a full-project import/parser pass.

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/menu-logo-svg-review/import-profile'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'build/menu-logo-svg-review/import-local-profile'
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/menu-logo-svg-review/import --editor --import
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/menu-logo-svg-review/import --script res://audit.gd
```

The first enlarged view exposed an inner-ribbon overlap and slight right-edge clipping; the final paths correct both. The first layer-measurement helper serialized namespace prefixes that ThorVG rejected; its corrected SVG serialization passes, and the owned failed process was stopped. Initial images, helper and logs remain in the evidence folder.

Q01: [source.patch](evidence/menu-logo-svg-2026-10-29/source.patch) is a task-baseline checkpoint; it includes only the vector/component/capture utility, runner, provenance and task notes. It is verified forward and reverse in isolated folders and reverse-checked against the working tree. [report.json](evidence/menu-logo-svg-2026-10-29/report.json) records outcomes and hashes. Existing concurrent changes are preserved, with no main-index staging, commit or merge.

Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query, APK, real authentication/purchase, live/backend write, deployment, owner-save mutation or owner-process restart was performed. Desktop Mobile means the desktop Vulkan renderer, not an Android-device run.
