# Prepared compact-kit assets

Original project-native geometry and photographs, generated in pinned Godot 4.7.2 from the fictional compact and `game/vehicle/compact_kits.gd`. No external model/reference bitmap or AI image-generation service is used.

`meshes/` contains 368 losslessly serialized immutable full/simple authored patches and caps. `manifest.json` records each source key and SHA256 of all source surface arrays before serialization. Runtime geometry uses the same source materials/transforms; missing prepared files retain the analytical builder fallback.

`previews/gl_compatibility/` and `previews/mobile/` each contain sixteen 384×112 native model photographs using the existing kit-card camera/light setup. They retain the original fixed showroom pigments and have lossless import/mip filtering. Only the selected renderer's sixteen textures can enter the existing bounded thumbnail cache.

Reproduce using `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical` and the equivalent `-RenderingMethod mobile -RenderingDriver vulkan` command, then Import. The offline baker explicitly bypasses prepared geometry/images. `tests/test_garage_customisation_speed.gd` verifies exact mesh-array hashes and imported preview pixels.
