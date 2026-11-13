extends SceneTree
## Bake only the five fixed, stock Forklift shadow meshes. The manifest update
## changes only its Forklift entry; all other car resources are untouched.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var candidate_dir: String = ""
	var body_target: int = 6000
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate="): candidate_dir = argument.trim_prefix("--candidate=")
		if argument.begins_with("--body-target="): body_target = int(argument.trim_prefix("--body-target="))
	if body_target < 1:
		push_error("Body target must be positive")
		quit(1)
		return
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var car := CarVisual.new()
	car.vehicle_id = "forklift"
	car.simple_model = true
	car.batch_parts = false
	car.cache_rest_pose = false
	root.add_child(car)
	while not car.model_ready: await process_frame
	# Existing proxies may be attached on a repeat bake. shadow_source ignores
	# SHADOWS_ONLY meshes and still reads the original visible meshes even when
	# those meshes have had their own shadow casting disabled by prepare().
	var frames: Array[Node3D] = [car.body]
	frames.append_array(car.rolling_wheels)
	if frames.size() != 5:
		push_error("Forklift must have one body and four rolling frames")
		quit(1)
		return
	var details: Array[Dictionary] = []
	for index: int in range(frames.size()):
		if not candidate_dir.is_empty() and index != 0: continue
		var source: ArrayMesh = RacingCarModels.shadow_source(frames[index])
		if source == null or source.get_surface_count() != 1:
			push_error("Missing shadow source for frame " + str(index))
			quit(1)
			return
		var source_arrays: Array = source.surface_get_arrays(0)
		var original_count: int = source_arrays[Mesh.ARRAY_INDEX].size()/3
		var preserved: ArrayMesh
		if index == 0:
			var partition: Array = partition_body(frames[index])
			if partition.size() != 2:
				push_error("Cannot locate required Forklift silhouette components")
				quit(1)
				return
			source_arrays = (partition[0] as ArrayMesh).surface_get_arrays(0)
			preserved = partition[1]
		var arrays: Array = source_arrays
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		importer.generate_lods(60.0,0.0,[])
		var target: int = body_target if index == 0 else 160
		var chosen: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var error: float = 0.0
		for lod: int in range(importer.get_surface_lod_count(0)):
			if chosen.size()/3 <= target: break
			var candidate: PackedInt32Array = importer.get_surface_lod_indices(0,lod)
			if candidate.size() < chosen.size():
				chosen = candidate
				error = importer.get_surface_lod_size(0,lod)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var compact := PackedVector3Array()
		var mapped: Dictionary = {}
		for corner: int in range(chosen.size()):
			var vertex: int = chosen[corner]
			if not mapped.has(vertex):
				mapped[vertex] = compact.size()
				compact.append(vertices[vertex])
			chosen[corner] = mapped[vertex]
		arrays[Mesh.ARRAY_VERTEX] = compact
		arrays[Mesh.ARRAY_INDEX] = chosen
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		if preserved != null:
			var merged := SurfaceTool.new()
			merged.begin(Mesh.PRIMITIVE_TRIANGLES)
			merged.append_from(mesh,0,Transform3D.IDENTITY)
			merged.append_from(preserved,0,Transform3D.IDENTITY)
			merged.index()
			mesh = merged.commit()
		mesh.custom_aabb = source.get_aabb()
		var path: String = (candidate_dir if not candidate_dir.is_empty() else RacingCarModels.ASSET_ROOT).path_join("forklift_shadow_"+str(index)+".res")
		if not candidate_dir.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(candidate_dir))
		var save_error: Error = ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)
		if save_error != OK:
			push_error("Cannot save " + path + ": " + str(save_error))
			quit(1)
			return
		var final_arrays: Array = mesh.surface_get_arrays(0)
		details.append({"frame":index,"source_triangles":original_count,"triangles":final_arrays[Mesh.ARRAY_INDEX].size()/3,"lod_error":error,"vertices":final_arrays[Mesh.ARRAY_VERTEX].size(),"preserved_triangles":preserved.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3 if preserved != null else 0})
	if candidate_dir.is_empty() and not update_manifest(details):
		push_error("Could not update only the Forklift shadow manifest entry")
		quit(1)
		return
	print("FORKLIFT_RACING_SHADOWS ",JSON.stringify(details))
	var output: String = OS.get_environment("BMT_FORKLIFT_SHADOW_REPORT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			push_error("Cannot write shadow report: " + output)
			quit(1)
			return
		file.store_string(JSON.stringify(details,"\t"))
	car.free()
	quit()

func partition_body(body: Node3D) -> Array:
	# Keep the slim, characteristic silhouette structures in the same shadow
	# draw. Generated siblings can have automatic names, so identify repeated
	# shapes by the original shared mesh, not only by their first named instance.
	var required: Array[String] = ["ForgedForkLeft","ForgedForkRight","GuardSideRail","GuardCrossRail","GuardSlat","WeldedBeam","MastWeb","MastFlange","MastSlidingRail","MastCrosshead","CarriageCrossmember","BackrestFrame","LoadBackrest"]
	var protected_meshes: Dictionary = {}
	for label: String in required:
		# The driver's steering spokes also use WeldedBeam under a nested node;
		# select the first direct body child for the four overhead-guard uprights.
		var part: Node = body.get_node_or_null(label) if label == "WeldedBeam" else body.find_child(label,true,false)
		if label=="WeldedBeam" and part==null:
			var rail: Node = body.find_child("GuardSideRail",true,false)
			if rail!=null: part = rail.get_parent().get_node_or_null(label)
		if not part is MeshInstance3D or part.mesh == null:
			printerr("FORKLIFT_SHADOW_MISSING ",label)
			return []
		protected_meshes[part.mesh.get_instance_id()] = true
	var parts: Array = [SurfaceTool.new(),SurfaceTool.new()]
	for tool: SurfaceTool in parts: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inverse: Transform3D = body.global_transform.affine_inverse()
	for part: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		if not part.is_visible_in_tree() or part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var selected: int = 1 if protected_meshes.has(part.mesh.get_instance_id()) else 0
		for surface: int in range(part.mesh.get_surface_count()):
			var source: Array = part.mesh.surface_get_arrays(surface)
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = source[Mesh.ARRAY_VERTEX]
			arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
			var positions := ArrayMesh.new()
			positions.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			(parts[selected] as SurfaceTool).append_from(VisualGeometry.indexed_surface(positions),0,inverse*part.global_transform)
	var result: Array = []
	for tool: SurfaceTool in parts:
		tool.index()
		result.append(tool.commit())
	return result

func update_manifest(details: Array[Dictionary]) -> bool:
	var path: String = RacingCarModels.ASSET_ROOT.path_join("manifest.json")
	var original: String = FileAccess.get_file_as_string(path)
	var before: Variant = JSON.parse_string(original)
	if not before is Dictionary or not before.get("cars") is Dictionary: print("MANIFEST_PROOF invalid initial JSON"); return false
	var start_re := RegEx.new()
	start_re.compile('"forklift"\\s*:\\s*\\[')
	var match_entry: RegExMatch = start_re.search(original)
	var declaration: String = '"forklift": '+JSON.stringify(details,"\t").replace("\n","\n\t\t")
	var changed: String
	if match_entry == null:
		var cars_re := RegEx.new()
		cars_re.compile('"cars"\\s*:\\s*\\{')
		var match_cars: RegExMatch = cars_re.search(original)
		if match_cars == null: print("MANIFEST_PROOF cars field absent"); return false
		var insert_at: int = match_cars.get_end()
		changed = original.substr(0,insert_at)+"\n\t\t"+declaration+","+original.substr(insert_at)
	else:
		var bracket: int = match_entry.get_end()-1
		var depth: int = 0
		var finish: int = -1
		for index: int in range(bracket,original.length()):
			if original[index] == "[": depth += 1
			if original[index] == "]":
				depth -= 1
				if depth == 0:
					finish = index+1
					break
		if finish < 0: print("MANIFEST_PROOF unclosed entry"); return false
		changed = original.substr(0,match_entry.get_start())+declaration+original.substr(finish)
	var after: Variant = JSON.parse_string(changed)
	if not after is Dictionary or not after.get("cars") is Dictionary: print("MANIFEST_PROOF invalid replacement JSON"); return false
	var old_other: Dictionary = before.duplicate(true)
	var new_other: Dictionary = after.duplicate(true)
	old_other.cars.erase("forklift")
	new_other.cars.erase("forklift")
	if old_other != new_other: print("MANIFEST_PROOF unrelated entries differ"); return false
	# JSON parsing represents whole numbers as floats, so compare like-for-like.
	if after.cars.get("forklift",[]) != JSON.parse_string(JSON.stringify(details)): print("MANIFEST_PROOF generated entries differ"); return false
	if changed == original: return true
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(changed)
	return true
