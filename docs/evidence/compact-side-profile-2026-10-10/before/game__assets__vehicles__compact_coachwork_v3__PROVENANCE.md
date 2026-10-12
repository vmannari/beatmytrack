# Original Compact coachwork revision 3

Fifty compressed original project-authored ArrayMesh resources: 46 coachwork, arch, mirror, bumper and front surfaces, plus four glazing/seal surfaces. The fictional vehicle contains no purchased/external mesh, texture, real vehicle identity or supplied screenshot pixels. Runtime uses this revision; previous v1/v2 assets remain preserved.

The front corner, face, hood and fender share boundary coordinates and matching polygon samples. A 30mm rolled upper edge joins the hood to the front and side surfaces. Curved front trim and indicators use the same skin. Previous mirror proportions, rear joints, roof and ruled glazing remain preserved, with exact array comparisons against v2 for the unaffected surfaces.

Editable sources: `game/vehicle/compact_coachwork.gd`, `compact_glazing.gd`; front fittings in `compact_detail.gd`. Offline bake: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd`, pinned Godot 4.7.2 stable ed1daf0bf. Manifest records all file sizes and SHA-256 hashes. Resource UIDs change when saving into the new asset directory; byte hashes are distinct even for unchanged geometry. Native regression compares the actual vertex/normal/tangent/UV/index arrays.

Materials and saved body/accent colors remain per instance. No canonical handling/collision or player account data enters the assets. Actual commands, captures, scoped Git checkpoint and remaining owner/device acceptance: `docs/COMPACT_FRONT_JOIN.md`.
