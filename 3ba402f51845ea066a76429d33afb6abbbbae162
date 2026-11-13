# Extra customisation colour row - 2026-10-26

EC01: Add one row of five distinct colours to Garage > Customise > Colours. The palette now has 20 swatches in four rows of five. The new row contains cobalt blue `3f62b2`, violet `6945a0`, rose `cf6f91`, mint `72b8a3` and warm brown `8b573b`. All original 15 colours retain their order.

EC02: Keep the existing selection and local persistence behavior. Only `PALETTE` in `game/ui/garage_livery_menu.gd` changes. The remainder of that runtime file is exact against the captured task-start source, preserving concurrent paint-list work. Selecting each new colour for Body, Accent and Detail and reopening disposable local records produces 15 matching selections per renderer (30 total).

EC03: Review the actual offline guest App with pinned Godot 4.7.2 on both desktop Compatibility and Mobile renderers. Native captures show the fourth row at 960x540, 1280x720 and 1720x960. The short window uses the existing vertical scroll; the taller windows show the palette and custom-colour control together. The extra 540x960 capture clips the existing landscape shell and is retained as a limitation, not a passing portrait layout.

- [Compatibility, 1280x720](evidence/customisation-extra-colours-2026-10-26/gl_compatibility/colours-1280x720.png)
- [Compatibility, 960x540](evidence/customisation-extra-colours-2026-10-26/gl_compatibility/colours-960x540.png)
- [Mobile renderer, 1280x720](evidence/customisation-extra-colours-2026-10-26/mobile/colours-1280x720.png)
- [Recorded commands, results and runtime hash](evidence/customisation-extra-colours-2026-10-26/report.json)
- [Task-only runtime checkpoint](evidence/customisation-extra-colours-2026-10-26/task-only.patch)

Actual commands from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/customisation-extra-colours-2026-10-26/run.ps1 -Mode headless
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/customisation-extra-colours-2026-10-26/run.ps1 -Mode gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/customisation-extra-colours-2026-10-26/run.ps1 -Mode mobile
python docs/evidence/customisation-extra-colours-2026-10-26/record.py
git apply --check --reverse docs/evidence/customisation-extra-colours-2026-10-26/task-only.patch
```

Both native review commands exit 0 and record 20 chips/five columns, four layout samples and 15 exact saved selections each. Static recording confirms 20 distinct colours, the original palette prefix and unchanged remaining runtime source. The reverse patch check passes.

The initial sandboxed headless run fails on Windows root-certificate/access-denied errors. The retry outside the sandbox reaches the retained `test_customisation_carousel.gd` but stops during page attachment at `electric_coachwork.gd:854`, `panel_reveal_point`, before colour interaction. That regression suite does not pass; its assertions are unchanged. Both logs remain in the evidence folder. This palette task does not change the electric model.

The evidence folder contains the task-start runtime snapshot, reusable capture/command/recording helpers, native screenshots, command metadata, logs, report and runtime patch. The runner temporarily installs its capture script under `game/tests/` to use the existing `scripts/dev.ps1` entry point, then removes it. No permanent regression test was added for this palette-only change.

Reload and owner appearance acceptance remain. No device attachment check or physical-device test was performed. No APK, real authentication/purchase, owner-save or live backend mutation, deployment, staging, commit, merge or owner-process restart was performed.
