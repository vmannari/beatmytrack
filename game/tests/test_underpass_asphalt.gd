extends SceneTree
## Returning bends retain their asphalt across a distant bridge-mouth plane.
const HEIGHT = preload("res://track/road_surface_height.gd")
const PREPARATION = preload("res://editor/road_preparation.gd")
const PATCH := Vector2(2.10801,-30.46882)
var checks: int = 0
var failures: int = 0
var measurements: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func area(polygon: PackedVector2Array) -> float:
	var value: float = 0.0
	for i: int in range(polygon.size()): value += (polygon[i]-polygon[0]).cross(polygon[(i+1)%polygon.size()]-polygon[0])
	return absf(value)*0.5

func review_mouth(pieces: Array, index: int, label: String) -> void:
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var shape: Dictionary = VisualRoadJoin.build(pieces,index,0.0,topology)
	var cuts: Array[Dictionary] = []
	for cut: Dictionary in RoadEdges._join_cuts(pieces,index,topology):
		var links: Array = RoadPieces._matches(topology,index,int(cut.endpoint))
		if links.size() == 1 and pieces[int(links[0][0])].kind == "bridge": cuts.append(cut)
	check(not cuts.is_empty(),label+" exercises an actual joined bridge mouth")
	var removed_area: float = 0.0
	var farthest: float = 0.0
	var maximum_depth: float = 0.0
	var clipped_valid: bool = true
	var cap_clear: bool = true
	var distant_vertices_retained: bool = true
	for polygon: PackedVector2Array in Geometry2D.offset_polygon(shape.contours[0],0.16,Geometry2D.JOIN_ROUND):
		var clipped: PackedVector2Array = HEIGHT.clip_bridge_mouths(polygon,pieces,index,topology)
		clipped_valid = clipped_valid and not Geometry2D.triangulate_polygon(clipped).is_empty()
		for point: Vector2 in polygon:
			var nearest: float = INF
			for cut: Dictionary in cuts:
				var across: Vector2 = Vector2(cut.normal).orthogonal()*float(cut.span)*0.5
				nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(cut.point)-across,Vector2(cut.point)+across)))
			if nearest > 0.25: distant_vertices_retained = distant_vertices_retained and clipped.has(point)
		for removed: PackedVector2Array in Geometry2D.clip_polygons(polygon,clipped):
			removed_area += area(removed)
			for point: Vector2 in removed:
				var nearest: float = INF
				for cut: Dictionary in cuts:
					var across: Vector2 = Vector2(cut.normal).orthogonal()*float(cut.span)*0.5
					nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(cut.point)-across,Vector2(cut.point)+across)))
					maximum_depth = maxf(maximum_depth,-(point-Vector2(cut.point)).dot(cut.normal))
				farthest = maxf(farthest,nearest)
		for cut: Dictionary in cuts:
			for across: float in [-0.4,0.0,0.4]:
				var point: Vector2 = Vector2(cut.point)+Vector2(cut.normal).orthogonal()*float(cut.span)*across
				cap_clear = cap_clear and not Geometry2D.is_point_in_polygon(point-Vector2(cut.normal)*0.08,clipped)
				cap_clear = cap_clear and Geometry2D.is_point_in_polygon(point+Vector2(cut.normal)*0.08,clipped)
	check(clipped_valid,label+" retains triangulatable asphalt")
	# Polygon Boolean output can carry a zero-area spur along an unchanged
	# edge. Exact retention of distant vertices avoids counting it as a cut.
	check(removed_area > 0.01 and removed_area < 2.0 and maximum_depth <= 0.161 and distant_vertices_retained,label+" trims only the local 16 cm cap")
	check(cap_clear,label+" meets the bridge plane without a ground cap under the deck")
	measurements.append({"fixture":label,"removed_m2":removed_area,"furthest_removed_m":farthest,"maximum_depth_m":maximum_depth})

