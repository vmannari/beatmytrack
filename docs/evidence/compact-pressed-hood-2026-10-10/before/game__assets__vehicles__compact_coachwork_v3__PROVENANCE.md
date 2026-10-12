# Original Compact coachwork revision 3

Fifty compressed original project-authored ArrayMesh resources: 46 coachwork, arch, mirror, bumper and front surfaces, plus four glazing/seal surfaces. The fictional vehicle contains no purchased/external mesh, texture, real vehicle identity or supplied screenshot pixels. Runtime uses this revision; previous v1/v2 assets remain preserved.

The front corner, face, hood and fender share boundary coordinates and matching polygon samples. A 30mm rolled upper edge joins the hood to the front and side surfaces. Curved front trim and indicators use the same skin. Previous mirror proportions, rear joints, roof and ruled glazing remain preserved, with exact array comparisons against v2 for the unaffected surfaces.

Editable sources: `game/vehicle/compact_coachwork.gd`, `compact_glazing.gd`; front fittings in `compact_detail.gd`. Offline bake: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_compact_coachwork.gd`, pinned Godot 4.7.2 stable ed1daf0bf. Manifest records all file sizes and SHA-256 hashes. Resource UIDs change when saving into the new asset directory; byte hashes are distinct even for unchanged geometry. Native regression compares the actual vertex/normal/tangent/UV/index arrays.

Materials and saved body/accent colors remain per instance. No canonical handling/collision or player account data enters the assets. Actual commands, captures, scoped Git checkpoint and remaining owner/device acceptance: `docs/COMPACT_FRONT_JOIN.md`.

Side-profile follow-up (2026-10-10): side-window openings share cabin-derived positions, matching sill/top rails and dark seals; the longer/taller door follows that same pillar and continues around its window frame. These are original native code additions; all50 baked resource hashes remain exact. Actual commands, captures and acceptance: `docs/COMPACT_SIDE_PROFILE.md`.

Front-bumper follow-up (2026-10-10): the front bumper now offsets the actual bowed body/corner path, has a closer rounded section and matching end-cap samples. Amber inserts attach to the new curve. Only `rounded_front_bumper.res` changes; the other49 native hashes remain exact. Final50resources total723722bytes. Original code, actual commands, captures and acceptance: `docs/COMPACT_FRONT_BUMPER.md`.

Shaped-hood follow-up (2026-10-10): original broad crown/central field and two tapered pressed shoulders, fading at the preserved body perimeter. Accent triangles share the shaped steel's grid. Only `crowned_hood.res` and `hood_accent.res` change;48other native hashes remain exact. Final50resources total735928bytes. Actual commands/captures/acceptance: `docs/COMPACT_SHAPED_HOOD.md`.

Owner stronger-hood correction (2026-10-10): central-field/shoulder relief doubles, middle crown102mm; matching paint triangles and perimeter retained. Only the same two hood native assets change;48others remain hash-exact. Final50resources total736278bytes. Actual commands/captures/acceptance: `docs/COMPACT_SHAPED_HOOD.md` (CG13 follow-up).
