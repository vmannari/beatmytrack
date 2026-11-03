extends SceneTree
## GPO01-GPO04: original geometry, bounded visual error and retained rendering.
const Prepared = preload("res://ui/garage_car_cache.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-performance-2026-11-01"
var images: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func frames(count: int = 8) -> void:
	for tick: int in range(count): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func compare_meshes(a: Node, b: Node, label: String) -> void:
	var left: Array[Node] = a.find_children("*","MeshInstance3D",true,false)
	var right: Array[Node] = b.find_children("*","MeshInstance3D",true,false)
	check(left.size() == right.size(),label+" keeps mesh count")
	for index: int in range(mini(left.size(),right.size())):
		var source: MeshInstance3D = left[index]
		var target: MeshInstance3D = right[index]
		check(a.get_path_to(source) == b.get_path_to(target),label+" keeps mesh path")
		check(source.transform == target.transform and source.cast_shadow == target.cast_shadow,label+" keeps transform and shadows")
		check(source.mesh.get_surface_count() == target.mesh.get_surface_count(),label+" keeps surfaces")
		for surface: int in range(source.mesh.get_surface_count()):
			check(source.mesh.surface_get_arrays(surface) == target.mesh.surface_get_arrays(surface),label+" keeps every original vertex/index attribute")

func geometry() -> void:
	var before: PackedScene = load(output.path_join("before/game/assets/garage/workshop_v1.scn"))
	var after: PackedScene = load(GarageEnvironment.PREPARED_ARCHITECTURE)
	var a: Node = before.instantiate()
	var b: Node = after.instantiate()
	compare_meshes(a,b,"room")
	a.free(); b.free()
	for id: String in VehicleCatalog.IDS:
		var source := CarVisual.new()
		source.vehicle_id = id
		source.editable_kits = VehicleCustomisation.supported(id)
		root.add_child(source)
		while not source.model_ready: await process_frame
		var hits: int = Prepared.hits
		var optimized := CarVisual.new()
		optimized.vehicle_id = id
		optimized.editable_kits = source.editable_kits
		optimized.garage_template = true
		root.add_child(optimized)
		while not optimized.model_ready: await process_frame
		check(Prepared.hits == hits+1,"prepared Garage model used "+id)
		compare_meshes(source,optimized,id)
		check(source.wheel_rest_positions == optimized.wheel_rest_positions,"wheel geometry retained "+id)
		source.free(); optimized.free()
		await process_frame

func review_images() -> void:
	for renderer: String in ["gl_compatibility","mobile"]:
		var folder: String = output.path_join("after/"+renderer)
		if not DirAccess.dir_exists_absolute(folder): continue
		for name: String in DirAccess.get_files_at(folder):
			if not name.begins_with("full-") or not name.ends_with(".png"): continue
			var a: Image = Image.load_from_file(folder.path_join(name))
			var b: Image = Image.load_from_file(folder.path_join(name.trim_prefix("full-")))
			check(a.get_size() == b.get_size(),"native image size "+name)
			var sum: float = 0.0
			var over: int = 0
			var maximum: float = 0.0
			for y: int in range(a.get_height()):
				for x: int in range(a.get_width()):
					var aa: Color = a.get_pixel(x,y)
					var bb: Color = b.get_pixel(x,y)
					var delta := Vector3(absf(aa.r-bb.r),absf(aa.g-bb.g),absf(aa.b-bb.b))*255.0
					sum += delta.x+delta.y+delta.z
					var peak: float = maxf(delta.x,maxf(delta.y,delta.z))
					maximum = maxf(maximum,peak)
					if peak > 8.01: over += 1
			var pixels: int = a.get_width()*a.get_height()
			var row: Dictionary = {"renderer":renderer,"image":name,"mean_channel_delta_255":sum/(pixels*3),"pixels_over_8_fraction":float(over)/pixels,"max_channel_delta":maximum}
			var original_path: String = output.path_join("baseline/"+renderer+"/"+name.trim_prefix("full-"))
			if FileAccess.file_exists(original_path):
				var original: Image = Image.load_from_file(original_path)
				row.full_matches_task_start = original.get_data() == a.get_data()
				var original_data: PackedByteArray = original.get_data()
				var full_data: PackedByteArray = a.get_data()
				var start_delta: int = 0
				for byte: int in range(original_data.size()): start_delta += absi(original_data[byte]-full_data[byte])
				row.full_vs_task_start_mean_byte_delta = float(start_delta)/original_data.size()
			images.append(row)
			print("GARAGE_IMAGE ",JSON.stringify(row))
			check(row.mean_channel_delta_255 < 0.25,"native image energy stays close "+name)
			check(row.pixels_over_8_fraction < 0.005,"visible pixel changes stay bounded "+name)
			if name == "full-hovercraft-close.png":
				var canopy_error: float = 0.0
				for y: int in range(390,430):
					for x: int in range(470,680):
						var delta: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
						canopy_error = maxf(canopy_error,maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b))))
				row.canopy_max_channel_delta_255 = canopy_error*255.0
				check(canopy_error*255.0 < 1.01,"layered Hover canopy has no LOD interference "+renderer)

