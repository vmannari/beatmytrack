# Original sport hovercraft surfaces

These 350 immutable ArrayMesh resources are baked from the project's original
`vehicle/hovercraft_model.gd` and `vehicle/hovercraft_surface.gd`. The fictional
model has no manufacturer identity. Each file carries the exact two source
hashes; editor builds reject a stale bake. Materials are assigned per vehicle.

The full model and lower-resolution racing model share the same authored shape,
with separate surface sampling. `tests/bake_hovercraft_surfaces.gd` verifies every
saved vertex, normal, UV and index array against the procedural construction.
Run it through the pinned `scripts/dev.ps1 -Action TestScript` entry point.

The formed hull/canopy, skirt fingers, fan/duct/cages, steering foils and fittings
are mathematical project geometry. The finish and opaque analytic glazing reuse
the project's CompactFinish and electric_glass shader without modifying them.
No downloaded model, copied photograph, bitmap generation, external code or new
dependency is included. Manufacturer photographs were consulted only to study
general hovercraft construction (bag/finger skirts and enclosed fans).

Native views, source provenance, budgets and acceptance limits are recorded in
`docs/HOVERCRAFT_MODEL_REBUILD_2026_10_28.md` and its evidence directory. The detail
budget and desktop captures do not certify AAA quality or Android performance.
