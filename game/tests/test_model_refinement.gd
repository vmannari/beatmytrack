extends SceneTree
## CMI01-CMI05: representation changes retain geometry, fit and live controls.
const OUT = "res://../docs/evidence/car-model-refinement-2026-11-12"
var checks: int = 0
var failures: int = 0
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("MODEL_REFINEMENT_FAIL ",label)
func bytes(mesh: ArrayMesh) -> int:
	var total: int = 0
	for packet: Dictionary in mesh.get("_surfaces"):
		for name: String in ["vertex_data","attribute_data","index_data","skin_data","blend_shapes"]: total += packet.get(name,PackedByteArray()).size()
		var levels: Array = packet.get("lods",[])
		for index: int in range(1,levels.size(),2): total += levels[index].size()
	return total
func run() -> void:
	var old: ArrayMesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var driver: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var helmet: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res")
	check(driver.get_surface_count()==2 and helmet.get_surface_count()==4,"six original material surfaces split into two deforming and four static")
	check(driver.get_blend_shape_count()==6 and helmet.get_blend_shape_count()==0,"six steering poses do not allocate helmet morph buffers")
	check(driver.get_faces().size()+helmet.get_faces().size()==old.get_faces().size(),"complete driver triangle count unchanged")
	check(bytes(old)-bytes(driver)-bytes(helmet)==495720,"exact 495720-byte native morph payload saving")
	for surface: int in range(6):
		var mesh: ArrayMesh = driver if surface<2 else helmet
		var slot: int = surface if surface<2 else surface-2
		var arrays: Array = mesh.surface_get_arrays(slot)
		var original: Array = old.surface_get_arrays(surface)
		for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_INDEX,Mesh.ARRAY_TEX_UV]: check(arrays[attribute]==original[attribute],"exact rest positions/topology/UVs surface "+str(surface)+" attribute "+str(attribute))
		check(mesh.surface_get_material(slot).resource_name==old.surface_get_material(surface).resource_name,"retained original native finish surface "+str(surface))
		if surface>=2: check(arrays==original,"all static helmet attributes exact "+str(surface))
		var finite: bool = true
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and normal.is_finite() and normal.length_squared()>0.95
		check(finite,"finite unit shading normals "+str(surface))
		if surface<2:
			var poses: Array[Array] = mesh.surface_get_blend_shape_arrays(slot)
			var old_poses: Array[Array] = old.surface_get_blend_shape_arrays(surface)
			for index: int in range(6): check(poses[index][Mesh.ARRAY_VERTEX]==old_poses[index][Mesh.ARRAY_VERTEX],"exact supported and moving pose positions "+str(surface)+"/"+str(index))
	var old_shadow: ArrayMesh = load(OUT+"/before/game/assets/vehicles/racing_simple_v1/hovercraft_shadow_0.res")
	var shadow: ArrayMesh = load("res://assets/vehicles/racing_simple_v1/hovercraft_shadow_0.res")
	check(shadow.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()<old_shadow.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(),"Hover shadow contains compact used positions")
	var seen: Dictionary = {}
	for index: int in shadow.surface_get_arrays(0)[Mesh.ARRAY_INDEX]: seen[index] = true
	check(seen.size()==shadow.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(),"every Hover shadow vertex is referenced")
	preload("res://vehicle/modular_car_base.gd").enabled = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		car.simple_model = true
		car.batch_parts = "--prepared" in OS.get_cmdline_user_args()
		root.add_child(car)
		while not car.model_ready: await process_frame
		var total: int = 0
		var surfaces: int = 0
		var buffer_bytes: int = 0
		var meshes: Dictionary = {}
		for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if part.mesh==null: continue
			if part.is_visible_in_tree() and part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				total += part.mesh.get_faces().size()/3
				surfaces += part.mesh.get_surface_count()
			if part.mesh is ArrayMesh and not meshes.has(part.mesh):
				buffer_bytes += bytes(part.mesh)
				meshes[part.mesh] = true
		check(total>10000 and total<55000,"bounded production geometry "+id)
		if id=="kart":
			var live: MeshInstance3D = car.find_child("TomkartDriver",true,false)
			var fixed: MeshInstance3D = live.find_child("HelmetStatic",true,false)
			check(fixed!=null and fixed.mesh.get_blend_shape_count()==0,"real car retains the static helmet under its live driver frame")
			check(fixed.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"static helmet retains a live shadow")
			var state := VehicleState.new()
			var frame := DriveFrame.new()
			for steering: float in [-1.0,0.0,1.0,0.0]:
				state.steering = steering
				state.tick += 1
				car.present(Vector2.ZERO,0,state,frame)
				check(fixed.transform==Transform3D.IDENTITY,"helmet position does not follow steering")
				var weight: float = 0
				for shape: int in range(6): weight += live.get_blend_shape_value(shape)
				check(is_equal_approx(weight,absf(steering)),"retained hand interpolation and exact centering")
		if id=="electric" and not car.batch_parts:
			for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				if not (str(part.name).begins_with("ReferenceDoorSeam") or str(part.name).begins_with("RefHandle") or str(part.name).begins_with("SportBonnetShutLine")): continue
				check(part.mesh.get_faces().size()>0,"nonempty fitted contour "+str(part.name))
				check(part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"flush contours do not self-shadow "+str(part.name))
		rows.append({"id":id,"triangles":total,"surfaces":surfaces,"array_mesh_bytes":buffer_bytes})
		car.free()
		await process_frame
	var file := FileAccess.open(OUT.path_join("prepared-measurements.json" if "--prepared" in OS.get_cmdline_user_args() else "direct-measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	file.close()
	print("MODEL_REFINEMENT ",checks," checks, ",failures," failures ",JSON.stringify(rows))
	quit(1 if failures else 0)
