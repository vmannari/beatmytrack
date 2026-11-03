# Volt kit visibility — 2026-11-01

The previous Volt kit previews had eight hood choices with no changed pixels against stock from the hood camera; some body kits and the smallest spoiler also made very small changes. The revised hood choices replace the factory hood with continuous sculpted panels and fitted shut lines, with extractor or louver details on appropriate variants. Rear spoilers are raised clear of the deck and have fitted edges; body kits use more visible splitters, skirts, rear valances and differing side details. Existing option IDs and the already-visible rims remain unchanged. Stock geometry is restored when the hood is reset.

The factory hood is a replaceable editable part, so the selected hood does not stack a second full surface over it. The Volt-specific preview and modular identities were refreshed, alongside 353 reference meshes, the four full/simple and fixed/editable base scenes, the Garage scene and 120 full/simple kit modules. The factory shadow and other cars were not rebaked.

## Verification

- Actual showroom captures compared each of the 60 non-stock choices against stock at the category camera. A pixel counts when an RGB channel changes by more than 12; each choice must change at least 1,500 pixels. Compatibility with silver and dark blue paint and desktop Forward Mobile with silver each passed 60/60. This catches missing and very subtle parts but is not a substitute for viewing every option from every angle. The lowest counts (hood, aero, rims, body) were 3291/2232/3793/3057 on silver and 2201/2213/3793/2224 on dark blue. Reports and before/after examples are in [the evidence folder](evidence/volt-kit-visibility-2026-11-01/).
- Both model qualities passed 610 kit option, uniqueness, replacement and restore checks. The prepared module comparison passed 1788 checks, including all 120 modules and race/ghost-related representations. Stock prepared shape passed 106 checks.
- The native Compatibility Garage workflow passed 54 checks. Body-kit/tire pose checks passed 180/180 and the retained electric wheel-clearance checks passed 79/79.
- The base scene source-hash audit reported the current key and no differing dependencies. The scoped source diff passed whitespace validation. Windows reported a root-certificate-store read error on these local test runs; the tests completed successfully without network access.

Run Godot checks with `python scripts/run_no_crash_dialog.py -- <Godot console executable> ...`, using isolated `APPDATA` and `LOCALAPPDATA`. Tests: `res://tests/test_volt_kit_visibility.gd` (add `-- --dark` for dark paint), `res://tests/test_volt_kits.gd`, `res://tests/test_volt_kits_garage.gd`, `res://tests/test_modular_car_assets.gd -- --vehicle=electric --all-kits`, `res://tests/test_volt_body_kit_wheel_fit.gd`, `res://tests/test_electric_wheel_clearance.gd`, and `res://tests/test_volt_sport_redesign.gd -- --prepared`.

Desktop renderers were checked on an NVIDIA GPU; no phone test or owner appearance acceptance is implied. Reload the game to see the changed resources.