func coverage(arrays: Array, point: Vector2) -> int:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count: int = 0
	for first: int in range(0,vertices.size(),3):
		var polygon := PackedVector2Array()
		for i: int in range(3):
			var p: Vector3 = vertices[first+i]
			if absf(p.y-0.062) > 0.00001: break
			polygon.append(Vector2(p.x,-p.z))
		if polygon.size() == 3 and area(polygon) > 0.000001 and Geometry2D.is_point_in_polygon(point,polygon): count += 1
	return count

func packet_coverage(packet: Dictionary, point: Vector2) -> int:
	var count: int = 0
	for part: Dictionary in packet.parts:
		if part.role == "road" and part.arguments[5] and not part.arguments[6]: count += coverage(part.arrays,point)
	return count

func mesh_coverage(visual: NativeTrackVisual, point: Vector2) -> int:
	var count: int = 0
	for child: Node in visual.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial: continue
		if child.material_override.get_shader_parameter("asphalt_surface") != true or child.material_override.get_shader_parameter("edge_fringe") == true: continue
		count += coverage(child.mesh.surface_get_arrays(0),point)
	return count

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/underpass.json"))
	var frozen_document: PackedByteArray = var_to_bytes(document)
	review_mouth(document.pieces,5,"original Underpass 216-degree bend")
	for angle: float in [90.0,180.0,216.0,270.0]:
		for flip: bool in [false,true]:
			for bridge_start: bool in [false,true]:
				var curve: Dictionary = RoadPieces.create("curve",Vector2(80,-110),37,10)
				curve.angle = angle
				curve.radius = 12.0
				curve.flip = flip
				var before: Dictionary = RoadPieces.create("bridge" if bridge_start else "straight",Vector2(80,-110)-Vector2.RIGHT.rotated(deg_to_rad(37))*30.0,37,10)
				before.length = 30.0
				var end: Dictionary = RoadPieces.end_pose(curve)
				var after: Dictionary = RoadPieces.create("straight" if bridge_start else "bridge",end.position,end.heading,10)
				after.length = 30.0
				review_mouth([before,curve,after],1,"%s degrees / flip %s / bridge start %s"%[angle,flip,bridge_start])
	for theme: String in ["night_city","pine","storm"]:
		var doc: Dictionary = document.duplicate(true)
		doc.theme = theme
		var track: NativeTrack = TrackCompiler.compile(doc)
		var support: RefCounted = HEIGHT.new(track)
		check(support.on_floor(PATCH),theme+" missing triangle retains asphalt presentation support")
		var packet: Dictionary = PREPARATION.prepare(track,true)
		check(packet_coverage(packet,PATCH) == 1,theme+" prepared CPU asphalt covers the reported hole exactly once")
		var direct := NativeTrackVisual.new()
		direct.cache_road_meshes = false
		direct.persist_road_meshes = false
		direct.theme_id = theme
		direct.colors = TrackTheme.palette(theme)
		root.add_child(direct)
		direct._build_creator_roads(track)
		check(mesh_coverage(direct,PATCH) == 1,theme+" direct native asphalt covers the reported hole exactly once")
		var restored := NativeTrackVisual.new()
		restored.theme_id = theme
		restored.colors = TrackTheme.palette(theme)
		restored.ground_support = support
		root.add_child(restored)
		restored._install_prepared_roads(track,packet)
		check(mesh_coverage(restored,PATCH) == 1,theme+" uploaded prepared asphalt covers the reported hole exactly once")
		direct.free()
		restored.free()
		if theme == "night_city": check(track.content_hash == "259e7adadd65d5365d03af4210db47f199ff4f93d89f02364972cec7bc8ae3ce","published Underpass native hash remains unchanged")
	check(var_to_bytes(document) == frozen_document,"original document, route, start and identities remain unchanged")
	var report_path: String = "res://../docs/evidence/underpass-artifact-2026-10-15/coverage-"+RenderingServer.get_current_rendering_method()+".json"
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"mouths":measurements},"\t"))
	print("UNDERPASS_ASPHALT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
