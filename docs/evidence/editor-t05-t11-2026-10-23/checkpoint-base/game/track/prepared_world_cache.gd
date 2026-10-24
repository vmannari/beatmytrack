extends RefCounted
## Immutable scenery resources; fresh nodes and mutable instance buffers per race.
const MAX_ENTRIES: int = 5
const MAX_BYTES: int = 64 * 1024 * 1024
static var entries: Array[Dictionary] = []

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
		return true
	return false

static func remember(key: Array, visual: Node3D, track: NativeTrack) -> void:
	var resources: Dictionary = {}
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
	entries.append({"key":key.duplicate(true),"scene":scene,"bytes":bytes,"metadata":metadata,"props":paths,"tyres":visual.tyre_instances.get_index() if visual.tyre_instances != null else -1,"scenic_count":visual.scenic_count})

static func _own(node: Node, holder: Node) -> void:
	node.owner = holder
	if holder != null:
		for group: StringName in node.get_groups():
			node.remove_from_group(group)
			node.add_to_group(group,true)
	for child: Node in node.get_children(): _own(child,holder)


static func restore_cooperative(key: Array, visual: NativeTrackVisual) -> bool:
	var entry: Dictionary = {}
	for index: int in range(entries.size()):
		if entries[index].key != key: continue
		entry = entries.pop_at(index); entries.append(entry); break
	if entry.is_empty(): return false
	if not await visual._yield_build(): return false
	var holder: Node3D = entry.scene.instantiate()
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
	return true


static func remember_cooperative(key: Array, visual: NativeTrackVisual, track: NativeTrack) -> void:
	var resources: Dictionary = {}
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
		var copy: Node = child.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
		holder.add_child(copy)
		_own(copy,holder)
		_isolate_instances(copy)
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
	if packed != OK or not visual._build_is_current(): return
	var paths: Array[int] = []
	for prop: Node3D in visual.light_instances: paths.append(prop.get_index())
	var metadata: Dictionary = {}
	for name: String in visual.get_meta_list(): metadata[name] = visual.get_meta(name)
	for index: int in range(entries.size()-1,-1,-1):
		if entries[index].key == key: entries.remove_at(index)
	var total: int = bytes
	for entry: Dictionary in entries: total += int(entry.bytes)
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or total > MAX_BYTES): total -= int(entries.pop_front().bytes)
	entries.append({"key":key.duplicate(true),"scene":scene,"bytes":bytes,"metadata":metadata,"props":paths,"tyres":visual.tyre_instances.get_index() if visual.tyre_instances != null else -1,"scenic_count":visual.scenic_count})

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
		seen[mesh.get_instance_id()] = true
		for surface: int in range(mesh.get_surface_count()):
			if mesh is ArrayMesh:
				# Counts are enough for this conservative budget. Avoid decoding
				# complete vertex/index arrays again after spatial preparation.
				bytes += mesh.surface_get_array_len(surface)*96+mesh.surface_get_array_index_len(surface)*4
				continue
			var arrays: Array = mesh.surface_get_arrays(surface)
			bytes += arrays[Mesh.ARRAY_VERTEX].size()*96
			if arrays[Mesh.ARRAY_INDEX] != null: bytes += arrays[Mesh.ARRAY_INDEX].size()*4
	for child: Node in node.get_children(): bytes += _resource_bytes(child,seen)
	return bytes
