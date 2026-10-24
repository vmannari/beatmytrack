extends RefCounted
## Transient planning detail only. Full meshes remain owned by the editor and
## are restored when the view settles close enough to inspect their details.
const DENSE_COUNT: int = 24
const OVERVIEW_SCALE: float = 8.0
const EXACT_KINDS: Array[String] = ["oil","puddle","jump","speed_bump","dirt","water","tyre_stack","tyre_wall","gantry","chevron","braking_board","neon_arrow","banner","flag","light","lantern_post"]
var reduced: bool = false
var enabled: bool = true
var proxies: Node3D
var _visual: NativeTrackVisual
var _track: NativeTrack
var _updates: int = -1
var _selected: int = -2
var _scale: float = -1.0
var _until: int = 0
var _proxy_groups: Array[Dictionary] = []
var _members: Dictionary = {}
var _objects: Array = []
var _dense: bool = false
var _proxy_dirty: bool = true

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
	if not rebuilt and next == reduced and canvas.selected_object == _selected and (not reduced or is_equal_approx(_scale,canvas.scale_factor())): return false
	if next and _proxy_dirty:
		_rebuild(visual,track,batches)
		_proxy_dirty = false
	reduced = next; _selected = canvas.selected_object; _scale = canvas.scale_factor()
	light.shadow_enabled = not reduced
	if is_instance_valid(visual.editor_cover): visual.editor_cover.visible = not reduced
	# Generated trees are already one scenery batch. Keep their recognizable
	# silhouettes; the expensive authored props are the overview replacement.
	if is_instance_valid(visual.editor_scenery): visual.editor_scenery.visible = true
	var retained: Dictionary = {}
	for key: String in batches.groups:
		var selected: bool = key == "tyres" or key.begins_with("shadow:")
		if reduced:
			for index: int in _members.get(key,[]):
				var size: Vector2 = CreatorObjects.size_of(_objects[index])
				if index == _selected or str(_objects[index].kind) in EXACT_KINDS or minf(size.x,size.y)*_scale >= 24.0: selected = true
		for node: GeometryInstance3D in batches.groups[key].nodes: node.visible = not reduced or selected
		if selected:
			for index: int in _members.get(key,[]): retained[index] = true
	for index: int in batches.individuals:
		var keep: bool = index == _selected or str(_objects[index].kind) in EXACT_KINDS
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
	for index: int in range(_objects.size()):
		var encoded: String = JSON.stringify(_objects[index],"",true)
		if not source_indices.has(encoded): source_indices[encoded] = []
		source_indices[encoded].append(index)
	for key: String in batches.groups:
		var indices: Array[int] = []
		var entry: Dictionary = batches.groups[key]
		for source: String in entry.get("sources",[]):
			var encoded: String = source.get_slice("/ground=",0)
			for index: int in source_indices.get(encoded,[]):
				if not indices.has(index): indices.append(index)
		if not key.begins_with("shadow:") and indices.is_empty():
			for pose: Transform3D in entry.get("poses",[]):
				for index: int in range(_objects.size()):
					var position := Vector2(_objects[index].position[0],_objects[index].position[1])
					if position.distance_squared_to(Vector2(pose.origin.x,-pose.origin.z)) < 0.0001 and not indices.has(index): indices.append(index)
		_members[key] = indices
	var groups: Dictionary = {}
	var objects: Array = _objects
	for index: int in range(objects.size()):
		var object: Dictionary = objects[index]
		var kind: String = str(object.kind)
		if kind in EXACT_KINDS: continue # Their exact gameplay cues stay visible.
		var shape: String = "tree" if kind == "tree" else "round" if kind in ["broadleaf","bush","rock","boulder","snowman"] else "box"
		var color: Color = Color(ContainerPaint.value(object)) if kind == "container" else Color("647b4a") if kind in ["tree","broadleaf","bush","grass_clump","flowers"] else Color("d1d9d6") if kind in PropWinterCraft.KINDS else Color("9b8d71")
		var key: String = shape+color.to_html()
		if not groups.has(key): groups[key] = {"shape":shape,"color":color,"poses":[],"indices":[]}
		var size: Vector2 = CreatorObjects.size_of(object)
		var height: float = (5.0 if shape == "tree" else 2.6 if kind == "container" else 2.0 if shape == "round" else 1.2)*float(object.get("scale",1.0))
		var point := Vector2(object.position[0],object.position[1])
		var elevation: float = visual.ground_support.ground(point) if visual.ground_support != null else 0.0
		if visual.desert_relief != null: elevation += visual.desert_relief.height(point)
		var basis := Basis(Vector3.UP,deg_to_rad(float(object.get("rotation",0.0))))*Basis.from_scale(Vector3(size.x,height,size.y))
		groups[key].poses.append(Transform3D(basis,VisualGeometry.world(point)+Vector3.UP*(elevation+height*0.5)))
		groups[key].indices.append(index if index < _objects.size() else -1)
	for group: Dictionary in groups.values():
		var mesh: PrimitiveMesh
		if group.shape == "tree":
			var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.5; cone.height = 1.0; cone.radial_segments = 8; mesh = cone
		elif group.shape == "round":
			var sphere := SphereMesh.new(); sphere.radius = 0.5; sphere.height = 1.0; sphere.radial_segments = 8; sphere.rings = 4; mesh = sphere
		else:
			var box := BoxMesh.new(); box.size = Vector3.ONE; mesh = box
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new(); node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = mesh; node.multimesh.instance_count = group.poses.size()
		node.material_override = VisualGeometry.material(group.color)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxies.add_child(node); group.node = node; _proxy_groups.append(group)
