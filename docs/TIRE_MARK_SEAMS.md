# Tire-mark seam reduction, 2026-10-13

Owner request: make the repeated tire-mark seams less visible without harming performance. Requirement IDs: TM01 continuous appearance, TM02 bounded cost, TM03 retained marks/colours; V04/V05 presentation/performance, G01/R01 canonical isolation, Q01 evidence.

The six-centimetre overlap between every pair of translucent segments caused double-opacity dark bands, particularly visible on the supplied curved asphalt marks. Each mark now covers its actual driven length. Grain and loose-surface tread use the existing interpolated world position; transverse asphalt streaks keep the same phase between segments. This removes per-segment pattern resets. Two unused varyings and the second fragment hash were removed.

The existing 16,384-slot ring, four wheel contacts, 0.32m sample spacing, thirty mesh vertices, ten triangles per instance and single instanced mark draw remain. No textures, passes, allocation pools or instance uploads were added. This seam slice does not alter RGB/alpha style functions, physics-derived intensity/width/relief, race persistence, reset or ground/deck guards. Canonical simulation/scoring/camera and original desert dust were not changed. A concurrent desert-only material/palette edit landed in the same file during the final review; it was preserved and both graphical diagnostics were rerun against the merged source.

Changed files:

- `game/vehicle/skid_trails.gd`: shader continuity and exact-length marks.
- `game/tests/test_soil.gd`: replace the deliberately superseded overlap expectation with an exact 1m driven-length assertion. The remaining physics/palette/fading/batch checks are retained.
- `game/tests/test_tire_mark_seams.gd`: paired frozen-original/current-source screenshots, pixel comparison and full-budget render/CPU diagnostic.
- This document, `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and `docs/evidence/tire-seams-2026-10-13/` record actual scope and acceptance.

Actual commands used the pinned Godot `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_tire_mark_seams.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_tire_mark_seams.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_tire_mark_seams.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestSoil
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_soil.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestDesert
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_trails.gd -Graphical -RenderingMethod gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_bridge_trails.gd -Graphical -RenderingMethod mobile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

Final outcomes: seam diagnostic 8 checks / zero failures per graphical renderer; soil 166 / zero; desert 87 / zero; bridge trails 8 / zero per renderer. Headless seam diagnostic 5 / zero. Bridge stress deliberately disables hardware depth: 9,722/9,492 leaking roof pixels in unprotected controls become zero with the existing guard. Ground/deck resumption and unchanged canonical snapshot pass.

Paired screenshots reproduce curved black rubber and carried-dirt marks with the actual shared shader/mesh. Straight-control endpoint-versus-midsegment darkness contrast drops from 0.05434 to 0.000087 on Compatibility and 0.00980 to 0.000305 on Mobile. This metric measures repeated join banding, not all possible seams or overall image quality. Both before/after screenshots were inspected. Diagnostic pixel mapping explicitly uses matching 1600x900 content and image dimensions.

Desktop RTX 3090, 1600x900, 2x MSAA, full 16,384 visible mark instances, three alternating before/after stages with sixty warm-up and 240 measured frames each:

| Renderer | Original GPU medians (ms) | Revised GPU medians (ms) | Draws |
| --- | --- | --- | --- |
| Compatibility | 0.347 / 0.312 / 0.310 | 0.279 / 0.280 / 0.279 | 2 total: ground + marks, identical |
| Mobile Vulkan | 0.316 / 0.277 / 0.275 | 0.253 / 0.253 / 0.252 | 2 total, identical |

These are isolated scene render times, including the ground, under deliberately high overlapping-mark stress. They are not full-game FPS or physical-phone results. CPU emission has the same operations except removal of a length addition; final merged-source nine-repeat medians were 32.81 -> 34.29 microseconds/sample in Compatibility and 32.28 -> 31.51 in Mobile. Across repeated runs the direction of the small CPU difference reversed with process load; this does not establish a CPU regression or a guaranteed improvement. No additional CPU work or GPU draw/geometry budget was introduced.

Initial outcomes retained: PowerShell execution policy required the standard process-local `-ExecutionPolicy Bypass`; restricted Godot user-log and ADB folder access required approved runner access. First soil run correctly failed the old 1.06m overlap expectation; the replacement asserts the intended exact driven length and the graphical 166-check suite subsequently passed. Initial diagnostic pixel coordinates used scaled content; corrected before the final measured comparison. Early exploratory render timings used only 1,282 marks; the final reports use all 16,384 and supersede them.

Evidence: `gl_compatibility-before.png`, `gl_compatibility-after.png`, `mobile-before.png`, `mobile-after.png`, renderer-specific `*-profile.json`, actual runner logs and `skid_trails-before.gd.txt` in this evidence folder. The frozen original is project-owned presentation code saved before this task; it retains earlier uncommitted desert/ice changes and enables the paired diagnostic to be rerun. It lives outside the game export root.

One task-only Git-format review patch is saved as `docs/evidence/tire-seams-2026-10-13/implementation.patch`. The workspace already contains extensive unrelated edits, so no broad commit/stage/reset was performed. The patch compares saved entry sources and includes only this slice's runtime/test/documentation changes; captures/reports are companion artifacts.

Remaining acceptance: owner review on actual race roads, abrupt turns and changing mark strengths/surfaces, and physical-phone appearance/performance. Tight curves can retain tiny wedges between rectangular segment ends; this pass removes the dominant overlap bands without adding dynamic ribbon reconstruction. Doctor reports attached OnePlus DN2103; no physical-device test, Android export/install, full regression, backend work or production deployment was performed for this task.
