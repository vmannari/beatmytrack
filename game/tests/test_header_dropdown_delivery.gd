extends SceneTree
const Icons = preload("res://ui/header_car_icons.gd")
var app: Node
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	Icons.customized.clear()
	var folder: String = "user://dropdown-delivery-"+TrackLibrary.unique_id()
	app = load("res://core/app.gd").new()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	var paints: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary = VehicleLivery.defaults(id)
		paint.colors.body = "ac5732"
		paints[id] = paint
	app.records.settings.vehicle_liveries = paints
	DirAccess.make_dir_recursive_absolute(folder)
	check(app.records.save_records()==OK,"save private custom appearances")
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(not app.online.configured,"private offline App")
	app.race_area_mode = "free"
	app._show_screen("tracks")
	var picker: MenuButton = app.account_button.get_node("MenuCarPicker")
	picker.show_popup()
	var deadline: int = Time.get_ticks_msec()+60000
	var next_report: int = 0
	while not app.header_car_cache.idle() and Time.get_ticks_msec()<deadline:
		app._publishing_slots_foreground = true
		app._garage_preloader.foreground = true
		if Time.get_ticks_msec()>next_report:
			next_report = Time.get_ticks_msec()+5000
			print("STATE ",app.header_car_cache._stage," jobs=",app.header_car_cache._jobs.size()," permitted=",app._header_car_capture_allowed("compact")," captures=",app.header_car_cache.captures)
		await process_frame
	check(app.header_car_cache.idle(),"all dropdown pictures finish with popup open")
	for row: int in range(picker.get_popup().item_count):
		var id: String = VehicleCatalog.IDS[picker.get_popup().get_item_id(row)]
		check(Icons.ready(id,app.records) and picker.get_popup().get_item_icon(row)==Icons.texture(id,app.records),"exact saved dropdown picture "+id)
	picker.get_popup().hide()
	# Simulate eviction by later saved designs without changing current records.
	# Opening must demand the current designs again even with an idle worker.
	Icons.customized.clear()
	var captures_before: int = app.header_car_cache.captures
	if "--old-demand" in OS.get_cmdline_user_args(): picker.request_pictures = Callable()
	picker.show_popup()
	deadline = Time.get_ticks_msec()+15000
	while not app.header_car_cache.idle() and Time.get_ticks_msec()<deadline:
		app._publishing_slots_foreground = true
		await process_frame
	for row: int in range(picker.get_popup().item_count):
		var id: String = VehicleCatalog.IDS[picker.get_popup().get_item_id(row)]
		check(Icons.ready(id,app.records) and picker.get_popup().get_item_icon(row)==Icons.texture(id,app.records),"reopened dropdown recovers evicted picture "+id)
	check(app.header_car_cache.captures==captures_before,"evicted pictures reuse exact disk files without rendering")
	picker.get_popup().hide()
	var other := LocalRecords.new(folder.path_join("other.json"))
	Icons.customized.clear()
	app.header_car_cache.request_pictures(other)
	check(app.header_car_cache.idle(),"stale picker owner cannot request current account pictures")
	app.queue_free()
	for tick: int in range(12): await process_frame
	print("HEADER_DROPDOWN_DELIVERY failures=",failures)
	quit(1 if failures else 0)
