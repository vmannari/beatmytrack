extends SceneTree
## Cold full-catalogue model builds, reusable appearance, warm disk and cancellation.
const Icons = preload("res://ui/garage_paint_icons.gd")
const Profile = preload("res://ui/profile_car.gd")
var checks: int = 0
var failures: int = 0
var output: String
var shelf: VBoxContainer
var scroll: ScrollContainer
var icons: Node
var cards: Array[Button] = []
var models: int = 0
var frame_us: Array[int] = []
var metrics: Dictionary = {}
var cache_directory: String
var renderer_script: GDScript = Icons

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func idle() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while icons.busy and Time.get_ticks_msec()<deadline:
		var at: int = Time.get_ticks_usec()
		await process_frame
		frame_us.append(Time.get_ticks_usec()-at)
	check(not icons.busy,"visible icons finish within the test deadline")
	await process_frame

func make_worker() -> void:
	icons = renderer_script.new()
	if icons.has_method("identity"): icons.cache_directory = cache_directory
	icons.scroll = scroll
	icons.child_entered_tree.connect(func(node: Node) -> void:
		if node.name=="ProfileCarRender": models += 1)
	shelf.add_child(icons)

func preset(index: int, vehicle: String = "compact") -> Dictionary:
	var value: Dictionary = VehicleLivery.defaults(vehicle)
	if index>0:
		var pattern: Dictionary = LiveryCatalog.patterns[index-1]
		value.pattern = pattern.id
		for slot: int in range(VehicleLivery.SLOTS.size()): value.colors[VehicleLivery.SLOTS[slot]] = pattern.colours[slot]
	return value

