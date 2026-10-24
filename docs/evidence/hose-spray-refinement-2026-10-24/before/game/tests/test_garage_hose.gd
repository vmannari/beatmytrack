extends SceneTree
## Hose rates, both saved layers, native picking/input and bounded tool lifecycle.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/hose-wash-2026-10-24"
var page: GaragePage

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func peak(bytes: PackedByteArray) -> int:
	var value: int = 0
	for byte: int in bytes: value = maxi(value,byte)
	return value

func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	while page._menu_motion != null: await frame()
	for tick: int in range(8): await frame()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for tick: int in range(4): await frame()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	GameSoundtrack.instance().music_enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://hose_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		var effect := VehicleWeathering.new()
		effect.configure(car,"pine",VehicleCatalog.config(id))
		effect.dirt_amount = 0.9
		effect.slow_dirt_amount = 0.3
		effect.grime_age.fill(255)
		var dirty: Dictionary = effect.snapshot()
		var point: Vector3 = effect.bounds.position+effect.bounds.size*Vector3(0,0.8,0.6)
		effect.wash(point,0.8,"hose")
		var primary: PackedByteArray = effect.wash_image.get_data()
		var film: PackedByteArray = effect.slow_wash_image.get_data()
		check(peak(film)>100 and peak(primary)>0 and peak(primary)<5,id+" film rinses quickly, heavy grime very slowly")
		check(effect.dirt_amount == 0.9 and effect.slow_dirt_amount == 0.3,id+" hose preserves accumulated condition amounts")
		var grid: int = VehicleCondition.GRID
		var opposite: bool = true
		for y: int in range(grid):
			for z: int in range(grid):
				if primary[y*grid*grid+z*grid+grid-1] != 0 or film[y*grid*grid+z*grid+grid-1] != 0: opposite = false
		check(opposite,id+" opposite side untouched")
		effect.restore(dirty)
		effect.begin_wash_batch()
		for tick: int in range(80): effect.wash(point,0.01,"hose")
		effect.end_wash_batch()
		check(effect.wash_image.get_data() == primary and effect.slow_wash_image.get_data() == film,id+" equal-time split spray exact in both layers")
		var rinsed: Dictionary = effect.snapshot()
		check(VehicleCondition.save(records,id,rinsed) == OK,id+" save both hose masks")
		effect.restore(VehicleCondition.read(records,id))
		check(effect.snapshot() == rinsed,id+" reload hose progress exact")
		effect.restore(dirty)
		effect.wash(point,0.8)
		check(peak(effect.wash_image.get_data())>peak(primary)*20,id+" mitt remains much faster on heavy dirt")
		effect.restore(dirty)
		for tick: int in range(20): effect.wash(point,0.1,"hose")
		check(peak(effect.slow_wash_image.get_data()) == 255 and peak(effect.wash_image.get_data()) < 12,id+" sustained rinse finishes film while grime remains")
		var unchanged: Dictionary = effect.snapshot()
		effect.wash(point,-1,"hose")
		effect.wash(point,NAN,"hose")
		effect.wash(Vector3(NAN,0,0),1,"hose")
		effect.wash(point,1,"invalid")
		effect.wash(effect.bounds.end+Vector3.ONE*10,1,"hose")
		check(effect.snapshot() == unchanged,id+" invalid and distant spray inert")
		# Demonstrate that primary dirt does eventually wash away with water alone.
		effect.wash(point,90,"hose")
		check(peak(effect.wash_image.get_data()) == 255,id+" prolonged hose removes heavy dirt")
		effect.reset()
		car.free()
	root.size = Vector2i(1280,720)
	VehicleCatalog.selected = "compact"
	page = GaragePage.new()
	page.theme = MenuStyle.theme()
	page.records = records
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await settle()
	page._show_section("care")
	await settle()
	var view: CarShowroom = page.showroom
	view.set_process(false)
	var dirty: Dictionary = view.weathering.snapshot()
	dirty.dirt = 0.85
	dirty.slow_dirt = 0.35
	dirty.wash = ""
	dirty.slow_wash = ""
	view.weathering.restore(dirty)
	view.elevation = 0.93
	view.yaw = 0.3
	view.set_zoom(0.8)
	var livery: Dictionary = view.livery.duplicate(true)
	var parts: Dictionary = view.customisation.duplicate(true)
	var pose: Transform3D = view.camera.transform
	var hose_button: Button = page.preview.get_node("GarageWashTools/GarageWashHose")
	check(hose_button.is_visible_in_tree(),"care offers visible Hose action")
	hose_button.button_pressed = true
	hose_button.pressed.emit()
	check(view.wash_mode and view.wash_tool == "hose", "Hose action selects and activates rinsing")
	var effect: Node3D = view.wash_effect
	for panel: Vector3 in [Vector3(0,1.44,0.1),Vector3(0,0.88,-1.4)]:
		var pixel: Vector2 = view.camera.unproject_position(view.car.body.global_transform*panel)*view.size/Vector2(view.showroom_viewport.size)
		var surface: Dictionary = view.pick_body_surface(pixel)
		check(not surface.is_empty(),"actual hood/roof hit")
		if surface.is_empty(): continue
		var before: PackedByteArray = view.weathering.slow_wash_image.get_data()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = pixel
		press.pressed = true
		view.gui_input.emit(press)
		for tick: int in range(12): view._process(1.0/30.0)
		check(view.weathering.slow_wash_image.get_data() != before,"held mouse rinses actual hood/roof film")
		check(effect.hose != null and effect.hose.visible and effect.jet.visible and not effect.mitt.visible,"hose nozzle and water replace mitt")
		check(effect.foam_slots.all(func(slot: Dictionary) -> bool: return slot.is_empty()),"water creates no soap foam")
		check(effect.jet.multimesh.instance_count == 12 and effect.water.multimesh.instance_count == 32,"fixed spray and droplet pools")
		check(view.camera.transform == pose and view.livery == livery and view.customisation == parts,"rinse retains camera, livery and fitted parts")
		await capture("hose-roof" if panel.y > 1.0 else "hose-hood")
		press.pressed = false
		view.gui_input.emit(press)
		view._process(0.05)
		check(not effect.hose.visible and not effect.jet.visible,"release stops water stream")
		var touch := InputEventScreenTouch.new()
		touch.index = 4
		touch.position = pixel
		touch.pressed = true
		view.gui_input.emit(touch)
		view._process(0.05)
		check(view.washing and effect.hose.visible,"touch hold sprays")
		touch.canceled = true
		view.gui_input.emit(touch)
		check(not view.washing and not effect.visible,"touch cancellation clears hose")
	page._select_wash_tool("mitt")
	check(view.wash_tool == "mitt" and not view.washing and not effect.visible,"tool swap stops held gesture and effects")
	page._select_wash_tool("hose")
	var before_miss: Dictionary = view.weathering.snapshot()
	check(not view.wash_at(Vector2(-20,-20),0.1) and view.weathering.snapshot() == before_miss,"missing the car preserves both layers")
	view._process(0.05)
	check(not effect.visible,"off-car spray creates no hit effect")
	page._toggle_wash()
	check(not view.wash_mode and page.wash_button.text == "Wash","Done leaves wash mode")
	var saved := VehicleCondition.read(records,"compact")
	check(saved == view.weathering.snapshot(),"Done durably saves hose progress")
	check(records._conditions().flush() == OK,"hose progress flushes to local storage")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(VehicleCondition.read(reopened,"compact") == saved,"reopened local records retain both exact hose masks")
	var disk: Dictionary = preload("res://persistence/condition_store.gd")._read(records.path+".conditions.json")
	check(disk.get("conditions",{}).get("compact",{}) == JSON.parse_string(JSON.stringify(saved)),"independent disk read retains serialized hose condition")
	root.size = Vector2i(800,480)
	await settle()
	for name: String in ["GarageWashMitt","GarageWashHose"]:
		var button: Control = page.preview.get_node("GarageWashTools/"+name)
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),name+" fits narrow landscape")
	await capture("hose-tools-narrow")
	page._show_section("cars")
	await settle()
	check(not page.preview.get_node("GarageWashTools").visible and not effect.visible,"navigation hides hose controls and effects")
	page.queue_free()
	await frame()
	print("Garage hose: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
