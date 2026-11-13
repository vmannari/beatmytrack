extends RefCounted
## Immutable scenery resources; fresh nodes and mutable instance buffers per race.
## Winter's optional surface materials are exclusively leased and reset on return.
const MAX_ENTRIES: int = 5
const MAX_BYTES: int = 64 * 1024 * 1024
const SURFACE_BYTES: int = 8192 # Material object, parameter map and GPU UBO estimate.
static var entries: Array[Dictionary] = []
static var generation: int = 0

static func bytes_used() -> int:
	var total: int = 0
	for entry: Dictionary in entries: total += int(entry.bytes)
	return total

static func shared_road_bytes(roads: Array) -> int:
	# Only identical immutable resource objects prove shared buffers. Geometry
	# equality/names do not; nodes and mutable instance buffers remain private.
	var owned: Dictionary = {}
	for entry: Dictionary in entries:
		for id: int in entry.get("resources",{}): owned[id] = int(entry.resources[id])
	var total: int = 0
	var seen: Dictionary = {}
	for entry: Dictionary in roads:
		for data: Dictionary in entry.meshes:
			var id: int = data.mesh.get_instance_id()
			if owned.has(id) and not seen.has(id):
				seen[id] = true
				total += int(owned[id])
	return total

static func trim_cache(allowance: int = 0) -> void:
	generation += 1
	var total: int = bytes_used()
	while not entries.is_empty() and total > allowance: total -= int(entries.pop_front().bytes)

static func restore(key: Array, visual: Node3D) -> bool:
	for index: int in range(entries.size()):
		if entries[index].key != key: continue
		var entry: Dictionary = entries.pop_at(index)
		entries.append(entry)
		var holder: Node3D = entry.scene.instantiate()
		visual.tyre_instances = holder.get_child(entry.tyres) if int(entry.tyres) >= 0 else null
		for child_index: int in entry.props: visual.light_instances.append(holder.get_child(child_index))
		for child: Node in holder.get_children():
			_own(child,null)
			holder.remove_child(child)
			visual.add_child(child)
			_isolate_instances(child)
		holder.free()
		for name: String in entry.metadata: visual.set_meta(name,entry.metadata[name])
		visual.scenic_count = entry.scenic_count
		visual.set_meta("prepared_world_key",key.duplicate(true))
		return true
	return false

static func remember(key: Array, visual: Node3D, track: NativeTrack) -> void:
	var resources: Dictionary = {}
	var retained_resources: Dictionary = {}
	# Include CPU/GPU grid masks conservatively, then each mesh/buffer once.
	var bytes: int = track.cells.size()*(20 if track.metadata.get("theme","pine") == "desert" else 16)
	for child: Node in visual.get_children(): bytes += _resource_bytes(child,resources)
	if bytes > MAX_BYTES: return
	var holder := Node3D.new()
	for child: Node in visual.get_children():
		var copy: Node = child.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
		holder.add_child(copy)
		_own(copy,holder)
		_isolate_instances(copy)
		_resource_bytes(copy,retained_resources)
	bytes += retained_resources.size()*32
	if bytes > MAX_BYTES: holder.free(); return
	var scene := PackedScene.new()
	var packed: Error = scene.pack(holder)
	holder.free()
	if packed != OK: return
	var paths: Array[int] = []
	for prop: Node3D in visual.light_instances: paths.append(prop.get_index())
	var metadata: Dictionary = {}
	for name: String in visual.get_meta_list(): metadata[name] = visual.get_meta(name)
	for index: int in range(entries.size()-1,-1,-1):
		if entries[index].key == key: entries.remove_at(index)
	var total: int = bytes
	for entry: Dictionary in entries: total += int(entry.bytes)
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or total > MAX_BYTES):
		total -= int(entries.pop_front().bytes)
	entries.append({"key":key.duplicate(true),"scene":scene,"bytes":bytes,"resources":retained_resources,"metadata":metadata,"props":paths,"tyres":visual.tyre_instances.get_index() if visual.tyre_instances != null else -1,"scenic_count":visual.scenic_count})
	visual.set_meta("prepared_world_key",key.duplicate(true))

static func _own(node: Node, holder: Node) -> void:
	node.owner = holder
	if holder != null:
		for group: StringName in node.get_groups():
			node.remove_from_group(group)
			node.add_to_group(group,true)
	for child: Node in node.get_children(): _own(child,holder)


