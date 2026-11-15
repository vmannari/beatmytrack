extends SceneTree
var output: String
var view: CarShowroom
var candidate_room: Node3D
var control_room: Node3D
var control_pedestal: Node3D
var candidate_meshes: Array[Mesh]=[]
var deck_parts: Array[MeshInstance3D]=[]
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE70_PAIR_FAIL ",label)

func capture(label: String,control: bool) -> void:
	candidate_room.visible=not control
	control_room.visible=control
	var control_roof: Node3D=control_room.find_child("GarageRoof",true,false)
	control_roof.visible=view.roof.visible
	for at: int in range(deck_parts.size()):
		deck_parts[at].mesh=control_pedestal.get_child(at).mesh if control else candidate_meshes[at]
	view._process(0.0)
	for _i: int in range(5):
		view.invalidate_render();view.reflections.request_draw()
		await RenderingServer.frame_post_draw
		await process_frame
	var directory: String=output.path_join("before" if control else "after")
	check(view.showroom_viewport.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"save "+label)
	for at: int in range(2):
		check(view.reflections.views[at].get_texture().get_image().save_png(directory.path_join(label+"-reflection"+str(at)+".png"))==OK,"save reflection "+label)

func pair(label: String) -> void:
	var car_id: int=view.car.get_instance_id()
	var paint: Dictionary=view.car.livery.duplicate(true)
	await capture(label,true)
	await capture(label,false)
	check(view.car.get_instance_id()==car_id and view.car.livery==paint,"same native car and finish "+label)

func prepare_deck() -> void:
	deck_parts.clear();candidate_meshes.clear()
	for child: Node in view.turntable.get_children():
		if child is MeshInstance3D and not (child.material_override is ShaderMaterial and child.material_override.shader.resource_path=="res://ui/studio_contact.gdshader"):
			deck_parts.append(child);candidate_meshes.append(child.mesh)
	check(deck_parts.size()==control_pedestal.get_child_count(),"matching physical platform finish groups")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.path_join("before"))
	DirAccess.make_dir_recursive_absolute(output.path_join("after"))
	root.size=Vector2i(1280,720)
	Engine.time_scale=0
	GarageEnvironment.architecture_scene=load("res://assets/garage/workshop_v1.scn")
	view=CarShowroom.new();view.garage_mode=true
	view.livery=VehicleLivery.defaults("compact")
	root.add_child(view);MenuStyle.fill(view)
	while not view.showroom_ready: await process_frame
	view.set_process(false)
	candidate_room=view.camera.get_parent().get_node("GarageArchitecture")
	control_room=load("res://../build/garage-simplified-apply-2026-11-15/before/workshop_v1.scn").instantiate()
	view.camera.get_parent().add_child(control_room)
	view.reflections._mark_room(control_room)
	control_room.hide()
	control_pedestal=load("res://../build/garage-simplified-apply-2026-11-15/before/pedestal.scn").instantiate()
	for id: String in VehicleCatalog.IDS:
		print("GARAGE70_CASE ",id)
		# Static comparison: avoid constructing an unrelated car-change reveal
		# shader while switching the fixture's model behind its hidden view.
		if view.vehicle_id!=id:
			view.hide()
			view.replace_car(id,VehicleLivery.defaults(id),{},VehicleCustomisation.defaults())
			view.show()
		view.finish_car_transition();await process_frame
		prepare_deck()
		for mode: String in ["front","rear","close"]:
			view.yaw=view.GARAGE_CAMERA_YAW+(PI if mode=="rear" else 0.0)
			view.zoom=view.MIN_ZOOM if mode=="close" else 1.0
			view._orbit()
			await pair(id+"-"+mode)
	for pose: Array in [
		["workbench",Vector3(6.35,1.6,4.7),Vector3(6.35,0.9,7.65)],
		["tyres",Vector3(7,1.8,5.1),Vector3(9.2,1,7.6)],
		["overhead",Vector3(0,9,-7),Vector3(0,0,0)],
		["compressor",Vector3(5.05,1.12,5.8),Vector3(5.4,0.48,7.1)],
		["shelf",Vector3(-6.9,3.1,6),Vector3(-6.9,3.2,7.7)],
		["tools",Vector3(5.9,2.15,6.5),Vector3(5.9,1.9,8.1)],
		["records",Vector3(8.45,1.25,4.05),Vector3(9.8,1.08,4.7)],
		["vice",Vector3(5.2,1.65,6.3),Vector3(5.2,1.2,7.6)],
		["plant",Vector3(-8.2,1.1,-3.4),Vector3(-9.55,1,-2.1)],
		["trophies",Vector3(-3.6,2.3,2.8),Vector3(-10.25,2.3,2.8)]]:
		view.camera.position=pose[1];view.camera.look_at(pose[2])
		view.roof.visible=view.camera.position.y<GarageEnvironment.ROOF_CUTAWAY_HEIGHT
		await pair(pose[0])
	print("GARAGE70_NATIVE_PAIRS ",checks," checks, ",failures," failures")
	control_pedestal.free();view.queue_free()
	Engine.time_scale=1
	for _i: int in range(8): await process_frame
	quit(1 if failures else 0)
