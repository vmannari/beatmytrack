# Trophy wall decoration refinement ? 2026-10-12

Requirements: GC25 sculpted original laurel and architectural finish; GC26 curved display foliage. Preserve GC15?GC24, CW13/CW15/CW16, V06/G01/R01/Q01. AAA+ is the owner's quality target and remains subject to visual and physical-device acceptance.

Changed `game/ui/garage_details.gd`: replaces disconnected flat oval leaves with indexed curved, pointed relief leaves, continuous stems and midribs; restrained inset panel reveals, lighter charcoal backing, quieter returns, layered gold-edged empty award bases and broader softer spot pools. Changed `game/ui/garage_workshop.gd`: replaces stick-like plant construction with nineteen curved, tapered folded blades in one indexed mesh. Original code-authored geometry, existing architecture batching/cache, no added assets/dependencies. Six award positions remain empty. Camera, car selection, local cosmetics, handling and scoring unchanged.

Actual commands (pinned 4.7.2.stable.official.ed1daf0bf):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_reference.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-polish-2026-10-12/compatibility'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_reference.gd -Graphical -RenderingMethod mobile -TestArgument '--evidence-root=res://../docs/evidence/trophy-polish-2026-10-12/mobile'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_garage_car_transition.gd -Graphical -TestArgument '--evidence-root=res://../docs/evidence/trophy-polish-2026-10-12/transition'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor
```

Final outcomes: Import passes; Compatibility layout/captures 25 checks, Mobile Vulkan layout/captures 25 checks; retained zoom/dissolve/trophy return 23 checks, all zero failures. Captures include four window sizes, all five cars and trophy wall on both renderers. Inspected final Compatibility trophy capture. Initial sandbox cache/log and ADB access failed; permitted normal-cache reruns succeeded. First relief capture exposed a typed-array runtime error; fixed before successful runs, with no weakened assertions.

[Final trophy wall](evidence/trophy-polish-2026-10-12/compatibility/trophy-wall.png), [Mobile Vulkan](evidence/trophy-polish-2026-10-12/mobile/trophy-wall.png). Baseline sources are under evidence/before. Scoped Git checkpoint is `build/trophy-polish-checkpoint`; main index and unrelated work are preserved.

Doctor lists no attached Android device. No physical-device test, sustained performance measurement, Android export/install, full regression, backend work or deployment performed. Remaining acceptance: owner review of decoration/material/lighting toward AAA+, physical-phone brightness/antialiasing/frame pacing and future earned-award integration. No earned trophies invented.
