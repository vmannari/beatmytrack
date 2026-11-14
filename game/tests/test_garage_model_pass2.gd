extends "res://tests/test_garage_model_simplification.gd"
## Compare normal and full-detail rendering; the control is an immutable room.
func _initialize() -> void:
	output = "res://../build/garage-model-pass2-2026-11-13/final"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-room="):
			GarageEnvironment.architecture_scene = load(argument.trim_prefix("--baseline-room="))
			phase = "before"
	if phase != "before": radial_geometry()
	run.call_deferred()

func radial_geometry() -> void:
	var holder := Node3D.new()
	var finish := StandardMaterial3D.new()
	for spec: Array in [[0.012,16],[0.034,16],[0.035,32],[0.075,32],[0.119,32],[0.12,48],[0.24,48],[0.499,48],[0.5,96],[3.65,96]]:
		var radius: float = spec[0]
		var expected: int = spec[1]
		var part: MeshInstance3D = GarageEnvironment.cylinder(holder,Vector3.ZERO,radius,0.08,finish)
		var mesh: CylinderMesh = part.mesh
		check(mesh.radial_segments == expected and mesh.rings == 0,"radius-aware cylinder detail "+str(radius))
		check(mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == expected*12,"closed caps and straight sides "+str(radius))
		var original := CylinderMesh.new()
		original.radial_segments = 96
		original.rings = 0
		original.top_radius = radius
		original.bottom_radius = radius
		original.height = 0.08
		check(mesh.get_aabb().is_equal_approx(original.get_aabb()),"fixture dimensions and axis extrema retained "+str(radius))
		if radius < 0.5:
			check(radius*(1.0-cos(PI/expected)) < 0.0011,"small-fixture radial chord error below 1.1 mm "+str(radius))
	holder.free()

func capture(view: CarShowroom, label: String) -> void:
	await super.capture(view,label)
	var threshold: float = view.showroom_viewport.mesh_lod_threshold
	view.showroom_viewport.mesh_lod_threshold = 0.0
	for reflected: SubViewport in view.reflections.views: reflected.mesh_lod_threshold = 0.0
	view.reflections.request_draw()
	await super.capture(view,"master-"+label)
	view.showroom_viewport.mesh_lod_threshold = threshold
	for reflected: SubViewport in view.reflections.views: reflected.mesh_lod_threshold = threshold
	view.reflections.request_draw()
