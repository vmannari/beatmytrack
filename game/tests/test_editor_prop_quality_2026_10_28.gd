extends SceneTree
const BATCHES = preload("res://editor/placed_object_batches.gd")
const BYTES = preload("res://editor/cache_bytes.gd")
const COSTS = preload("res://editor/creator_prop_costs.gd")
var checks: int = 0
var failures: int = 0
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: ",message)

func baseline(file: String, global_name: String) -> GDScript:
	var path: String = "res://../docs/evidence/editor-ux-improvements-2026-10-28/before/game/track/"+file
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace("\r\n","\n").replace("class_name "+global_name+"\n","")
	check(script.reload() == OK,"exact task-start "+file+" compiles independently")
	return script

func geometry(kind: String, previous: bool, structures: GDScript, visual: GDScript, kit: NativeTrackVisual) -> ArrayMesh:
	var tool: SurfaceTool = PropGeometry.model()
	if kind == "cliff":
		if previous: visual._cliff(tool,kit,Vector3.ZERO,Vector3(8,4,3),0.0,Color("98937e"))
		else: CreatorPropVisual._cliff(tool,kit,Vector3.ZERO,Vector3(8,4,3),0.0,Color("98937e"))
	elif previous: structures.append(tool,kit,kind,Vector3.ZERO,1.0,0.0,true)
	else: PropStructures.append(tool,kit,kind,Vector3.ZERO,1.0,0.0,true)
	return PropGeometry.finish(tool)

func run() -> void:
	var structures: GDScript = baseline("prop_structures.gd","PropStructures")
	var visual: GDScript = baseline("creator_prop_visual.gd","CreatorPropVisual")
	var kit := NativeTrackVisual.new(); kit.theme_id = "pine"; kit.colors = TrackTheme.palette("pine"); kit.editor_preview = true
	root.add_child(kit)
	for kind: String in ["parked_car","van","car_wreck","cliff","hut","shed","grandstand"]:
		var old: ArrayMesh = geometry(kind,true,structures,visual,kit)
		var current: ArrayMesh = geometry(kind,false,structures,visual,kit)
		var before: AABB = old.get_aabb(); var after: AABB = current.get_aabb()
		check(after.position.x >= before.position.x-0.001 and after.end.x <= before.end.x+0.001 and after.position.z >= before.position.z-0.001 and after.end.z <= before.end.z+0.001,kind+" retains its original horizontal envelope")
		check(after.position.y >= before.position.y-0.001 and after.end.y <= before.end.y+0.04,kind+" retains its ground contact and bounded height")
		var arrays: Array = current.surface_get_arrays(0); var valid: bool = true
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if not vertex.is_finite(): valid = false
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			if not normal.is_finite(): valid = false
		check(valid,kind+" has finite actual geometry and normals")
		var changed: bool = var_to_bytes(old.surface_get_arrays(0)) != var_to_bytes(arrays)
		check(changed == (kind in ["parked_car","van","car_wreck","cliff"]),kind+" matches the intended sculpt-only scope")
		measurements[kind] = {"old_triangles":old.surface_get_array_len(0)/3,"new_triangles":current.surface_get_array_len(0)/3,"old_size":str(before.size),"new_size":str(after.size)}
	kit.free()
	var revised_costs: Dictionary = {}
	for biome: String in TrackTheme.IDS:
		for kind: String in ["parked_car","van","car_wreck","cliff","burning_car"]:
			kit = NativeTrackVisual.new(); kit.theme_id = biome; kit.colors = TrackTheme.palette(biome); kit.editor_preview = true; kit._suppress_night_fx = true
			root.add_child(kit)
			var object: Dictionary = {"kind":kind,"position":[0.0,0.0],"rotation":0.0}
			var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":[object]},"scenery_objects":[]}
			await kit._build_placed_objects(track)
			var cost: int = BYTES.scene(kit)+1024
			var planner = BATCHES.new(); var model: Dictionary = planner._model(kit,object,kind)
			var retained: int = 1024
			for part: Dictionary in model.parts:
				if part.baked:
					retained += part.arrays[Mesh.ARRAY_VERTEX].size()*192+part.hidden.size()*16
					if part.arrays[Mesh.ARRAY_INDEX] != null: retained += part.arrays[Mesh.ARRAY_INDEX].size()*12
				else: retained += BYTES.mesh(part.mesh)
			cost = maxi(cost,retained)
			var key: String = biome+"/"+kind
			revised_costs[key] = cost
			check(cost <= int(COSTS.BYTES[key]),key+" remains inside the authoring memory estimate")
			kit.free()
		await process_frame
	measurements.costs = revised_costs; measurements.checks = checks; measurements.failures = failures
	var report := FileAccess.open("res://../docs/evidence/editor-ux-improvements-2026-10-28/prop-quality.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements,"\t")); report.close()
	print("EDITOR_PROP_QUALITY: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
