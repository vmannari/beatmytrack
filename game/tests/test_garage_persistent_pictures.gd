extends SceneTree
## Separate-process native capture/reuse and durable prepared-picture regression.
const Cache = preload("res://ui/garage_preview_cache.gd")
const Thumbnail = preload("res://ui/garage_cached_thumbnail.gd")
var checks: int=0
var failures: int=0
var output: String
var folder: String
var phase: String="seed"
var fixture_pictures: String=""
var vehicle_ids: Array[String]=[]
var capture_scale: float=1.0
var service: Node
var host: Control
var cards: Dictionary={}
var metrics: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func checksum(image: Image) -> String:
	var digest:=HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(image.get_data())
	return digest.finish().hex_encode()

func card(id: String,index: int) -> CarShowroom:
	var view: CarShowroom=Thumbnail.new()
	view.vehicle_id=id
	view.livery=VehicleLivery.for_car({},id)
	view.livery.colors.body="c72d34"
	view.condition=VehicleWeathering.new().snapshot()
	view.condition.dirt=0.35
	view.condition.slow_dirt=0.2
	view.customisation=VehicleCustomisation.defaults()
	view.preview_service=service
	view.position=Vector2(12+(index%3)*220,12+floori(index/3.0)*140)
	view.size=Vector2(174,104)
	host.add_child(view)
	return view

func wait_for_pictures(expected: int) -> void:
	var deadline: int=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		var ready: int=0
		for view: CarShowroom in cards.values():
			if view.displayed_key==view.preview_key: ready+=1
		if ready>=expected: return
		await process_frame
	var renderer: CarShowroom=service.renderer
	print("PERSISTENT_WAIT: ",JSON.stringify({"ready":expected,"active":service.active.get("vehicle",""),"queued":service.queued.size(),"frames":service.frames,"render_allowed":service._render_allowed(),"showroom_ready":renderer.showroom_ready if renderer!=null else false,"model_ready":renderer.car.model_ready if renderer!=null and renderer.car!=null else false,"input_pressed":Input.is_anything_pressed(),"touches":service._touches,"focus":str(root.gui_get_focus_owner())}))
	check(false,"all expected pictures arrive before the deadline")

