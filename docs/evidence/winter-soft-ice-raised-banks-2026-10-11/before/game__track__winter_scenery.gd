class_name WinterScenery
extends RefCounted
## Original snow-covered instanced kit. Placement never changes canonical cells.
const TYPES: Array[String] = ["tree","broadleaf","bush","rock","boulder","slate","fence"]
const TILE: float = 32.0
static var meshes: Dictionary = {}
static var surface: StandardMaterial3D

static func material() -> StandardMaterial3D:
	if surface == null:
		surface = StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		surface.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		surface.roughness = 0.95
		surface.metallic_specular = 0.0
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	return surface

static func mesh_for(kind: String, length: float = -1.0) -> ArrayMesh:
	var cache_key: String = kind+":"+str(length)
	if meshes.has(cache_key): return meshes[cache_key]
	var kit := NativeTrackVisual.new()
	kit.theme_id = "pine"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "tree": CreatorPropVisual.pine(tool,kit,Vector3.ZERO,1.25,0.0,Color("294a47"))
	elif kind == "marker":
		kit._colored_box(tool,Vector3(0,0.60,0),Vector3(0.09,1.20,0.09),0.0,Color("a43327"))
		for y: float in [0.88,1.08]: kit._colored_box(tool,Vector3(0,y,0),Vector3(0.095,0.10,0.095),0.0,Color("e4e7da"))
		kit._colored_box(tool,Vector3(0,0.10,0),Vector3(0.13,0.20,0.13),0.0,Color("665343"))
	elif kind == "twig":
		for i: int in range(5):
			var angle: float = i*2.4
			kit._colored_box(tool,Vector3(sin(angle)*0.20,0.30,cos(angle)*0.20),Vector3(0.026,0.65,0.026),angle,Color("62534c"))
	else: CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1.0,0.0,length)
	tool.generate_normals()
	var original: ArrayMesh = tool.commit()
	var arrays: Array = original.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i: int in range(vertices.size()):
		var cover: float = smoothstep(0.13,0.62,normals[i].y) * smoothstep(0.15,0.50,vertices[i].y)
		if kind == "marker" or kind == "twig": cover = 0.0
		var snow := Color("d7e2ed").darkened(0.025*(i%5))
		colors[i] = colors[i].lerp(snow,cover*0.96)
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.surface_set_material(0,material())
	if meshes.size() >= 64: meshes.erase(meshes.keys()[0])
	meshes[cache_key] = result
	kit.free()
	return result

static func batch(parent: Node3D, groups: Dictionary) -> void:
	for key: String in groups:
		var poses: Array[Transform3D] = groups[key]
		var kind: String = key.get_slice("|",0)
		var node := MultiMeshInstance3D.new()
		node.name = "Winter_" + kind
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh_for(kind,float(key.get_slice("|",3)))
		instances.instance_count = poses.size()
		for i: int in range(poses.size()): instances.set_instance_transform(i,poses[i])
		node.multimesh = instances
		node.material_override = material()
		if poses[0].basis.get_scale().x < 0.5 or kind == "twig":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)

static func append_pose(groups: Dictionary, kind: String, point: Vector2, scale: float, rotation: float, length: float = -1.0) -> void:
	var tile := Vector2i((point/TILE).floor())
	var key: String = "%s|%d|%d|%s" % [kind,tile.x,tile.y,str(length)]
	if not groups.has(key): groups[key] = [] as Array[Transform3D]
	groups[key].append(Transform3D(Basis(Vector3.UP,rotation).scaled(Vector3.ONE*scale),VisualGeometry.world(point)+Vector3.UP*0.015))

static func build_authored(parent: Node3D, track: NativeTrack) -> void:
	var groups: Dictionary = {}
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[]) + track.metadata.get("scenery_objects",[]):
		if str(object.kind) not in TYPES: continue
		var scale: float = float(object.get("scale",1.0))
		append_pose(groups,str(object.kind),Vector2(object.position[0],object.position[1]),scale,deg_to_rad(float(object.get("rotation",0.0))),float(object.length)/scale if object.has("length") else -1.0)
	batch(parent,groups)

static func build_cover(parent: NativeTrackVisual, track: NativeTrack) -> void:
	var groups: Dictionary = {}
	var sites: Array[Vector2i] = parent._scenery_sites(track,maxi(1,ceili(5.5/track.cell_size)))
	var count: int = 0
	for cell: Vector2i in sites:
		if count >= 180: break
		if not parent._cover_clear(track,cell,1.8): continue
		var seed: int = (cell.x*73856093 ^ cell.y*19349663)&0x7fffffff
		var point := Vector2((cell.x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(cell.y+0.5)*track.cell_size)
		var kind: String = "rock" if seed%4 == 0 else "twig" if seed%4 == 1 else "bush"
		var scale: float = (0.30 if kind == "rock" else 0.40) + float(seed%9)*0.015
		append_pose(groups,kind,point,scale,float(seed%360)*PI/180.0)
		count += 1
	var markers: Array[Dictionary] = marker_sites(track)
	for marker: Dictionary in markers: append_pose(groups,"marker",marker.position,1.0,0.0)
	batch(parent,groups)
	parent.set_meta("winter_cover_count",count)
	parent.set_meta("winter_marker_count",markers.size())

static func marker_sites(track: NativeTrack) -> Array[Dictionary]:
	# True metre spacing replaces square buckets, which crowded short inside arcs.
	var occupied: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for triangle: Dictionary in track.snow_banks.triangles:
		var points: PackedVector2Array = triangle.points
		var heights: PackedFloat32Array = triangle.heights
		for i: int in range(3):
			if heights[i] < 0.30: continue
			var point: Vector2 = points[i]
			var index: int = track.nearest_route(point)
			var center: Vector2 = track.route[index]
			var before: Vector2 = track.route[posmod(index-3,track.route.size())]
			var after: Vector2 = track.route[(index+3)%track.route.size()]
			var side: int = 1 if (after-before).normalized().orthogonal().dot(point-center) >= 0.0 else -1
			var inside: bool = (before+after-center*2.0).dot(point-center) > 0.01
			var key: String = "%d:%d:%d" % [floori(point.x/6.0),floori(point.y/6.0),side]
			if occupied.has(key): continue
			if CreatorBridges.at_any(track.creator_bridges,point): continue
			occupied[key] = true
			candidates.append({"position":point,"side":side,"inside":inside,"route":index,"spacing":28.0 if inside else 18.0})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.inside != b.inside: return not a.inside
		if a.route != b.route: return a.route < b.route
		if a.position.x != b.position.x: return a.position.x < b.position.x
		return a.position.y < b.position.y)
	var result: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if result.size() >= 40: break
		var clear: bool = true
		for existing: Dictionary in result:
			var minimum: float = maxf(candidate.spacing,existing.spacing) if candidate.side == existing.side else 7.5
			if candidate.position.distance_to(existing.position) < minimum: clear = false; break
		if clear: result.append(candidate)
	return result
