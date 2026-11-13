extends SceneTree
## The actual App must install visible Desert props and road artwork after reload.
const FIXTURE = preload("res://tests/test_desert_appearance.gd")
var checks: int = 0
var failures: int = 0
var folder: String = "res://../docs/evidence/desert-appearance-fix-2026-11-07/app/"
var rows: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func draw(game: Node) -> Image:
	game.paused = false
	game.hud.pause_menu.hide(); game.hud.message_label.hide()
	for frame: int in range(3):
		await process_frame
		RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func run() -> void:
	folder += RenderingServer.get_current_rendering_method()+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280,720)
	var track: NativeTrack = TrackCompiler.compile(FIXTURE.document())
	track.metadata.cloud_version = "desert-appearance-offline-fixture"
	var private_folder: String = "user://desert_appearance"
	DirAccess.make_dir_recursive_absolute(private_folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(private_folder)
	app.records = LocalRecords.new(private_folder.path_join("records.json"))
	app.cloud_root_override = private_folder.path_join("cloud")
	NativeTrackVisual.ROAD_DISK_CACHE.directory = private_folder.path_join("roads")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	NativeTrackVisual.PREPARED_WORLDS.entries.clear()
	for pass_index: int in range(2):
		app._show_screen("tracks"); app.selected_track = track
		await app._start_race(track,false,true)
		var game: Node = app.game
		check(is_instance_valid(game) and game.preparation_complete,"actual App finishes Desert race installation pass "+str(pass_index))
		if not is_instance_valid(game): break
		game.set_physics_process(false); game.set_process(false); game.race_cues.hide()
		check(game.track_ground.world_built,"actual App publishes a complete world pass "+str(pass_index))
		var props: Array[Node] = game.track_ground.find_children("EgyptianStonework*","MeshInstance3D",true,false)
		check(not props.is_empty(),"actual App retains authored Egyptian objects pass "+str(pass_index))
		var roads: Array[ShaderMaterial] = []
		for child: Node in game.track_ground.find_children("*","MeshInstance3D",true,false):
			var material: ShaderMaterial = child.material_override as ShaderMaterial
			if material != null and material.get_shader_parameter("asphalt_surface") == true and material.get_shader_parameter("edge_fringe") != true:
				roads.append(material)
		check(not roads.is_empty(),"actual App retains the Desert road pass "+str(pass_index))
		for material: ShaderMaterial in roads:
			check(material.get_shader_parameter("desert_road_albedo") == NativeTrackVisual.DESERT_ROAD_ALBEDO,"actual App binds approved road artwork pass "+str(pass_index))
		if DisplayServer.get_name() != "headless":
			for view: String in ["road","pyramid"]:
				var at := Vector2(0,-18) if view == "road" else Vector2(-38,0)
				game.camera.follow(at,Vector2.ZERO,0,0,true)
				var before: Image = await draw(game)
				before.save_png(folder+"pass%d-%s.png" % [pass_index,view])
				if view == "road":
					var flat_image := Image.create(4,4,false,Image.FORMAT_RGBA8); flat_image.fill(Color(0.5,0.5,0.5))
					var flat := ImageTexture.create_from_image(flat_image)
					for material: ShaderMaterial in roads: material.set_shader_parameter("desert_road_albedo",flat)
				else:
					for prop: Node3D in props: prop.hide()
				var after: Image = await draw(game)
				var count: int = FIXTURE.pixels(before,after)
				check(count > 1000,"actual App visibly renders "+view+" pass "+str(pass_index))
				rows.append({"pass":pass_index,"view":view,"pixels":count})
				for material: ShaderMaterial in roads: material.set_shader_parameter("desert_road_albedo",NativeTrackVisual.DESERT_ROAD_ALBEDO)
				for prop: Node3D in props: prop.show()
		app._leave_race(); await process_frame
	app.queue_free(); await process_frame
	FileAccess.open(folder+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("DESERT_APP_APPEARANCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
