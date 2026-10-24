extends SceneTree
const Economy = preload("res://backend/cosmetic_economy.gd")
const Sync = preload("res://backend/appearance_sync.gd")
const State = preload("res://persistence/appearance_state.gd")
var checks: int = 0
var failures: int = 0

class Peer extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"alice"}
	var online: bool = true
	var puts: int = 0
	func signed_in() -> bool: return online
	func base_url() -> String: return "http://fixture.invalid"
	func request_api(_path: String, method: int = 0, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		if method == HTTPClient.METHOD_GET: return {"ok":true,"status":200,"data":{"appearances":{}}}
		puts += 1
		return {"ok":false,"status":403,"error":"COSMETIC_NOT_OWNED","data":{}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	var directory: String = "user://security_ownership_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var value: Dictionary = State.car(records.settings,"compact")
	value.livery.pattern = "offset_gt"
	value.customisation.body = "wide"
	State.apply(records.settings,value)
	records.settings.cosmetic_legacy = ["livery/offset_gt","kit/compact/body/wide"]
	check(records.save_records() == OK,"existing local design saved")
	var peer := Peer.new()
	root.add_child(peer)
	var economy: Node = Economy.new()
	economy.records = records
	economy.client = peer
	root.add_child(economy)
	check(not economy.owns("livery/offset_gt") and not economy.owns("kit/compact/body/wide"),"signed-in account ignores client legacy assertions")
	economy.wallet = {"owned":["livery/offset_gt"]}
	check(economy.owns("livery/offset_gt") and not economy.owns("kit/compact/body/wide"),"account ledger grants only exact owned item")
	peer.online = false
	check(economy.owns("livery/offset_gt") and economy.owns("kit/compact/body/wide"),"offline historical cosmetics retained")
	peer.online = true
	var sync: Node = Sync.new()
	sync.client = peer
	root.add_child(sync)
	sync.bind_records(records)
	await sync.refresh()
	check(peer.puts == 1 and not sync.busy,"ownership denial ends current upload")
	check(sync.status == "This design includes items not owned by this account.","ownership denial explains account requirement")
	check(State.car(records.settings,"compact") == value,"rejected upload retains local design")
	check(State.pending(records.settings).get("compact") == value,"rejected upload remains recoverable")
	var reloaded := LocalRecords.new(records.path)
	reloaded.load_records()
	check(State.car(reloaded.settings,"compact") == value and State.pending(reloaded.settings).get("compact") == value,"local design and pending edit survive restart")
	sync.free()
	economy.free()
	peer.free()
	print("SECURITY_OWNERSHIP: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
