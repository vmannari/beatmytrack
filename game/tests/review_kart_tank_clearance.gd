extends SceneTree
const OUT = "res://../docs/evidence/kart-tank-clearance-2026-11-12"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100,850)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "kart"
	car.simple_model = true
	car.batch_parts = prepared
	world.add_child(car)
	while not car.model_ready: await process_frame
	if before:
		for node: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
			if str(node.name) not in ["FuelTank","FuelCap","FuelLine"]:
				if str(node.name).begins_with("Fuel"): node.hide()
				continue
			if str(node.get_parent().name)=="FuelAssembly": node.get_parent().position = Vector3.ZERO
			node.mesh = load(OUT+"/before-simple-"+str(node.name)+".res")
			if str(node.name)=="FuelCap": node.position = Vector3(0,0.332,-0.26)
	ShowroomStudio.build(world,car)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 32
	for shot: Array in [["rear-tank",Vector3(-1.4,1.0,1.5),Vector3(-0.25,0.35,0.50)],["tank-top",Vector3(0,1.5,-0.15),Vector3(0,0.26,-0.3)],["lap",Vector3(0.65,1.15,0.2),Vector3(0,0.29,-0.25)],["cockpit",Vector3(1.1,0.87,-0.9),Vector3(0,0.55,-0.12)],["side",Vector3(2.3,0.82,0.15),Vector3(0,0.53,-0.12)],["tank",Vector3(0.85,0.70,-0.65),Vector3(0,0.29,-0.27)]]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		for frame: int in range(6): await process_frame; await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(OUT+("/before-" if before else "/prepared-" if prepared else "/after-")+shot[0]+".png")==OK)
	viewport.free()
	quit()
