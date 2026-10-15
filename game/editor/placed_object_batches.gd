extends RefCounted
## Retained eight-prop baked groups and original instanced shadows/Winter/tyres.
## Race meshes and mutable race props stay separate.
const MODEL_BUDGET: int = 16 * 1024 * 1024
const MODEL_LIMIT: int = 96
const BAKED_GROUP_SIZE: int = 4
var groups: Dictionary = {}
var individuals: Dictionary = {}
var models: Dictionary = {}
var active_models: Dictionary = {}
var model_bytes: int = 0
var sources: Array = []
var tyre_origins := PackedVector2Array()
var shadow_model: Dictionary = {}
var updates: int = 0
var baked_signature: Dictionary = {}
var baked_plan: Dictionary = {}
var shared_vertices: Dictionary = {}
var shared_vertex_bytes: int = 0
var ground_key: String = ""
const SHARED_VERTEX_BUDGET: int = 1024 * 1024

func refresh(kit: NativeTrackVisual, track: NativeTrack, sliced: bool, current: Callable) -> bool:
	var objects: Array = track.metadata.get("creator_document",{}).get("objects",[]).duplicate(true)
	var tyres: PackedVector2Array = track.tyre_origins.duplicate()
	if objects == sources and tyres == tyre_origins and updates > 0 and ground_key == track.content_hash: return false
	var desired: Dictionary = {}
	var next_models: Dictionary = {}
	var separate: Dictionary = {}
	var pending_nodes: Array[NativeTrackVisual] = []
	for index: int in range(objects.size()):
		if sliced and kit._menu_yield_due():
			await kit.get_tree().process_frame
			if not is_instance_valid(kit) or not current.is_valid() or not current.call():
				for pending: NativeTrackVisual in pending_nodes: pending.free()
				return false
			kit._slice_started = Time.get_ticks_usec()
		var object: Dictionary = objects[index]
		var kind: String = object.kind
		if kind in ["tyre_stack","tyre_wall"]: continue
		# Preserve the original lamp glow orientation, movable nodes and damage phases.
		if kind in CreatorCatalog.SOFT or kind in ["oil","puddle","jump","speed_bump"] or (kind == "light" and kit.theme_id == "night_city"):
			var entry: Dictionary = individuals.get(index,{})
			if entry.get("source",{}) != object:
				var node := NativeTrackVisual.new()
				node.theme_id = kit.theme_id
				node.colors = kit.colors
				node.editor_preview = true
				var single := NativeTrack.new()
				single.metadata = {"creator_document":{"objects":[object]},"scenery_objects":[]}
				await node._build_placed_objects(single)
				entry = {"source":object,"node":node}
				pending_nodes.append(node)
			separate[index] = entry
			if kit.ground_support != null: entry.node.position.y = kit.ground_support.ground(Vector2(object.position[0],object.position[1]))
		else:
			# Preserve the original world-space float vertices and generated normals.
			# Moving a prop prepares that prop; unchanged streams are copied in bulk.
			var key: String = JSON.stringify(object,"",true)+"/ground="+str(kit.ground_support.ground(Vector2(object.position[0],object.position[1])) if kit.ground_support != null else 0.0)
			var model: Dictionary = active_models[key] if active_models.has(key) else _model(kit,object,key)
			next_models[key] = model
			for part_index: int in range(model.parts.size()):
				var part: Dictionary = model.parts[part_index]
				if part.baked:
					var role: String = ("ink:" if part.material.next_pass != null else "opaque:")+str(Vector2i(floori(float(object.position[0])/32.0),floori(float(object.position[1])/32.0)))+":"+str(index/BAKED_GROUP_SIZE)
					if not desired.has(role): desired[role] = {"baked":true,"components":[],"sources":[],"bounds":[],"material":part.material,"poses":[]}
					desired[role].components.append(part.arrays)
					desired[role].sources.append(key+":"+str(part_index))
					desired[role].bounds.append(part.bounds)
				else:
					var tile := Vector2i((Vector2(object.position[0],object.position[1])/WinterScenery.TILE).floor())
					var group: String = "%s|%s|%s|%s" % [kind,str(tile),str(float(object.get("length",-1.0))/float(object.get("scale",1.0))),str(part_index)]
					if not desired.has(group): desired[group] = {"model":{"parts":[part]},"poses":[]}
					desired[group].poses.append(part.pose)
		if kind in ContactShading.STATIC_KINDS:
			var point := Vector2(object.position[0],object.position[1])
			var tile := Vector2i(floori(point.x/32.0),floori(point.y/32.0))
			var key: String = "shadow:"+str(tile)
			if not desired.has(key): desired[key] = {"model":_shadow(),"poses":[]}
			var size: Vector2 = CreatorObjects.size_of(object)
			if kind in ["tree","broadleaf"]: size *= 0.40
			size += Vector2.ONE*0.65
			var basis := Basis(Vector3.UP,deg_to_rad(float(object.rotation)))*Basis.from_scale(Vector3(size.x,0.5,size.y))
			desired[key].poses.append(Transform3D(basis,VisualGeometry.world(point)+Vector3.UP*0.025))
	if not tyres.is_empty():
		var tyre: Dictionary = {"kind":"tyre_stack","position":[0.0,0.0],"rotation":0.0}
		var poses: Array = []
		for point: Vector2 in tyres: poses.append(Transform3D(Basis.IDENTITY,VisualGeometry.world(point)+Vector3.UP*(kit.ground_support.ground(point) if kit.ground_support != null else 0.0)))
		var model: Dictionary = _model(kit,tyre,"tyres")
		var part: Dictionary = model.parts[0].duplicate()
		part.pose = Transform3D.IDENTITY
		for index: int in range(poses.size()): poses[index] = poses[index]*model.parts[0].pose
		desired["tyres"] = {"model":{"parts":[part]},"poses":poses}
	await _prepare_baked_groups(desired,kit,sliced,current)
	if not is_instance_valid(kit) or not current.is_valid() or not current.call():
		for pending: NativeTrackVisual in pending_nodes: pending.free()
		return false
	for key: String in desired:
		var entry: Dictionary = desired[key]
		if not entry.get("baked",false) or (groups.has(key) and groups[key].sources == entry.sources): continue
		if sliced and kit._menu_yield_due():
			await kit.get_tree().process_frame
			kit._slice_started = Time.get_ticks_usec()
			if not current.is_valid() or not current.call():
				for pending: NativeTrackVisual in pending_nodes: pending.free()
				return false
		var vertices: int = 0
		for component: Array in entry.components: vertices += component[Mesh.ARRAY_VERTEX].size()
		if sliced and vertices > 8192:
			var job = preload("res://editor/work_job.gd").start(_assembly_arrays.bind(entry.components),kit.get_tree())
			while not job.done:
				await kit.get_tree().process_frame
				if not current.call():
					job.cancel()
					for pending: NativeTrackVisual in pending_nodes: pending.free()
					return false
			entry["prepared_mesh"] = _upload_arrays(job.result) if job.result is Array and not job.result.is_empty() else _assemble(entry.components)
		else: entry["prepared_mesh"] = _assemble(entry.components)
	# Publish once, after preparation. A superseded sliced update changes no live groups.
	for key: String in groups.keys():
		if desired.has(key): continue
		for node: GeometryInstance3D in groups[key].nodes:
			kit.remove_child(node)
			node.queue_free()
		groups.erase(key)
	for key: String in desired:
		var entry: Dictionary = desired[key]
		var old: Dictionary = groups.get(key,{})
		if entry.get("baked",false):
			if not old.is_empty() and old.sources == entry.sources: continue
			var mesh: ArrayMesh = entry.prepared_mesh
			var node: MeshInstance3D = old.nodes[0] if not old.is_empty() else MeshInstance3D.new()
			if old.is_empty():
				node.name = "Authored_"+key.get_slice(":",0)+"_"+str(groups.size())
				kit.add_child(node)
			node.mesh = mesh
			node.material_override = entry.material
			groups[key] = {"nodes":[node],"sources":entry.sources,"poses":[]}
			continue
		if not old.is_empty() and old.poses == entry.poses: continue
		var nodes: Array = old.get("nodes",[])
		if old.is_empty():
			for part: Dictionary in entry.model.parts:
				var node := MultiMeshInstance3D.new()
				node.name = part.name
				node.multimesh = MultiMesh.new()
				node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				node.multimesh.mesh = part.mesh
				node.material_override = part.material
				node.cast_shadow = part.cast_shadow
				node.layers = part.layers
				if part.contact: node.add_to_group("contact_lighting")
				kit.add_child(node)
				nodes.append(node)
		for part_index: int in range(nodes.size()):
			var node: MultiMeshInstance3D = nodes[part_index]
			var part: Dictionary = entry.model.parts[part_index]
			if node.multimesh.mesh != part.mesh: node.multimesh.mesh = part.mesh
			node.material_override = part.material
			node.cast_shadow = part.cast_shadow
			node.layers = part.layers
			var resized: bool = node.multimesh.instance_count != entry.poses.size()
			if resized: node.multimesh.instance_count = entry.poses.size()
			for index: int in range(entry.poses.size()):
				if not resized and old.poses[index] == entry.poses[index]: continue
				node.multimesh.set_instance_transform(index,entry.poses[index])
		groups[key] = {"nodes":nodes,"poses":entry.poses,"model":entry.model}
	for index: int in individuals:
		if separate.has(index) and separate[index].node == individuals[index].node: continue
		var old: NativeTrackVisual = individuals[index].node
		kit.remove_child(old)
		old.queue_free()
	kit.light_instances.clear()
	for index: int in separate:
		var node: NativeTrackVisual = separate[index].node
		if node.get_parent() == null: kit.add_child(node)
		kit.light_instances.append_array(node.light_instances)
	individuals = separate
	kit.tyre_instances = groups["tyres"].nodes[0] if groups.has("tyres") else null
	kit._tyre_positions.clear()
	kit._tyre_spins.clear()
	sources = objects
	active_models = next_models
	tyre_origins = tyres
	updates += 1
	ground_key = track.content_hash
	return true

