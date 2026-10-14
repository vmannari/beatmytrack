# Slightly larger snow puffs — 2026-10-13

WSP06 / V04 / V05 / G01 / R01 / Q01: the owner requests slightly bigger bank powder. `game/vehicle/sand_dust.gd` advances to `winter-spray-8` and increases both card dimensions by approximately15%: entry1.15×0.85→1.32×0.98 m; pushing1.45×0.90→1.67×1.04 m. Particle counts, lifetimes, movement, opacity, texture/depth guards, material-role discovery and bank resistance remain. No new asset, sampler, geometry batch, physics pin or dependency is introduced. Larger cards can rasterize more pixels; this is not a zero-cost claim.

Actual pinned Godot4.7.2 commands use `scripts/dev.ps1` with process execution-policy Bypass and normal Windows graphics/certificate access:

- `-Action TestScript -ScriptPath res://tests/test_snow_bank_behaviour.gd -Graphical -TestArgument @('--capture','--output-dir=res://../docs/evidence/winter-powder-size-2026-10-13')`:52,040 checks,0 failures.
- The same command with `-RenderingMethod mobile`:52,040 checks,0 failures on desktop Vulkan.

Both retain cold/disk/legacy bank-height coverage, actual driving/replay/rewind and180 captured frames with80 pushing frames. GPU visibility probes detect2,489 Compatibility and1,592 Mobile powder pixels. [Motion](evidence/winter-powder-size-2026-10-13/motion.html), [still](evidence/winter-powder-size-2026-10-13/push-visible.png), [Mobile motion](evidence/winter-powder-size-2026-10-13/mobile/motion.html).

The capture uses a closer diagnostic camera; runtime framing is untouched. Its readbacks/frozen profiling do not establish active-game or phone FPS. No physical-device test, Android export/install, full Validate, physics merge, backend/deployment or live write was performed. Owner size/readability review remains; restart the client to load the change.

`DEVELOPMENT_STATUS.md` and `docs/PHASE_0_PLAN.md` record the delivery. The isolated task-only checkpoint/source patch is under `build/winter_powder_size`; main index/HEAD and concurrent work are preserved. Motion HTML and disposable cache artifacts remain in workspace evidence.
