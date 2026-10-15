# Garage workbench plate removal — 2026-10-14

Requirement BC01 / V05 / G01 / R01 / Q01: remove the shallow plate circled by the owner beneath the left workbench.

`game/ui/garage_furnishings.gd` no longer creates the 4.20 × 0.055 × 0.38 m steel plate at local `(0, 0.17, 0.32)`. The original tabletop, four legs/feet, upper rear brace, drawers, toolboard, compressor and tyre rack remain. This is a single decorative geometry deletion; camera, materials, batching/caches, Garage behavior, car cosmetics and canonical simulation are unchanged.

The existing native workshop capture passes **19 checks, zero failures**, before and after in Compatibility on pinned Godot `4.7.2.stable.official.ed1daf0bf`. The prepared room retains 64 material meshes and loses exactly 44 triangles / 96 vertices. Inspected the actual [before](evidence/garage-bench-cleanup-2026-10-14/before/gl_compatibility/left-workshop.png) and [after](evidence/garage-bench-cleanup-2026-10-14/after/gl_compatibility/left-workshop.png) left-workshop views, plus the updated overview and compressor views. The plate is absent in the final capture.

Actual successful commands, with APPDATA relocated to `build/garage-bench-cleanup-user`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_workshop.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-bench-cleanup-2026-10-14/before/gl_compatibility' -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/capture_garage_workshop.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--evidence-root=res://../docs/evidence/garage-bench-cleanup-2026-10-14/after/gl_compatibility' -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://ui/garage_furnishings.gd -CommandTimeoutSeconds 60
git diff --no-index --check -- build/garage-bench-cleanup/before/garage_furnishings.gd game/ui/garage_furnishings.gd
```

Parser and scoped whitespace checks pass. Native capture initially required bypassing the local PowerShell script policy and access to the Windows certificate store, which automatic approval review allowed. Two Mobile attempts using `build/garage-bench-cleanup/run_check.ps1 -Renderer mobile -ScriptName capture_garage_workshop` failed during concurrent compact-car work: first `CompactGrille` was unregistered, then mesh generation reported `SurfaceTool.set_uv` without `ARRAY_FORMAT_TEX_UV`. Those attempts are not passes; their logs are retained. No unrelated car source was changed.

Changed delivery files: the one runtime file above, this report, and the BC01 entries in `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`. Native captures and logs are under `docs/evidence/garage-bench-cleanup-2026-10-14`. A task-only Git checkpoint and patch live in `build/garage-bench-cleanup/checkpoint-repo` and the evidence directory; the main branch/index and other workspace edits are preserved.

Remaining acceptance: owner's appearance review and Mobile/physical-phone verification. No phone test, APK export/install, deployment, full Validate or physics change was performed.
