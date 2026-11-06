extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	var car := CarVisual.new()
	car.vehicle_id = "electric"
	root.add_child(car)
	while not car.model_ready: await process_frame
	for mesh: MeshInstance3D in car.find_children("Reference*", "MeshInstance3D", true, false):
		if "Glass" not in str(mesh.name) and "Screen" not in str(mesh.name) and "Roof" not in str(mesh.name): continue
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var low := Vector3.ONE*100.0
		var high := -low
		for n: Vector3 in normals:
			low = low.min(n)
			high = high.max(n)
		print(mesh.name," normals ",low," to ",high," vertices ",normals.size())
	car.free()
	quit()