func catalogue() -> void:
	for start: int in range(0,49,cards.size()):
		for index: int in range(cards.size()):
			if start+index>=49: break
			icons.request(cards[index],"compact",preset(start+index),VehicleCustomisation.defaults())
		await idle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	if OS.get_environment("BMT_ICON_DIAG_SKIP_REST_CACHE")=="1":
		preload("res://vehicle/prepared_car_cache.gd").enabled = false
	GameSoundtrack.instance().music_enabled = false
	output = "res://../docs/evidence/garage-paint-icon-performance-2026-10-26/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_environment("BMT_ICON_DIAG_OLD_WORKER")=="1":
		renderer_script = GDScript.new()
		renderer_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/garage-icon-latency-2026-10-26/before/game/ui/garage_paint_icons.gd")
		check(renderer_script.reload()==OK,"task-start worker reloads for the isolated geometry control")
	cache_directory = ProjectSettings.globalize_path("user://icon_perf_"+TrackLibrary.unique_id())
	if DisplayServer.get_name()=="headless":
		print("GARAGE_PAINT_ICON_PERFORMANCE: native rendering required")
		quit(1)
		return
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	root.theme = MenuStyle.theme()
	shelf = VBoxContainer.new()
	root.add_child(shelf)
	MenuStyle.fill(shelf)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for index: int in range(4):
		var row := preload("res://ui/garage_part_option.gd").new()
		row.setup(index,["paint","Paint"],"Graphic paint scheme",func() -> void: pass)
		row.add_car_icon()
		list.add_child(row)
		cards.append(row)
	make_worker()
	for tick: int in range(5): await process_frame
	Icons.images.clear()
	var cold_at: int = Time.get_ticks_usec()
	await catalogue()
	metrics.cold = {"model_builds":models,"elapsed_us":Time.get_ticks_usec()-cold_at,"frame_max_us":frame_us.max(),"frames":frame_us.size(),"build_us":icons.build_us,"repaint_us":icons.repaint_us,"io_us":icons.io_us,"readback_us":icons.readback_us}
	if icons.get("read_batches")!=null:
		metrics.cold.read_batches = icons.read_batches
		metrics.cold.write_batches = icons.write_batches
		metrics.cold.model_slice_us = icons.studio.car.model_max_slice_us
		check(icons.read_batches<=13 and icons.write_batches<=13,"catalogue I/O is batched by visible group")
		check(not icons.studio.car.cache_rest_pose and icons.studio.cooperative_build,"icon construction skips unused snapshots and yields between build slices")
	flush_metrics()
	check(models==1,"all 49 cold icons reuse one model")
	check(Icons.images.size()<=Icons.CACHE_LIMIT,"GPU image cache remains bounded")
	if icons.has_method("identity"):
		await warm_disk()
		await cache_guards()
		shelf.show()
		icons.cache_directory = cache_directory
		await changed_appearances()
	else: check(false,"persistent exact-appearance icon cache exists")
	var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	shelf.queue_free()
	for tick: int in range(8): await process_frame
	print("GARAGE_PAINT_ICON_PERFORMANCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func warm_disk() -> void:
	var directory: String = icons.cache_directory
	icons.queue_free()
	await process_frame
	Icons.images.clear()
	for row: Button in cards:
		row.car_icon.texture = null
		row.icon_key = ""
	models = 0
	make_worker()
	icons.cache_directory = directory
	frame_us.clear()
	var at: int = Time.get_ticks_usec()
	await catalogue()
	metrics.warm = {"model_builds":models,"elapsed_us":Time.get_ticks_usec()-at,"disk_hits":icons.disk_hits,"renders":icons.rendered,"frame_max_us":frame_us.max(),"frames":frame_us.size()}
	if icons.get("read_batches")!=null:
		metrics.warm.read_batches = icons.read_batches
		check(icons.read_batches<=13,"warm reads share a worker for each visible group")
	flush_metrics()
	check(models==0 and icons.disk_hits==49 and icons.rendered==0,"warm cache supplies the full catalogue without loading a model")
	check(icons.studio==null,"disk-only menu needs no studio")
	check(Icons.images.size()<=Icons.CACHE_LIMIT,"warm GPU cache remains bounded")

func changed_appearances() -> void:
	var differences: Array[Dictionary] = []
	for vehicle: String in VehicleCatalog.IDS:
		var parts: Dictionary = VehicleCustomisation.defaults()
		if vehicle=="compact": parts.body = "wide"
		for index: int in [0,2,4]:
			var paint: Dictionary = preset(index,vehicle)
			paint.colors.body = "a44844"
			if index==4: paint.stickers.hood.id = LiveryCatalog.stickers[0].id
			icons.request(cards[0],vehicle,paint,parts)
			await idle()
			var reference: Control = Profile.make_preview(vehicle,paint,parts)
			reference.position = Vector2(-10000,-10000)
			reference.size = Vector2(Icons.SIZE)*0.5
			root.add_child(reference)
			Profile.apply_presentation(reference)
			for tick: int in range(4): await RenderingServer.frame_post_draw
			reference.viewport.size = Icons.SIZE
			reference._fit_camera()
			reference.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var expected: Image = reference.viewport.get_texture().get_image()
			var actual: Image = cards[0].car_icon.texture.get_image()
			var difference: float = 0.0
			for y: int in range(0,Icons.SIZE.y,2):
				for x: int in range(0,Icons.SIZE.x,2):
					var a: Color = actual.get_pixel(x,y)
					var b: Color = expected.get_pixel(x,y)
					difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)
			difference /= float(Icons.SIZE.x*Icons.SIZE.y)
			differences.append({"vehicle":vehicle,"paint":index,"mean_rgba_difference":difference})
			check(difference<0.02,"reused model matches unchanged profile renderer "+vehicle+"/"+str(index))
			reference.queue_free()
			await process_frame
	metrics.appearance = differences
	metrics.final_counters = {"model_builds":icons.model_builds,"repaints":icons.repaints,"disk_hits":icons.disk_hits,"readback_us":icons.readback_us,"build_us":icons.build_us,"repaint_us":icons.repaint_us}
	check(icons.peak_worlds<=1,"at most one icon studio remains attached")
	shelf.hide()
	await process_frame
	check(not icons.busy and icons.studio==null,"hiding releases the idle studio")