func wait_for_io() -> void:
	var deadline: int=Time.get_ticks_msec()+10000
	while (service.worker!=null or not service.get("pending_writes").is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(service.worker==null and service.get("pending_writes").is_empty(),"picture writes finish before closing the process")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--cache="): folder=arg.trim_prefix("--cache=")
		if arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
		if arg.begins_with("--fixture-pictures="): fixture_pictures=arg.trim_prefix("--fixture-pictures=")
		if arg.begins_with("--cars="): vehicle_ids.assign(arg.trim_prefix("--cars=").split(","))
		if arg.begins_with("--scale="): capture_scale=float(arg.trim_prefix("--scale="))
	if vehicle_ids.is_empty(): vehicle_ids.assign(VehicleCatalog.IDS)
	if "--procedural" in OS.get_cmdline_user_args():
		preload("res://ui/garage_car_cache.gd").enabled=false
		preload("res://vehicle/prepared_car_cache.gd").enabled=false
	if folder.is_empty(): folder="user://garage-persistent-pictures"
	root.size=Vector2i(roundi(1280*capture_scale),roundi(720*capture_scale))
	host=Control.new()
	host.theme=MenuStyle.theme()
	root.add_child(host)
	MenuStyle.fill(host)
	host.scale=Vector2(capture_scale,capture_scale)
	service=Cache.new()
	if "--original-renderer" in OS.get_cmdline_user_args():
		service.free()
		var original:=GDScript.new()
		original.source_code=FileAccess.get_file_as_string("res://../docs/evidence/garage-persistent-pictures-2026-10-28/before/game/ui/garage_preview_renderer.gd")
		check(original.reload()==OK,"compile the exact task-start capture renderer")
		var control:=GDScript.new()
		control.source_code=FileAccess.get_file_as_string("res://ui/garage_preview_cache.gd").replace('preload("res://ui/garage_preview_renderer.gd").new()','get_meta("original_renderer").new()')
		check(control.reload()==OK,"compile the unchanged cache with only the original-renderer fixture")
		service=control.new()
		service.set_meta("original_renderer",original)
	service.directory=folder
	service.idle_ms=0
	host.add_child(service)
	metrics.build_id=preload("res://core/build_identity.gd").ID
	metrics.preview_revision=preload("res://core/build_identity.gd").GARAGE_PREVIEW_SHA256
	metrics.cars=vehicle_ids
	metrics.capture_scale=capture_scale
	# Reuse must work even while deliberate input prohibits native GPU work.
	service.can_render=func() -> bool: return phase=="seed"
	var began: int=Time.get_ticks_usec()
	for index: int in range(vehicle_ids.size()):
		var id: String=vehicle_ids[index]
		cards[id]=card(id,index)
	# A controlled PNG-import case checks decoder/upload on another renderer
	# independently of the concurrently changing native model construction.
	if not fixture_pictures.is_empty():
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture_pictures.path_join("pixels.json")))
		var images: Dictionary={}
		for file: String in DirAccess.get_files_at(fixture_pictures):
			if not file.ends_with(".png"): continue
			var image:=Image.load_from_file(fixture_pictures.path_join(file))
			images[checksum(image)]=image
		DirAccess.make_dir_recursive_absolute(folder)
		for id: String in cards:
			check(images.has(fixture[id]),"import exact native PNG fixture "+id)
			if images.has(fixture[id]): check(images[fixture[id]].save_png(folder.path_join(cards[id].preview_key+".png"))==OK,"store owned PNG fixture "+id)
		var file:=FileAccess.open(folder.path_join("pixels.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(fixture))
		file.close()
		began=Time.get_ticks_usec()
	await wait_for_pictures(vehicle_ids.size())
	metrics.ready_ms=(Time.get_ticks_usec()-began)/1000.0
	await wait_for_io()
	metrics.renders=service.renders
	metrics.cache_hits=service.cache_hits
	check(service.renders==(vehicle_ids.size() if phase=="seed" else 0),"only the first process constructs previews; restart reuses pictures")
	var manifest: Dictionary={}
	if phase!="seed": manifest=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("pixels.json")))
	var hashes: Dictionary={}
	for id: String in cards:
		var view: CarShowroom=cards[id]
		check(view.car==null and view.showroom_viewport==null,"thumbnail owns no native world "+id)
		check(view.displayed_key==view.preview_key,"stored picture has the exact saved appearance "+id)
		if view._image.texture==null: continue
		check(view._image.texture.get_size()==Vector2(2048,512),"picture has the persistent pixel dimensions at any display scale "+id)
		hashes[id]=checksum(view._image.texture.get_image())
		check(FileAccess.file_exists(folder.path_join(view.preview_key+".png")),"native picture is stored on disk "+id)
		if phase!="seed": check(hashes[id]==manifest[id],"new-process PNG pixels match the first capture exactly "+id)
	if phase=="seed":
		var file:=FileAccess.open(folder.path_join("pixels.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(hashes))
		file.close()
	metrics.pixel_hashes=hashes
	# A persisted clean condition must use the existing exact factory image.
	for id: String in cards:
		var view: CarShowroom=cards[id]
		var saved: Dictionary=view.condition
		view.condition={}
		var empty_key: String=service.identity(view)
		view.condition=VehicleWeathering.new().snapshot()
		check(service.identity(view)==empty_key,"clean saved snapshot shares the empty-condition picture "+id)
		view.livery=VehicleLivery.for_car({},id)
		check(service._default(view),"clean default appearance uses the bundled picture "+id)
		view.livery.colors.body="c72d34"
		view.condition=saved
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join(phase+"-pictures.png"))==OK,"capture all current exact stored pictures")
	if phase=="reuse" and vehicle_ids.size()>1: await mixed_and_prepared()
	host.queue_free()
	for _frame: int in range(4): await process_frame
	metrics.checks=checks
	metrics.failures=failures
	metrics.phase=phase
	var result:=FileAccess.open(output.path_join(phase+".json"),FileAccess.WRITE)
	result.store_string(JSON.stringify(metrics,"  "))
	print("PERSISTENT_PICTURES: ",JSON.stringify(metrics))
	quit(1 if failures else 0)

func mixed_and_prepared() -> void:
	var first: CarShowroom=cards.compact
	var exact: Texture2D=first._image.texture
	var saved_key: String=first.preview_key
	check(DirAccess.remove_absolute(folder.path_join(saved_key+".png"))==OK,"remove only the owned first-car fixture PNG")
	service.queued.clear()
	for view: CarShowroom in cards.values():
		view.preview_key=""
		view.refresh_thumbnail()
	var began: int=Time.get_ticks_usec()
	await wait_for_pictures(vehicle_ids.size()-1)
	metrics.mixed_cached_ready_ms=(Time.get_ticks_usec()-began)/1000.0
	check(first._image.texture==null and first._placeholder.visible,"a missing exact picture waits without substituting another livery")
	check(service.renders==0 and service.renderer==null,"a cold first card cannot block six stored pictures or start a world while input is gated")
	service.queued.clear()
	# Simulate the actual preloader handoff with this exact captured texture.
	service.prepared_picture={"vehicle":first.vehicle_id,"paint":first.livery.duplicate(true),"condition":first.condition.duplicate(true),"parts":first.customisation.duplicate(true),"texture":exact}
	service.request(first)
	check(first._image.texture==exact,"prepared handoff publishes its existing exact photograph immediately")
	await wait_for_io()
	check(FileAccess.file_exists(folder.path_join(saved_key+".png")),"the preloaded picture is persisted without a second capture")
	service.prepared_picture={}
	first.preview_key=""
	first.refresh_thumbnail()
	await wait_for_pictures(vehicle_ids.size())
	check(service.renders==0 and checksum(first._image.texture.get_image())==checksum(exact.get_image()),"preloaded PNG survives without its live renderer or prepared texture")
