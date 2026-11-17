extends SceneTree
const D = preload("res://vehicle/car_detail_reduction.gd")
const S = preload("res://vehicle/car_surface_reduction.gd")
const OUT = "res://../docs/evidence/volt-front-door-2026-11-17"
const WORK = "res://../build/volt-front-door-2026-11-17"
var raw: Dictionary = {}
var post: Dictionary = {}

static func selected(label: String) -> bool:
	var name: String = label.trim_suffix("_simple").trim_suffix("_fitted_v2").replace("_", ".")
	for prefix: String in ["ReferenceFrontSideGlass", "ReferenceRearSideGlass", "ReferenceBPillar"]:
		if name.begins_with(prefix): return true
	if name.begins_with("RefHandle"): return not name.contains("0.86")
	return name in ["ReferenceDoorSeam-1.01", "ReferenceDoorSeam1.01", "ReferenceWindowDoorJoin-1.01", "ReferenceWindowDoorJoin1.01"]

func key(group: Dictionary) -> String:
	var codes: Array = []
	for entry: Dictionary in group.entries:
		if not selected(str(entry.part.name)): codes.append(entry.code)
	codes.sort()
	return var_to_bytes(codes).hex_encode().sha256_text()

func detail(group: Dictionary) -> void:
	var data: Dictionary = D.recipe("electric", group.code).duplicate(true)
	for entry: Dictionary in group.entries:
		assert(not selected(str(entry.part.name)) or not data.get("parts", {}).has(entry.code), "Changed door parts have no hidden-face replacement")
	raw[key(group)] = {"context": group.code, "recipe": data}
	D.apply_group(group)

func surface(group: Dictionary) -> void:
	var path: String = S.ROOT.path_join("electric_" + group.code + ".json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"schema": S.SCHEMA, "context": group.code, "parts": {}}
	var retained: Dictionary = data.duplicate(true)
	var removed: Array = []
	for entry: Dictionary in group.entries:
		if selected(str(entry.part.name)) and retained.parts.has(entry.code):
			removed.append({"name": str(entry.part.name), "row": retained.parts[entry.code]})
			retained.parts.erase(entry.code)
	post[key(group)] = {"context": group.code, "recipe": retained, "changed_rows": removed}
	S.apply_group(group, D)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	D.offline = detail
	S.offline = surface
	for editable: bool in [false, true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.editable_kits = editable
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		car.free()
		await process_frame
	FileAccess.open(OUT.path_join("frame-registry.json"), FileAccess.WRITE).store_string(JSON.stringify({"raw": raw, "post": post}, "  "))
	print("VFD_REGISTRY ", raw.size(), " raw / ", post.size(), " post frames")
	quit()
