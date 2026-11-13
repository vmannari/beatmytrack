extends SceneTree
## Regression: hidden bottom, clean roofs, faint residue and real missed doors.
var checks: int = 0
var failures: int = 0
var inspector_script: GDScript = preload("res://ui/garage_cleanliness.gd")

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func check_underbody(view: CarShowroom) -> void:
	var original: Array[Dictionary] = view.pick_meshes
	var original_bindings: Array[Dictionary] = view.weathering.bindings.duplicate()
	var node := MeshInstance3D.new()
	view.car.body.add_child(node)
	var a := Vector3(-1,0.2,-1)
	var b := Vector3(1,0.8,-1)
	var c := Vector3(1,0.8,1)
	var d := Vector3(-1,0.2,1)
	for bottom: bool in [true,false]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in ([a,c,b,a,d,c] if bottom else [a,b,c,a,c,d]): surface.add_vertex(vertex)
		node.mesh = surface.commit()
		view.pick_meshes = [{"node":node,"bounds":node.mesh.get_aabb(),"triangles":node.mesh.generate_triangle_mesh()}]
		var binding: Dictionary = original_bindings[0].duplicate()
		binding.node = node
		binding.index = 0 # The synthetic patch has exactly one surface.
		view.weathering.bindings = [binding]
		var inspector: RefCounted = inspector_script.new()
		inspector._sample_exterior(view)
		check(inspector.points.is_empty() if bottom else not inspector.points.is_empty(),view.vehicle_id+" sloping underside excluded / exterior retained: "+str(bottom))
	view.pick_meshes = original
	view.weathering.bindings = original_bindings
	node.queue_free()

func check_material_boundary(view: CarShowroom) -> void:
	var original: Array[Dictionary] = view.pick_meshes
	var original_bindings: Array[Dictionary] = view.weathering.bindings.duplicate()
	var mesh := ArrayMesh.new()
	for side: int in [-1,1]:
		var x: float = float(side) * 0.6
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in [Vector3(x-0.4,0.5,-0.8),Vector3(x+0.4,0.5,-0.8),Vector3(x+0.4,0.5,0.8),Vector3(x-0.4,0.5,-0.8),Vector3(x+0.4,0.5,0.8),Vector3(x-0.4,0.5,0.8)]: surface.add_vertex(vertex)
		surface.commit(mesh)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	view.car.body.add_child(node)
	view.pick_meshes = [{"node":node,"bounds":mesh.get_aabb(),"triangles":mesh.generate_triangle_mesh()}]
	var binding: Dictionary = original_bindings[0].duplicate()
	binding.node = node
	binding.index = 1
	view.weathering.bindings = [binding]
	var inspector: RefCounted = inspector_script.new()
	inspector._sample_exterior(view)
	var only_washable: bool = not inspector.points.is_empty()
	for point: Vector3 in inspector.points:
		if point.x < 0.0: only_washable = false
	check(only_washable,view.vehicle_id+" unwashable material in the same mesh is excluded")
	view.pick_meshes = original
	view.weathering.bindings = original_bindings
	node.queue_free()

func run() -> void:
	var reduced: bool="--simple-model" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--before-file="): continue
		inspector_script = GDScript.new()
		inspector_script.source_code = FileAccess.get_file_as_string(argument.trim_prefix("--before-file=")).replace("class_name GarageCleanliness","")
		check(inspector_script.reload() == OK,"saved pre-task checker compiles")
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.simple_model = reduced
		root.add_child(view)
		await process_frame
		check_underbody(view)
		check_material_boundary(view)
		var inspector: RefCounted = inspector_script.new()
		var effect: VehicleWeathering = view.weathering
		var dirty: Dictionary = effect.snapshot()
		dirty.dirt = 0.95
		dirty.slow_dirt = 0.0
		effect.restore(dirty)
		check(not inspector.is_clean(view),id+" unwashed exterior still requires cleaning")
		var mask := PackedByteArray()
		mask.resize(VehicleCondition.CELLS)
		mask.fill(255)
		# Leave the lowest storage row untouched. Two rows extend into visible
		# sills on the pickup/classic and are not an underside-only fixture.
		for y: int in range(1):
			for z: int in range(16):
				for x: int in range(16): mask[y*256+z*16+x] = 0
		var hidden: Dictionary = dirty.duplicate(true)
		hidden.wash = Marshalls.raw_to_base64(mask)
		hidden.slow_wash = hidden.wash
		effect.restore(hidden)
		check(inspector.is_clean(view),id+" dirty bottom does not prevent customisation")
		if reduced and id=="kart" and not inspector.is_clean(view):
			var residual_points: Array=[]
			for index: int in range(inspector.points.size()):
				var point: Vector3=inspector.points[index]
				var residue: float=1.0-inspector._washed(point,effect.bounds,effect.wash_image.get_data())
				if residue>0.3 and inspector._scopes[index].x>0.3:residual_points.append([point,inspector._regions[index],residue,inspector._scopes[index]])
			print("REDUCED_KART_WASH_DIAGNOSTIC bounds=",effect.bounds," mean=",inspector._mean_residue," dirty=",inspector._dirty_fraction," points=",residual_points)
		# Road dirt is absent from high panels, even with untouched mask cells.
		mask.fill(255)
		for y: int in range(16):
			var height: float = effect.bounds.position.y + effect.bounds.size.y * float(y) / 15.0
			if height < float(VehicleWeathering.HEIGHTS[id]) * 0.82: continue
			for z: int in range(16):
				for x: int in range(16): mask[y*256+z*16+x] = 0
		hidden.wash = Marshalls.raw_to_base64(mask)
		effect.restore(hidden)
		check(inspector.is_clean(view),id+" a clean roof with unwiped road-dirt cells is accepted")
		mask.fill(205)
		hidden = dirty.duplicate(true)
		hidden.wash = Marshalls.raw_to_base64(mask)
		effect.restore(hidden)
		check(inspector.is_clean(view),id+" faint remaining wash interpolation is forgiven")
		# The same inspector must invalidate both decisions when masks change.
		mask.fill(255)
		for y: int in range(16):
			for z: int in range(16):
				for x: int in range(8): mask[y*256+z*16+x] = 0
		hidden.wash = Marshalls.raw_to_base64(mask)
		effect.restore(hidden)
		check(not inspector.is_clean(view),id+" a visibly missed half still requires washing")
		mask.fill(255)
		hidden.wash = Marshalls.raw_to_base64(mask)
		effect.restore(hidden)
		check(inspector.is_clean(view),id+" completed wash unlocks immediately")
		view.queue_free()
		await process_frame
	print("Garage wash surfaces: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
