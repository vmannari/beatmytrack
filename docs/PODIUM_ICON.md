# Where you stand podium icon — 2026-10-09

Requirement: owner icon correction, V03/V05/Q01. Track detail now uses an original three-step podium glyph with centre winner, preserving the existing 20px size and colour.

Changed files: `game/ui/track_browser.gd`, `game/ui/results_icons.gd`. Evidence: `docs/evidence/podium-icon-2026-10-09/discovery-1280x720.png`, visually inspected in pinned Godot 4.7.2.

Commands: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical`; `git diff --check -- game/ui/results_icons.gd game/ui/track_browser.gd`.

The graphical run generated the updated heading successfully, but the wider existing check failed three chart-fit assertions and then encountered a nil track metadata access at line 123. It is not reported as passed. Whitespace check passed. Initial direct entry failed PowerShell execution policy; sandbox parser invocation could not write user logs. An unrelated CaptureCompactDetail action succeeded but captures vehicle detail, so is not acceptance evidence for this icon.

No phone attachment check or device test performed. Owner/device review remains; no export or deployment.

## Owner quality revision

Replaced the thin outline with a balanced solid three-step silhouette, subtle side-step tonal hierarchy, softly rounded outer corners and a negative-space winner mark. Podium rasterization now uses 4x SVG sampling and mipmaps for clean scaling at the existing 20px heading size. Changed file: `game/ui/results_icons.gd`; requirement V03/V05/Q01 and owner quality correction.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical` — 90 checks, zero failures on current workspace. Scoped `git diff --check` passed. Inspected actual desktop evidence: `docs/evidence/podium-icon-2026-10-09/refined-discovery-1280x720.png`. Earlier wider-check failures are retained above as historical outcomes. No phone attachment check/device test/export/install/deployment performed. Owner visual acceptance remains.

## Connected awards podium revision

Owner rejected the isolated bars again. Requirements: owner quality correction, V03/V05/Q01. The original glyph now depicts connected second/first/third platforms with numbered front faces, a shared plinth, shallow perspective top faces and a matte gold first-place platform. The restrained blue side platforms retain the heading colour. The podium alone uses 26px instead of 20px for readable facets; heading text and other icons retain their sizes. The numeral cutouts are transparent, preserving the real panel background. Source remains editable SVG paths in `game/ui/results_icons.gd`, with the heading-size change in `game/ui/track_browser.gd`. Original authored artwork; no external assets or dependencies.

Actual graphical command (twice, after separate artwork changes): `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical`. First run: 95 checks, zero failures. Final run: 141 checks, zero failures on the current shared workspace. Scoped `git diff --check -- game/ui/results_icons.gd game/ui/track_browser.gd` passed, with line-ending advisories only. Local Godot needed sandbox escalation to access its normal user log directory. No checks were modified for this change.

Final retained evidence: `docs/evidence/podium-icon-2026-10-09/final/discovery-1280x720.png`, `discovery-960x540.png` and `check.log`. Desktop and compact captures visually inspected. `heading-review-3x.png` is an explicitly enlarged crop of the actual desktop screenshot for review, produced with PowerShell/System.Drawing; it is not an independent device capture. `icon-quality.patch` is the task-scoped review checkpoint against the preceding rejected implementation, excluding concurrent edits.

No phone attachment check, device test, export, install or deployment performed. Owner visual acceptance remains.

## Flat style and proportions correction (current)

Owner explicitly rejects perspective and added colours and directs a return to the preceding 2D version with proportion changes. This supersedes the connected awards podium revision above. Requirements: owner correction, V03/V05/Q01.

Restored a flat filled podium, the inherited heading colour, only the centre winner mark, and the original 20px heading-icon size. Relative to the earlier flat glyph, stand widths are now 8/10/8 rather than 6/10/6, and heights are 13/18/10 rather than 12/22/8 (second/first/third). The centre is shorter and the side stands broader and closer in height. Small one-unit gaps and the original subtle outer corner rounding remain. Changed source files: `game/ui/results_icons.gd`, `game/ui/track_browser.gd`. Original vector artwork, no external assets.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_unified_histograms.gd -Graphical` — 141 checks, zero failures. Scoped `git diff --check -- game/ui/results_icons.gd game/ui/track_browser.gd` passed with line-ending advisories only. Test code unchanged.

Current evidence and task-scoped review checkpoint are under `docs/evidence/podium-icon-2026-10-09/proportions/`: native desktop and compact screenshots, `check.log`, `icon-proportions.patch`, and `heading-review-3x.png` (an enlarged crop of the desktop screenshot produced with PowerShell/System.Drawing and visually inspected). Historical rejected designs remain evidence only. No phone attachment check/device test/export/install/deployment performed. Owner visual acceptance remains.