func animation() -> void:
	var music: GameSoundtrack = GameSoundtrack.instance()
	music.music_enabled = false
	var view := CarShowroom.new()
	view.garage_mode = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(view)
	while not view.showroom_ready: await process_frame
	await frames()
	check(not view._record_animation_visible(),"off-camera record is outside both main and reflected frusta")
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	var data := PackedByteArray(); data.resize(44100); stream.data = data
	music.mode = "menu"
	music.music_enabled = true
	music.menu_target = 1.0
	music.menu_player.stream = stream
	music.menu_player.play()
	music.menu_player.stream_paused = false
	await frames()
	var requests: int = view.render_requests
	var rotation: float = view.record_vinyl.rotation.y
	await frames(16)
	check(view.render_requests == requests,"music in car view submits zero repeated 3D draws")
	if DisplayServer.get_name() != "headless": check(view.record_vinyl.rotation.y != rotation,"off-camera record retains its playback phase")
	view.set_record_view(true)
	await create_timer(0.8).timeout
	await frames()
	check(view._record_animation_visible(),"visible record is retained in its close view")
	requests = view.render_requests
	var captures: PackedInt64Array = view.reflections.draw_requests.duplicate()
	await frames(16)
	if DisplayServer.get_name() != "headless":
		check(view.render_requests > requests,"visible spinning record still redraws")
		check(view.reflections.draw_requests[0] > captures[0],"visible record keeps its floor reflection animated")
		check(view.reflections.draw_requests[1] == captures[1],"record does not redraw unchanged car reflection")
	# Look below the floor: only the mirrored camera can see the real disc.
	var center: Vector3 = view.record_vinyl.global_position
	view.camera.look_at(Vector3(center.x,-0.05-center.y,center.z))
	check(not view.camera.is_position_in_frustum(center),"reflection-only fixture excludes real record")
	check(view._record_animation_visible(),"reflection-only visibility keeps animation alive")
	music.music_enabled = false
	music.menu_target = 0.0
	music.menu_player.stop()
	view.set_record_view(false)
	await create_timer(0.8).timeout
	await frames()
	requests = view.render_requests
	view.rotate_view(Vector2(25,0))
	await frames()
	check(view.render_requests > requests,"car orbit still renders immediately")
	view.weathering.restore({"snow":0.5,"slow_snow":0.2})
	requests = view.render_requests
	await frames()
	check(view.render_requests > requests,"snow melt continues to render")
	view.weathering.restore({})
	view.hide()
	await frames()
	requests = view.render_requests
	await frames()
	check(view.render_requests == requests,"hidden Garage remains idle")
	view.show()
	await frames()
	check(view.render_requests > requests,"return refreshes retained Garage")
	view.free()

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: print("FAIL: Garage optimization deadline"); quit(1))
	root.size = Vector2i(1280,720)
	output = ProjectSettings.globalize_path(output)
	await geometry()
	await animation()
	review_images()
	FileAccess.open(output.path_join("image-review.json"),FileAccess.WRITE).store_string(JSON.stringify(images,"\t"))
	print("GARAGE_RENDER_OPTIMIZATION ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
