extends SceneTree
## Menu header lifetime, real clipping, prepared geometry and capture equivalence.
var checks: int=0
var failures: int=0
var output: String="res://../build/menu-responsiveness-tests"
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func frames(count: int=4) -> void:
	for _i: int in range(count): await process_frame
func geometry(node: Node, result: Array) -> void:
	preload("res://tests/support/garage_geometry_comparison.gd").geometry(node, result)
func architecture() -> void:
	var prepared: PackedScene=load(GarageEnvironment.PREPARED_ARCHITECTURE)
	GarageEnvironment.architecture_scene=null
	var world:=Node3D.new()
	root.add_child(world)
	var car:=preload("res://tests/support/garage_architecture_car.gd").new()
	world.add_child(car)
	GarageEnvironment.build(world,car,true,false)
	var before: Node=GarageEnvironment.architecture_scene.instantiate()
	var after: Node=prepared.instantiate()
	var original: Array=[]
	var baked: Array=[]
	geometry(before,original)
	geometry(after,baked)
	check(original==baked,"prepared workshop preserves every node, transform, mesh array and finish")
	check(original.size()>100,"geometry comparison includes the authored workshop furniture")
	before.free();after.free();world.free()
	GarageEnvironment.architecture_scene=prepared
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	architecture()
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://menu-responsive-test-"+TrackLibrary.unique_id()
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled=false
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false
	music.menu_player.stop()
	music.menu_player.stream=null
	app._show_screen("tracks")
	await frames()
	var header: Control=app.root_ui.find_child("MenuProfileCar",true,false)
	var native_preview: Control=header.preview
	for destination: String in ["settings","tracks","profile","tracks","settings","biome"]:
		app._show_screen(destination)
		await frames()
		check(app.root_ui.find_child("MenuProfileCar",true,false)==header,"header stays attached to the active shell: "+destination)
		check(header.preview==native_preview,"unchanged appearance retains native preview: "+destination)
		check(header.is_visible_in_tree(),"retained header remains visible: "+destination)
		check(header.size.is_equal_approx(Vector2(88,56)) and header.preview.size.is_equal_approx(Vector2(88,56)),"retained header keeps its exact picture slot: "+destination)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1720,900),Vector2i(1280,720)]:
		root.size=dimensions
		await frames()
		check(header.size.is_equal_approx(Vector2(88,56)) and header.preview.size.is_equal_approx(Vector2(88,56)),"header picture remains bounded after resize "+str(dimensions))
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("header-return.png"))==OK,"capture retained header after resize and return")
	var old: WeakRef=weakref(header)
	app.records=LocalRecords.new(folder.path_join("other-records.json"))
	app._show_screen("settings")
	await frames()
	check(old.get_ref()==null,"another records owner releases the prior header")
	check(app._retained_profile_car.records==app.records,"new header uses the current records owner")
	app.queue_free()
	await frames()
	# Native visibility alone does not account for the carousel's clipping.
	var clip:=Control.new()
	clip.clip_contents=true
	clip.position=Vector2(20,20);clip.size=Vector2(200,100)
	root.add_child(clip)
	var view:=Control.new()
	view.size=Vector2(100,80)
	clip.add_child(view)
	var cache: Node=preload("res://ui/garage_preview_cache.gd").new()
	root.add_child(cache)
	check(cache._on_screen(view),"intersecting card is eligible")
	view.position.x=201
	check(view.is_visible_in_tree() and not cache._on_screen(view),"offscreen card does not construct a showroom")
	view.position.x=199
	check(cache._on_screen(view),"partially revealed card can resolve")
	clip.hide()
	check(not cache._on_screen(view),"hidden Garage cannot resolve")
	clip.free();cache.free()
	if DisplayServer.get_name()!="headless": await compare_capture()
	await frames(8)
	print("MENU_RESPONSIVENESS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func compare_capture() -> void:
	var images: Array[Image]=[]
	# Warm the renderer before comparing equally settled native captures. The
	# first synchronous capture differs even from the next synchronous capture.
	for cooperative: bool in [false,false,true,false]:
		var view:=CarShowroom.new()
		view.read_only=true;view.garage_mode=true
		view.cooperative_build=cooperative
		view.size=Vector2(1024,256)
		view.livery=VehicleLivery.defaults("compact")
		view.livery.colors.body="c72d34"
		root.add_child(view)
		while not view.showroom_ready: await process_frame
		for _i: int in range(30 if images.is_empty() else 6):
			view.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			view.reflections.request_draw()
			await RenderingServer.frame_post_draw
		images.append(view.showroom_viewport.get_texture().get_image())
		images[-1].save_png(output.path_join("cooperative.png" if cooperative else "synchronous-"+str(images.size())+".png"))
		check(view.car.model_ready,"capture waits for complete native model")
		view.free()
		await frames()
	check(images[1].get_data()==images[2].get_data(),"cooperative capture has exact synchronous native pixels")
	check(images[1].get_data()==images[3].get_data(),"equally warmed synchronous captures remain exact")
	images[2].save_png(output.path_join("cooperative-capture.png"))
