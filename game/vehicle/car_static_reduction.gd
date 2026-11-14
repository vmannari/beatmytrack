extends RefCounted
## Load offline-authored static reductions. Runtime never generates LOD indices.
const ROOT: String = "res://assets/vehicles/car_reduced_v1"
const IDS: Array[String] = ["compact","kart","electric","hovercraft"]
static var enabled: bool = true
static var offline: Callable
static var meshes: Dictionary = {}
static var hits: int = 0
const CACHE_LIMIT: int = 128

static func key(mesh: ArrayMesh) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for packet: Dictionary in mesh.get("_surfaces"):
		hash.update(var_to_bytes([packet.format,packet.primitive,packet.vertex_count,packet.get("index_count",0)]))
		for field: String in ["vertex_data","attribute_data","index_data"]:
			var data: PackedByteArray = packet.get(field,PackedByteArray())
			if not data.is_empty(): hash.update(data)
	return hash.finish().hex_encode()

static func resolve(source: ArrayMesh, id: String) -> ArrayMesh:
	var cache_key: String = id+"_"+key(source)
	if not meshes.has(cache_key):
		if meshes.size()>=CACHE_LIMIT: meshes.clear()
		var path: String = ROOT.path_join(cache_key+".res")
		meshes[cache_key] = load(path) if ResourceLoader.exists(path) else null
	if meshes[cache_key]!=null:
		hits+=1
		return meshes[cache_key]
	return source

static func apply(car: CarVisual, holders: Variant = null) -> void:
	if not enabled or not car.simple_model or not car.batch_parts or car.vehicle_id not in IDS: return
	var parts: Array = []
	if holders==null: parts=car.find_children("*","MeshInstance3D",true,false)
	else:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count()>0: continue
		if part.mesh.has_meta("car_reduction_source") or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if offline.is_valid():
			part.mesh = offline.call(part,car.vehicle_id)
			continue
		# Cache by content, never by a transient assembled mesh. A negative lookup
		# must not pin every old kit assembly for the lifetime of the process.
		part.mesh = resolve(part.mesh,car.vehicle_id)
