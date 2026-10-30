extends SceneTree
## Saved six-car appearances, read-only server recovery and actual Garage models.
const State = preload("res://persistence/appearance_state.gd")
const Sync = preload("res://backend/appearance_sync.gd")
var checks: int = 0
var failures: int = 0
var output: String
var expected: Dictionary = {}
var app: Node

class ReadOnlyServer extends Node:
	var player: Dictionary = {"id":"garage-recovery-fixture"}
	var appearances: Dictionary = {}
	var puts: int = 0
	func signed_in() -> bool: return true
	func base_url() -> String: return "https://garage-recovery.invalid"
	func request_api(_path: String, method: int = 0, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		if method != HTTPClient.METHOD_GET:
			puts += 1
			return {"ok":false,"status":503,"data":{}}
		return {"ok":true,"status":200,"data":{"appearances":appearances.duplicate(true)}}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)

func settle() -> void:
	await create_timer(0.8).timeout
	for _frame: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	create_timer(180).timeout.connect(func() -> void: print("FAIL: appearance recovery deadline"); quit(1))
	root.size = Vector2i(1280,720)
	var folder: String = "user://garage-appearance-recovery-"+TrackLibrary.unique_id()
	check(DirAccess.make_dir_recursive_absolute(folder) == OK,"create isolated fixture")
	var source := LocalRecords.new(folder.path_join("source.json"))
	source.load_records()
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		var value: Dictionary = State.car({},id)
		value.livery.colors.body = ["b52e36","2779ba","a64bce","e6b130","3b9c75","b86725"][index]
		value.livery.colors.accent = "f0e5c8"
		if id in ["compact","kart"]:
			value.livery.pattern = "offset_gt"
			value.livery.stickers.hood.id = LiveryCatalog.stickers[0].id
		if id == "compact": value.customisation.body = "wide"
		if id == "kart": value.customisation.merge({"hood":"enduro","aero":"blade","rims":"six","body":"wedge"},true)
		check(VehicleCustomisation.valid(value.customisation,id),"typed per-car validation "+id)
		check(VehicleCustomisation.valid(value.customisation),"typed unspecified-car validation "+id)
		State.apply(source.settings,value)
		expected[id] = State.normalized_car(value)
	check(source.save_records() == OK,"save all liveries and both car kits together")
	var reopened := LocalRecords.new(source.path)
	reopened.load_records()
	for id: String in VehicleCatalog.IDS:
		check(State.car(reopened.settings,id) == expected[id],"disk reload retains exact appearance "+id)
	var invalid: Dictionary = VehicleCustomisation.defaults()
	invalid.body = "wide"
	check(not VehicleCustomisation.valid(invalid,"kart"),"reject Compact-only kit on kart")
	check(not VehicleCustomisation.valid(invalid,"electric"),"reject non-stock kit on unsupported car")
	# Match the failure's empty local appearance state. Existing online designs
	# must download and commit without any upload of the default local cars.
	var recovered := LocalRecords.new(folder.path_join("recovered.json"))
	recovered.settings = {"music_enabled":false,"selected_car":"kart"}
	check(recovered.save_records() == OK,"save fixture with missing local appearances")
	var server := ReadOnlyServer.new()
	server.appearances = expected.duplicate(true)
	root.add_child(server)
	var sync: Node = Sync.new()
	sync.client = server
	root.add_child(sync)
	sync.bind_records(recovered)
	await sync.refresh()
	check(sync.status.is_empty(),"existing online appearances recover without sync errors")
	check(server.puts == 0,"recovery never uploads defaults")
	for id: String in VehicleCatalog.IDS:
		check(State.car(recovered.settings,id) == expected[id],"sync restores exact appearance "+id)
	await sync.refresh()
	check(server.puts == 0 and server.appearances == expected,"repeated refresh preserves remote designs")
	sync.free()
	server.free()
	var restarted := LocalRecords.new(recovered.path)
	restarted.load_records()
	for id: String in VehicleCatalog.IDS:
		check(State.car(restarted.settings,id) == expected[id],"recovered save survives another load "+id)
	# Construct the production App with the recovered local profile and no API.
	preload("res://backend/menu_snapshot_writer.gd").shared()
	app = load("res://core/app.tscn").instantiate()
	app.records = restarted
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	app._garage_preloader.idle_ms = 100000
	app._garage_preloader.foreground = true
	GameSoundtrack.instance().music_enabled = false
	GameSoundtrack.instance().menu_player.stop()
	if DisplayServer.get_name() != "headless":
		check(await app._prepare_garage_pictures(),"prepare all exact recovered carousel images")
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	check(page != null and page.cards.get_child_count() == VehicleCatalog.IDS.size(),"all six catalogue cards include kart")
	for index: int in range(VehicleCatalog.IDS.size()):
		var id: String = VehicleCatalog.IDS[index]
		page.preview_car(index)
		page.gallery.scroll_horizontal = index*page.tile_stride
		await settle()
		var car: CarVisual = page.showroom.car
		check(car != null and car.vehicle_id == id and car.model_ready,"main Garage model completes "+id)
		check(car.livery == expected[id].livery,"main Garage keeps saved paint and marks "+id)
		check(car.customisation == expected[id].customisation,"main Garage keeps saved parts "+id)
		var visible_meshes: int = 0
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if mesh.is_visible_in_tree() and mesh.mesh != null: visible_meshes += 1
		check(visible_meshes > 0,"Garage contains visible car geometry "+id)
		var thumbnail: CarShowroom = page.thumbnails[id]
		check(thumbnail.livery == expected[id].livery and thumbnail.customisation == expected[id].customisation,"carousel keeps exact saved appearance "+id)
		if DisplayServer.get_name() != "headless":
			check(thumbnail._image.texture != null and not thumbnail._placeholder.visible,"carousel displays recovered picture "+id)
		if id == "kart":
			check(car.rolling_wheels.size() == 4 and car.editable_kits,"visible fitted kart retains four wheels and editable parts")
		await capture(id)
	app.queue_free()
	for _frame: int in range(8): await process_frame
	var report: Dictionary = {"checks":checks,"failures":failures,"cars":VehicleCatalog.IDS,"rendering_method":RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GARAGE_APPEARANCE_RECOVERY: ",JSON.stringify(report))
	quit(1 if failures else 0)
