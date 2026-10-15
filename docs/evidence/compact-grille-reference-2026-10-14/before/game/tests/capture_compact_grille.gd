extends SceneTree
## Native production car: matched close-up, orbit, fitted kit and condition views.
var output: String = "res://../docs/evidence/compact-grille-2026-10-14/after"
var showroom: CarShowroom
func _initialize() -> void: _run.call_deferred()
func settle() -> void:
	for frame: int in range(10): await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String, target: Vector3, direction: Vector3) -> void:
	var aim: Vector3 = showroom.car.body.global_transform*target
	showroom.camera.look_at_from_position(aim+direction,aim)
	showroom.reflections.sync()
	await settle()
	assert(showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png"))==OK)
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440,900)
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	showroom = CarShowroom.new()
	showroom.garage_mode = true
	showroom.livery = VehicleLivery.defaults("compact")
	host.add_child(showroom)
	MenuStyle.fill(showroom)
	await settle()
	await capture("front",Vector3(0,0.79,-2.10),Vector3(0,0.08,-2.25))
	await capture("grille-detail",Vector3(0,0.795,-2.11),Vector3(0.36,0.18,-0.94))
	await capture("grille-left",Vector3(0,0.795,-2.11),Vector3(-0.48,0.09,-0.94))
	await capture("front-quarter",Vector3(0,0.78,-0.4),Vector3(3.6,1.85,-5.0))
	await capture("overhead",Vector3(0,0.79,-1.90),Vector3(0.55,2.2,-1.6))
	showroom.apply_customisation({"version":1,"hood":"vented","aero":"wing","rims":"mesh","body":"club"})
	await capture("fitted-front",Vector3(0,0.79,-1.95),Vector3(1.1,0.65,-2.8))
	showroom.apply_customisation(VehicleCustomisation.defaults())
	showroom.zoom = 0.57
	showroom.elevation = 0.25
	showroom.yaw = -0.68
	showroom._orbit()
	await settle()
	assert(root.get_texture().get_image().save_png(output.path_join("garage.png"))==OK)
	var condition: Dictionary = showroom.weathering.snapshot()
	condition.dirt = 0.55
	showroom.weathering.restore(condition)
	await capture("grille-dirty",Vector3(0,0.795,-2.11),Vector3(0.36,0.18,-0.94))
	host.queue_free()
	await process_frame
	print("COMPACT_GRILLE_CAPTURE: 8 native views")
	quit()
