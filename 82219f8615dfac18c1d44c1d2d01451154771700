# Consistent B-logo tire ribbons (2026-10-29)

LTR01: The upper tire ribbons in `game/assets/menu/logo.svg` now have equal 64-unit widths and 26-unit gaps. Both curves derive from the same centerline and its normal offsets, replacing the hand-drawn outlines that narrowed to points and widened through the bend. The right-hand B body follows a parallel inner edge. All three horizontal upper sections are 64 units high. Removing the former nonuniform group scale keeps these widths consistent in the actual SVG coordinate system.

LTR02: The B retains the complete text height: native SVG raster bounds for both layers are y=8 to y=528, height 520. The wordmark, lettering, colours, SVG import settings, layout component and loading code remain exact. `boot_logo.png` is regenerated from this corrected SVG through the existing bake utility, so startup, menu and loading share the correction.

R01: Actual SVG vertices measure 63.9991-64.0010 units across the two ribbons and 25.9991-26.0009 across their gap; the sub-0.001 variation is coordinate rounding. [Measurements](evidence/logo-tire-width-2026-10-29/widths.json), [native layer bounds](evidence/logo-tire-width-2026-10-29/alignment.json). The evidence generator is byte-idempotent on the final SVG. These are one-off artwork measurements, not a new automated regression suite.

The pinned engine imported the corrected SVG in the isolated review project. Its matching `.ctex`/`.md5` caches were copied to the game cache. The existing App capture utility completed with ten native Compatibility views across 1280x720, 960x540 and 1920x1080, covering menu, loading, sign-in and a large detail. [Final detail](evidence/logo-tire-width-2026-10-29/after/gl_compatibility/logo-detail.png), [small menu](evidence/logo-tire-width-2026-10-29/after/gl_compatibility/menu-960x540.png), [loading](evidence/logo-tire-width-2026-10-29/after/gl_compatibility/loading-1280x720.png). The splash bake succeeded with error 0 and the existing 640x225 canvas. No runtime script or regression invariant was changed; broader tests and the desktop Mobile renderer were not rerun for this asset-only correction.

Commands run from the repository root:

```powershell
python docs/evidence/logo-tire-width-2026-10-29/build_ribbons.py
# Focused import uses the pinned engine and isolated APPDATA/LOCALAPPDATA:
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-tire-width-review/import --editor --import
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-tire-width-review/import --script res://alignment.gd
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/logo-tire-width-2026-10-29/run.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/logo-tire-width-2026-10-29/run.ps1 -ScriptPath res://tests/capture_menu_logo_svg.gd -Renderer gl_compatibility
git apply --reverse --check docs/evidence/logo-tire-width-2026-10-29/source.patch
```

The App runner uses `scripts/dev.ps1`, task-specific profiles, disposable records and an empty API URL. Native commands used normal local Windows access for engine initialization. The first two enlarged candidates retained a merged band and then a pointed upper return; the final version corrects these, and their previews remain in evidence.

Q01: [source.patch](evidence/logo-tire-width-2026-10-29/source.patch) includes the SVG, derived splash, evidence helpers, provenance and task notes. It passes working-tree reverse check and isolated forward/reverse byte comparisons. [Report and hashes](evidence/logo-tire-width-2026-10-29/report.json). The existing identity derives from the owner's original artwork; this geometric correction introduces no external art, font or dependency.

Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query, APK, live/backend write, real authentication/purchase, owner-save mutation, owner-process restart, deployment or main-index staging/commit/merge was performed. Concurrent work is preserved.
