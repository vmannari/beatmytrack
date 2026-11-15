extends SceneTree
var checks: int=0;var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("PANEL_BATCH_FAIL ",label)
func verify(car: CarVisual,label: String) -> void:
	var parts: Array=car.find_children("*","MeshInstance3D",true,false)
	var locked: int=0;var triangles: int=0
	for part: MeshInstance3D in parts:
		triangles+=part.mesh.get_faces().size()/3
		if part.mesh.get_meta("car_keep_master",false):
			locked+=1
			check(part.mesh.get_faces().size()/3==24,label+" retains both protected originals")
			check(part.mesh.has_meta("car_authored_far"),label+" preserves distance policy")
	check(parts.size()==2 and locked==1,label+" splits protected and ordinary ranges")
	check(triangles==36,label+" no master geometry removed or added")
func run() -> void:
	var car:=CarVisual.new();root.add_child(car)
	while not car.model_ready:await process_frame
	for child: Node in car.get_children():child.free()
	car.front_wheels.clear();car.rear_wheels.clear();car.rolling_wheels.clear();car.brake_lights.clear();car.kit_frames.clear();car.paint_materials.clear();car.paint_variants.clear()
	car.brake_material=null;car.accent_roof=null
	car.body=Node3D.new();car.add_child(car.body)
	var material:=StandardMaterial3D.new()
	for at: int in range(3):
		var box:=BoxMesh.new();var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
		if at<2:mesh.set_meta("car_keep_master",true)
		var part:=MeshInstance3D.new();part.mesh=mesh;part.material_override=material;part.position=Vector3(at*2,0,0);car.body.add_child(part)
	await VisualGeometry.batch_static_parts(car.body)
	verify(car,"sibling batch")
	await VisualGeometry.batch_car_parts(car)
	verify(car,"frame batch")
	preload("res://vehicle/car_mesh_lods.gd").new().prepare_vehicle(car,"electric")
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh.get_meta("car_keep_master",false):
			for packet: Dictionary in part.mesh.get("_surfaces"):check(packet.get("lods",[]).is_empty(),"protected master has no destructive distance levels")
	car.free();print("PANEL_BATCH_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
