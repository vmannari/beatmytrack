extends RefCounted
## Offline-authored coarse pieces. Never generate indices in a running game.
const ROOT: String = "res://assets/vehicles/car_coarse_v1"
const METRIC: float = 0.01
const IDS: Array[String] = ["compact","kart","forklift","electric","hovercraft","super_rally"]
const LIMIT: int = 256
static var enabled: bool = true
static var offline: Callable
static var meshes: Dictionary = {}
static var hits: int = 0

static func key(source: ArrayMesh, budget: float) -> String:
	return preload("res://vehicle/car_static_reduction.gd").key(source)+"_"+var_to_bytes(budget).hex_encode().sha256_text().left(12)

static func resolve(source: ArrayMesh, id: String) -> ArrayMesh:
	var code: String = id+"_"+key(source,METRIC)
	if not meshes.has(code):
		if meshes.size()>=LIMIT: meshes.clear()
		var path: String = ROOT.path_join(code+".res")
		meshes[code] = load(path) if ResourceLoader.exists(path) else null
	if meshes[code]!=null:
		hits+=1
		return meshes[code]
	return source

static func apply(car: CarVisual, holders: Variant = null) -> void:
	if not enabled or not car.simple_model or not car.batch_parts or car.vehicle_id not in IDS: return
	var parts: Array = car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count()>0 or part.mesh.has_meta("car_coarse_source"): continue
		if offline.is_valid():
			part.mesh = offline.call(part,car)
			continue
		var selected: ArrayMesh = resolve(part.mesh,car.vehicle_id)
		if selected!=part.mesh:
			var materials: Array[Material] = []
			if part.material_override==null:
				for surface: int in range(part.mesh.get_surface_count()): materials.append(part.get_active_material(surface))
			part.mesh = selected
			for surface: int in range(materials.size()): part.set_surface_override_material(surface,materials[surface])
