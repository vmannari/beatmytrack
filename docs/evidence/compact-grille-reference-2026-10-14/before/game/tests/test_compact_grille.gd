extends SceneTree
## Real cooling aperture, closed fabricated parts, source/bake and retained fit.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func intersects(mesh: Mesh, from: Vector3, to: Vector3) -> bool:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	if indices.is_empty():
		for index: int in range(points.size()): indices.append(index)
	for triangle: int in range(0,indices.size(),3):
		if Geometry3D.segment_intersects_triangle(from,to,points[indices[triangle]],points[indices[triangle+1]],points[indices[triangle+2]])!=null: return true
	return false
func valid_part(key: String, mesh: ArrayMesh) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var finite: bool = true
	var outward: bool = true
	var edges: Dictionary = {}
	for index: int in range(vertices.size()):
		var p: Vector3 = vertices[index]
		finite = finite and is_finite(p.x) and is_finite(p.y) and is_finite(p.z) and absf(normals[index].length()-1)<0.001
	for index: int in range(0,indices.size(),3):
		var a: Vector3 = vertices[indices[index]]
		var b: Vector3 = vertices[indices[index+1]]
		var c: Vector3 = vertices[indices[index+2]]
		var face: Vector3 = (b-a).cross(c-a)
		outward = outward and face.length_squared()>1e-18 and face.dot(normals[indices[index]]+normals[indices[index+1]]+normals[indices[index+2]])<0
		for pair: Array in [[a,b],[b,c],[c,a]]:
			var first: String = str(Vector3i((pair[0]*1000000.0).round()))
			var second: String = str(Vector3i((pair[1]*1000000.0).round()))
			var edge: String = first+"/"+second if first<second else second+"/"+first
			edges[edge] = int(edges.get(edge,0))+1
	check(finite,key+" finite unit normals")
	check(outward,key+" winding and normals agree without collapsed faces")
	if key!="FrontGrilleCooling":
		var closed: bool = true
		for count: int in edges.values(): closed = closed and count==2
		check(closed,key+" welded edges close the actual surround/slats/hardware")
	return indices.size()/3
func _run() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	var car := CarVisual.new()
	car.batch_parts = false
	root.add_child(car)
	check(car.rolling_wheels.size()==4 and car.front_wheels.size()==2,"four independent original wheels")
	var grille_triangles: int = 0
	for key: String in CompactGrille.meshes:
		grille_triangles += valid_part(key,CompactGrille.meshes[key])
	check(grille_triangles<1600,"bounded grille detail: "+str(grille_triangles))
	var shell: ArrayMesh = CompactCoachwork.meshes.front_coachwork
	var fascia: MeshInstance3D
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh.get_aabb().size.x>1.5 and absf(part.mesh.get_aabb().position.y-0.660)<0.0001: fascia = part
	check(fascia!=null,"actual front fascia found")
	for y: float in [0.733,0.772,0.811,0.850,0.890]:
		for x: float in [-0.20,-0.08,0.0,0.08,0.20]:
			var from := Vector3(x,y,-2.3)
			var to := Vector3(x,y,-1.9)
			check(not intersects(shell,from,to),"real opening through painted steel")
			if fascia!=null: check(not intersects(fascia.mesh,from,to),"real opening through dark fascia")
			check(not intersects(CompactGrille.meshes.FrontGrilleLouvers,from,to),"real air gap between solid slats")
			check(intersects(CompactGrille.meshes.FrontGrilleCooling,from,to),"radiator closes view into car interior")
	var bounds := AABB()
	for key: String in CompactGrille.meshes: bounds = bounds.merge((CompactGrille.meshes[key] as ArrayMesh).get_aabb()) if bounds.size!=Vector3.ZERO else (CompactGrille.meshes[key] as ArrayMesh).get_aabb()
	check(bounds.size.z>0.13,"visible fabricated depth exceeds 13cm")
	check(bounds.position.x>=-0.2811 and bounds.end.x<=0.2811,"grille clears inner headlight envelopes")
	check(bounds.position.y>0.672 and bounds.end.y<0.918,"grille fits fascia and clears bumper/hood")
	var baked: Dictionary = CompactCoachwork.meshes.duplicate()
	CompactCoachwork.use_baked = false
	CompactCoachwork.meshes.clear()
	var source := CarVisual.new()
	source.batch_parts = false
	root.add_child(source)
	for key: String in baked: check(var_to_bytes((baked[key] as ArrayMesh).surface_get_arrays(0))==var_to_bytes((CompactCoachwork.meshes[key] as ArrayMesh).surface_get_arrays(0)),"exact source/bake "+key)
	var simple := CarVisual.new()
	simple.batch_parts = false
	simple.simple_model = true
	root.add_child(simple)
	var simple_source: ArrayMesh = CompactCoachwork.meshes.front_coachwork_simple
	var simple_baked: ArrayMesh = load(RacingCarModels.COACH_ROOT.path_join("front_coachwork_simple.res"))
	check(var_to_bytes(simple_source.surface_get_arrays(0))==var_to_bytes(simple_baked.surface_get_arrays(0)),"simple front exact source/bake")
	for key: String in CompactGrille.meshes:
		check((car.body.get_node(key) as MeshInstance3D).mesh==(simple.body.get_node(key) as MeshInstance3D).mesh,"full/simple share immutable crafted grille "+key)
	var wear := VehicleWeathering.new()
	wear.configure(car,"pine",VehicleCatalog.config("compact"))
	var condition: Dictionary = wear.snapshot()
	condition.dirt = 0.55
	wear.restore(condition)
	for key: String in CompactGrille.meshes:
		var finish: ShaderMaterial = (car.body.get_node(key) as MeshInstance3D).material_override as ShaderMaterial
		check(finish!=null,"local condition binds actual grille "+key)
		if finish!=null: check(finish.get_shader_parameter("rear_only")==0.0,"front grille receives the original whole-body condition scope "+key)
	wear.reset()
	for key: String in CompactGrille.meshes: check((car.body.get_node(key) as MeshInstance3D).material_override is StandardMaterial3D,"clean reset restores original grille finish "+key)
	var cache = preload("res://vehicle/prepared_car_cache.gd")
	cache.enabled = true
	cache.entries.clear()
	var first := CarVisual.new()
	root.add_child(first)
	var prior_hits: int = cache.hits
	var restored := CarVisual.new()
	root.add_child(restored)
	check(cache.hits==prior_hits+1,"ordinary stock car restores its prepared template")
	var restored_wear := VehicleWeathering.new()
	restored_wear.configure(restored,"pine",VehicleCatalog.config("compact"))
	restored_wear.restore(condition)
	var tagged_bindings: int = 0
	for binding: Dictionary in restored_wear.bindings:
		if binding.source.get_meta("compact_grille_finish",false)!=true: continue
		tagged_bindings += 1
		check(binding.finish.get_shader_parameter("rear_only")==0.0,"prepared restoration preserves actual grille condition scope")
	check(tagged_bindings==3,"prepared material copies retain all three grille finishes")
	var state := VehicleState.new()
	state.steering = 0.3
	var before: Array = state.snapshot()
	car.present(Vector2.ZERO,0,state,DriveFrame.new())
	check(state.snapshot()==before,"cosmetic grille does not write canonical state")
	for model: CarVisual in [car,source,simple,first,restored]: model.queue_free()
	await process_frame
	print("COMPACT_GRILLE: %d checks, %d failures; %d grille triangles"%[checks,failures,grille_triangles])
	quit(1 if failures else 0)
