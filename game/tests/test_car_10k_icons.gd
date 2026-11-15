extends SceneTree
## Native geometry budget, appearance parity, cached delivery and interrupted capture.
const Renderer = preload("res://ui/header_icon_renderer.gd")
const Icons = preload("res://ui/header_car_icons.gd")
const Cache = preload("res://ui/header_car_appearance_cache.gd")
var checks: int = 0
var failures: int = 0
var evidence: String
var metrics: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
func drawn() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func parts_for(id: String) -> Dictionary:
	var parts: Dictionary = VehicleCustomisation.defaults()
	for category: String in VehicleCustomisation.CATEGORIES:
		var options: Array = VehicleCustomisation.options(category,id)
		parts[category] = options[mini(2,options.size()-1)][0]
	return parts
func paint_for(id: String) -> Dictionary:
	var paint: Dictionary = VehicleLivery.defaults(id)
	paint.colors.body = "278da3"
	paint.pattern = "apex_twin"
	paint.stickers.hood.id = str(LiveryCatalog.stickers[3].id)
	return paint

func image_difference(a: Image,b: Image) -> Dictionary:
	var error: float = 0
	var alpha_error: float = 0
	var occupied: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var first: Color = a.get_pixel(x,y)
			var second: Color = b.get_pixel(x,y)
			error += absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)
			alpha_error += absf(first.a-second.a)
			if maxf(first.a,second.a)>0.5: occupied += 1
	return {"rgb_mean":error/(a.get_width()*a.get_height()*3),"alpha_mean":alpha_error/(a.get_width()*a.get_height()),"occupied":occupied}

func native_models() -> void:
	var simplified_total: int = 0
	var full_total: int = 0
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally": continue
		var paint: Dictionary = paint_for(id)
		var parts: Dictionary = parts_for(id)
		var bases_before: int = preload("res://vehicle/modular_car_base.gd").hits
		var kits_before: int = preload("res://vehicle/modular_car_kits.gd").hits
		var view: Control = Renderer.make_preview(id,paint,parts)
		view.size = Vector2(Icons.SIZE)
		root.add_child(view)
		var deadline: int = Time.get_ticks_msec()+20000
		while not view.presentation_ready and Time.get_ticks_msec()<deadline: await process_frame
		check(view.presentation_ready,id+" reduced icon becomes ready")
		check(preload("res://vehicle/modular_car_base.gd").hits==bases_before+1,id+" restores a current prepared base")
		var expected_kits: int = 0
		for category: String in VehicleCustomisation.CATEGORIES:
			if parts[category]!="stock": expected_kits += 1
		check(preload("res://vehicle/modular_car_kits.gd").hits-kits_before==expected_kits,id+" restores every equipped prepared kit")
		check(view.car.livery==paint and view.car.customisation==parts,id+" keeps the actual equipped appearance")
		check(view.find_children("*","WorldEnvironment",true,false).is_empty() and view.find_children("*","Light3D",true,false).is_empty(),id+" has no reflective studio or light nodes")
		check(view.viewport.size==Icons.SIZE,id+" renders at the icon's native size")
		for _frame: int in range(3):
			view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await drawn()
		var simple_primitives: int = view.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var simple: Image = view.viewport.get_texture().get_image()
		var camera_pose: Transform3D = view.camera.transform
		var field_of_view: float = view.camera.fov
		view.viewport.mesh_lod_threshold = 0
		for _frame: int in range(3):
			view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await drawn()
		var full_primitives: int = view.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var full: Image = view.viewport.get_texture().get_image()
		var difference: Dictionary = image_difference(simple,full)
		check(simple_primitives>0 and simple_primitives<full_primitives,id+" uses the prepared mesh distance levels")
		check(difference.occupied>1500 and difference.rgb_mean<0.025 and difference.alpha_mean<0.025,id+" retains its silhouette, livery and fitted shape at 176x112")
		check(view.camera.transform==camera_pose and view.camera.fov==field_of_view,id+" compares geometry with an identical camera")
		for binding: Dictionary in view.car.graphics.bindings:
			var active: ShaderMaterial = binding.node.get_active_material(binding.index) as ShaderMaterial
			check(active.shader==preload("res://ui/rivalry_simple_car.gd").FINISH,id+" uses one preview finish")
			for uniform: String in ["mesh_to_body","livery_mask","livery_body","livery_accent","livery_detail","hood_sticker","roof_sticker","hood_emblem","roof_emblem","panel_levels"]:
				check(active.get_shader_parameter(uniform)==binding.finish.get_shader_parameter(uniform),id+" keeps production graphic uniform "+uniform)
		var pair := Image.create(Icons.SIZE.x*2,Icons.SIZE.y,false,Image.FORMAT_RGBA8)
		pair.blit_rect(full,Rect2i(Vector2i.ZERO,Icons.SIZE),Vector2i.ZERO)
		pair.blit_rect(simple,Rect2i(Vector2i.ZERO,Icons.SIZE),Vector2i(Icons.SIZE.x,0))
		check(pair.save_png(evidence.path_join(id+"-full-versus-icon.png"))==OK,id+" save native detail comparison")
		simplified_total += simple_primitives
		full_total += full_primitives
		metrics.append({"vehicle":id,"full_primitives":full_primitives,"icon_primitives":simple_primitives,"difference":difference})
		view.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		view.free()
		await process_frame
	check(simplified_total<full_total*0.85,"prepared icon models remove at least fifteen percent of drawn triangles")

