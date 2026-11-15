extends SceneTree
## Native generation only. Validate inputs and publish the manifest last.
const Renderer = preload("res://tests/support/garage_car_portrait.gd")
const Pictures = preload("res://ui/garage_selection_pictures.gd")
const Build = preload("res://core/build_identity.gd")
const SIZE := Vector2i(512,288)
var inputs: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func scan(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	for file: String in directory.get_files():
		if file.get_extension() in ["gd","gdshader","res","scn","tres"]:
			var source: String = path.path_join(file)
			inputs[source] = FileAccess.get_sha256(source)
	for child: String in directory.get_directories(): scan(path.path_join(child))

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	scan("res://vehicle")
	scan("res://rendering")
	scan("res://resources/cars")
	scan("res://assets/vehicles")
	for source: String in HandlingSelection.PROFILE_PATHS:
		inputs[source] = FileAccess.get_sha256(source)
	for source: String in ["res://tests/bake_garage_selection_portraits.gd","res://core/build_identity.gd","res://ui/header_icon_renderer.gd","res://ui/header_simple_cache.gd","res://ui/rivalry_simple_car.gd","res://ui/rivalry_preview_finish.gdshader"]:
		inputs[source] = FileAccess.get_sha256(source)
	for source: String in ["res://tests/support/garage_car_portrait.gd","res://ui/garage_environment.gd","res://ui/showroom_studio.gd","res://ui/studio_sky.gdshader"]:
		inputs[source] = FileAccess.get_sha256(source)
	var staging: String = ProjectSettings.globalize_path("res://../build/garage-reference-2026-11-15/portraits-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(staging)
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var pictures: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var view: Control = Renderer.new()
		view.vehicle_id = id
		view.livery = VehicleLivery.defaults(id)
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(SIZE)
		canvas.add_child(view)
		while not view.presentation_ready: await process_frame
		for frame: int in range(6):
			await process_frame
			await RenderingServer.frame_post_draw
		var pixels: Image = canvas.get_texture().get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		# Godot canvas readback is premultiplied; saved PNGs use straight alpha.
		for y: int in range(SIZE.y):
			for x: int in range(SIZE.x):
				var color: Color = pixels.get_pixel(x,y)
				if color.a > 0.0 and color.a < 1.0:
					pixels.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
		if pixels.get_used_rect().size.x < 30 or pixels.save_png(staging.path_join(id+".png")) != OK:
			quit(1); return
		pictures[id] = FileAccess.get_sha256(staging.path_join(id+".png"))
		view.queue_free()
		await process_frame
	for source: String in inputs:
		if FileAccess.get_sha256(source) != inputs[source]:
			printerr("SELECTION_PORTRAIT_INPUT_CHANGED ",source)
			quit(1); return
	var destination: String = ProjectSettings.globalize_path(Pictures.DIRECTORY)
	DirAccess.make_dir_recursive_absolute(destination)
	for id: String in pictures:
		var file := FileAccess.open(destination.path_join(id+".png"),FileAccess.WRITE)
		if file == null: quit(1); return
		file.store_buffer(FileAccess.get_file_as_bytes(staging.path_join(id+".png")))
		file.close()
	var manifest: Dictionary = {"version":Pictures.VERSION,"revision":Build.HEADER_PREVIEW_SHA256,"garage_revision":Build.GARAGE_PREVIEW_SHA256,"recipe":FileAccess.get_sha256("res://tests/support/garage_car_portrait.gd"),"producer":FileAccess.get_sha256("res://tests/bake_garage_selection_portraits.gd"),"size":[512,288],"source_count":inputs.size(),"source_digest":JSON.stringify(inputs).sha256_text(),"pictures":pictures,"provenance":"Native Beat my track stock cars and finishes; Garage lighting; no reference-image pixels"}
	var output := FileAccess.open(destination.path_join("provenance.json"),FileAccess.WRITE)
	if output == null: quit(1); return
	output.store_string(JSON.stringify(manifest,"\t"))
	output.close()
	canvas.queue_free()
	await process_frame
	print("GARAGE_SELECTION_PORTRAITS ",pictures.size()," pictures, ",inputs.size()," stable inputs")
	quit()
