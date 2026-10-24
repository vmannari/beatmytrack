extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Sync = preload("res://backend/appearance_sync.gd")
const State = preload("res://persistence/appearance_state.gd")
var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func records_for(name: String) -> LocalRecords:
	var value := LocalRecords.new(directory.path_join(name+".json"))
	value.load_records()
	return value

func sync_for(records: LocalRecords, client: Node) -> Node:
	var node: Node = Sync.new()
	node.client = client
	root.add_child(node)
	node.bind_records(records)
	return node

func edit(records: LocalRecords, id: String, colour: String) -> void:
	var value: Dictionary = State.car(records.settings,id)
	value.livery.colors.body = colour
	value.livery.pattern = "offset_gt"
	value.livery.stickers.hood = {"id":"crest","x":0.13,"y":0.77,"size":0.4,"rotation":123.0}
	if id == "compact": value.customisation = {"version":1,"hood":"scoop","aero":"wing","rims":"mesh","body":"wide"}
	State.apply(records.settings,value)
	check(records.save_records() == OK,"saved authored design "+id)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	directory = "user://appearance_http_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var first: Node = Client.new()
	var second: Node = Client.new()
	for node: Node in [first,second]:
		root.add_child(node)
		check(node.configure(OS.get_environment("BMT_API_URL")) == OK,"configured isolated HTTP service")
		var login: Dictionary = await node.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
		check(login.ok,"real independent authenticated session")
	check(first.player.id == second.player.id,"both device sessions belong to same account")
	var a: LocalRecords = records_for("a")
	for id: String in VehicleCatalog.IDS: edit(a,id,"c94026")
	var sa: Node = sync_for(a,first)
	await sa.refresh()
	check(sa.status.is_empty(),"first device uploads through real validated API")
	var b: LocalRecords = records_for("b")
	var sb: Node = sync_for(b,second)
	await sb.refresh()
	check(sb.status.is_empty(),"second device downloads through real validated API")
	for id: String in VehicleCatalog.IDS:
		check(State.car(a.settings,id) == State.car(b.settings,id),"all appearance fields restore exactly "+id)
	check(not b.settings.has("vehicle_conditions") and not b.settings.has("guest_coins") and not b.settings.has("selected_car"),"sync excludes dirt, money and device selection")
	edit(b,"pickup","abcdef")
	await sb.refresh()
	await sa.refresh()
	check(sa.status.is_empty() and State.car(a.settings,"pickup").livery.colors.body == "abcdef","live device restores second-device change")
	# Real API refuses a stale write and leaves other cars intact.
	var previous: Dictionary = State.car(a.settings,"pickup")
	edit(b,"pickup","aabbcc")
	await sb.refresh()
	var stale: Dictionary = previous.duplicate(true)
	stale.livery.colors.body = "000000"
	var rejected: Dictionary = await first.request_api("/me/appearances",HTTPClient.METHOD_PUT,{"appearance":stale,"previous":previous},"",true)
	check(not rejected.ok and rejected.status == 409,"real server rejects stale car compare-and-swap")
	await sa.refresh()
	check(State.car(a.settings,"pickup").livery.colors.body == "aabbcc","conflict re-read restores winning car")
	sa.free()
	a = records_for("a")
	sa = sync_for(a,first)
	await sa.refresh()
	check(sa.status.is_empty() and State.car(a.settings,"compact") == State.car(b.settings,"compact"),"restart baseline JSON retains integer wire versions")
	# The retained Garage's current model also receives a remote design.
	var garage := GaragePage.new()
	garage.records = a
	root.add_child(garage)
	MenuStyle.fill(garage)
	for i: int in range(3): await process_frame
	await capture("before-device-update")
	edit(b,"compact","224466")
	await sb.refresh()
	await sa.refresh()
	garage.refresh_cosmetics()
	check(garage.showroom.livery == VehicleLivery.for_car(a.settings,"compact") and garage.showroom.customisation == VehicleCustomisation.for_car(a.settings,"compact"),"retained live Garage presents restored paint and fitted parts")
	await capture("after-device-update")
	garage.free()
	# Exercise the actual sign-in composition, including its profile-owned shop.
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records.path = directory.path_join("guest.json")
	app.library = TrackLibrary.new(directory.path_join("guest-tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+15000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete,"actual app startup completes")
	await app.online.sign_in_developer()
	deadline = Time.get_ticks_msec()+10000
	while (app.appearance_sync.busy or app.screen == "restoring") and Time.get_ticks_msec() < deadline: await process_frame
	check(app.records != app.guest_records and app.cosmetic_economy.records == app.records and app.appearance_sync.records == app.records,"real sign-in binds sync and ownership to the account profile")
	await app.appearance_sync.refresh()
	check(State.car(app.records.settings,"compact") == State.car(b.settings,"compact"),"real signed-in app restores saved appearance")
	await app.online.sign_out()
	check(app.records == app.guest_records and app.cosmetic_economy.records == app.guest_records and app.appearance_sync.records == app.guest_records,"sign-out restores guest bindings")
	check(not app.guest_records.settings.has("vehicle_liveries"),"signed-out Guest never inherits account paint")
	deadline = Time.get_ticks_msec()+10000
	while app.screen == "restoring" and Time.get_ticks_msec() < deadline: await process_frame
	app.queue_free()
	for node: Node in [sa,sb,first,second]: node.queue_free()
	for i: int in range(20): await process_frame
	print("APPEARANCE_SYNC_HTTP: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func capture(name: String) -> void:
	var folder: String = OS.get_environment("BMT_APPEARANCE_CAPTURE")
	if folder.is_empty() or DisplayServer.get_name() == "headless": return
	for i: int in range(6): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"native screenshot "+name)
