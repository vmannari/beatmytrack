extends "res://tests/test_garage_model_pass2.gd"
## Swap only room meshes around the same live car, camera, finishes and lights.
var control_scene: String = ""
var control_holder: Node
var control_meshes: Array[Node] = []
var live_meshes: Array[Node] = []
var optimized: Array[Mesh] = []
var paired_root: String = ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--control-room="): control_scene = argument.trim_prefix("--control-room=")
	if control_scene.is_empty():
		printerr("FAIL: --control-room must name the preserved task-start room")
		quit(1)
		return
	super._initialize()

func prepare_pair(view: CarShowroom) -> void:
	control_holder = (load(control_scene) as PackedScene).instantiate()
	root.add_child(control_holder)
	control_holder.hide()
	control_meshes = control_holder.find_children("*","MeshInstance3D",true,false)
	var room: Node = view.camera.get_parent().find_child("GarageArchitecture",true,false)
	live_meshes = room.find_children("*","MeshInstance3D",true,false)
	check(control_meshes.size() == live_meshes.size(),"same workshop mesh roles in paired render")
	for index: int in range(mini(control_meshes.size(),live_meshes.size())):
		var a: MeshInstance3D = control_meshes[index]
		var b: MeshInstance3D = live_meshes[index]
		check(a.transform == b.transform,"paired geometry keeps local transform "+str(index))
		check(a.get_parent().transform == b.get_parent().transform,"paired geometry keeps parent transform "+str(index))
		var left: Material = a.get_active_material(0)
		var right: Material = b.get_active_material(0)
		check(left.get_class() == right.get_class(),"paired finish type "+str(index))
		if left is ShaderMaterial:
			check(left.shader.code == right.shader.code,"paired shader "+str(index))
		elif left is BaseMaterial3D:
			check(left.albedo_color == right.albedo_color and left.metallic == right.metallic and left.roughness == right.roughness,"paired finish values "+str(index))
		optimized.append(b.mesh)
	paired_root = output
	DirAccess.make_dir_recursive_absolute(paired_root.path_join("before"))
	DirAccess.make_dir_recursive_absolute(paired_root.path_join("after"))

func capture(view: CarShowroom, label: String) -> void:
	if control_holder == null: prepare_pair(view)
	var car_identity: int = view.car.get_instance_id()
	for index: int in range(live_meshes.size()): live_meshes[index].mesh = control_meshes[index].mesh
	output = paired_root.path_join("before")
	view.reflections.request_draw()
	await super.capture(view,label)
	for index: int in range(live_meshes.size()): live_meshes[index].mesh = optimized[index]
	output = paired_root.path_join("after")
	view.reflections.request_draw()
	await super.capture(view,label)
	check(view.car.get_instance_id() == car_identity,"paired render retains the exact live car "+label)
	output = paired_root
