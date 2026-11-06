extends Node
## Stage first use of actual material/mesh combinations under the loading cover.
## Lifetime belongs to Game, so navigation cannot leave hidden surviving meshes.
const Graphics = preload("res://rendering/graphics_preparation.gd")
const FAST_DRAW_US: int = Graphics.FAST_DRAW_US
static var warmed: Dictionary = Graphics.warmed
var programs_per_draw: int = Graphics.PROGRAMS_PER_DRAW
var adaptive: bool = true
var _batch_programs: int = 1
var _fast_draws: int = 0
# Insertion order retains the original first-seen program order; each bucket
# is consumed from the end, just like the former reverse scan of all nodes.
var pending: Dictionary = {}
var _pending_keys: Array[String] = []
var _key_cursor: int = 0
var frame_groups: int = 0
var draw_us_max: int = 0
var _material_keys: Dictionary = {}
var _world: WeakRef
var _hold_context: String = ""
var _active_margins: Array[Dictionary] = []

func hold(world: Node) -> void:
	_world = weakref(world)
	_hold_context = ""
	for geometry: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		if not geometry.is_visible_in_tree(): continue
		hold_geometry(geometry)

func hold_geometry(geometry: GeometryInstance3D) -> void:
	if _world == null: _world = weakref(geometry.get_parent())
	var key: String = _key(geometry,_material_keys)
	var camera: Camera3D = get_parent().get("camera") if get_parent() != null else null
	if camera != null:
		if _hold_context.is_empty(): _hold_context = Graphics.context(_view(),_world.get_ref(),camera)
		if Graphics.cacheable(geometry) and Graphics.ready(_hold_context,Graphics.receipt_key(geometry,_hold_context,_material_keys)): return
	if not pending.has(key):
		pending[key] = []
		_pending_keys.append(key)
	pending[key].append(weakref(geometry))
	geometry.hide()

func _view() -> Viewport:
	return get_parent().showroom_viewport if "showroom_viewport" in get_parent() else get_viewport()

