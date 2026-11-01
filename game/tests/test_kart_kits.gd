extends SceneTree
## Per-car admission, independent native assemblies and the actual Garage equip flow.
const Shop = preload("res://persistence/cosmetic_catalog.gd")
const State = preload("res://persistence/appearance_state.gd")
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-variety-2026-10-29/native"
var metrics: Array[Dictionary] = []
var page: GaragePage

class FixtureEconomy extends Node:
	signal changed
	var scope: String = "kart-kit-fixture"
	var busy: bool = false
	var pending: Dictionary = {}
	var status: String = ""
	var locked: bool = false
	func authenticated() -> bool: return false
	func owns(id: String) -> bool: return not locked or preload("res://persistence/cosmetic_catalog.gd").free_item(id)
	func balance() -> int: return 0
	func price(id: String) -> int: return int(preload("res://persistence/cosmetic_catalog.gd").items().get(id,0))
	func refresh() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	for frame: int in range(18): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	if DisplayServer.get_name()!="headless": check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native capture "+label)

func tap(control: Control) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = control.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch,true)
	await process_frame
	touch = touch.duplicate()
	touch.pressed = false
	root.push_input(touch,true)
	await settle()

func signature(node: Node3D) -> String:
	var parts: Array[int] = []
	var inverse: Transform3D = node.global_transform.affine_inverse()
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			var transform: Transform3D = inverse*mesh.global_transform
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			for triangle: int in range(faces.size()/3):
				var vertices: Array[Vector3] = []
				for corner: int in range(3): vertices.append((transform*faces[triangle*3+corner]).snapped(Vector3.ONE*0.00001))
				vertices.sort()
				parts.append(hash(vertices))
	parts.sort()
	return str(parts).sha256_text()

