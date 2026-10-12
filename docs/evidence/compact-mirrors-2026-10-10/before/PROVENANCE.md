# Original Compact coachwork revision 2

Forty-six compressed original project-authored ArrayMesh resources: 42 coachwork/mirror/bumper surfaces and four glazing/seal surfaces. Sources are `game/vehicle/compact_coachwork.gd` and `compact_glazing.gd`. No external model, purchased texture, real vehicle identity or supplied reference image is embedded in these meshes. Revision 1 resources remain preserved; runtime now uses this revision.

Offline bake: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd`, using pinned Godot 4.7.2 stable ed1daf0bf. `manifest.json` records exact byte sizes and SHA-256 hashes. Native regression checks compare every baked vertex/normal/tangent/UV/index array against source regeneration and compare actual mesh boundaries at the repaired joins.

Materials and saved player colors remain per instance. No canonical handling/collision or player account data enters the assets. Actual commands, native captures, remaining owner/device acceptance and the task-only review checkpoint are in `docs/COMPACT_GEOMETRY_CORRECTIONS.md`.
