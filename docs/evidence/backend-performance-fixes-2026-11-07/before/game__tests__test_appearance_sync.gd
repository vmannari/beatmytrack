extends SceneTree
const Sync = preload("res://backend/appearance_sync.gd")
const State = preload("res://persistence/appearance_state.gd")
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var directory: String

class FakeClient extends Node:
	var player: Dictionary = {"id":"alice"}
	var online: bool = true
	var available: bool = true
	var saved: Dictionary = {}
	var delay_put: bool = false
	var delay_get: bool = false
	var lost: bool = false
	var puts: int = 0
	func signed_in() -> bool: return online
	func base_url() -> String: return "http://fixture.invalid"
	func request_api(_path: String, method: int = 0, body: Dictionary = {}, _key: String = "", auth: bool = false) -> Dictionary:
		if not auth or not available: return {"ok":false,"status":503,"data":{}}
		var result: Dictionary
		if method == HTTPClient.METHOD_GET:
			result = {"ok":true,"status":200,"data":{"appearances":saved.duplicate(true)}}
			while delay_get: await get_tree().process_frame
		else:
			puts += 1
			var value: Dictionary = body.appearance.duplicate(true)
			var current: Variant = saved.get(value.vehicle_id)
			if current != value and current != body.previous: return {"ok":false,"status":409,"data":{}}
			saved[value.vehicle_id] = value
			result = {"ok":true,"status":200,"data":value}
			while delay_put: await get_tree().process_frame
			if lost:
				lost = false
				return {"ok":false,"status":0,"data":{}}
		return result

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func store(name: String) -> LocalRecords:
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
	value.livery.stickers.hood = {"id":LiveryCatalog.stickers[0].id,"x":0.12,"y":0.86,"size":0.71,"rotation":-73.0}
	if id == "compact": value.customisation.body = "wide"
	State.apply(records.settings,value)
	check(records.save_records() == OK,"atomic paint/parts commit "+id)

