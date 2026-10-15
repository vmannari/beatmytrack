extends SceneTree
## Independent geometry permits exact triangle bounds for the complete catalog.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/compact-kits-expanded-2026-10-14"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func triangles(car: CarVisual) -> int:
	var count: int = 0
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			count += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	return count
func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	CompactKits.use_baked = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	CompactKits.meshes.clear()
	var report: Array[Dictionary] = []
	for simple: bool in [false,true]:
		var base := CarVisual.new()
		base.simple_model = simple
		root.add_child(base)
		var stock_count: int = triangles(base)
		var wash := VehicleWeathering.new()
		wash.configure(base,"pine",VehicleCatalog.config("compact"))
		var bounds: AABB = wash.bounds
		base.queue_free()
		await process_frame
		var changes: Dictionary = {}
		var maximum: Dictionary = VehicleCustomisation.defaults()
		for category: String in VehicleCustomisation.CATEGORIES:
			check(VehicleCustomisation.OPTIONS[category].size()==(13 if category=="aero" else 10),"complete distinct "+category+" choices")
			changes[category] = []
			var best: int = -2147483648
			var ids: Dictionary = {}
			for option: Array in VehicleCustomisation.OPTIONS[category]:
				check(not ids.has(option[0]),"unique stable ID "+category+"/"+str(option[0]))
				ids[option[0]] = true
				var car := CarVisual.new()
				car.simple_model = simple
				car.customisation = VehicleCustomisation.defaults()
				car.customisation[category] = option[0]
				root.add_child(car)
				var delta: int = triangles(car)-stock_count
				changes[category].append(delta)
				if delta>best:
					best = delta
					maximum[category] = option[0]
				check(car.rolling_wheels.size()==4 and car.front_wheels.size()==2,"original four articulated wheels")
				car.queue_free()
				await process_frame
		var largest: int = 0
		var total: int = 0
		for h: int in changes.hood:
			for a: int in changes.aero:
				for r: int in changes.rims:
					for b: int in changes.body:
						largest = maxi(largest,stock_count+h+a+r+b)
						total += 1
		check(total==13000 and largest<170000,"all 13,000 combinations retain the triangle budget "+str(largest))
		var combined := CarVisual.new()
		combined.simple_model = simple
		combined.customisation = maximum
		root.add_child(combined)
		check(triangles(combined)==largest,"independent sum equals real maximum combined geometry")
		var tuned_wash := VehicleWeathering.new()
		tuned_wash.configure(combined,"pine",VehicleCatalog.config("compact"))
		check(tuned_wash.bounds.is_equal_approx(bounds),"original local wash coordinates retained")
		var points := PackedVector3Array()
		for mesh: MeshInstance3D in combined.find_children("*","MeshInstance3D",true,false):
			var transform: Transform3D = combined.global_transform.affine_inverse()*mesh.global_transform
			for point: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: points.append(transform*point)
		for index: int in range(24):
			var state := VehicleState.new()
			state.roll_ticks = maxi(1,VehicleSimulation.ROLL_DURATION_TICKS-index*VehicleSimulation.ROLL_DURATION_TICKS/24)
			state.roll_direction = 1
			var snapshot: Array = state.snapshot()
			combined.position = Vector3.ZERO
			combined.rotation = Vector3.ZERO
			combined.present_roll(state)
			var low: float = INF
			for point: Vector3 in points: low = minf(low,(combined.transform*point).y)
			check(low>=-0.003 and state.snapshot()==snapshot,"maximum fitted model roll clearance and canonical invariance")
		report.append({"simple":simple,"stock_triangles":stock_count,"max_triangles":largest,"max_options":maximum,"combinations":total})
		combined.queue_free()
		await process_frame
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CompactKits.ASSET_ROOT.path_join("manifest.json")))
	check(CompactKits.meshes.size()==manifest.meshes.size() and CompactKits.meshes.size()<1400,"complete bounded cache independent of combinations")
	for key: String in CompactKits.meshes:
		var arrays: Array = (CompactKits.meshes[key] as ArrayMesh).surface_get_arrays(0)
		check(manifest.meshes.has(key) and digest(var_to_bytes(arrays))==manifest.meshes[key].surface_sha256,"prepared data equals actual source builder "+key)
		if key.begins_with("body6/") and "/arch" in key:
			var axle: float = -1.28 if "/-1.28" in key else 1.28
			var outside: bool = true
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var radius: float = Vector2(point.y-0.37,point.z-axle).length()
				var original: float = CompactCoachwork.body_width(point.y,point.z)+CompactKits.arch_roll(radius,axle)
				if absf(point.x)<original+0.007: outside = false
			check(outside,"extension clears the actual rolled fender "+key)
	var directory: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("catalog.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"mesh_count":CompactKits.meshes.size(),"levels":report},"\t"))
	file.close()
	print("EXPANDED_COMPACT_CATALOG: %d checks, %d failures; cache=%d"%[checks,failures,CompactKits.meshes.size()])
	quit(1 if failures else 0)