# Car resource accounting also loads this cache. Keep the same generic Node3D
# boundary as restore() so that accounting does not import world builders.
static func restore_cooperative(key: Array, visual: Node3D) -> bool:
	var entry: Dictionary = {}
	for index: int in range(entries.size()):
		if entries[index].key != key: continue
		entry = entries.pop_at(index); entries.append(entry); break
	if entry.is_empty(): return false
	if not await visual._yield_build(): return false
	var instantiate_started: int = Time.get_ticks_usec() if visual.profile_build else 0
	var holder: Node3D = entry.scene.instantiate()
	if visual.profile_build: visual.build_costs.cache_instantiate_us = Time.get_ticks_usec()-instantiate_started
	var lease: Node = preload("res://race/install_staging.gd").new()
	lease.name = "RaceInstallStaging"; lease.staged = holder; visual.add_child(lease)
	var tyres: Node3D = holder.get_child(entry.tyres) if int(entry.tyres) >= 0 else null
	var props: Array[Node3D] = []
	for index: int in entry.props: props.append(holder.get_child(index))
	for child: Node in holder.get_children():
		if not await visual._yield_build():
			if is_instance_valid(lease): lease.free()
			return false
		_own(child,null)
		holder.remove_child(child)
		visual.add_child(child)
		_isolate_instances(child)
	lease.free()
	if not visual._build_is_current(): return false
	visual.tyre_instances = tyres
	visual.light_instances.assign(props)
	for name: String in entry.metadata: visual.set_meta(name,entry.metadata[name])
	visual.scenic_count = entry.scenic_count
	visual.set_meta("prepared_world_key",key.duplicate(true))
	return true


static func remember_cooperative(key: Array, visual: Node3D, track: NativeTrack) -> void:
	var started_generation: int = generation
	var resources: Dictionary = {}
	var retained_resources: Dictionary = {}
	var bytes: int = track.cells.size()*(20 if track.metadata.get("theme","pine") == "desert" else 16)
	for child: Node in visual.get_children():
		if not await visual._yield_build(): return
		bytes += _resource_bytes(child,resources)
	if bytes > MAX_BYTES: return
	var holder := Node3D.new()
	var sources: Array[Node] = visual.get_children()
	var lease: Node = preload("res://race/install_staging.gd").new()
	lease.name = "RaceInstallStaging"; lease.staged = holder; visual.add_child(lease)
	for child: Node in sources:
		if not await visual._yield_build():
			if is_instance_valid(lease): lease.free()
			return
		var duplicate_started: int = Time.get_ticks_usec() if visual.profile_build else 0
		var copy: Node = child.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
		holder.add_child(copy)
		_own(copy,holder)
		_isolate_instances(copy)
		_resource_bytes(copy,retained_resources)
		if visual.profile_build: visual.build_costs.cache_duplicate_max_us = maxi(int(visual.build_costs.get("cache_duplicate_max_us",0)),Time.get_ticks_usec()-duplicate_started)
	if not await visual._yield_build():
		if is_instance_valid(lease): lease.free()
		return
	var scene := PackedScene.new()
	var pack_started: int = Time.get_ticks_usec() if visual.profile_build else 0
	var packed: Error = scene.pack(holder)
	if visual.profile_build: visual.build_costs.cache_pack_us = Time.get_ticks_usec()-pack_started
	lease.free()
	# Packing is an indivisible engine call. Publish only a complete current
	# scene; never expose partial cache entries during cooperative preparation.
	bytes += retained_resources.size()*32
	if packed != OK or not visual._build_is_current() or started_generation != generation or bytes > MAX_BYTES: return
	var paths: Array[int] = []
	for prop: Node3D in visual.light_instances: paths.append(prop.get_index())
	var metadata: Dictionary = {}
	for name: String in visual.get_meta_list(): metadata[name] = visual.get_meta(name)
	for index: int in range(entries.size()-1,-1,-1):
		if entries[index].key == key: entries.remove_at(index)
	var total: int = bytes
	for entry: Dictionary in entries: total += int(entry.bytes)
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or total > MAX_BYTES): total -= int(entries.pop_front().bytes)
	entries.append({"key":key.duplicate(true),"scene":scene,"bytes":bytes,"resources":retained_resources,"metadata":metadata,"props":paths,"tyres":visual.tyre_instances.get_index() if visual.tyre_instances != null else -1,"scenic_count":visual.scenic_count})
	visual.set_meta("prepared_world_key",key.duplicate(true))

static func _surface_entry(visual: Node3D) -> Dictionary:
	var key: Array = visual.get_meta("prepared_world_key",[])
	for entry: Dictionary in entries:
		if entry.key == key: return entry
	return {}

