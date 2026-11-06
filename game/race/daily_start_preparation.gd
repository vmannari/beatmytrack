extends RefCounted
## One race tap owns two readiness stages: CPU geometry and fresh Daily limits.
## The loading cover owns this receipt; late reads cannot publish another start.
const KEY: StringName = &"daily_start_preparation"
const Event = preload("res://race/selected_event.gd")
var track: NativeTrack
var vehicle: String
var request: Dictionary
var geometry_ready: bool = false
var done: bool = false
var response: Dictionary = {}
var expires_msec: int = -1
var _cancelled: bool = false
var _app: WeakRef
var _client: WeakRef
var _session_generation: int
var _loading: WeakRef
var _scope: String
var _navigation: int
var _screen: String
var _selection: NativeTrack
var _identity: String
var _source: Array
var _content_hash: String
var _page: WeakRef
var _event_pin: Array

static func find(loading: Node) -> RefCounted:
	return loading.get_meta(KEY) if is_instance_valid(loading) and loading.has_meta(KEY) else null

static func begin(app: Node, value: NativeTrack, car: String, daily: Dictionary, loading: Node) -> RefCounted:
	var existing: RefCounted = find(loading)
	if existing != null:
		if not existing.matches(value,car,daily): existing.cancel()
		return existing
	var prepared = load("res://race/daily_start_preparation.gd").new()
	prepared.track = value
	prepared.vehicle = car
	prepared.request = daily.duplicate(true)
	prepared._app = weakref(app)
	prepared._client = weakref(app.online.client)
	prepared._session_generation = app.online.client._session_generation
	prepared._loading = weakref(loading)
	prepared._scope = app.lifecycle.scope()
	prepared._navigation = app._navigation_generation
	prepared._screen = app.screen
	prepared._selection = app.selected_track
	prepared._identity = value.identity
	prepared._source = Event.identity(value.metadata.get("cloud_entry",{}))
	prepared._content_hash = "" if value.metadata.get("metadata_only",false) else value.content_hash
	var event: Dictionary = app._selected_preparation_event
	if event.get("kind","") == "daily" and app._selected_preparation_track == value:
		prepared._page = event.page
		prepared._event_pin = event.pin.duplicate(true)
		prepared.expires_msec = int(event.expires)
	loading.set_meta(KEY,prepared)
	loading.tree_exiting.connect(prepared.cancel,CONNECT_ONE_SHOT)
	if prepared.valid(): _read(weakref(prepared),app.online.client,car,prepared.request,app.get_instance_id())
	else: prepared.done = true
	return prepared

func matches(value: NativeTrack, car: String, daily: Dictionary) -> bool:
	return track == value and vehicle == car and request == daily

func valid() -> bool:
	if _cancelled: return false
	var app: Object = _app.get_ref()
	var loading: Object = _loading.get_ref()
	if not is_instance_valid(app) or app.is_queued_for_deletion() or not app.is_inside_tree(): return false
	if not is_instance_valid(loading) or app.race_loading != loading: return false
	if app.online.client != _client.get_ref() or app.online.client._session_generation != _session_generation: return false
	if app.lifecycle.scope() != _scope or app._navigation_generation != _navigation or app.screen != _screen: return false
	if app.selected_track != _selection or VehicleCatalog.selected != vehicle: return false
	if track.identity != _identity or str(track.metadata.get("cloud_version","")) != str(request.get("version_id","")): return false
	if Event.identity(track.metadata.get("cloud_entry",{})) != _source: return false
	if not _content_hash.is_empty() and track.content_hash != _content_hash: return false
	if expires_msec >= 0 and Time.get_ticks_msec() >= expires_msec: return false
	if _page != null:
		var page: Object = _page.get_ref()
		if not is_instance_valid(page) or Event.pin(app,"daily",page) != _event_pin: return false
		if int(request.get("day",-1)) != int(_event_pin[0]): return false
	return true

func geometry_finished() -> void:
	if not valid() or track.metadata.get("metadata_only",false): return
	_content_hash = track.content_hash
	geometry_ready = true

func received(data: Dictionary, request_started: int) -> void:
	# Include the read's own wait conservatively as well as later CPU/render work.
	var deadline: int = request_started+maxi(0,int(data.get("ends_at",0))-int(data.get("server_now",0)))*1000
	expires_msec = deadline if expires_msec < 0 else mini(expires_msec,deadline)

func await_response(tree: SceneTree) -> Dictionary:
	while valid() and not done: await tree.process_frame
	return response if valid() and done and geometry_ready else {}

static func request_limits(client: Node, car: String, daily: Dictionary, owner_id: int) -> Dictionary:
	var path: String = "/track-of-the-day/limits?day=%d&version_id=%s&vehicle_id=%s" % [int(daily.get("day",-1)),str(daily.get("version_id","")).uri_encode(),car.uri_encode()]
	return await client.request_api(path,HTTPClient.METHOD_GET,{},"",true) if client.signed_in() else await client.request_public(path,owner_id)

static func _read(receipt: WeakRef, client: Node, car: String, daily: Dictionary, owner_id: int) -> void:
	var began: int = Time.get_ticks_msec()
	var result: Dictionary = await request_limits(client,car,daily,owner_id)
	var prepared: RefCounted = receipt.get_ref()
	if prepared == null or not prepared.valid(): return
	prepared.response = result.duplicate(true)
	if result.get("ok",false): prepared.received(result.get("data",{}),began)
	prepared.done = true

func cancel() -> void:
	_cancelled = true
	response = {}
