# Prepared compact-kit assets

Original project-native geometry and photographs, generated in pinned Godot 4.7.2 from the fictional compact and `game/vehicle/compact_kits.gd`. No external model/reference bitmap or AI image-generation service is used.

`meshes/` contains 1,244 losslessly serialized immutable full/simple authored patches and caps after the 2026-10-14 aero silhouette revision. `manifest.json` records each source key and SHA256 of all source surface arrays before serialization. Runtime geometry uses the same source materials/transforms; missing prepared files retain the analytical builder fallback. `compact_kit_variants.gd` owns the hood/body/rim collection; `compact_aero.gd` owns distinct hatch spoilers, roof wings and lower rear wings, using the original roof/rear-metal fitting profiles. Arch extensions retain the original rolled fender underneath. Obsolete generated aero meshes are removed only by exact previous-manifest filenames after the replacement is prepared.

`previews/gl_compatibility/` and `previews/mobile/` each contain forty-three 384×112 native model photographs: thirteen aero choices and ten each for hood/rims/body, including Original. Aero uses one common side/rear photo camera to expose height and aft position; the other category photos retain their previous cameras. Original fixed pigments and lossless import/mip filtering remain. At most sixteen textures can enter the existing bounded thumbnail cache.

Reproduce using `scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_kit_previews.gd -Graphical` and the equivalent `-RenderingMethod mobile -RenderingDriver vulkan` command, then Import. The offline baker explicitly bypasses prepared geometry/images. `tests/test_garage_customisation_speed.gd` verifies exact mesh-array hashes and imported preview pixels.

For an aero-only change, pass `-TestArgument '--aero-only'`. This prepares that category at both sampling levels, merges the unchanged other categories into the manifest and preserves their photos/resources.
