# Volt hood quality — 2026-11-02

VHQ01 fixes the large grey inserts; VHQ02 replaces swollen shapes with restrained formed metal; VHQ03 preserves the existing choices, saved IDs, paint, replacement workflow and racing appearances.

All fifteen optional hoods now use lower, shaped creases and channels. The skin has exactly the factory nose, cowl and fender boundaries, with zero displacement at those edges. Sampled full/simple skins stay between −20 and +30 mm relative to Original in the builder's unscaled coordinates (the existing whole-car scale remains 0.88). Original is unchanged. The previous Gaussian relief added roughly 11–13 cm and lifted the entire panel perimeter by 7 mm.

The reported grey areas were explicitly authored large rubber-coloured inlays and pale alloy strips, rather than missing materials. Those broad inserts and metal strips are removed from the painted choices. Only Carbon centre has a charcoal centre insert; four vented choices have small dark pocket floors with body-coloured louvre lips. The remaining formed surfaces use the same mutable body-paint material as the car. Regression checks require more than 87% painted surface area on ordinary choices and more than 73% on Carbon centre, including both model qualities and red/blue colour changes after selecting a hood.

## Real-car references

- [Porsche Taycan exterior design](https://newsroom.porsche.com/en_US/products/taycan/exterior-design-18551.html): low bonnet between stronger wing shoulders, restrained EV front proportions. Used to guide the overall relief and edge fit.
- [BMW M3 CS manufacturer article](https://newsroom.bmwgroup.com/global/the-all-new-bmw-m3-cs): pressed bonnet indents and controlled exposed-carbon contrast. Used to guide the paired channels and the limited charcoal insert.
- [Lotus Emeya manufacturer gallery/release](https://www.lotuscars.com/en/press/news/lotus-unveils-emeya-its-first-hyper-gt): supplementary electric GT reference. These references inform original procedural geometry; no manufacturer images, badges or vehicle geometry enter the game assets.

## Review images

- [Before, all choices in blue](evidence/volt-hood-quality-2026-11-02/before-views-contact.jpg).
- [After, all choices in blue](evidence/volt-hood-quality-2026-11-02/final-gl-blue-contact.jpg).
- [After, all choices in silver](evidence/volt-hood-quality-2026-11-02/final-gl-silver-contact.jpg).
- [Desktop Mobile contact sheet](evidence/volt-hood-quality-2026-11-02/after-mobile-blue-contact.jpg).

The full native image folders contain quarter, front and low side views for Original and every option in both colours: 96 before images, 96 final Compatibility images and 96 desktop Forward Mobile images. The first 96-image candidate set is retained separately. All six final Compatibility Original PNGs are byte-identical to their matching before images; see `stock-picture-comparison.json`.

## Sources and prepared assets

Runtime changes are limited to `game/vehicle/electric_kits.gd`, an explicit hood revision in `game/vehicle/modular_car_kits.gd`, and that same revision in `game/ui/garage_preview_cache.gd`. The latter prevents old hood photographs from surviving this change. The existing kit regression recognizes the new skin name without changing its replacement requirement. New focused mesh/material regression and native capture helpers are `game/tests/test_volt_hood_quality.gd` and `game/tests/capture_volt_hood_quality.gd`.

Four Volt base scenes, 120 full/simple Volt modules and the Volt Garage rest scene are refreshed because the prepared resources carry conservative shared-source provenance. The actual geometry change is confined to the thirty optional hood modules. No catalogue IDs, prices, translations, handling resources, account data or backend code change.

## Actual verification and retained findings

- Procedural hood regression: 250 checks, zero failures. The same mesh/material constraints against the archived task-start hood builder produce 250 checks and 82 failures, including excessive relief, lifted seams, steep normals and overly large non-paint areas.
- Retained complete Volt kit regression: 610 checks, zero failures.
- Native Garage preview/equip/local fixture save/reload/purchase cancellation/race/ghost/reset workflow: 54 checks, zero failures on Compatibility and 54/0 on desktop Forward Mobile.
- Prepared full/simple hood material and actual module-admission check: 160 checks, zero failures. Exhaustive prepared comparison of all 120 Volt modules, both qualities, bases, live replacement, materials, normals, UVs and racing representations: 1,788 checks, zero failures. See `prepared-pinned.log` and `all-modules-pinned.log` in the evidence directory. After concurrent source edits settled, all 125 prepared resources were rebuilt in the actual workspace; the final workspace admission/material check also passes 160/0 (`prepared-workspace-final.log`).

The first focused test had an indentation parse error; its log is retained. The first geometric implementation failed two depth assertions on Race channels because its vent pocket overlapped a channel; the channel depth was reduced, with the −20/+30 mm requirement unchanged. The first prepared checks failed all thirty admission assertions when concurrent forklift sources and generated build identity changed during preparation. The original logs and source-key probe are retained. The final prepared comparison uses the recorded source copy in `tmp/volt-hood-quality-pinned/game`, whose source hashes are retained in `pinned-source-sha256.json`. It shares the actual production assets and imported resources, and never substitutes an expected material or bypasses a module-admission check. Later unrelated source or generated identity changes can invalidate conservative prepared fingerprints and trigger the existing procedural fallback; they do not change these hood shapes. No concurrent sources or generated identity were reverted.

Windows emitted its existing root-certificate-store read error during isolated offline Godot startup. Completed native commands retain their actual test counts and exit status; no connection to an API was configured. A failed optional reference-image download did not supply a runtime asset.

## Commands

Use the pinned `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`. Every engine launch was wrapped with `python scripts/run_no_crash_dialog.py --`. Test processes use separate repository `tmp/volt-hood-quality-*-user` directories for `APPDATA` and `LOCALAPPDATA`, empty `BMT_API_URL`, and `--audio-driver Dummy`. No owner save or owner process is used.

Commands include `--path game`. The recorded exhaustive prepared comparison and its bake sequence use `--path tmp/volt-hood-quality-pinned/game`; the last rebuild and 160/0 prepared check use the actual `--path game` again:

```text
--headless --script res://tests/test_volt_hood_quality.gd
--headless --script res://tests/test_volt_hood_quality.gd -- --historical
--headless --script res://tests/test_volt_hood_quality.gd -- --prepared
--headless --script res://tests/test_volt_kits.gd
--headless --script res://tests/bake_modular_car_bases.gd -- --vehicle=electric
--headless --script res://tests/bake_modular_car_kits.gd -- --vehicle=electric
--headless --script res://tests/bake_garage_cars.gd -- --vehicle=electric
--headless --script res://tests/test_modular_car_assets.gd -- --vehicle=electric --all-kits
--rendering-method gl_compatibility --script res://tests/test_volt_kits_garage.gd
--rendering-method mobile --script res://tests/test_volt_kits_garage.gd
--rendering-method gl_compatibility --script res://tests/capture_volt_hood_quality.gd -- --output=res://../docs/evidence/volt-hood-quality-2026-11-02/final-gl
--rendering-method mobile --script res://tests/capture_volt_hood_quality.gd -- --output=res://../docs/evidence/volt-hood-quality-2026-11-02/after-mobile
```

The task-start copy, binary-inclusive task-only checkpoint and round-trip validation are in `docs/evidence/volt-hood-quality-2026-11-02/`. The main Git index is untouched. The first checkpoint attempt exposed Git attribute newline normalization; the final checkpoint uses isolated temporary Git repositories with `* -text` to prove the actual source bytes as well as compressed binary resources round-trip exactly.

Reload is required. Owner appearance acceptance and physical-device rendering/performance remain unmeasured. No device attachment query/test, APK, real purchase, owner-save mutation, owner-process restart, live/backend mutation or deployment was performed.