func cache_capture() -> void:
	var records := LocalRecords.new("user://header-native-capture/records.json")
	records.settings = {"vehicle_liveries":{"compact":paint_for("compact")},"vehicle_customisation":{"compact":parts_for("compact")}}
	Icons.customized.clear()
	var service: Node = Cache.new()
	var policy: Dictionary = {"allowed":true}
	service.allowed = func() -> bool: return policy.allowed
	root.add_child(service)
	service.bind_records(records)
	var deadline: int = Time.get_ticks_msec()+20000
	while service._stage!="build" and Time.get_ticks_msec()<deadline: await process_frame
	check(service._stage=="build","actual capture enters a cooperative model build")
	var stale_key: String = Icons.appearance_key("compact",records)
	policy.allowed = false
	await process_frame
	await process_frame
	check(service.canvas==null and service.captures==0 and not Icons.customized.has(stale_key),"closing the gate releases the model without publishing")
	policy.allowed = true
	service.resume_pending()
	deadline = Time.get_ticks_msec()+20000
	while not service.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(service.idle() and service.captures==1 and service.peak_worlds==1,"resumed capture publishes once with one native world")
	var actual: Image = Icons.texture("compact",records).get_image()
	actual.clear_mipmaps()
	var view: Control = Renderer.make_preview("compact",paint_for("compact"),parts_for("compact"))
	view.size = Vector2(Icons.SIZE)
	root.add_child(view)
	while not view.presentation_ready: await process_frame
	for _frame: int in range(4): await drawn()
	var expected: Image = view.viewport.get_texture().get_image()
	# The worker stores straight alpha after resolving the transparent canvas.
	for y: int in range(expected.get_height()):
		for x: int in range(expected.get_width()):
			var pixel: Color = expected.get_pixel(x,y)
			if pixel.a>0 and pixel.a<1: expected.set_pixel(x,y,Color(minf(1,pixel.r/pixel.a),minf(1,pixel.g/pixel.a),minf(1,pixel.b/pixel.a),pixel.a))
	var difference: Dictionary = image_difference(actual,expected)
	check(difference.rgb_mean<0.02 and difference.alpha_mean<0.02,"two-draw capture retains the independently rendered equipped icon")
	view.free()
	Icons.customized.clear()
	service.bind_records(null)
	service.bind_records(records)
	deadline = Time.get_ticks_msec()+5000
	while not service.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(service.idle() and service.captures==1 and service.disk_hits==1,"disk reuse needs no second model capture")
	service.free()
	await process_frame

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	evidence = OS.get_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1200,610)
	await native_models()
	await cache_capture()
	FileAccess.open(evidence.path_join("models.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	print("HEADER_ICON_MODELS ",JSON.stringify(metrics))
	print("HEADER_ICON_CAPTURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