func cache_guards() -> void:
	var paint: Dictionary = preset(1)
	var parts: Dictionary = VehicleCustomisation.defaults()
	var key: String = icons.identity("compact",paint,parts)
	check(key==icons.identity("compact",paint.duplicate(true),parts.duplicate(true)),"equivalent appearance retains cache identity")
	var changed: Dictionary = paint.duplicate(true)
	changed.colors.body = "a44844"
	check(key!=icons.identity("compact",changed,parts),"custom pigment invalidates the icon")
	changed = paint.duplicate(true)
	changed.stickers.hood.id = LiveryCatalog.stickers[0].id
	check(key!=icons.identity("compact",changed,parts),"panel sticker invalidates the icon")
	var fitted: Dictionary = parts.duplicate(true)
	fitted.body = "wide"
	check(key!=icons.identity("compact",paint,fitted),"fitted geometry invalidates the icon")
	check(key!=icons.identity("pickup",paint,parts),"vehicle invalidates the icon")
	var directory: String = ProjectSettings.globalize_path("user://cache_guards_"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(directory)
	var corrupt: String = directory.path_join("corrupt.png")
	var file := FileAccess.open(corrupt,FileAccess.WRITE)
	file.store_string("invalid cache image")
	file.close()
	check(Icons._read(func() -> bool: return false,corrupt).image==null,"corrupt cache is treated as a miss")
	var small: Image = Image.create(1,1,false,Image.FORMAT_RGBA8)
	small.save_png(corrupt)
	check(Icons._read(func() -> bool: return false,corrupt).image==null,"wrong image dimensions are rejected before decode")
	var oversized := PackedByteArray()
	oversized.resize(Icons.FILE_BYTES+1)
	file = FileAccess.open(corrupt,FileAccess.WRITE)
	file.store_buffer(oversized)
	file.close()
	check(Icons._read(func() -> bool: return false,corrupt).image==null,"cache read has a compressed-byte bound")
	var image: Image = Image.create(Icons.SIZE.x,Icons.SIZE.y,false,Image.FORMAT_RGBA8)
	Icons._write(func() -> bool: return true,directory,key,image)
	check(not FileAccess.file_exists(directory.path_join(key+".png")),"cancelled work cannot publish a cache image")
	for index: int in range(Icons.FILE_LIMIT+3):
		file = FileAccess.open(directory.path_join(str(index).sha256_text()+".png"),FileAccess.WRITE)
		file.store_8(0)
		file.close()
	Icons._trim(directory)
	var folder := DirAccess.open(directory)
	var owned: int = 0
	for name: String in folder.get_files():
		if name.ends_with(".png") and name.trim_suffix(".png").length()==64: owned += 1
	check(owned==Icons.FILE_LIMIT and FileAccess.file_exists(corrupt),"disk eviction is bounded and leaves unrelated files alone")
	shelf.show()
	changed.colors.detail = "123456"
	icons.request(cards[0],"compact",changed,parts)
	await process_frame
	check(icons.busy,"a cold read can be cancelled in flight")
	shelf.hide()
	for tick: int in range(8): await process_frame
	check(not icons.busy and icons.studio==null and cards[0].car_icon.texture==null,"hide cancels disk/model work without publishing a stale picture")
	shelf.show()
	icons.request(cards[0],"compact",changed,parts)
	await process_frame
	icons.queue_free()
	await process_frame
	make_worker()
	changed.colors.detail = "654321"
	icons.request(cards[0],"compact",changed,parts)
	await idle()
	check(cards[0].get_meta("icon_livery")==changed and cards[0].car_icon.texture!=null,"replacement worker publishes only its latest appearance")
	if icons.get("read_batches")!=null:
		icons.cache_directory = ""
		changed.colors.detail = "123abc"
		icons.request(cards[0],"compact",changed,fitted)
		var deadline: int = Time.get_ticks_msec()+5000
		while icons._stage!="build" and Time.get_ticks_msec()<deadline: await process_frame
		check(icons._stage=="build" and icons.busy and not icons.studio.presentation_ready,"cold construction is exercised before presentation is ready")
		if icons._stage=="build":
			shelf.hide()
			for tick: int in range(8): await process_frame
			check(not icons.busy and icons.studio==null,"hiding during sliced construction clears the pending studio")

func flush_metrics() -> void:
	var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))