static func acquire_surface(visual: Node3D, original: ShaderMaterial, owner: Node) -> Dictionary:
	var entry: Dictionary = _surface_entry(visual)
	var key: String = str(original.get_instance_id())+":"+original.shader.code.sha256_text()
	var surfaces: Dictionary = entry.get("surfaces",{})
	var record: Dictionary = surfaces.get(key,{})
	if not record.is_empty():
		var borrower: Object = record.owner.get_ref() if record.owner != null else null
		if not is_instance_valid(borrower) or borrower == owner:
			record.owner = weakref(owner)
			return record
	# Sharing a live owner's mutable wind state is never allowed.
	var result: Dictionary = {"material":original.duplicate(),"original":original,"owner":weakref(owner)}
	if entry.is_empty() or not record.is_empty(): return result
	if surfaces.size() >= 512 or bytes_used()+SURFACE_BYTES > MAX_BYTES:
		entries.erase(entry); generation += 1
		return result
	entry.bytes += SURFACE_BYTES
	surfaces[key] = result
	entry["surfaces"] = surfaces
	return result

static func account_surface(visual: Node3D, material: ShaderMaterial) -> void:
	var entry: Dictionary = _surface_entry(visual)
	if entry.is_empty(): return
	var texture: Texture2D = material.get_shader_parameter("snow_road_sources")
	if texture == null: return
	# Count an entire float lookup's CPU/GPU footprint conservatively even if
	# the independent bounded source cache also currently owns the same lookup.
	# All surfaces of this immutable world bind the same lookup. Reserve its
	# largest footprint rather than accumulating identities after regeneration.
	var required: int = texture.get_width()*texture.get_height()*32
	var bytes: int = maxi(0,required-int(entry.get("surface_texture_bytes",0)))
	if bytes_used()+bytes > MAX_BYTES:
		entries.erase(entry); generation += 1
		return
	entry["surface_texture_bytes"] = maxi(required,int(entry.get("surface_texture_bytes",0)))
	entry.bytes += bytes

static func release_surface(record: Dictionary, owner: Node) -> void:
	if record.owner == null or record.owner.get_ref() != owner: return
	var material: ShaderMaterial = record.material
	var original: ShaderMaterial = record.original
	material.set_shader_parameter("wind_surface_strength",0.0)
	# Idle leases retain no run-specific source texture or presentation state.
	for name: String in ["wind_surface_flow","snow_road_sources","wind_surface_elapsed","wind_surface_travel","wind_surface_focus","wind_surface_car","snow_source_bounds","snow_edge_sources"]:
		material.set_shader_parameter(name,original.get_shader_parameter(name))
	record.owner = null

static func _isolate_instances(node: Node) -> void:
	if node is MultiMeshInstance3D and node.multimesh != null:
		var source: MultiMesh = node.multimesh
		var copy := MultiMesh.new()
		copy.transform_format = source.transform_format
		copy.use_colors = source.use_colors
		copy.use_custom_data = source.use_custom_data
		copy.mesh = source.mesh
		copy.instance_count = source.instance_count
		copy.visible_instance_count = source.visible_instance_count
		copy.custom_aabb = source.custom_aabb
		# Dummy/headless rendering has no backing instance buffer.
		var buffer: PackedFloat32Array = source.buffer
		if not buffer.is_empty(): copy.buffer = buffer
		node.multimesh = copy
	for child: Node in node.get_children(): _isolate_instances(child)

static func _resource_bytes(node: Node, seen: Dictionary) -> int:
	var bytes: int = 512
	var mesh: Mesh
	if node is MeshInstance3D: mesh = node.mesh
	elif node is MultiMeshInstance3D and node.multimesh != null:
		mesh = node.multimesh.mesh
		bytes += node.multimesh.instance_count*128
	if mesh != null and not seen.has(mesh.get_instance_id()):
		var mesh_bytes: int = 0
		for surface: int in range(mesh.get_surface_count()):
			if mesh is ArrayMesh:
				# Counts are enough for this conservative budget. Avoid decoding
				# complete vertex/index arrays again after spatial preparation.
				mesh_bytes += mesh.surface_get_array_len(surface)*96+mesh.surface_get_array_index_len(surface)*4
				continue
			var arrays: Array = mesh.surface_get_arrays(surface)
			mesh_bytes += arrays[Mesh.ARRAY_VERTEX].size()*96
			if arrays[Mesh.ARRAY_INDEX] != null: mesh_bytes += arrays[Mesh.ARRAY_INDEX].size()*4
		mesh_bytes += int(mesh.get_meta("scenery_lod_bytes",0))+int(mesh.get_meta("scenery_lod_plan_bytes",0))
		seen[mesh.get_instance_id()] = mesh_bytes
		bytes += mesh_bytes
	for child: Node in node.get_children(): bytes += _resource_bytes(child,seen)
	return bytes