func _model(kit: NativeTrackVisual, object: Dictionary, key: String) -> Dictionary:
	if models.has(key): return models[key]
	var prototype := NativeTrackVisual.new()
	prototype.theme_id = kit.theme_id
	prototype.colors = kit.colors
	prototype.editor_preview = true
	prototype.ground_support = kit.ground_support if key != "tyres" else null
	prototype._capture_editor_prop_arrays = true
	var track := NativeTrack.new()
	track.metadata = {"creator_document":{"objects":[object]},"scenery_objects":[]}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	prototype._build_placed_objects(track)
	var parts: Array = []
	var bytes: int = 0
	for child: Node in prototype.get_children():
		if child.is_in_group("contact_lighting"): continue
		var mesh: Mesh
		var pose: Transform3D
		if child is MeshInstance3D:
			mesh = child.mesh
			pose = child.transform
		elif child is MultiMeshInstance3D and child.multimesh.instance_count == 1:
			mesh = child.multimesh.mesh
			pose = child.transform*child.multimesh.get_instance_transform(0)
		else: continue
		for surface: int in range(mesh.get_surface_count()):
			bytes += mesh.surface_get_array_len(surface)*64+mesh.surface_get_array_index_len(surface)*4
		var baked: bool = child is MeshInstance3D
		# Keep pre-upload normals. Decoding/re-encoding a compressed ArrayMesh
		# introduces an extra quantization step, visible in Mobile lighting.
		parts.append({"mesh":null if baked else mesh,"arrays":_baked_arrays(child) if baked else [],"bounds":mesh.get_aabb(),"baked":baked,"pose":pose,"material":child.material_override,"cast_shadow":child.cast_shadow,"layers":child.layers,"name":str(child.name),"contact":false})
	prototype.free()
	var result: Dictionary = {"parts":parts,"bytes":bytes}
	if bytes <= MODEL_BUDGET:
		while not models.is_empty() and (models.size() >= MODEL_LIMIT or model_bytes+bytes > MODEL_BUDGET):
			var expired: String = models.keys()[0]
			model_bytes -= int(models[expired].bytes)
			models.erase(expired)
		models[key] = result
		model_bytes += bytes
	return result

