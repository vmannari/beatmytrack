extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func run() -> void:
	for id: String in ["compact","pickup","classic","formula","kart"]:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		car.set_night_headlights(false)
		check(car.headlights == null,"daytime allocates no lights: "+id)
		car.set_night_headlights(true)
		var lamps: Array[Node] = car.find_children("*","Light3D",true,false)
		check(lamps.size() == 1,"one shared light budget: "+id)
		var lamp := lamps[0] as SpotLight3D
		check(not lamp.shadow_enabled and lamp.spot_range <= 22.0,"bounded shadow-free light: "+id)
		check(lamp.position.z < 0 and lamp.transform.basis.z.y > 0,"beam faces nose and road: "+id)
		car.set_night_headlights(false)
		check(not lamp.is_visible_in_tree(),"off disables the beam: "+id)
		car.set_night_headlights(true)
		check(car.find_children("*","Light3D",true,false).size() == 1,"toggle reuses light: "+id)
		car.free()
	var document: Dictionary = TrackDocument.create_default()
	document.theme = "night_city"
	var saved: Dictionary = TrackLibrary.new().load_document("track_c7ad183a78f7a033")
	if not saved.is_empty(): document = saved
	var game: Node = preload("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	root.size = Vector2i(1280,720)
	root.add_child(game)
	check(game.car.headlights != null and game.car.headlights.visible,"night race enables headlights")
	if "--capture" in OS.get_cmdline_user_args():
		var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/headlights-2026-09-24")
		DirAccess.make_dir_recursive_absolute(folder)
		game.set_physics_process(false)
		for enabled: bool in [false,true]:
			game.car.set_night_headlights(enabled)
			for i: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+("/on.png" if enabled else "/off.png"))
	game.free()
	await process_frame
	print("Headlights: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
