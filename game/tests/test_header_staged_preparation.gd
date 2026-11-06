extends SceneTree
## Actual header capture versus its retained native reference and gated teardown.
const Cache = preload("res://ui/header_car_appearance_cache.gd")
const Icons = preload("res://ui/header_car_icons.gd")
const Profile = preload("res://ui/profile_car.gd")
const Shared = preload("res://rendering/graphics_preparation.gd")
const Before = preload("res://../docs/evidence/mobile-performance-implementation-2026-11-06/idle/before/game/ui/header_car_appearance_cache.gd")
var checks: int = 0
var failures: int = 0

class Captured extends "res://ui/header_car_appearance_cache.gd":
	var same_frame_exact: bool = false
	var texture_roundtrip_exact: bool = false
	var camera_stable: bool = true
	var staging_frames: int = 0
	var restored_geometry: bool = false
	var original_camera: Transform3D
	var original_fov: float
	var geometry: Array[Dictionary] = []
	func _prepare_header(generation: int, owner: WeakRef) -> void:
		original_camera = studio.camera.global_transform
		original_fov = studio.camera.fov
		for bucket: Array in _preparation.pending.values():
			for reference: WeakRef in bucket:
				var mesh: GeometryInstance3D = reference.get_ref()
				geometry.append({"node":reference,"margin":mesh.extra_cull_margin})
		await super._prepare_header(generation,owner)
		if not _preparation_current(generation,owner): return
		restored_geometry = geometry.all(func(entry: Dictionary) -> bool: return is_instance_valid(entry.node.get_ref()) and entry.node.get_ref().is_visible_in_tree() and entry.node.get_ref().extra_cull_margin == entry.margin)
	func _preparation_frame(generation: int, owner: WeakRef) -> bool:
		staging_frames += 1
		camera_stable = camera_stable and studio.camera.global_transform == original_camera and studio.camera.fov == original_fov
		var result: bool = await super._preparation_frame(generation,owner)
		if _preparation_current(generation,owner): camera_stable = camera_stable and studio.camera.global_transform == original_camera and studio.camera.fov == original_fov
		return result
	func _after_draw() -> void:
		if canvas == null or _stage != "draw" or _draws != 1:
			super._after_draw()
			return
		var image: Image = canvas.get_texture().get_image()
		var key: String = _current.key
		# Compare the actual operation added by this task in the same target.
		# Publishing a mipmapped ImageTexture is an existing GPU round trip.
		preload("res://rendering/graphics_preparation.gd").finish_capture(_graphics_ticket,studio.car.get_parent(),studio.viewport,studio.viewport.get_camera_3d())
		same_frame_exact = image.get_data() == canvas.get_texture().get_image().get_data()
		super._after_draw()
		var texture: Texture2D = preload("res://ui/header_car_icons.gd").customized.get(key)
		if texture != null:
			var published: Image = texture.get_image()
			published.clear_mipmaps()
			texture_roundtrip_exact = image.get_data() == published.get_data()

func appearance_difference(actual: Image, expected: Image) -> float:
	# Retain the existing equipped-header reference invariant, including its
	# straight/premultiplied alpha conversion. Separate native allocations are
	# not bit deterministic: the archived unchanged-control comparison proves it.
	var difference: float = 0.0
	for y: int in range(0,Icons.SIZE.y,2):
		for x: int in range(0,Icons.SIZE.x,2):
			var a: Color = actual.get_pixel(x,y)
			var b: Color = expected.get_pixel(x,y)
			if b.a > 0 and b.a < 1: b = Color(minf(1,b.r/b.a),minf(1,b.g/b.a),minf(1,b.b/b.a),b.a)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)
	return difference/float(Icons.SIZE.x*Icons.SIZE.y)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("STAGED_HEADER_FAIL ",label)
func frames(count: int = 5) -> void:
	for _i: int in range(count): await process_frame