static func _baked_arrays(node: MeshInstance3D) -> Array:
	# Default arguments are eager; the retained path must never read back a mesh.
	if node.has_meta("editor_prop_arrays"): return node.get_meta("editor_prop_arrays")
	return node.mesh.surface_get_arrays(0)

func _prepare_baked_groups(desired: Dictionary, kit: NativeTrackVisual, sliced: bool, current: Callable) -> void:
	var signature: Dictionary = {}
	for key: String in desired:
		if desired[key].get("baked",false): signature[key] = desired[key].sources
	if signature != baked_signature:
		baked_signature = signature.duplicate(true)
		baked_plan = {}
		for role: String in ["opaque","ink"]:
			var parts: Array = []
			for key: String in signature:
				if not key.begins_with(role+":"): continue
				var entry: Dictionary = desired[key]
				for index: int in range(entry.components.size()):
					parts.append({"arrays":entry.components[index],"bounds":entry.bounds[index],"source":entry.sources[index],"material":entry.material,"chunk":key,"cluster":parts.size()})
			# Overlapping opaque surfaces must keep the original triangle order.
			# Shared vertices additionally need their original joined normals.
			var shared: Dictionary = {}
			for a: int in range(parts.size()):
				if sliced and kit._menu_yield_due():
					await kit.get_tree().process_frame; kit._slice_started = Time.get_ticks_usec()
					if not current.call(): baked_signature = {}; return
				for b: int in range(a+1,parts.size()):
					if not AABB(parts[a].bounds).grow(0.00001).intersects(parts[b].bounds): continue
					var from: int = parts[b].cluster
					var into: int = parts[a].cluster
					if from != into:
						for part: Dictionary in parts:
							if part.cluster == from: part.cluster = into
					if _shared_vertex(parts[a],parts[b]): shared[parts[a].source] = true
			var clusters: Dictionary = {}
			for part: Dictionary in parts:
				var key: int = part.cluster
				if not clusters.has(key): clusters[key] = []
				clusters[key].append(part)
			for cluster: Array in clusters.values():
				var connected: bool = cluster.size() > 1
				var key: String = role+":joined:"+cluster[0].source if connected else cluster[0].chunk
				if not baked_plan.has(key): baked_plan[key] = {"baked":true,"components":[],"sources":[],"material":cluster[0].material,"poses":[]}
				var components: Array = []
				var regenerate: bool = false
				for part: Dictionary in cluster:
					components.append(part.arrays)
					baked_plan[key].sources.append(part.source)
					regenerate = regenerate or shared.has(part.source)
				if regenerate:
					if sliced:
						var job = preload("res://editor/work_job.gd").start(_join_arrays.bind(components),kit.get_tree())
						while not job.done:
							await kit.get_tree().process_frame
							if not current.call(): job.cancel(); baked_signature = {}; return
						baked_plan[key].components.append(job.result if job.result is Array and not job.result.is_empty() else _joined_arrays(components))
					else: baked_plan[key].components.append(_joined_arrays(components))
				else: baked_plan[key].components.append_array(components)
	for key: String in signature: desired.erase(key)
	for key: String in baked_plan: desired[key] = baked_plan[key]

