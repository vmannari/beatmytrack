# Optional racing car meshes

These are reduced samples of the project's original procedural cars. No reference
image, downloaded model or generated raster asset is included. Paint, outlines,
glass, lamps, wheel positions and authored body shapes use the same native source.
Full-detail garage resources remain in `compact_coachwork_v3`.

`game/tests/bake_racing_car_models.gd` runs offline with the exact build in
`godot-version.txt`. It saves fifty compact coachwork/glazing meshes using half
the original sampling count on each axis, plus twenty-five positions-only shadow
meshes: a sprung-body mesh and four independently rolling wheel meshes per car.
Bodies already below the shadow budget keep their original simplified topology.
The manifest records source/output triangle counts and the engine's LOD values;
those values are not physical error distances or device performance measurements.

The shadow bake uses Godot's [ImporterMesh LOD generation](https://docs.godotengine.org/en/stable/classes/class_importermesh.html#class-importermesh-method-generate-lods).
Runtime loads the baked resources without running the importer or a simplifier.
Low-resolution primitive copies remain local to the race car, and the shadow
meshes are excluded from paint/weathering bindings and ghost geometry.

Rebuild through `scripts/dev.ps1 -Action TestScript -ScriptPath
res://tests/bake_racing_car_models.gd`. This never replaces the detailed artwork.
