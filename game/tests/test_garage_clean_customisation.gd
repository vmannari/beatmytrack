extends SceneTree
## Actual local Garage: dirty mutation guards, exterior washing and saved unlock.
var checks: int = 0
var failures: int = 0
var output: String

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	await create_timer(0.4).timeout
	for index: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func wash_exterior(page: GaragePage, save: bool = true) -> void:
	var effect: VehicleWeathering = page.showroom.weathering
	# A real stroke makes the lazy exterior inspection necessary.
	effect.wash(Vector3(-0.9,0.5,0.1),0.1)
	page._cleanliness.is_clean(page.showroom)
	check(not page._cleanliness.points.is_empty(),"actual native exterior samples prepared")
	effect.begin_wash_batch()
	for point: Vector3 in page._cleanliness.points: effect.wash(point,8.0)
	effect.end_wash_batch()
	if save: page._save_condition()

func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	var renderer: String = RenderingServer.get_current_rendering_method()
	if DisplayServer.get_name() == "headless": renderer = "headless"
	output = ProjectSettings.globalize_path("res://../docs/evidence/garage-wash-forgiving-2026-10-18/"+renderer)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://clean_customisation_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	var dirty: Dictionary = VehicleWeathering.new().snapshot()
	dirty.dirt = 0.85
	dirty.slow_dirt = 0.25
	check(VehicleCondition.save(records,"compact",dirty) == OK,"seed isolated dirt")
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.theme = MenuStyle.theme()
	var page := GaragePage.new()
	page.records = records
	root.add_child(page)
	MenuStyle.fill(page)
	page.open_car(0)
	await settle()
	var car: CarVisual = page.showroom.car
	var camera: Transform3D = page.showroom.camera.transform
	var paint: Dictionary = page.draft.duplicate(true)
	var kits: Dictionary = page.kit_draft.duplicate(true)
	var saved: Dictionary = records.settings.duplicate(true)
	check(page._customisation_locked and page.livery_menu == null,"dirty Customise shows requirement instead of editing controls")
	check(page._wash_requirement.visible and page._wash_requirement.tooltip_text.contains("dirty"),"compact wash notice explains the cleanliness requirement")
	check(not page.tools_panel.visible and page.customise_layout==null,"dirty car does not open or reserve a workbench sidebar")
	for name: String in ["GarageTopView","GarageZoomIn","GarageZoomOut","GarageResetView"]:
		check(page.find_child(name,true,false)==null,"view button removed: "+name)
	for action: Callable in [page._select_livery.bind(2),page._preview_color.bind(Color.RED,"body"),page._choose_sticker.bind(1),page._move_sticker.bind(Vector2(0.2,0.2)),page._sticker_property.bind(0.8,"size"),page._centre_sticker,page._reset]:
		action.call()
		check(page.draft == paint and records.settings == saved,"dirty livery/colour/sticker/reset callback cannot change or save appearance")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		var button: Control = page.preview.find_child("GarageWashForCustomisation",true,false)
		check(page.preview.get_global_rect().encloses(page._wash_requirement.get_global_rect()) and root.get_visible_rect().encloses(button.get_global_rect()),"wash overlay fits "+str(dimensions))
		check(page._wash_requirement.size.y<=80 and not page.tools_panel.visible,"wash notice stays compact without a sidebar")
		await capture("wash-required-livery-"+str(dimensions.x))
	page._show_section("tuning")
	await settle()
	check(page._customisation_locked and page.tools.find_child("GarageResetKits",true,false) == null,"dirty kits cannot be edited")
	page._select_kit("hood","scoop")
	page._reset_kits()
	check(page.kit_draft == kits and records.settings == saved,"kit selection and reset cannot change dirty car")
	await capture("wash-required-kits")
	await click(page.preview.find_child("GarageWashForCustomisation",true,false))
	check(page.section == "care" and page.showroom.wash_mode,"Wash car opens actual manual washing")
	check(not page.tools_panel.visible and not page._wash_requirement.visible,"washing hides the requirement without a sidebar")
	check(page._wash_status_panel.visible and page._wash_status_panel.tooltip_text == "Wash the exterior before customising","wash view explains when more washing is needed")
	check(page._wash_status_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE and page._wash_status.mouse_filter == Control.MOUSE_FILTER_IGNORE and page._wash_status_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE,"status does not intercept wash gestures")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,720)]:
		root.size = dimensions
		await settle()
		check(page.preview.get_global_rect().encloses(page._wash_status_panel.get_global_rect()),"wash status fits preview "+str(dimensions))
		check(not page._wash_status_panel.get_global_rect().intersects(page.preview.get_node("GarageViewControls").get_global_rect()),"wash status clears view controls "+str(dimensions))
		await capture("needs-washing-"+str(dimensions.x))
	page.showroom.weathering.wash(Vector3(-0.9,0.5,0.1),0.5)
	page._show_section("customise")
	check(page._customisation_locked,"one clean patch does not unlock dirty car")
	check(page.showroom.car == car and page.showroom.camera.transform == camera,"blocked changes retain actual car and camera")
	page._show_section("care")
	page._toggle_wash()
	var before_live_wash: Dictionary = VehicleCondition.read(records,"compact")
	wash_exterior(page,false)
	page._process(0.0)
	check(page._cleanliness.is_clean(page.showroom),"scrubbing native exterior unlocks car")
	check(page.showroom.wash_mode and page._wash_status.text == "Shiny. For now.","shiny indication updates during washing without pressing Done")
	check(page._wash_status_icon.texture == MenuIcon.texture("check") and page._wash_status.get_theme_color("font_color") == MenuStyle.POSITIVE,"ready state uses a checkmark and positive colour")
	check(VehicleCondition.read(records,"compact") == before_live_wash,"live indication does not save or clear dirt")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,720)]:
		root.size = dimensions
		await settle()
		check(page.preview.get_global_rect().encloses(page._wash_status_panel.get_global_rect()),"ready status fits preview "+str(dimensions))
		check(not page._wash_status.text.contains("%") and not page._wash_status.text.contains("0"),"ready indication is nonnumeric")
		await capture("clean-enough-"+str(dimensions.x))
	check(page.showroom.weathering.wash_image.get_data().count(0) > 0,"inaccessible interior voxels do not require washing")
	page._show_section("customise")
	check(not page._wash_status_panel.visible,"wash status stays in the care view")
	check(not page._customisation_locked and page.livery_menu != null,"clean car exposes original livery workbench")
	page._select_livery(2)
	page._preview_color(Color("417585"),"body")
	page._choose_sticker(1)
	page._move_sticker(Vector2(0.35,0.55))
	page._save()
	check(page.draft != paint and VehicleLivery.for_car(records.settings,"compact") == page.draft,"washed car can change and save livery colours and stickers")
	page._show_section("tuning")
	page._select_kit("hood",str(VehicleCustomisation.OPTIONS.hood[1][0]))
	check(page.kit_draft != kits,"washed car can fit kits")
	await settle()
	await capture("clean-kits-unlocked")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	var restored_paint: Dictionary = VehicleLivery.for_car(reopened.settings,"compact")
	check(restored_paint.colors == page.draft.colors and restored_paint.pattern == page.draft.pattern and restored_paint.stickers.hood.id == page.draft.stickers.hood.id and is_equal_approx(restored_paint.stickers.hood.x,page.draft.stickers.hood.x) and VehicleCustomisation.for_car(reopened.settings,"compact") == page.kit_draft,"appearance persists on restart")
	var restored_condition: Dictionary = VehicleCondition.read(reopened,"compact")
	var washed_condition: Dictionary = page.showroom.weathering.snapshot()
	check(restored_condition.wash == washed_condition.wash and restored_condition.slow_wash == washed_condition.slow_wash and is_equal_approx(restored_condition.dirt,washed_condition.dirt) and is_equal_approx(restored_condition.slow_dirt,washed_condition.slow_dirt),"washing remains separate and local")
	# New race wear must fence a retained workbench before the next frame.
	page._show_section("customise")
	var washed_paint: Dictionary = page.draft.duplicate(true)
	check(VehicleCondition.save(records,"compact",dirty) == OK,"new race deposits persisted")
	page._select_livery(3)
	check(page._customisation_locked and page.draft == washed_paint,"retained dirty workbench locks after race")
	for id: String in VehicleCatalog.IDS:
		page._show_section("cars")
		page.open_car(VehicleCatalog.IDS.find(id))
		check(VehicleCondition.save(records,id,dirty) == OK,"seed "+id)
		page._process(0.0)
		page._show_section("customise")
		check(page._customisation_locked,id+" dirty livery blocked")
		check(not page.tools_panel.visible and page._wash_requirement.visible,id+" uses the compact wash overlay")
		if id=="forklift":
			await settle()
			await capture("forklift-wash-required-overlay")
		wash_exterior(page)
		page._show_section("customise")
		check(not page._customisation_locked,id+" actual exterior wash unlocks")
		var snow: Dictionary = dirty.duplicate(true)
		snow.dirt = 0.0
		snow.slow_dirt = 0.0
		snow.snow = 0.8
		check(VehicleCondition.save(records,id,snow) == OK,"seed snow "+id)
		page._process(0.0)
		check(page._customisation_locked,id+" snowy car requires cleaning")
		var trace: Dictionary = VehicleWeathering.new().snapshot()
		trace.dirt = 0.005
		check(VehicleCondition.save(records,id,trace) == OK,"seed trace dirt "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" trace dirt does not require spot hunting")
		trace.dirt = 0.04
		check(VehicleCondition.save(records,id,trace) == OK,"seed faint film "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" faint remaining film is acceptable")
		trace.dirt = 0.08
		trace.slow_dirt = 0.08
		check(VehicleCondition.save(records,id,trace) == OK,"seed overlapping faint layers "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" faint layers no longer add up to a false lock")
		page._show_section("care")
		check(page._wash_status.text == "Clean for most people.",id+" care indication agrees with faint-film customisation")
		var faint_condition: Dictionary = page.showroom.weathering.snapshot()
		page._show_section("customise")
		page._preview_color(Color("49798a"),"body")
		page._save()
		check(VehicleLivery.for_car(records.settings,id).colors.body == "49798a" and page.showroom.weathering.snapshot() == faint_condition,id+" faint-film painting saves without removing dirt")
		trace.dirt = 0.0
		trace.slow_dirt = 0.15
		check(VehicleCondition.save(records,id,trace) == OK,"seed faint slow film "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" slow film uses its softer rendered strength")
		trace.slow_dirt = 0.4
		check(VehicleCondition.save(records,id,trace) == OK,"seed heavy slow film "+id)
		page._process(0.0)
		check(page._customisation_locked,id+" heavy slow film still blocks")
		trace.slow_dirt = 0.0
		trace.dirt = 0.15
		check(VehicleCondition.save(records,id,trace) == OK,"seed noticeable film "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" light unwashed film no longer requires spot hunting")
		var leftover: Dictionary = dirty.duplicate(true)
		var faint_mask := PackedByteArray()
		faint_mask.resize(VehicleCondition.CELLS)
		faint_mask.fill(232)
		leftover.wash = Marshalls.raw_to_base64(faint_mask)
		leftover.slow_wash = leftover.wash
		check(VehicleCondition.save(records,id,leftover) == OK,"seed washed car with faint interpolation residue "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" broad faint wash residue no longer needs further scrubbing")
		page._show_section("care")
		check(page._wash_status_panel.tooltip_text == "Ready to customise",id+" washed-film indicator agrees with gate")
		if id == "compact":
			await settle()
			await capture("faint-residue-clean-enough")
		check(VehicleCondition.save(records,id,dirty) == OK,"seed new race wear during care "+id)
		page._process(0.0)
		check(page._wash_status_panel.tooltip_text == "Wash the exterior before customising",id+" new race wear revokes ready indication")
		page._show_section("customise")
		# Leave a real dirty interpolation cell on an otherwise washed exterior.
		var bounds: AABB = page.showroom.weathering.bounds
		var sample: Vector3 = page._cleanliness.points[0]
		var cell := Vector3i(((sample - bounds.position) / bounds.size * 15.0).floor().clamp(Vector3.ZERO,Vector3.ONE * 14.0))
		var mask := PackedByteArray()
		mask.resize(VehicleCondition.CELLS)
		mask.fill(255)
		for z: int in range(2):
			for y: int in range(2):
				for x: int in range(2): mask[(cell.y+y)*256+(cell.z+z)*16+cell.x+x] = 0
		var speck: Dictionary = dirty.duplicate(true)
		speck.wash = Marshalls.raw_to_base64(mask)
		speck.slow_wash = speck.wash
		check(VehicleCondition.save(records,id,speck) == OK,"seed small missed exterior patch "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" small missed dirty patch is accepted")
		var tolerated_condition: Dictionary = page.showroom.weathering.snapshot()
		page._preview_color(Color("417585"),"body")
		page._save()
		check(page.draft.colors.body == "417585" and page.showroom.weathering.snapshot() == tolerated_condition,id+" tolerated dirt permits edits without removing dirt")
		if id == "compact":
			page._select_livery(3)
			check(VehicleLivery.for_car(records.settings,id).pattern == page._preset_value(3).pattern,"small missed patch permits saved livery selection")
			await settle()
			await capture("small-missed-patch-customisation-allowed")
			page._show_section("tuning")
			page._select_kit("aero","lip")
			check(VehicleCustomisation.for_car(records.settings,id).aero == "lip","small missed patch permits saved kit selection")
			check(page.showroom.weathering.snapshot().wash == tolerated_condition.wash,"fitting kit retains tolerated dirt")
			await settle()
			await capture("small-missed-patch-kits-allowed")
			page._show_section("customise")
		# A broad unwiped half of the car must still be rejected.
		mask.fill(255)
		for z: int in range(16):
			for y: int in range(16):
				for x: int in range(8): mask[y*256+z*16+x] = 0
		speck.wash = Marshalls.raw_to_base64(mask)
		speck.slow_wash = speck.wash
		check(VehicleCondition.save(records,id,speck) == OK,"seed broadly missed dirt "+id)
		page._process(0.0)
		check(page._customisation_locked,id+" a broadly dirty car still blocks edits")
		var wet: Dictionary = VehicleWeathering.new().snapshot()
		wet.wetness = 1.0
		check(VehicleCondition.save(records,id,wet) == OK,"seed clean wet "+id)
		page._process(0.0)
		check(not page._customisation_locked,id+" clean wet car may customise")
	# Follow one actual washing session through every nonnumeric label.
	page._show_section("cars")
	page.open_car(0)
	page._show_section("care")
	page.showroom.finish_car_transition()
	if not page.showroom.wash_mode: page._toggle_wash()
	var labels: Array[String] = []
	var coat: Dictionary = VehicleWeathering.new().snapshot()
	coat.dirt = 1.0
	coat.snow = 1.0
	coat.slow_dirt = 1.0
	coat.slow_snow = 1.0
	var progressive := PackedByteArray()
	progressive.resize(VehicleCondition.CELLS)
	for strength: int in range(0,256,8):
		progressive.fill(strength)
		coat.wash = Marshalls.raw_to_base64(progressive)
		coat.slow_wash = coat.wash
		VehicleCondition.save(records,"compact",coat)
		page._process(0.0)
		var label: String = page._wash_status.text
		check(page._wash_status_icon.texture == MenuIcon.texture("check" if page._cleanliness.is_clean(page.showroom) else "care"),"label and editing gate agree during progressive washing")
		if label in labels: continue
		labels.append(label)
		for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
			root.size = dimensions
			await settle()
			check(page.preview.get_global_rect().encloses(page._wash_status_panel.get_global_rect()),"graded status fits preview "+str(dimensions))
			check(page._wash_status.size.x >= page._wash_status.get_minimum_size().x,"graded label is not clipped")
			await capture(label.to_snake_case().replace(".","")+"-"+str(dimensions.x))
	check(labels == ["There is a car under there. Maybe.","I can tell the color now","OK in the dark","Clean for most people.","Shiny. For now."],"all five humorous grades appear in washing order")
	page.queue_free()
	await process_frame
	var report: Dictionary = {"checks":checks,"failures":failures,"renderer":renderer,"phone_test":false}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("Garage clean customisation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
