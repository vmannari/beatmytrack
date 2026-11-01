extends RefCounted
## Transient planning detail only. Full meshes remain owned by the editor and
## are restored when the view settles close enough to inspect their details.
const DENSE_COUNT: int = 24
const OVERVIEW_SCALE: float = 8.0
const EXACT_KINDS: Array[String] = ["oil","puddle","jump","speed_bump","dirt","water","tyre_stack","tyre_wall","gantry","chevron","braking_board","neon_arrow","banner","flag","light","lantern_post","burning_car","burning_barrel","snow_lantern","ice_lantern"]
var reduced: bool = false
var enabled: bool = true
var proxies: Node3D
var _visual: NativeTrackVisual
var _track: NativeTrack
var _updates: int = -1
var _selected: int = -2
var _selection: Array[int] = []
var _scale: float = -1.0
var _until: int = 0
var _proxy_groups: Array[Dictionary] = []
var _members: Dictionary = {}
var _objects: Array = []
var _dense: bool = false
var _proxy_dirty: bool = true
var _applied_enabled: bool = true
var _cover_id: int = 0

func update(visual: NativeTrackVisual, track: NativeTrack, canvas: EditorCanvas, light: DirectionalLight3D, moving: bool) -> bool:
	if visual == null or track == null or visual.editor_objects == null: return false
	var batches: RefCounted = visual.editor_objects._editor_authored_batches
	if batches == null: return false
	var rebuilt: bool = visual != _visual or track != _track or batches.updates != _updates
	if rebuilt:
		_visual = visual; _track = track; _updates = batches.updates
		_objects = batches.sources
		_proxy_dirty = true
	if rebuilt or moving:
		var visible_count: int = 0
		var area := Rect2(Vector2.ZERO,canvas.size).grow(96.0)
		for object: Dictionary in _objects:
			if area.has_point(canvas.to_screen(Vector2(object.position[0],object.position[1]))): visible_count += 1
		_dense = visible_count >= DENSE_COUNT
	if moving or canvas.active_pointer != -99: _until = Time.get_ticks_msec()+140
	var next: bool = enabled and _dense and (canvas.scale_factor() < OVERVIEW_SCALE or Time.get_ticks_msec() < _until)
	var selection: Array[int] = canvas.object_indices()
	var cover_id: int = visual.editor_cover.get_instance_id() if is_instance_valid(visual.editor_cover) else 0
	if not rebuilt and next == reduced and selection == _selection and enabled == _applied_enabled and cover_id == _cover_id and (not reduced or is_equal_approx(_scale,canvas.scale_factor())): return false
	if next and _proxy_dirty:
		_rebuild(visual,track,batches)
		_proxy_dirty = false
	reduced = next; _selected = canvas.selected_object; _selection = selection; _scale = canvas.scale_factor()
	_applied_enabled = enabled; _cover_id = cover_id
	light.shadow_enabled = not reduced
	# Small decorative ground flecks compete with selection dots. The explicit
	# Detailed scenery view restores this race decoration for appearance checks.
	if is_instance_valid(visual.editor_cover): visual.editor_cover.visible = not enabled
	# Generated trees are already one scenery batch. Keep their recognizable
	# silhouettes; the expensive authored props are the overview replacement.
	if is_instance_valid(visual.editor_scenery): visual.editor_scenery.visible = true
	var retained: Dictionary = {}
	for key: String in batches.groups:
		var selected: bool = key == "tyres" or key.begins_with("shadow:")
		if reduced:
			for index: int in _members.get(key,[]):
				var size: Vector2 = CreatorObjects.size_of(_objects[index])
				if index in selection or str(_objects[index].kind) in EXACT_KINDS or minf(size.x,size.y)*_scale >= 24.0: selected = true
		for node: GeometryInstance3D in batches.groups[key].nodes: node.visible = not reduced or selected
		if selected:
			for index: int in _members.get(key,[]): retained[index] = true
	for index: int in batches.individuals:
		var keep: bool = index in selection or str(_objects[index].kind) in EXACT_KINDS
		batches.individuals[index].node.visible = not reduced or keep
		if keep: retained[index] = true
	if reduced:
		for group: Dictionary in _proxy_groups:
			var cursor: int = 0
			for index: int in range(group.poses.size()):
				if int(group.indices[index]) >= 0 and retained.has(int(group.indices[index])): continue
				group.node.multimesh.set_instance_transform(cursor,group.poses[index]); cursor += 1
			group.node.multimesh.visible_instance_count = cursor
	if is_instance_valid(proxies): proxies.visible = reduced
	return true

