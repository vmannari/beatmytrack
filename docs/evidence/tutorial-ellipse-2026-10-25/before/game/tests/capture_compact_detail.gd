extends SceneTree
## Captures the production asset with both the gameplay and inspection cameras.
func _initialize() -> void: call_deferred("run")

func save_view(label: String) -> void:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://../docs/evidence/compact-look/"+label+".png")
	if result != OK:
		push_error("Could not save "+label)
		quit(1)

func run() -> void:
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_label.hide()
	game.race_cues.hide()
	game.car.present(game.initial_track.spawn,0.0,VehicleState.new(),DriveFrame.new())
	game.camera.follow(game.initial_track.spawn,Vector2.ZERO,0.0,0.0,true)
	await save_view("gameplay")
	game.hud.hide()
	var camera := Camera3D.new()
	game.get_node("World").add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	camera.current = true
	for rear: bool in [false,true]:
		camera.position = game.car.position + Vector3(-5,5,7 if rear else -7)
		camera.look_at(game.car.position+Vector3(0,0.5,0))
		await save_view("rear" if rear else "front")
	for side: float in [-1.0,1.0]:
		camera.position = game.car.position + Vector3(side*8,7,-1)
		camera.look_at(game.car.position+Vector3(0,0.5,0))
		await save_view("side-left" if side < 0 else "side-right")
	camera.position = game.car.position + Vector3(-1.2,9,7)
	camera.look_at(game.car.position+Vector3(0,0.5,0))
	await save_view("high-rear")
	camera.position = game.car.position + Vector3(-5,5,-7)
	camera.look_at(game.car.position+Vector3(0,0.5,0))
	for angle: int in [0,30,60,90]:
		game.car.rotation.y = deg_to_rad(angle)
		await save_view("reflection-turn-"+str(angle))
	game.free()
	print("COMPACT_DETAIL_CAPTURE: 10 views saved")
	quit()
