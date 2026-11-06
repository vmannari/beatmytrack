extends SceneTree
## Production five-car captures retain their native target, AA and reflection.
const Shared = preload("res://rendering/graphics_preparation.gd")
var checks: int = 0
var failures: int = 0
class Captured extends "res://ui/garage_preview_cache.gd":
	var unchanged: Array[bool] = []
	var actual_views: Array[Dictionary] = []
	func _capture() -> void:
		if not is_instance_valid(renderer) or not _render_allowed() or not _current(active,true):
			super._capture()
			return
		var image: Image = renderer.showroom_viewport.get_texture().get_image()
		preload("res://rendering/graphics_preparation.gd").finish_capture(_graphics_ticket,renderer.camera.get_parent(),renderer.showroom_viewport,renderer.camera)
		unchanged.append(image.get_data() == renderer.showroom_viewport.get_texture().get_image().get_data())
		actual_views.append({"size":renderer.showroom_viewport.size,"aa":renderer.showroom_viewport.msaa_3d,"reflections":renderer.reflections.views.size(),"world_shared":renderer.showroom_viewport.find_world_3d() == renderer.reflections.views[0].find_world_3d()})
		super._capture()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("GRAPHICS_THUMBNAILS_FAIL ",label)
func run() -> void:
	create_timer(160).timeout.connect(func() -> void: printerr("GRAPHICS_THUMBNAILS_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	var records := LocalRecords.new("user://graphics-thumbnails/records.json")
	var paints: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary = VehicleLivery.defaults(id)
		paint.colors.body = "32b5d7"
		paint.pattern = "offset_gt"
		paints[id] = paint
	records.settings = {"vehicle_liveries":paints}
	var service := Captured.new()
	service.idle_ms = 0
	root.add_child(service)
	Shared.invalidate()
	service.warm_records(records,false)
	while not service.pictures_ready(): await process_frame
	check(service.renders == 5 and service.unchanged.size() == 5,"one capture for each current car")
	check(service.unchanged.all(func(ok: bool) -> bool: return ok),"shared bookkeeping preserves all actual native thumbnail pixels")
	for view: Dictionary in service.actual_views:
		check(view.size == Vector2i(2048,512) and view.aa == Viewport.MSAA_4X,"full original capture size and sampling")
		check(view.reflections == 1 and view.world_shared,"actual car-only planar capture retained")
	check(not Shared.warmed.is_empty(),"thumbnail captures contribute completed context-specific preparation")
	for id: String in VehicleCatalog.IDS:
		var texture: Texture2D = service.ready_pictures[id].texture
		check(texture.get_image().save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(id+".png")) == OK,"actual thumbnail evidence "+id)
	while service.worker != null or not service.pending_writes.is_empty(): await process_frame
	service.queue_free()
	for _i: int in range(12): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("GRAPHICS_THUMBNAILS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