func geometry(car: CarVisual) -> Dictionary:
	var triangles: int = 0
	var finite: bool = true
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		triangles += mesh.mesh.get_faces().size()/3
		for surface: int in range(mesh.mesh.get_surface_count()):
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: finite = finite and point.is_finite()
	return {"triangles":triangles,"finite":finite}

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var defaults: Dictionary = VehicleCustomisation.defaults()
	for category: String in VehicleCustomisation.CATEGORIES:
		check(VehicleCustomisation.options(category,"kart").size()==(9 if category in ["hood","body"] else 8),"kart choices "+category)
		for option: Array in VehicleCustomisation.options(category,"kart"):
			var value: Dictionary = defaults.duplicate(true)
			value[category] = option[0]
			check(VehicleCustomisation.valid(value,"kart"),"kart schema "+category+"/"+str(option[0]))
			check(not VehicleCustomisation.description(category,str(option[0]),"kart").is_empty(),"kart description")
			var item: String = "kit/kart/"+category+"/"+str(option[0])
			check(Shop.free_item(item) if option[0]=="stock" else Shop.items().get(item)==750,"kart ownership identity "+item)
			var compact_ids: Array = VehicleCustomisation.options(category,"compact").map(func(item: Array) -> String: return str(item[0]))
			if option[0] not in compact_ids: check(not VehicleCustomisation.valid(value,"compact"),"Compact rejects kart-only part")
	check(VehicleCustomisation.valid_collection({"compact":defaults,"kart":defaults}),"independent compact/kart saves")
	check(not VehicleCustomisation.valid_collection({"pickup":defaults}),"unsupported saved kits rejected")
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.editable_kits = true
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var wheels: Array = car.rolling_wheels.duplicate()
		var positions: Array = car.wheel_rest_positions.duplicate()
		var tyres: Array[Mesh] = []
		for wheel: Node3D in car.rolling_wheels: tyres.append(wheel.find_child("SlickTyre",true,false).mesh)
		var stock_signature: String = signature(car)
		var stock_wear := VehicleWeathering.new()
		stock_wear.configure(car,"pine",VehicleCatalog.config("kart"))
		print("KART_STOCK_WASH_BOUNDS: ",stock_wear.bounds)
		stock_wear.reset()
		for category: String in VehicleCustomisation.CATEGORIES:
			var seen: Array[String] = []
			for option: Array in VehicleCustomisation.options(category,"kart"):
				var before: Dictionary = {}
				for other: String in VehicleCustomisation.CATEGORIES:
					if other!=category: before[other] = car.kit_frames[other].duplicate()
				var value: Dictionary = car.customisation.duplicate(true)
				value[category] = option[0]
				car.graphics.restore_originals()
				car.change_kit_parts(value)
				check(car.rolling_wheels==wheels and car.wheel_rest_positions==positions,"retains exact axles/rotors")
				for index: int in range(4): check(wheels[index].find_child("SlickTyre",true,false).mesh==tyres[index],"retains exact tyre")
				for other: String in before: check(car.kit_frames[other]==before[other],"retains unchanged "+other)
				var identity: String = signature(car)
				check(identity not in seen,"distinct actual geometry "+category+"/"+str(option[0]))
				seen.append(identity)
				var info: Dictionary = geometry(car)
				info.merge({"simple":simple,"category":category,"option":option[0]})
				metrics.append(info)
				check(info.finite and info.triangles<120000,"bounded finite kart")
			car.graphics.restore_originals()
			car.change_kit_parts(defaults)
		check(signature(car)==stock_signature,"reset restores exact stock geometry")
		var fitted: Dictionary = defaults.duplicate(true)
		fitted.merge({"hood":"enduro","aero":"blade","rims":"six","body":"wedge"},true)
		car.change_kit_parts(fitted)
		var fitted_wear := VehicleWeathering.new()
		fitted_wear.configure(car,"pine",VehicleCatalog.config("kart"))
		check(fitted_wear.bounds.is_equal_approx(stock_wear.bounds),"saved wash coordinates survive fitted kits")
		fitted_wear.reset()
		var other := CarVisual.new()
		other.vehicle_id = "kart"
		other.simple_model = simple
		other.editable_kits = true
		other.batch_parts = false
		other.customisation = fitted
		root.add_child(other)
		while not other.model_ready: await process_frame
		check(signature(car)==signature(other),"fresh race assembly matches independent Garage replacement")
		other.customisation = defaults
		check(preload("res://vehicle/prepared_car_cache.gd").key_for(car)!=preload("res://vehicle/prepared_car_cache.gd").key_for(other),"fitted rest-pose identity")
		other.free()
		car.free()
		await process_frame
	if "--geometry-only" not in OS.get_cmdline_user_args(): await garage()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("KART_KITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func garage() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	VehicleCatalog.selected = "kart"
	var folder: String = "res://../build/kart-variety/local/"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	var holder := MarginContainer.new()
	holder.theme = MenuStyle.theme()
	root.add_child(holder)
	MenuStyle.fill(holder)
	var economy := FixtureEconomy.new()
	root.add_child(economy)
	page = GaragePage.new()
	page.records = records
	page.economy = economy
	holder.add_child(page)
	MenuStyle.fill(page)
	page.open_car(VehicleCatalog.IDS.find("kart"))
	page._show_section("tuning")
	await settle()
	check(page.showroom.car.editable_kits,"kart enters editable showroom")
	var retained_car: CarVisual = page.showroom.car
	var retained_viewport: SubViewport = page.showroom.showroom_viewport
	for category: String in VehicleCustomisation.CATEGORIES:
		await tap(page.kit_categories[category])
		check(page.kit_category==category and page.kit_cards.get_child_count()==(9 if category in ["hood","body"] else 8),"touch selects kart category "+category)
		check(page.kit_categories[category].text.nocasecmp_to(VehicleCustomisation.label(category,"kart"))==0,"kart category label")
		for index: int in range(1,8):
			var before: Dictionary = page.kit_draft.duplicate(true)
			page.kit_scroll.ensure_control_visible(page.kit_cards.get_child(index))
			await settle()
			await tap(page.kit_cards.get_child(index))
			var option: String = str(VehicleCustomisation.options(category,"kart")[index][0])
			check(page.showroom.car.customisation[category]==option,"touch previews "+category+"/"+option)
			check(page.kit_draft==before,"preview does not equip or save")
			page._equip_cosmetic_preview()
			await settle()
			check(page.kit_draft[category]==option,"equip commits "+category+"/"+option)
			var reopened := LocalRecords.new(records.path)
			reopened.load_records()
			check(VehicleCustomisation.for_car(reopened.settings,"kart")==page.kit_draft,"atomic kit reload")
			check(page.showroom.car==retained_car and page.showroom.showroom_viewport==retained_viewport,"retains actual car and viewport")
			await capture(category+"-"+option)
		await capture("tuning-"+category)
	var appearance: Dictionary = State.car(records.settings,"kart")
	check(State.valid_car(appearance),"fitted kart appearance is admitted for sync")
	var restored: Dictionary = {}
	State.apply(restored,appearance)
	check(VehicleCustomisation.for_car(restored,"kart")==page.kit_draft,"synced kart retains kits")
	var before: Dictionary = page.kit_draft.duplicate(true)
	var path: String = records.path
	records.path = folder.path_join("missing/records.json")
	page._select_kit("hood","stock")
	check(page.kit_draft==before and page.showroom.car.customisation==before,"failed save restores exact installed kits")
	records.path = path
	economy.locked = true
	page._preview_kit(page.kit_category,"sprint")
	page._equip_cosmetic_preview()
	await settle()
	check(is_instance_valid(page._purchase_dialog),"unowned kart kit opens purchase confirmation")
	if is_instance_valid(page._purchase_dialog):
		check(page._purchase_dialog.item_id=="kit/kart/body/sprint","purchase uses exact kart item")
		page._purchase_dialog.cancel_button.pressed.emit()
		await settle()
	check(page.kit_draft==before,"cancelled purchase leaves saved kit exact")
	economy.locked = false
	page._cancel_cosmetic_preview()
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		check(page.tools_panel.get_global_rect().end.x<=dimensions.x+1,"workbench fits "+str(dimensions))
		await capture("tuning-"+str(dimensions.x))
	page.open_car(VehicleCatalog.IDS.find("compact"))
	page._show_section("tuning")
	await settle()
	check(page.showroom.car.vehicle_id=="compact" and page.kit_cards.get_child_count()==10,"Compact kit choices preserved")
	page.open_car(VehicleCatalog.IDS.find("kart"))
	page._show_section("tuning")
	await settle()
	check(page.showroom.car.editable_kits and page.kit_draft==before,"return to kart restores exact installed choices")
	var game: Node = load("res://core/game.tscn").instantiate()
	game.preference_records = records
	game.vehicle_id = "kart"
	game.initial_track = NativeTrack.read("res://resources/tracks/ellipse.json")
	game.production_mode = true
	root.add_child(game)
	while game.car==null or not game.car.model_ready: await process_frame
	game.set_physics_process(false)
	check(game.car.customisation==before,"actual race loads the equipped kart kits")
	check(game.handling.snapshot()==VehicleCatalog.config("kart").snapshot(),"race keeps exact canonical kart handling")
	game.ghost_mode = "race"
	game.ghost_bests.race = {}
	game._prepare_personal_ghost()
	check(game.personal_ghost!=null and game.personal_ghost.mesh!=null,"race ghost retains fitted kart geometry")
	game.free()
	await process_frame
	page._reset_kits()
	await settle()
	check(page.kit_draft==VehicleCustomisation.defaults(),"kart reset restores Original")
	await capture("tuning-original")
	for locale: String in ["fi","de"]:
		TranslationServer.set_locale(locale)
		page._show_section("customise")
		page._show_section("tuning")
		await capture("tuning-"+locale)
		for category: String in VehicleCustomisation.CATEGORIES:
			var source: String = VehicleCustomisation.label(category,"kart")
			check(not str(TranslationServer.get_translation_object(locale).get_message(source)).is_empty(),"packaged kart category translation "+locale)
	TranslationServer.set_locale("en")
	holder.free()
	economy.free()
	await process_frame