func run() -> void:
	create_timer(240,true,false,true).timeout.connect(func() -> void: printerr("STAGED_HEADER_TIMEOUT"); quit(1))
	root.size = Vector2i(640,360)
	Engine.time_scale = 0.0
	var rows: Array = []
	for id: String in VehicleCatalog.IDS:
		var selected: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--vehicle="): selected = argument.trim_prefix("--vehicle=")
		if not selected.is_empty() and id != selected: continue
		var records := LocalRecords.new("user://graphics-header/"+id+"/records.json")
		var paint: Dictionary = VehicleLivery.defaults(id)
		paint.colors.body = "32b5d7"
		paint.pattern = "offset_gt"
		records.settings = {"vehicle_liveries":{id:paint},"selected_car":id}
		VehicleCatalog.selected = id
		var baseline_records := LocalRecords.new("user://graphics-header-before/"+id+"/records.json")
		baseline_records.settings = records.settings.duplicate(true)
		var baseline: Node = Before.new()
		baseline.allowed = func() -> bool: return true
		root.add_child(baseline)
		baseline.bind_records(baseline_records)
		while not baseline.idle(): await process_frame
		var baseline_image: Image = Icons.texture(id,baseline_records).get_image()
		baseline_image.clear_mipmaps()
		baseline_image.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(id+"-before.png"))
		baseline.queue_free()
		await frames(8)
		var repeated_records := LocalRecords.new("user://graphics-header-repeat/"+id+"/records.json")
		repeated_records.settings = records.settings.duplicate(true)
		var repeated: Node = Before.new()
		repeated.allowed = func() -> bool: return true
		root.add_child(repeated)
		repeated.bind_records(repeated_records)
		while not repeated.idle(): await process_frame
		var repeated_image: Image = Icons.texture(id,repeated_records).get_image()
		repeated_image.clear_mipmaps()
		repeated_image.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(id+"-control-repeat.png"))
		print("HEADER_UNCHANGED_CONTROL_EXACT ",id," ",baseline_image.get_data() == repeated_image.get_data())
		repeated.queue_free()
		await frames(8)
		var service: Node = Captured.new()
		var permission: Dictionary = {"allowed":true}
		service.allowed = func() -> bool: return permission.allowed
		root.add_child(service)
		Shared.invalidate()
		service.bind_records(records)
		var began: int = Time.get_ticks_usec()
		while not service.idle(): await process_frame
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		check(service.camera_stable and service.staging_frames > 0,"real staged draws preserve the exact camera "+id)
		check(service.restored_geometry,"all geometry visibility and cull margins restored "+id)
		check(service.captures == 1 and service.peak_worlds == 1 and service.canvas == null,"one owned exact capture "+id)
		check(not Shared.warmed.is_empty(),"header contributes valid completed preparation "+id)
		var actual: Image = Icons.texture(id,records).get_image()
		actual.clear_mipmaps()
		check(service.same_frame_exact,"shared bookkeeping preserves exact actual capture pixels "+id)
		var canvas := SubViewport.new()
		canvas.size = Icons.SIZE
		canvas.disable_3d = true
		canvas.transparent_bg = true
		canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(canvas)
		var reference: Control = Profile.make_preview(id,paint,VehicleCustomisation.defaults())
		reference.header_template = true
		reference.cooperative_build = true
		reference.cache_rest_pose = false
		reference.size = Vector2(Icons.SIZE)
		canvas.add_child(reference)
		while not reference.presentation_ready: await process_frame
		Profile.apply_presentation(reference)
		for _i: int in range(7): await RenderingServer.frame_post_draw
		var expected: Image = canvas.get_texture().get_image()
		expected.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(id+"-reference.png"))
		print("STAGED_HEADER_PIXEL_META ",id," ",actual.get_size(),"/",baseline_image.get_size(),"/",expected.get_size()," bytes ",actual.get_data().size(),"/",baseline_image.get_data().size(),"/",expected.get_data().size())
		var difference: float = appearance_difference(actual,expected)
		check(difference < 0.02,"retained native equipped-header appearance invariant "+id)
		check(actual.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(id+".png")) == OK,"native header evidence "+id)
		rows.append({"vehicle":id,"ms":elapsed,"programs":Shared.warmed.size(),"same_frame_exact":service.same_frame_exact,"texture_roundtrip_exact":service.texture_roundtrip_exact,"appearance_difference":difference,"baseline_exact":actual.get_data() == baseline_image.get_data(),"unchanged_control_exact":baseline_image.get_data() == repeated_image.get_data()})
		canvas.queue_free()
		service.queue_free()
		await frames(8)
	var records := LocalRecords.new("user://graphics-header/cancel/records.json")
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "ff4411"
	records.settings = {"vehicle_liveries":{"compact":paint}}
	var service: Node = Cache.new()
	var permission: Dictionary = {"allowed":false}
	service.allowed = func() -> bool: return permission.allowed
	root.add_child(service)
	Shared.invalidate()
	service.bind_records(records)
	await frames(8)
	check(service.canvas == null and Shared.warmed.is_empty(),"gated header never starts a renderer or publishes preparation")
	permission.allowed = true
	service.resume_pending()
	while service._stage != "prepare": await process_frame
	var generation: int = service._capture_generation
	permission.allowed = false
	await frames(3)
	check(service.canvas == null and service.captures == 0 and not Icons.ready("compact",records),"closing the gate during real staging releases the world without publication")
	check(service._capture_generation > generation and service._jobs.size() == 1,"interrupted preparation leaves one pinned retry and invalidates its continuation")
	permission.allowed = true
	service.resume_pending()
	while not service.idle(): await process_frame
	check(service.captures == 1 and Icons.ready("compact",records) and service.peak_worlds == 1,"resumed preparation publishes once with a single native world")
	service.queue_free()
	await frames(8)
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("STAGED_HEADER ",checks," checks, ",failures," failures")
	Engine.time_scale = 1.0
	quit(1 if failures else 0)
