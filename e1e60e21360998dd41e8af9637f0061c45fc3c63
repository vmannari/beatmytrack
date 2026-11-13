# Correct the marked shoulder in the B logo (2026-10-29)

MBC01: The owner's marked image identifies the shoulder on the outer edge of the upper tire track, where two crossing curves formed a visible kink. The straight section now leads into one smooth cubic curve (`H395 C455 95 508 163 515 222`). Its horizontal tangent matches the straight lead-in. [Corrected B](evidence/logo-marked-bend-2026-10-29/corrected-b.png), [preferred earlier B](evidence/logo-marked-bend-2026-10-29/preferred-b.png).

MBC02: The preceding attempt rounded the wrong join. That edit is removed. The earlier pointed inner return, lower tracks, outer B outline and group transform are restored from the original preferred SVG. The wordmark and SVG definitions are exact. Only the marked upper contour changes shape relative to that preferred revision. `boot_logo.png` is regenerated from the same corrected SVG, so menu, loading and startup agree.

R01: Native alpha comparison against the preferred revision finds 3,741 changed pixels confined to x=318..522/y=106..238; alpha everywhere else is identical, including the lower tracks. This is a shape comparison, not an assertion of identical per-path RGB gradient sampling. [Comparison data](evidence/logo-marked-bend-2026-10-29/comparison.json). The source generator is byte-idempotent. The outer B path, group attributes, wordmark and definitions pass exact XML comparisons. MenuBrand and SVG import settings remain unchanged.

The pinned engine successfully imported the SVG in a minimal project; its matching cache was copied to the game cache. The existing splash bake succeeded (640x225, error 0). The existing native App capture utility completed ten Compatibility views at 1280x720, 960x540 and 1920x1080, covering menu, loading, sign-in and enlarged detail. [Actual menu](evidence/logo-marked-bend-2026-10-29/after/gl_compatibility/menu-1280x720.png), [loading](evidence/logo-marked-bend-2026-10-29/after/gl_compatibility/loading-1280x720.png), [detail](evidence/logo-marked-bend-2026-10-29/after/gl_compatibility/logo-detail.png). No runtime script or regression invariant changes; no new test suite was added. Broader tests and desktop Mobile were not rerun for this asset correction.

Commands run from the repository root:

```powershell
python docs/evidence/logo-marked-bend-2026-10-29/correct_marked_bend.py
# Pinned engine, task-specific APPDATA/LOCALAPPDATA:
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-marked-bend-review/import --script res://preview.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-marked-bend-review/import --script res://compare.gd
& 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path build/logo-marked-bend-review/import --editor --import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/logo-marked-bend-2026-10-29/run.ps1 -Headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/logo-marked-bend-2026-10-29/run.ps1 -ScriptPath res://tests/capture_menu_logo_svg.gd -Renderer gl_compatibility
git apply --reverse --check docs/evidence/logo-marked-bend-2026-10-29/source.patch
```

The App runner uses `scripts/dev.ps1`, isolated profiles, disposable records and an empty API URL; normal local Windows access is used for engine initialization. Q01: The [binary-inclusive source checkpoint](evidence/logo-marked-bend-2026-10-29/source.patch) passes working-tree reverse check and isolated forward/reverse exact-content comparisons. [Report and hashes](evidence/logo-marked-bend-2026-10-29/report.json). This remains an original vector reconstruction of the owner's identity, with no new external artwork, font or dependency.

Reload/rebuild and owner appearance acceptance remain. No physical-device test or attachment query, APK, live/backend write, real authentication/purchase, owner-save mutation, owner-process restart, deployment or main-index staging/commit/merge was performed. Concurrent work is preserved.
