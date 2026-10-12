# Original Compact coachwork

These fourteen compressed Godot ArrayMesh resources are original project-authored geometry for the existing fictional Compact. They are shared by the race and Garage model. No external model, purchased asset, third-party vehicle identity, image reference texture or generated poster is included in the meshes.

Editable source: `game/vehicle/compact_coachwork.gd`. Offline bake: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd`, using pinned Godot 4.7.2 stable ed1daf0bf. `manifest.json` records the exact bytes and SHA-256 hashes. Studio regression checks compare every baked surface's vertices, normals, tangents, UVs and indices with regeneration from its source.

Materials are supplied per model instance; baked meshes contain no player paint, account data, handling or collision state. Release inclusion uses the existing all-resources export rule. Actual visual/phone-performance acceptance remains in `docs/GARAGE_STUDIO.md`.
