extends Node3D
## App-owned, hidden preparation nodes only. Live emitter state is never pooled.
const MAX_NODES: int = 64
const MAX_BYTES: int = 12 * 1024 * 1024
var entries: Array[Dictionary] = []
var bytes: int = 0
var hits: int = 0
var retaining: bool = true

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED

func take(label: String) -> GPUParticles3D:
	for index: int in range(entries.size()-1,-1,-1):
		if entries[index].label != label: continue
		var entry: Dictionary = entries.pop_at(index)
		bytes = _footprint()
		var particles: GPUParticles3D = entry.node
		particles.set_meta("preparation_reused",true)
		hits += 1
		return particles
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.set_meta("preparation_reused",false)
	return particles

func measure(particles: GPUParticles3D) -> void:
	# Include conservative node/GPU bookkeeping and all retained resource state.
	# Estimates are an admission bound, not Android PSS or driver allocation.
	var seen: Dictionary = {}
	_estimate(particles.process_material,seen)
	for index: int in range(particles.draw_passes): _estimate(particles.get_draw_pass_mesh(index),seen)
	var cost: int = 64 * 1024
	for value: int in seen.values(): cost += value
	particles.set_meta("preparation_bytes",cost)
	particles.set_meta("preparation_resources",seen)

func contains(label: String) -> bool:
	for entry: Dictionary in entries:
		if entry.label == label: return true
	return false

func put(particles: GPUParticles3D, initialized: bool) -> void:
	if not is_instance_valid(particles): return
	var cost: int = int(particles.get_meta("preparation_bytes",MAX_BYTES+1))
	if not initialized or not retaining or not is_inside_tree() or is_queued_for_deletion() or cost > MAX_BYTES:
		particles.free()
		return
	particles.emitting = false
	particles.speed_scale = 0.0
	particles.hide()
	particles.process_mode = Node.PROCESS_MODE_DISABLED
	if particles.get_parent() == null: add_child(particles)
	else: particles.reparent(self,false)
	entries.append({"label":str(particles.get_meta("preparation_key",particles.name)),"node":particles,"bytes":cost,"resources":particles.get_meta("preparation_resources",{})})
	bytes = _footprint()
	while not entries.is_empty() and (entries.size() > MAX_NODES or bytes > MAX_BYTES):
		var old: Dictionary = entries.pop_front()
		old.node.free()
		bytes = _footprint()

func _footprint() -> int:
	var resources: Dictionary = {}
	for entry: Dictionary in entries:
		for id: int in entry.resources: resources[id] = entry.resources[id]
	var total: int = entries.size()*64*1024
	for cost: int in resources.values(): total += cost
	return total

func trim() -> void:
	# In-flight nodes remain owned by their preparing world and are freed when
	# returned. Pressure must not destroy a node in the middle of a covered draw.
	retaining = false
	for entry: Dictionary in entries: entry.node.free()
	entries.clear()
	bytes = 0

func trim_to(allowance: int) -> void:
	# Evict idle leases without disabling future retention or touching in-flight
	# proxies. Real OS pressure still uses trim() and its suppression fence.
	while not entries.is_empty() and bytes > maxi(0,allowance):
		var entry: Dictionary = entries.pop_front()
		entry.node.free()
		bytes = _footprint()

static func _estimate(value: Variant, seen: Dictionary) -> int:
	if value is Resource:
		if seen.has(value.get_instance_id()): return 0
		var id: int = value.get_instance_id()
		seen[id] = 0
		if value is Texture2D:
			# Authored particle PNGs are RGBA8; six bytes/pixel covers their
			# complete mip chain with headroom. Curve/gradient textures get 4 KiB.
			seen[id] = maxi(4096,value.get_width()*value.get_height()*6)
			return 0
		if value is Texture3D:
			seen[id] = maxi(4096,value.get_width()*value.get_height()*value.get_depth()*8)
			return 0
		var total: int = 4096
		if value is Mesh:
			for surface: int in range(value.get_surface_count()):
				var arrays: Array = value.surface_get_arrays(surface)
				total += arrays[Mesh.ARRAY_VERTEX].size()*96
				if arrays[Mesh.ARRAY_INDEX] != null: total += arrays[Mesh.ARRAY_INDEX].size()*4
				total += _estimate(value.surface_get_material(surface),seen)
			seen[id] = total
			return 0
		for property: Dictionary in value.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_") and property.name != "script":
				total += _estimate(value.get(property.name),seen)
		seen[id] = total
		return 0
	if value is Array or value is Dictionary:
		var total: int = 64
		for key: Variant in value: total += _estimate(value[key] if value is Dictionary else key,seen)
		return total
	if value is String: return value.length()*4
	return var_to_bytes(value).size()
