# Previous tire tracks with a corrected upper return (2026-10-29)

LUC01: The owner prefers the tire tracks from before the equal-width redesign. The shared `logo.svg` restores that earlier B outline, swept ribbon profile, lower ends and group transform from `logo-tire-width-2026-10-29/before/game/assets/menu/logo.svg`.

LUC02: Only the pinched upper return is reshaped: a small rounded connection replaces its pointed, malformed join. Existing curve portions are split at their exact intersections and retained; the lower ribbon endpoints and outer B path are unchanged from the preferred revision. The lettering and SVG dimensions remain exact. The derived `boot_logo.png` is regenerated through the existing bake, so menu, loading and startup use the same corrected artwork.

R01: Native SVG comparison against the preferred revision finds 1,243 changed alpha pixels, confined to x=318..522/y=106..329 in the 1800x536 image. Alpha elsewhere is identical, including the lower ends and lettering. This is a shape/alpha comparison, not a claim of identical RGB gradients across the combined paths. The first optional Pillow comparison could not run because that package is absent; the native engine comparison succeeded without adding a dependency. [Comparison](evidence/logo-upper-curve-2026-10-29/comparison.json), [preferred artwork](evidence/logo-upper-curve-2026-10-29/preferred.png), [corrected artwork](evidence/logo-upper-curve-2026-10-29/corrected.png).

The pinned engine successfully imported the SVG in a minimal isolated project, and its matching cache was copied to the game cache. The existing native App utility captured ten Compatibility views across 1280x720, 960x540 and 1920x1080, including menu, loading, sign-in and enlarged detail. The existing splash bake succeeded. [Final detail](evidence/logo-upper-curve-2026-10-29/after/gl_compatibility/logo-detail.png), [menu](evidence/logo-upper-curve-2026-10-29/after/gl_compatibility/menu-1280x720.png), [loading](evidence/logo-upper-curve-2026-10-29/after/gl_compatibility/loading-1280x720.png). No runtime script or regression invariant changes, and no new automated test suite is added. Broader tests and desktop Mobile were not rerun for this artwork correction.

Commands run from the repository root:

```powershell
python docs/evidence/logo-upper-curve-2026-10-29/fix_curve.py
# Pinned engine, isolated APPDATA/LOCALAPPDATA:
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-upper-curve-review/import --script res://preview.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-upper-curve-review/import --script res://compare.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-upper-curve-review/import --editor --import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/logo-upper-curve-2026-10-29/run.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/logo-upper-curve-2026-10-29/run.ps1 -ScriptPath res://tests/capture_menu_logo_svg.gd -Renderer gl_compatibility
git apply --reverse --check docs/evidence/logo-upper-curve-2026-10-29/source.patch
```

The App runner uses `scripts/dev.ps1`, isolated profiles, disposable records and an empty API URL. Normal local Windows access is used for engine initialization. Q01: The [binary-inclusive source checkpoint](evidence/logo-upper-curve-2026-10-29/source.patch) passes working-tree reverse check and isolated forward/reverse exact-content comparisons. [Report and hashes](evidence/logo-upper-curve-2026-10-29/report.json). Source assets remain derived from the owner's original identity; no external artwork, font or dependency is introduced.

Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query, APK, live/backend write, real authentication/purchase, owner-save mutation, owner-process restart, deployment or main-index staging/commit/merge was performed. Concurrent work is preserved.
