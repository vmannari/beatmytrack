# Volt rear light at the trunk seams — 2026-11-01

The rear lamp housing and illuminated guide are now divided into left, liftgate and right sections. Two narrow dark joints follow the same rear-surface coordinates as the trunk shut line, so the lamp no longer bridges the opening. All three illuminated sections use the existing shared brake material. The rear body and hatch profile are otherwise unchanged.

The Volt reference mesh assets, editable/fixed full/simple modular bases, Garage scene and 120 prepared kit modules were refreshed under the updated source identity. Earlier reference assets were retained.

Verification: `test_volt_rear_lamp_gaps.gd` passes 98 checks on prepared full/simple geometry, including actual sampled hatch-ribbon alignment, gaps in the lens and housing, and shared running/brake illumination. The retained `test_volt_rear_window_curve.gd -- --prepared` passes 62 checks. `test_modular_car_assets.gd -- --vehicle=electric --all-kits` passes 1788 checks including the race representations and brake material. The prepared base reports its current source key with no changed dependencies. Native Garage views were captured on desktop Compatibility and Forward Mobile, in silver and blue; see [the rear views](evidence/volt-rear-light-joints-2026-11-01/). These are desktop renderer checks, not a phone test.

Noninteractive Godot commands were run through `scripts/run_no_crash_dialog.py` with isolated profile directories. The Windows root-certificate-store read warning occurred during local runs; the listed checks completed successfully. Reload the game to see the refreshed resources.
