extends RefCounted
## The build tool and source-checkout guards use this same reviewed manifest.
## Unknown geometry inputs stay shared; generated outputs never feed their key.
const MANIFEST: String = "res://vehicle/prepared_asset_dependencies.json"
static var _manifest: Dictionary = {}
static var _file_hashes: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if value is Dictionary and value.get("schema","") == "prepared-asset-dependencies-1": _manifest = value
	return _manifest

static func vehicles_for(path: String) -> Array:
	var spec: Dictionary = manifest()
	if spec.is_empty(): return []
	for pattern: String in spec.excluded:
		if path.match(pattern): return []
	for rule: Dictionary in spec.rules:
		if path.match(rule.pattern): return rule.vehicles
	if path.begins_with("game/resources/cars/") and path.ends_with(".tres"):
		var id: String = path.get_file().get_basename()
		if id in spec.vehicles: return [id]
	if path.begins_with("game/vehicle/") or path.begins_with("game/assets/vehicles/") or path.begins_with("game/assets/liveries/") or path.begins_with("game/assets/fonts/") or path.begins_with("game/resources/") or path.match("game/track/*.gdshader") or path.match("game/track/*.gdshaderinc") or path == "godot-version.txt": return spec.vehicles
	return []

static func _files(directory: String, result: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(directory):
		if file.ends_with(".uid") or file.ends_with(".import"): continue
		result.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		if not child.begins_with("."): _files(directory.path_join(child),result)

static func hashes(id: String) -> Dictionary:
	var files: Array[String] = []
	# Only declared consumed mesh roots need source-checkout binary validation.
	# Old generated model revisions are not runtime inputs. Unknown inputs stay
	# shared in the build identity; the dependency audit checks builder references.
	for directory: String in ["res://vehicle","res://assets/liveries","res://assets/fonts","res://resources"]: _files(directory,files)
	var roots: Dictionary = {}
	for rule: Dictionary in manifest().get("rules",[]):
		if id not in rule.vehicles or not str(rule.pattern).begins_with("game/assets/vehicles/"): continue
		roots[str(rule.pattern).get_base_dir()] = true
	for directory: String in roots: _files("res://"+directory.trim_prefix("game/"),files)
	files.append("res://ui/garage_car_cache.gd")
	if id == "compact": files.append("res://ui/header_simple_cache.gd")
	for file: String in DirAccess.get_files_at("res://track"):
		if file.ends_with(".gdshader") or file.ends_with(".gdshaderinc"): files.append("res://track/"+file)
	files.sort()
	var result: Dictionary = {}
	for path: String in files:
		var relative: String = "game/"+path.trim_prefix("res://")
		if id in vehicles_for(relative):
			if not _file_hashes.has(path): _file_hashes[path] = FileAccess.get_sha256(path)
			result[relative] = _file_hashes[path]
	return result
