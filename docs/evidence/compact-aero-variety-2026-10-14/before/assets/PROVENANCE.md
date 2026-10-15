# Prepared compact-kit assets

Original project-native geometry and photographs, generated in pinned Godot 4.7.2 from the fictional compact and `game/vehicle/compact_kits.gd`. No external model/reference bitmap or AI image-generation service is used.

`meshes/` contains 1,268 losslessly serialized immutable full/simple authored patches and caps after the 2026-10-14 expansion. `manifest.json` records each source key and SHA256 of all source surface arrays before serialization. Runtime geometry uses the same source materials/transforms; missing prepared files retain the analytical builder fallback. The second original collection is authored in `compact_kit_variants.gd` against the same fitted sheet, roof and wheel profiles; arch extensions also follow the original rolled fender underneath.

`previews/gl_compatibility/` and `previews/mobile/` each contain forty 384×112 native model photographs: ten choices in each of four categories, including Original. They use the existing kit-card camera/light setup, fixed showroom pigments and lossless import/mip filtering. At most sixteen textures can enter the existing bounded thumbnail cache; forty pictures are never retained together in that cache.

Reproduce using `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical` and the equivalent `-RenderingMethod mobile -RenderingDriver vulkan` command, then Import. The offline baker explicitly bypasses prepared geometry/images. `tests/test_garage_customisation_speed.gd` verifies exact mesh-array hashes and imported preview pixels.