func _shared_vertex(first: Dictionary, second: Dictionary) -> bool:
	var key: String = first.source+"\n"+second.source
	if shared_vertices.has(key): return shared_vertices[key].shared
	var vertices: Dictionary = {}
	for point: Vector3 in first.arrays[Mesh.ARRAY_VERTEX]: vertices[point] = true
	var shared: bool = false
	for point: Vector3 in second.arrays[Mesh.ARRAY_VERTEX]:
		if vertices.has(point): shared = true; break
	var bytes: int = key.to_utf8_buffer().size()+96
	while not shared_vertices.is_empty() and shared_vertex_bytes+bytes > SHARED_VERTEX_BUDGET:
		var expired: String = shared_vertices.keys()[0]
		shared_vertex_bytes -= int(shared_vertices[expired].bytes)
		shared_vertices.erase(expired)
	if bytes <= SHARED_VERTEX_BUDGET:
		shared_vertices[key] = {"shared":shared,"bytes":bytes}
		shared_vertex_bytes += bytes
	return shared

static func _joined_arrays(components: Array) -> Array:
	return _join_arrays(Callable(),components)

static func _join_arrays(cancelled: Callable, components: Array) -> Array:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for component: Array in components:
		if cancelled.is_valid() and cancelled.call(): return []
		var points: PackedVector3Array = component[Mesh.ARRAY_VERTEX]
		var pigments: PackedColorArray = component[Mesh.ARRAY_COLOR]
		for index: int in component[Mesh.ARRAY_INDEX]:
			tool.set_color(pigments[index])
			tool.add_vertex(points[index])
	tool.generate_normals()
	tool.index()
	return tool.commit_to_arrays()

static func _assemble(components: Array) -> ArrayMesh:
	return _upload_arrays(_assembly_arrays(Callable(),components))

static func _assembly_arrays(cancelled: Callable, components: Array) -> Array:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var pigments := PackedColorArray()
	var indices := PackedInt32Array()
	for component: Array in components:
		if cancelled.is_valid() and cancelled.call(): return []
		var offset: int = vertices.size()
		vertices.append_array(component[Mesh.ARRAY_VERTEX])
		normals.append_array(component[Mesh.ARRAY_NORMAL])
		pigments.append_array(component[Mesh.ARRAY_COLOR])
		var local: PackedInt32Array = component[Mesh.ARRAY_INDEX]
		for index: int in local: indices.append(index+offset)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = pigments
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func _upload_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _shadow() -> Dictionary:
	if not shadow_model.is_empty(): return shadow_model
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = ContactShading.material()
	shadow_model = {"parts":[{"mesh":box,"pose":Transform3D.IDENTITY,"material":null,"cast_shadow":GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"layers":1,"name":"PropContactShadows","contact":true}]}
	return shadow_model
