extends Node
## Garage-owned staging; shared receipts require matching actual render features.
const Key = preload("res://rendering/graphics_preparation.gd")
static var warmed: Dictionary = Key.warmed
var pending: Array[Dictionary] = []
var held: Array[WeakRef] = []
var frame_groups: int = 0
var _copies: Array[GeometryInstance3D] = []
var _local_warmed: Dictionary = {}
var _batch_programs: int = 1
var _fast_draws: int = 0

func _context() -> String:
	var owner: Node = get_parent()
	var camera: Camera3D = owner.get("camera")
	var view: Viewport = owner.showroom_viewport if "showroom_viewport" in owner else get_viewport()
	return Key.context(view,camera.get_parent() if camera != null else owner,camera)

func hold(world: Node) -> void:
	var materials: Dictionary = {}
	var context: String = _context()
	for node: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		if not node is MeshInstance3D and not node is MultiMeshInstance3D: continue
		var key: String = Key.geometry_key(node,materials)
		if Key.ready(context,Key.receipt_key(node,context,materials)): continue
		pending.append({"node":weakref(node),"key":key})
		held.append(weakref(node))
		node.hide()

func release() -> void:
	_clear_copies()
	for reference: WeakRef in held:
		var node: Object = reference.get_ref()
		if is_instance_valid(node): node.show()
	held.clear()
	pending.clear()
	_local_warmed.clear()
	_batch_programs = 1
	_fast_draws = 0

func _clear_copies() -> void:
	for copy: GeometryInstance3D in _copies:
		if is_instance_valid(copy):
			if copy.get_parent() != null: copy.get_parent().remove_child(copy)
			copy.queue_free()
	_copies.clear()

func _copy(source: GeometryInstance3D, camera: Camera3D) -> GeometryInstance3D:
	var copy: GeometryInstance3D
	if source is MeshInstance3D:
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.mesh = source.mesh
		mesh_copy.skin = source.skin
		if source.mesh is ArrayMesh:
			for index: int in range(source.mesh.get_blend_shape_count()): mesh_copy.set_blend_shape_value(index,source.get_blend_shape_value(index))
		for surface: int in range(source.mesh.get_surface_count()): mesh_copy.set_surface_override_material(surface,source.get_surface_override_material(surface))
		copy = mesh_copy
	elif source is MultiMeshInstance3D:
		var instances_copy := MultiMeshInstance3D.new()
		instances_copy.multimesh = source.multimesh
		copy = instances_copy
	else: return null
	copy.set_meta("garage_opening_warm",true)
	copy.material_override = source.material_override
	copy.material_overlay = source.material_overlay
	copy.cast_shadow = source.cast_shadow
	copy.gi_mode = source.gi_mode
	copy.layers = 8
	camera.get_parent().add_child(copy)
	if source is MeshInstance3D:
		var skeleton: Node = source.get_node_or_null(source.skeleton)
		if skeleton is Skeleton3D: copy.skeleton = copy.get_path_to(skeleton)
	copy.global_transform = source.global_transform
	var bounds: AABB = source.get_aabb()
	var delta: Vector3 = (source.to_local(camera.global_position)-bounds.get_center()).abs()
	copy.extra_cull_margin = maxf(source.extra_cull_margin,maxf(delta.x,maxf(delta.y,delta.z))+camera.near+1.0)
	_copies.append(copy)
	return copy

func prepare(draw: Callable, current: Callable) -> bool:
	var instance: WeakRef = weakref(self)
	while not pending.is_empty():
		if not current.is_valid() or not current.call(): return false
		var camera: Camera3D = get_parent().get("camera")
		var context: String = _context()
		var epoch: int = Key.generation
		var groups: Array[String] = []
		var submitted: Array[Dictionary] = []
		var materials: Dictionary = {}
		for index: int in range(pending.size()-1,-1,-1):
			var node: Object = pending[index].node.get_ref()
			if not is_instance_valid(node): pending.remove_at(index); continue
		for entry: Dictionary in pending:
			if not groups.has(entry.key): groups.append(entry.key)
			if groups.size() >= _batch_programs: break
		for key: String in groups:
			var ready: bool = _local_warmed.has(str(epoch)+context+key)
			var shown: int = 0
			for index: int in range(pending.size()-1,-1,-1):
				if pending[index].key != key: continue
				var entry: Dictionary = pending[index]
				var node: Object = entry.node.get_ref()
				# Only the scheduled group needs fresh keys. A changed finish moves
				# to its actual group before either drawing or accepting local reuse.
				entry.key = Key.geometry_key(node,materials)
				if entry.key != key: continue
				if ready: pending.remove_at(index); continue
				if shown >= Key.OBJECTS_PER_PROGRAM: continue
				if _copy(node,camera) == null: node.show()
				submitted.append(entry)
				pending.remove_at(index)
				shown += 1
		if submitted.is_empty(): continue
		var began: int = Time.get_ticks_usec()
		var drawn: bool = await draw.call()
		if not is_instance_valid(instance.get_ref()): return false
		_clear_copies()
		frame_groups += 1
		if not current.is_valid() or not current.call():
			pending.append_array(submitted)
			_fast_draws = 0
			_batch_programs = 1
			return false
		var valid_context: bool = drawn and epoch == Key.generation and context == _context()
		if valid_context and Time.get_ticks_usec()-began <= Key.FAST_DRAW_US:
			_fast_draws += 1
			if _fast_draws >= 2: _batch_programs = Key.PROGRAMS_PER_DRAW
		else:
			_fast_draws = 0
			_batch_programs = 1
		var valid_keys: Dictionary = {}
		materials = {} # The awaited draw may have changed finishes in place.
		for entry: Dictionary in submitted:
			var node: Object = entry.node.get_ref()
			var valid: bool = valid_context and is_instance_valid(node) and Key.geometry_key(node,materials) == entry.key
			valid_keys[entry.key] = bool(valid_keys.get(entry.key,true)) and valid
			if not valid: pending.append(entry)
		for key: String in valid_keys:
			if not valid_keys[key]: continue
			# Proxy draws certify this local pass only. The owning full-view
			# settle sequence publishes cross-view receipts after real captures.
			_local_warmed[str(epoch)+context+key] = true
			# The final complete main view and both reflection draws still
			# precede live reveal; other instances need no repeated program draw.
			for index: int in range(pending.size()-1,-1,-1):
				if pending[index].key != key: continue
				var node: Object = pending[index].node.get_ref()
				if not is_instance_valid(node): pending.remove_at(index); continue
				pending[index].key = Key.geometry_key(node,materials)
				if pending[index].key == key: pending.remove_at(index)
	return current.is_valid() and current.call()

func _exit_tree() -> void:
	release()