func prepare(draw: Callable, current: Callable) -> bool:
	var instance: WeakRef = weakref(self)
	var camera: Camera3D = get_parent().get("camera")
	var world: Node = _world.get_ref() if _world != null else null
	var context: String = Graphics.context(_view(),world,camera)
	while not pending.is_empty():
		if not current.is_valid() or not current.call(): return false
		_material_keys.clear()
		var epoch: int = Graphics.generation
		var submitted: Array[Dictionary] = []
		var margins: Array[Dictionary] = []
		var budget: int = mini(_batch_programs,programs_per_draw) if adaptive else programs_per_draw
		while not pending.is_empty() and submitted.size() < clampi(budget,1,Graphics.PROGRAMS_PER_DRAW):
			while _key_cursor < _pending_keys.size() and not pending.has(_pending_keys[_key_cursor]): _key_cursor += 1
			if _key_cursor >= _pending_keys.size(): break
			var key: String = _pending_keys[_key_cursor]
			var bucket: Array = pending[key]
			# Keys are rechecked after yields. Changed programs must get a real draw.
			var refreshed: Array = []
			for reference: WeakRef in bucket:
				var node: Object = reference.get_ref()
				if not is_instance_valid(node): continue
				var actual: String = _key(node,_material_keys)
				if actual != key:
					if not pending.has(actual): pending[actual] = []; _pending_keys.append(actual)
					pending[actual].append(reference)
				elif Graphics.cacheable(node) and Graphics.ready(context,Graphics.receipt_key(node,context,_material_keys)): node.show()
				else: refreshed.append(reference)
			bucket.assign(refreshed)
			if bucket.is_empty(): pending.erase(key); continue
			var sources: Array[Dictionary] = []
			while not bucket.is_empty() and sources.size() < Graphics.OBJECTS_PER_PROGRAM:
				var node: Object = bucket.pop_back().get_ref()
				if not is_instance_valid(node): continue
				if node is MeshInstance3D and camera != null:
					margins.append({"node":weakref(node),"margin":node.extra_cull_margin})
					var bounds: AABB = node.get_aabb()
					var distance: Vector3 = (node.to_local(camera.global_position)-bounds.get_center()).abs()
					node.extra_cull_margin = maxf(node.extra_cull_margin,maxf(distance.x,maxf(distance.y,distance.z))+camera.near+1.0)
				node.show()
				sources.append({"node":weakref(node),"key":key,"receipt":Graphics.receipt_key(node,context,_material_keys)})
			if sources.is_empty(): pending.erase(key); continue
			submitted.append({"key":key,"bucket":bucket,"sources":sources})
			# Leave a failed program at this cursor so its remaining geometry
			# participates in the next real draw, preserving the retry contract.
			_key_cursor += 1
		if submitted.is_empty(): continue
		var began: int = Time.get_ticks_usec()
		_active_margins = margins
		var drawn: bool = await draw.call()
		for entry: Dictionary in margins:
			var node: Object = entry.node.get_ref()
			if is_instance_valid(node): node.extra_cull_margin = entry.margin
		if not is_instance_valid(instance.get_ref()): return false
		_active_margins = []
		if not current.is_valid() or not current.call(): return false
		draw_us_max = maxi(draw_us_max,Time.get_ticks_usec()-began)
		# Begin conservatively. Slow native/driver work restores one program
		# per interval; two fast real draws admit the bounded warm batch.
		if drawn and Time.get_ticks_usec()-began <= FAST_DRAW_US:
			_fast_draws += 1
			if _fast_draws >= 2: _batch_programs = Graphics.PROGRAMS_PER_DRAW
		else:
			_fast_draws = 0
			_batch_programs = 1
		frame_groups += 1
		var valid_context: bool = epoch == Graphics.generation and context == Graphics.context(_view(),world,camera)
		if not valid_context: _fast_draws = 0; _batch_programs = 1
		_material_keys.clear()
		for group: Dictionary in submitted:
			var valid: bool = drawn and valid_context
			for source: Dictionary in group.sources:
				var node: Object = source.node.get_ref()
				if not is_instance_valid(node) or _key(node,_material_keys) != source.key or Graphics.receipt_key(node,context,_material_keys) != source.receipt: valid = false
			if valid:
				for source: Dictionary in group.sources:
					# Expanded staging bounds may select a different set of local
					# lights. Spatial views publish only their normal full captures.
					if not Graphics.spatial_context(context) and Graphics.cacheable(source.node.get_ref()): Graphics.complete(context,source.receipt,epoch)
				for reference: WeakRef in group.bucket:
					var node: Object = reference.get_ref()
					if is_instance_valid(node): node.show()
				pending.erase(group.key)
			elif group.bucket.is_empty():
				for source: Dictionary in group.sources:
					if is_instance_valid(source.node.get_ref()): group.bucket.append(source.node)
		# Rescan unresolved groups after a failed draw, mutation or invalidation.
		_key_cursor = 0
		context = Graphics.context(_view(),world,camera)
	_material_keys.clear()
	_pending_keys.clear()
	_key_cursor = 0
	return current.call()

static func _key(node: GeometryInstance3D, materials: Dictionary = {}) -> String:
	return Graphics.geometry_key(node,materials)

static func _material_key(material: Material, cache: Dictionary) -> String:
	return Graphics._material_key(material,cache)

func release() -> void:
	for entry: Dictionary in _active_margins:
		var node: Object = entry.node.get_ref()
		if is_instance_valid(node): node.extra_cull_margin = entry.margin
	_active_margins.clear()
	for bucket: Array in pending.values():
		for reference: WeakRef in bucket:
			var node: Object = reference.get_ref()
			if is_instance_valid(node): node.show()
	pending.clear()
	_pending_keys.clear()
	_key_cursor = 0
	_material_keys.clear()
	_hold_context = ""

func _exit_tree() -> void:
	release()
