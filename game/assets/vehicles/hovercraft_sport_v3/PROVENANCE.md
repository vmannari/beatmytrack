# Sport hovercraft surfaces

These immutable ArrayMesh resources are native offline bakes of the original
fictional racer authored in `hovercraft_model.gd`, `hovercraft_sport_hull.gd`,
`hovercraft_sport_drive.gd` and `hovercraft_sport_surface.gd`. Their source
signature is stored on each mesh. The detailed and racing versions use separate
sampling; mutable paint, glass and light materials remain per vehicle.

`tests/bake_hovercraft_sport_surfaces.gd` saves and compares every vertex,
normal, UV and index array with the procedural construction. Run through the
pinned `scripts/dev.ps1 -Action TestScript` entry point. The previously rejected
`hovercraft_body_v2` assets are retained for history and are not this model.

The model, shapes, mechanical assemblies and native photographs are original
project work. The existing project CompactFinish and opaque analytic glass shader
are reused. No third-party model, photograph, trademark, generated bitmap or new
runtime dependency is shipped. Design references informed general construction
only. See `docs/HOVERCRAFT_SPORT_REDESIGN_2026_10_29.md` for results and limits.