func run() -> void:
	directory = "user://appearance_sync_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var fake := FakeClient.new()
	root.add_child(fake)
	var a: LocalRecords = store("device-a")
	var b: LocalRecords = store("device-b")
	for id: String in VehicleCatalog.IDS: edit(a,id,"c94026")
	a.settings.selected_car = "kart"
	check(a.save_records() == OK,"selected car local setting")
	var sa: Node = sync_for(a,fake)
	await sa.refresh()
	check(fake.saved.size() == VehicleCatalog.IDS.size(),"all authored cars upload without opening Rivalry")
	var sb: Node = sync_for(b,fake)
	await sb.refresh()
	for id: String in VehicleCatalog.IDS:
		check(State.car(a.settings,id) == State.car(b.settings,id),"other device restores exact design "+id)
	check(not b.settings.has("selected_car") and not b.settings.has("vehicle_conditions"),"device preferences and condition excluded")
	var writes: int = fake.puts
	await sb.refresh()
	check(fake.puts == writes,"clean fresh device never uploads defaults")
	edit(b,"pickup","123456")
	await sb.refresh()
	await sa.refresh()
	check(State.car(a.settings,"pickup").livery.colors.body == "123456","running first device downloads edits")
	# Independent cars are retained when both devices edit offline.
	edit(a,"compact","abcdef")
	edit(b,"kart","fedcba")
	await sb.refresh()
	await sa.refresh()
	await sb.refresh()
	check(State.car(b.settings,"compact").livery.colors.body == "abcdef" and State.car(a.settings,"kart").livery.colors.body == "fedcba","independent car edits merge")
	# The older offline car cannot overwrite a newer accepted online car.
	edit(a,"pickup","111111")
	edit(b,"pickup","222222")
	await sb.refresh()
	await sa.refresh()
	check(State.car(a.settings,"pickup").livery.colors.body == "222222","same-car conflict retains accepted online value")
	fake.available = false
	edit(a,"formula","333333")
	await sa.refresh()
	check(not sa.status.is_empty(),"offline save retains retry status")
	sa.free()
	a = store("device-a")
	sa = sync_for(a,fake)
	fake.available = true
	await sa.refresh()
	check(fake.saved.formula.livery.colors.body == "333333","restart retries persisted local edit against original baseline")
	fake.lost = true
	edit(a,"classic","444444")
	await sa.refresh()
	check(fake.saved.classic.livery.colors.body == "444444" and not sa.status.is_empty(),"lost reply retains committed remote write")
	await sa.refresh()
	check(sa.status.is_empty() and State.baseline(a.settings).classic == fake.saved.classic,"lost reply recovery acknowledges exact remote car")
	fake.lost = true
	edit(a,"classic","454545")
	await sa.refresh()
	edit(a,"classic","464646")
	sa.free()
	a = store("device-a")
	sa = sync_for(a,fake)
	await sa.refresh()
	check(sa.status.is_empty() and fake.saved.classic.livery.colors.body == "464646","lost reply plus newer local edit survives restart without a false conflict")
	# A local edit while a write is pending must remain dirty after acknowledgement.
	fake.delay_put = true
	edit(a,"kart","555555")
	sa.refresh()
	await process_frame
	check(sa.busy,"write delayed")
	edit(a,"kart","666666")
	fake.delay_put = false
	await process_frame
	check(State.car(a.settings,"kart").livery.colors.body == "666666","late acknowledgement preserves new local edit")
	await sa.refresh()
	check(fake.saved.kart.livery.colors.body == "666666","new local edit uploads after acknowledgement")
	edit(a,"classic","778899")
	await create_timer(1.0).timeout
	check(fake.saved.classic.livery.colors.body == "778899","local commit automatically schedules debounced sync")
	edit(a,"formula","8899aa")
	sa._debounce.stop()
	var original_path: String = a.path
	fake.delay_put = true
	sa.refresh()
	await process_frame
	a.path = directory.path_join("blocked-records")
	DirAccess.make_dir_recursive_absolute(a.path)
	fake.delay_put = false
	await process_frame
	check(not sa.status.is_empty() and State.car(a.settings,"formula").livery.colors.body == "8899aa","failed acknowledgement save retains last committed local edit")
	a.path = original_path
	await sa.refresh()
	check(sa.status.is_empty() and State.baseline(a.settings).formula == fake.saved.formula,"retry recovers failed acknowledgement storage")
	# Fresh device with legacy defaults adopts server data before any upload.
	var legacy: LocalRecords = store("legacy")
	edit(legacy,"compact","000000")
	var sl: Node = sync_for(legacy,fake)
	writes = fake.puts
	await sl.refresh()
	check(fake.puts == writes and State.car(legacy.settings,"compact") == fake.saved.compact,"first adoption preserves existing server appearance")
	# A response from another identity or origin can never touch the new profile.
	fake.delay_get = true
	sa.refresh()
	await process_frame
	var other: LocalRecords = store("bob")
	fake.player.id = "bob"
	sa.bind_records(other)
	fake.delay_get = false
	await process_frame
	check(not sa.busy and other.settings.is_empty(),"late old-account read is fenced")
	fake.online = false
	sa.bind_records(other)
	await sa.refresh()
	check(other.settings.is_empty(),"guest does not import or upload account cars")
	# Wire and local recovery validation reject malformed/unbounded cars.
	check(Client.valid_response("/me/appearances",HTTPClient.METHOD_GET,{"appearances":fake.saved}),"wire accepts exact catalog appearance")
	for invalid: Variant in [null,[],{"compact":{}},{"unknown":fake.saved.compact}]:
		check(not Client.valid_response("/me/appearances",HTTPClient.METHOD_GET,{"appearances":invalid}),"wire rejects malformed collection")
	var bad: Dictionary = State.car(a.settings,"compact")
	bad.livery.colors.body = "invalid"
	check(not Client.valid_response("/me/appearances",HTTPClient.METHOD_PUT,bad),"wire rejects invalid pigment")
	other.settings[State.KEY] = {"version":1,"baseline":{"compact":bad}}
	check(other.save_records() == ERR_INVALID_DATA and other.settings.is_empty(),"invalid sync recovery rolls back atomically")
	for node: Node in [sa,sb,sl,fake]: node.free()
	print("APPEARANCE_SYNC: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
