extends SceneTree
## Reload exact task-start geometry in this disposable process only.
const COACH = preload("res://vehicle/electric_coachwork.gd")
const OUTPUT: String = "res://../docs/evidence/electric-lucid-hood-2026-10-25/before"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var source: String = FileAccess.get_file_as_string(OUTPUT+"/game/vehicle/electric_coachwork.gd")
	source = source.replace("res://assets/vehicles/electric_coachwork_v4",OUTPUT+"/electric_coachwork_v4")
	COACH.source_code = source
	assert(COACH.reload() == OK)
	root.size = Vector2i(1440,900)
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for simple: bool in [false,true]:
		var world := Node3D.new()
		viewport.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.livery = VehicleLivery.defaults("electric")
		world.add_child(car)
		ShowroomStudio.build(world,car)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.fov = 32
		var shots: Array = [
			["hood",Vector3(-2.5,2.4,-4.3),Vector3(0,0.75,-1.1)],
			["nose",Vector3(0,1.6,-5),Vector3(0,0.72,-1.0)],
			["overhead",Vector3(0,6,-2.7),Vector3(0,0.65,-0.6)]]
		for shot: Array in shots:
			camera.position = shot[1]
			camera.look_at(shot[2])
			for frame: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().save_png(OUTPUT.path_join(("simple-" if simple else "full-")+shot[0]+".png")) == OK)
		world.free()
	viewport.free()
	print("ELECTRIC_HOOD_BASELINE: six matched task-start views saved")
	quit()
