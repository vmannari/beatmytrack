extends SceneTree
## Offline exact native image reuse, mutation isolation and resize fallback.
const Pictures = preload("res://ui/rivalry_podium_pictures.gd")
const Cached = preload("res://ui/rivalry_cached_podium.gd")
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
var output: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PODIUM_PICTURES_FAIL ",label)
func frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func make_view(vehicle: String) -> Control:
	var view: Control = Cached.new()
	view.vehicle_id = vehicle
	view.size = Vector2(320,176)
	view.position = Vector2(100,80)
	view.livery = VehicleLivery.defaults(vehicle)
	view.livery.colors.body = "e58e26"
	view.livery.pattern = str(LiveryCatalog.patterns[33].id)
	view.livery.stickers.hood.id = str(LiveryCatalog.stickers[3].id)
	view.customisation = VehicleCustomisation.defaults()
	if vehicle == "compact":
		view.customisation.hood = "scoop"
		view.customisation.body = "wide"
		view.customisation.rims = "mesh"
		view.customisation.aero = "whale"
	return view

func run() -> void:
	root.size = Vector2i(720,440)
	output = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	create_timer(180,true,false,true).timeout.connect(func() -> void: printerr("PODIUM_PICTURES_TIMEOUT");quit(1))
	var native: bool = DisplayServer.get_name() != "headless"
	for vehicle: String in ["compact","electric"]:
		var start: int = Time.get_ticks_usec()
		var view: Control = make_view(vehicle)
		root.add_child(view)
		while not view.presentation_ready: await process_frame
		await frames(8)
		var first_ms: float = (Time.get_ticks_usec()-start)/1000.0
		check(view.car != null,vehicle+" first use builds actual native car")
		if not native:
			check(Pictures.hits == 0,vehicle+" headless bypasses pictures")
			view.queue_free()
			await frames(2)
			continue
		var texture: Texture2D = view.picture_texture()
		var raw: Image = texture.get_image()
		var occupied: int = 0
		var pixels: PackedByteArray = raw.get_data()
		for index: int in range(3,pixels.size(),4):
			if pixels[index] > 32: occupied += 1
		check(occupied > 1000,vehicle+" native image contains visible car/studio pixels")
		var key: String = Pictures.identity(view,view.viewport.size)
		var saved: ImageTexture = Pictures.read_picture(key,view.viewport.size)
		check(saved != null,vehicle+" settled exact picture persisted")
		if saved != null: check(saved.get_image().get_data() == raw.get_data(),vehicle+" native pixel bytes exact on disk")
		var live_frame: Image = root.get_texture().get_image()
		live_frame.save_png(output.path_join(vehicle+"-live.png"))
		# Substitute on the same canvas target to isolate texture representation.
		var render: TextureRect = view.find_child("VictoryCarRender",true,false)
		render.texture = saved
		view.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await frames(2)
		check(root.get_texture().get_image().get_data() == live_frame.get_data(),vehicle+" same-target raw ImageTexture composite is byte exact")
		view.queue_free()
		await frames(2)
		start = Time.get_ticks_usec()
		var hit: Control = make_view(vehicle)
		root.add_child(hit)
		while not hit.presentation_ready: await process_frame
		await frames(2)
		var hit_ms: float = (Time.get_ticks_usec()-start)/1000.0
		check(hit.car == null and hit.find_children("*","Node3D",true,false).is_empty(),vehicle+" cache hit builds no native car or studio")
		check(hit.picture_texture().get_image().get_data() == raw.get_data(),vehicle+" cache hit preserves all native bytes")
		check(root.get_texture().get_image().get_data() == live_frame.get_data(),vehicle+" fresh cached control preserves full frame exactly")
		root.get_texture().get_image().save_png(output.path_join(vehicle+"-cached.png"))
		var original: String = Pictures.identity(hit,hit.viewport.size)
		hit.livery.colors.body = "12ab56"
		check(Pictures.identity(hit,hit.viewport.size) != original,vehicle+" paint alters identity")
		hit.livery.colors.body = "e58e26"
		hit.condition = {"wetness":0.8}
		check(Pictures.identity(hit,hit.viewport.size) != original,vehicle+" local condition alters identity")
		hit.condition = {}
		check(Pictures.identity(hit,hit.viewport.size+Vector2i.ONE) != original,vehicle+" actual resolution alters identity")
		hit.size.x += 3
		await frames(8)
		check(hit.car != null and hit.presentation_ready,vehicle+" unknown resized extent restores original native renderer")
		metrics[vehicle] = {"first_ms":first_ms,"hit_ms":hit_ms,"size":[raw.get_width(),raw.get_height()],"format":raw.get_format()}
		hit.queue_free()
		await frames(3)
	var before_cancel: int = Pictures.writes
	var abandoned: Control = make_view("compact")
	abandoned.size.x += 17
	root.add_child(abandoned)
	abandoned.queue_free()
	await frames(4)
	check(Pictures.writes == before_cancel,"cancelled owner cannot publish an image")
	check(Pictures.read_picture("../invalid",Vector2i(8,8)) == null,"invalid cache path rejected")
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"hits":Pictures.hits,"writes":Pictures.writes},"  "))
	print("PODIUM_PICTURES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