func _rebuild(visual: NativeTrackVisual, track: NativeTrack, batches: RefCounted) -> void:
	if is_instance_valid(proxies): proxies.queue_free()
	proxies = Node3D.new(); proxies.name = "EditorOverviewProps"; proxies.hide(); visual.add_child(proxies)
	_proxy_groups.clear(); _members.clear()
	_objects = batches.sources
	var source_indices: Dictionary = {}
	var position_index: Dictionary = {}
	var position_index_ready: bool = false
	for index: int in range(_objects.size()):
		var encoded: String = JSON.stringify(_objects[index],"",true)
		if not source_indices.has(encoded): source_indices[encoded] = []
		source_indices[encoded].append(index)
	for key: String in batches.groups:
		var indices: Array[int] = []
		var seen: Dictionary = {}
		var entry: Dictionary = batches.groups[key]
		for source: String in entry.get("sources",[]):
			var encoded: String = source.get_slice("/ground=",0)
			for index: int in source_indices.get(encoded,[]):
				if not seen.has(index): indices.append(index); seen[index] = true
		if key == "tyres":
			for index: int in range(_objects.size()):
				if _objects[index].kind in ["tyre_stack","tyre_wall"]: indices.append(index)
		elif not key.begins_with("shadow:") and indices.is_empty():
			var poses: Array = entry.get("poses",[])
			if not poses.is_empty():
				if not position_index_ready:
					position_index = _index_positions(_objects)
					position_index_ready = true
				indices = _pose_indices(_objects,poses,position_index)
		_members[key] = indices
	var groups: Dictionary = {}
	var objects: Array = _objects
	for index: int in range(objects.size()):
		var object: Dictionary = objects[index]
		var kind: String = str(object.kind)
		if kind in EXACT_KINDS: continue # Their exact gameplay cues stay visible.
		var color: Color = preload("res://editor/overview_prop_models.gd").color(kind,visual.theme_id,object)
		var key: String = kind+"/"+color.to_html()
		if not groups.has(key): groups[key] = {"kind":kind,"color":color,"poses":[],"indices":[]}
		var size: Vector2 = CreatorObjects.size_of(object)
		var height: float = preload("res://editor/overview_prop_models.gd").height(kind)*float(object.get("scale",1.0))
		var point := Vector2(object.position[0],object.position[1])
		var elevation: float = visual.ground_support.ground(point) if visual.ground_support != null else 0.0
		if visual.desert_relief != null: elevation += visual.desert_relief.height(point)
		var basis := Basis(Vector3.UP,deg_to_rad(float(object.get("rotation",0.0))))*Basis.from_scale(Vector3(size.x,height,size.y))
		groups[key].poses.append(Transform3D(basis,VisualGeometry.world(point)+Vector3.UP*(elevation+height*0.5)))
		groups[key].indices.append(index if index < _objects.size() else -1)
	for group: Dictionary in groups.values():
		var mesh: ArrayMesh = preload("res://editor/overview_prop_models.gd").mesh(group.kind,group.color)
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new(); node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = mesh; node.multimesh.instance_count = group.poses.size()
		node.material_override = VisualGeometry.material(Color.WHITE)
		(node.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxies.add_child(node); group.node = node; _proxy_groups.append(group)

# Match the previous strict 1 cm radius test, including nearby cell boundaries.
# Sorting candidates preserves the old object-order traversal for each pose.
static func _index_positions(objects: Array) -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(objects.size()):
		var position := Vector2(objects[index].position[0],objects[index].position[1])
		var cell := Vector2i(floori(position.x*100.0),floori(position.y*100.0))
		if not result.has(cell): result[cell] = []
		result[cell].append(index)
	return result

static func _pose_indices(objects: Array, poses: Array, position_index: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var seen: Dictionary = {}
	for pose: Transform3D in poses:
		var point := Vector2(pose.origin.x,-pose.origin.z)
		var cell := Vector2i(floori(point.x*100.0),floori(point.y*100.0))
		var candidates: Array = []
		for x: int in range(-1,2):
			for y: int in range(-1,2): candidates.append_array(position_index.get(cell+Vector2i(x,y),[]))
		candidates.sort()
		for index: int in candidates:
			var position := Vector2(objects[index].position[0],objects[index].position[1])
			if position.distance_squared_to(point) < 0.0001 and not seen.has(index):
				result.append(index); seen[index] = true
	return result
