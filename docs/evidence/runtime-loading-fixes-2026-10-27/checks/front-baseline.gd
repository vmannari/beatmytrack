extends SceneTree
var rows: Array=[]
func _initialize() -> void: run.call_deferred()
func record(node: Node) -> Array:
	var value: Array=[node.get_class()]
	if node is Node3D: value.append(node.transform)
	if node is MeshInstance3D:
		value.append([node.cast_shadow,node.mesh.get_aabb()])
		for surface: int in range(node.mesh.get_surface_count()):
			value.append(var_to_bytes(node.mesh.surface_get_arrays(surface)).hex_encode().sha256_text())
	for child: Node in node.get_children(): value.append(record(child))
	return value
func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	for simple: bool in [false,true]:
		var car:=CarVisual.new();car.simple_model=simple
		car.body=Node3D.new();car.add_child(car.body)
		var paint:=VisualGeometry.material(Color("326da8"))
		var trim:=VisualGeometry.material(Color("20252b"))
		var began: int=Time.get_ticks_usec()
		CompactDetail._front(car,paint,paint,trim,trim)
		var signature: Array=record(car.body)
		rows.append({"simple":simple,"elapsed_us":Time.get_ticks_usec()-began,"signature":var_to_bytes(signature).hex_encode().sha256_text(),"tree":signature})
		car.free()
	var file:=FileAccess.open("res://../build/runtime-loading-fixes-2026-10-27/front-before.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	print("FRONT_BASELINE ",JSON.stringify(rows.map(func(row: Dictionary) -> Dictionary: return {"simple":row.simple,"signature":row.signature,"elapsed_us":row.elapsed_us})))
	quit()
