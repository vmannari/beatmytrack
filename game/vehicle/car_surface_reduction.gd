extends RefCounted
## CST02: separately reviewed, surface-preserving recipes after the opaque pass.
## Complete frame identity includes geometry, articulation, finish and shader code.
const ROOT: String="res://assets/vehicles/car_surface_v1"
const SCHEMA: String="car-surface-frame-1"
static var enabled: bool=true
static var offline: Callable
static var recipes: Dictionary={}
static var meshes: Dictionary={}
static var hits: int=0

static func permitted(entry: Dictionary) -> bool:
	var part: MeshInstance3D=entry.part
	if part.mesh is ArrayMesh and part.mesh.get_blend_shape_count()>0: return false
	# The driver's static suit is separate from the protected helmet and arms.
	if entry.protected and str(part.name)!="DriverStaticSuit": return false
	if part.mesh.get_meta("car_keep_master",false): return false
	if entry.opaque: return true
	var shaders: Dictionary=load("res://vehicle/car_surface_shader_allowlist.gd").HASHES
	for surface: int in range(part.mesh.get_surface_count()):
		var material: Material=part.get_active_material(surface)
		if not material is ShaderMaterial or material.shader==null: return false
		var path: String=material.shader.resource_path
		if not shaders.has(path) or material.shader.code.sha256_text()!=shaders[path]: return false
		if material.next_pass!=null: return false
	return true

static func apply_group(group: Dictionary, detail: GDScript) -> void:
	var key: String=group.vehicle+"_"+group.code
	if not recipes.has(key):
		if recipes.size()>=256: recipes.clear()
		var file: String=ROOT.path_join(key+".json")
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
		recipes[key]=value if value is Dictionary else {}
	var data: Dictionary=recipes[key]
	if data.get("schema","")!=SCHEMA or data.get("context","")!=group.code: return
	var changes: Array=[]
	for entry: Dictionary in group.entries:
		var row: Dictionary=data.get("parts",{}).get(entry.code,{})
		if row.is_empty(): continue
		if row.get("source","")!=entry.source or not permitted(entry): return
		var path: String=ROOT.path_join(row.get("mesh",""))
		if not path.begins_with(ROOT+"/") or not row.get("mesh","").is_valid_filename(): return
		if not meshes.has(path):
			if meshes.size()>=512: meshes.clear()
			meshes[path]=load(path) if ResourceLoader.exists(path) else null
		var mesh: Mesh=meshes[path]
		if mesh==null or mesh.get_meta("car_surface_source","")!=entry.source or detail.mesh_key(mesh)!=row.get("result",""): return
		if mesh.get_surface_count()!=entry.part.mesh.get_surface_count() or mesh.get_aabb()!=entry.part.mesh.get_aabb(): return
		changes.append([entry.part,mesh])
	# Every member is qualified before the first replacement.
	for change: Array in changes:
		preload("res://vehicle/car_budget_reduction.gd").swap(change[0],change[1])
		hits+=1

static func apply(car: CarVisual, holders: Variant, detail: GDScript) -> void:
	if not enabled or not car.simple_model or not car.batch_parts or car.vehicle_id not in ["compact","kart","forklift","electric"]: return
	for group: Dictionary in detail.groups(car,holders):
		if offline.is_valid(): offline.call(group)
		else: apply_group(group,detail)
