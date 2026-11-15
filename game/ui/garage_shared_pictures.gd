extends "res://ui/garage_preview_cache.gd"
## Garage uses the profile's exact texture. This adapter owns no capture or IO.
const Icons = preload("res://ui/header_car_icons.gd")
var records: LocalRecords
var header_cache: Node
var _views: Array[WeakRef] = []
var _requested: Dictionary = {}

func _ready() -> void:
	set_process(false)
	if is_instance_valid(header_cache): header_cache.changed.connect(_picture_changed)

func _process(_delta: float) -> void:
	set_process(false)

func identity(view: CarShowroom) -> String:
	if records == null: return ""
	return JSON.stringify([Icons.appearance_key(view.vehicle_id,records),view.livery,view.customisation]).sha256_text()

func shared_texture(view: CarShowroom) -> Texture2D:
	if records == null or view.livery != VehicleLivery.for_car(records.settings,view.vehicle_id) or view.customisation != VehicleCustomisation.for_car(records.settings,view.vehicle_id): return null
	return Icons.texture(view.vehicle_id,records)

func request(view: CarShowroom) -> void:
	var registered: bool = false
	for index: int in range(_views.size()-1,-1,-1):
		var current: Object = _views[index].get_ref()
		if not is_instance_valid(current): _views.remove_at(index)
		elif current == view: registered = true
	if not registered: _views.append(weakref(view))
	var key: String = identity(view)
	view.preview_key = key
	var picture: Texture2D = shared_texture(view)
	if picture != null:
		cache_hits += 1
		ready_pictures[view.vehicle_id] = {"key":key,"texture":picture}
		view.publish_preview(key,picture)
		_requested.erase(key)
	else:
		ready_pictures.erase(view.vehicle_id)
		view.displayed_key = ""
		view._image.texture = null
		view._placeholder.show()
		if records != null and is_instance_valid(header_cache) and not _requested.has(key):
			_requested[key] = true
			header_cache.request_pictures.call_deferred(records)

func _picture_changed(vehicle: String) -> void:
	if records == null or not is_instance_valid(header_cache) or header_cache.records != records: return
	for reference: WeakRef in _views.duplicate():
		var view: Object = reference.get_ref()
		if is_instance_valid(view) and view.vehicle_id == vehicle:
			view.livery = VehicleLivery.for_car(records.settings,vehicle)
			view.customisation = VehicleCustomisation.for_car(records.settings,vehicle)
			view.refresh_thumbnail()
	if records != null and Icons.ready(vehicle,records):
		var texture: Texture2D = Icons.texture(vehicle,records)
		ready_pictures[vehicle] = {"key":Icons.appearance_key(vehicle,records),"texture":texture}
	else: ready_pictures.erase(vehicle)

func warm_records(value: LocalRecords, _read_immediately: bool = true) -> void:
	if records != value:
		ready_pictures.clear()
		_requested.clear()
	records = value
	for vehicle: String in VehicleCatalog.IDS: _picture_changed(vehicle)
	if is_instance_valid(header_cache): header_cache.request_pictures(records)

func pictures_ready() -> bool:
	if records == null: return false
	for vehicle: String in VehicleCatalog.IDS:
		if not Icons.ready(vehicle,records): return false
	return true

func suspend_previews() -> void:
	set_process(false)
