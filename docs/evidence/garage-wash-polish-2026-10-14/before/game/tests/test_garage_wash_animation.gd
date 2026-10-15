extends SceneTree
## Real Garage input, surface alignment, bounded motion, local persistence and cleanup.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-wash-animation-2026-10-14"
var page: GaragePage
var records: LocalRecords

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	while page._menu_motion != null: await frame()
	for tick: int in range(6): await frame()

func screenshot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK, "capture "+label)

func mouse(view: CarShowroom, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	view.gui_input.emit(event)

func project(view: CarShowroom, point: Vector3) -> Vector2:
	return view.camera.unproject_position(view.car.body.global_transform * point) * view.size / Vector2(view.showroom_viewport.size)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
	var directory: String = "user://wash_animation_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	records = LocalRecords.new(directory.path_join("records.json"))
	for id: String in VehicleCatalog.IDS:
		var dirty: Dictionary = VehicleWeathering.new().snapshot()
		dirty.dirt = 0.93
		dirty.mud = 0.9
		dirty.color = Color(0.32,0.25,0.17).to_html(false)
		check(VehicleCondition.save(records, id, dirty) == OK, id+" isolated dirty fixture")
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	page = GaragePage.new()
	page.records = records
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await settle()
	page.open_car(0)
	page._show_section("care")
	await settle()
	var view: CarShowroom = page.showroom
	view.set_process(false)
	view.yaw = -PI * 0.5
	view.elevation = 0.20
	view.set_zoom(0.72)
	var car: CarVisual = view.car
	var camera_pose: Transform3D = view.camera.transform
	var pigment: Dictionary = view.livery.duplicate(true)
	var parts: Dictionary = view.customisation.duplicate(true)
	check(view.wash_effect == null, "idle garage allocates no wash effect")
	page._toggle_wash()
	var effect: Node3D = view.wash_effect
	check(effect != null and not effect.visible, "Wash prepares one hidden effect")
	var target: Vector2 = project(view, Vector3(-0.85,0.54,0.05))
	var surface: Dictionary = view.pick_body_surface(target)
	check(not surface.is_empty(), "pick actual door surface")
	check(view.pick_body_point(target) == surface.point, "existing wash coordinates unchanged")
	check((surface.normal as Vector3).is_normalized(), "surface normal normalized")
	check((surface.normal as Vector3).dot(view.camera.project_ray_normal(target*Vector2(view.showroom_viewport.size)/view.size)) < 0.0, "normal faces visible side")
	check(view.pick_body_surface(Vector2(-100,-100)).is_empty(), "miss has no contact")
	await settle()
	await screenshot("dirty")
	var dirty_pixels := PackedByteArray()
	if DisplayServer.get_name() != "headless": dirty_pixels = view.showroom_viewport.get_texture().get_image().get_data()
	var mask: PackedByteArray = view.weathering.wash_image.get_data()
	mouse(view,target,true)
	view._process(1.0/30.0)
	check(effect.visible and effect.mitt.visible, "actual held hit shows mitt and particles")
	check(effect.mitt.global_position.distance_to(surface.position) < 0.06, "mitt centred on picked patch")
	check(effect.mitt.global_basis.y.dot(surface.normal) > 0.999, "mitt follows panel normal")
	var first_pose: Transform3D = effect.mitt.global_transform
	var nodes: int = effect.get_child_count()
	var resources: Array = [effect.foam.multimesh, effect.water.multimesh]
	for tick: int in range(18): view._process(1.0/30.0)
	check(effect.mitt.global_transform != first_pose, "held washing has real scrub motion")
	check(view.weathering.wash_image.get_data() != mask, "animation accompanies progressive local cleaning")
	check(view.car == car and view.camera.transform == camera_pose and view.livery == pigment and view.customisation == parts, "retained car camera paint and kits")
	check(effect.foam.multimesh.instance_count == 24 and effect.water.multimesh.instance_count == 32, "fixed particle budgets")
	await frame()
	await screenshot("washing-door")
	var wet_pixels: PackedFloat32Array = effect.water.multimesh.buffer.duplicate()
	view._process(1.0/30.0)
	check(effect.water.multimesh.buffer != wet_pixels, "droplets move during hold")
	# Remove only transient feedback to compare the underlying original car pixels.
	mouse(view,target,false)
	for tick: int in range(30): view._process(1.0/30.0)
	check(not effect.visible and not effect.mitt.visible, "release drains feedback within one second")
	check(VehicleCondition.read(records,"compact") == view.weathering.snapshot(), "release persists existing local condition")
	view.wash_pointer_valid = false
	view.queue_redraw()
	await settle()
	await screenshot("cleaned-patch")
	if DisplayServer.get_name() != "headless":
		check(view.showroom_viewport.get_texture().get_image().get_data() != dirty_pixels, "real paint changes beneath transient feedback")
	# Missing the car gives no false mitt/suds; quick swipes retain existing sampling.
	var saved: Dictionary = view.weathering.snapshot()
	mouse(view,Vector2(-100,-100),true)
	for tick: int in range(5): view._process(1.0/30.0)
	check(not effect.visible and view.weathering.snapshot() == saved, "background hold never animates or cleans")
	mouse(view,Vector2(-100,-100),false)
	await motion(view)
	saved = view.weathering.snapshot()
	check(effect.get_child_count() == nodes and [effect.foam.multimesh,effect.water.multimesh] == resources, "motion reuses original nodes and pools")
	# Second finger changes to orbit and clears contact; lifting needs a fresh stroke.
	view.yaw = -PI * 0.5
	view.elevation = 0.20
	view.set_zoom(0.72)
	view.set_wash_mode(true)
	target = project(view, Vector3(-0.85,0.54,0.05))
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = target
	view.gui_input.emit(touch)
	view._process(0.05)
	check(effect.mitt.visible and view.washing, "one finger animates washing")
	touch.index = 1
	touch.position += Vector2(80,0)
	view.gui_input.emit(touch)
	view._process(0.05)
	check(not view.washing and not effect.mitt.visible, "second finger stops scrubbing")
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = touch.position + Vector2(10,0)
	view.gui_input.emit(drag)
	check(not effect.visible, "orbit clears surface effects")
	touch.canceled = true
	view.gui_input.emit(touch)
	check(not effect.visible and view.touches.is_empty(), "cancel clears all washing feedback")
	saved = view.weathering.snapshot()
	view.hide()
	view._process(0.1)
	check(not effect.visible, "hidden garage stops effect")
	view.show()
	page._toggle_wash()
	check(not view.wash_mode and not effect.visible, "Done clears effects")
	page._toggle_wash()
	check(view.wash_effect == effect, "reopening Wash retains bounded effect")
	page._show_section("customise")
	await settle()
	check(not effect.visible and not view.wash_mode, "navigation clears transient effects")
	for id: String in VehicleCatalog.IDS:
		var before: Dictionary = VehicleCondition.read(records,id)
		if id != "compact": check(before.dirt == 0.93, id+" condition untouched")
	page.queue_free()
	await frame()
	check(not is_instance_valid(effect), "teardown releases effect")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(VehicleCondition.read(reopened,"compact") == JSON.parse_string(JSON.stringify(saved)), "restart retains exact serialized completed wash")
	await other_cars()
	print("GARAGE_WASH_ANIMATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func motion(view: CarShowroom) -> void:
	# Deterministic production updates produce real native screenshots, not a timing claim.
	view.set_wash_mode(true)
	view.yaw = -0.95
	view.elevation = 0.65
	view.set_zoom(0.68)
	for tick: int in range(72):
		var along: float = sin(float(tick) * 0.09) * 0.38
		var target: Vector2 = project(view,Vector3(-0.40,0.70,-1.0+along))
		if tick == 0: mouse(view,target,true)
		var drag := InputEventMouseMotion.new()
		drag.position = target
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		view.gui_input.emit(drag)
		view._process(1.0/30.0)
		await frame()
		await screenshot("motion/frame-%03d" % tick)
		if tick == 30: await screenshot("washing-hood")
	mouse(view,view.wash_pointer,false)
	for tick: int in range(30): view._process(1.0/30.0)
	view.set_wash_mode(false)

func other_cars() -> void:
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.garage_mode = true
		view.vehicle_id = id
		view.condition = VehicleCondition.read(records,id)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(view)
		view.set_process(false)
		view.yaw = -PI * 0.5
		view.elevation = 0.45
		view.set_zoom(0.72)
		for tick: int in range(4): await frame()
		var point: Vector3 = view.weathering.bounds.get_center()
		var pixel: Vector2 = project(view,point)
		var surface: Dictionary = view.pick_body_surface(pixel)
		check(not surface.is_empty(), id+" picks actual geometry")
		var before: Dictionary = view.weathering.snapshot()
		view.set_wash_mode(true)
		mouse(view,pixel,true)
		view._process(0.05)
		check(view.wash_effect.mitt.visible and view.wash_effect.mitt.global_basis.y.dot(surface.normal) > 0.999, id+" actual contact animation")
		check(view.weathering.snapshot() != before, id+" still cleans actual condition")
		await frame()
		if id != "compact": await screenshot("washing-"+id)
		view.set_wash_mode(false)
		check(not view.wash_effect.visible, id+" Done clears feedback")
		view.queue_free()
		await frame()
