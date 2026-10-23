extends SceneTree
## Independent scanline coverage of the retained Free Race document snapshot.
const HEIGHT = preload("res://track/road_surface_height.gd")
const PREPARATION = preload("res://editor/road_preparation.gd")
const SPACING: float = 0.25
const EDGE_PRECISION: float = 0.0001
const OUTPUT: String = "res://../docs/evidence/catalog-road-review-2026-10-16/"
var results: Array[Dictionary] = []
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func surfaces(document: Dictionary) -> Array[PackedVector2Array]:
	var pieces: Array = document.pieces
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var result: Array[PackedVector2Array] = []
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var shape: Dictionary = VisualRoadJoin.build(pieces,index,0.0,topology)
		var contours: Array[PackedVector2Array] = RoadEdges.section_contours(pieces,index,0.0,topology) if pieces[index].kind == "spline" else shape.contours
		var swept: bool = pieces[index].kind == "spline" or shape.get("swept",false)
		var polygons: Array[PackedVector2Array] = SplineBorders.surface(SplineBorders.offset(contours,0.16)) if swept else Geometry2D.offset_polygon(contours[0],0.16,Geometry2D.JOIN_ROUND)
		for polygon: PackedVector2Array in polygons:
			if document.theme not in ["desert","winter"]: polygon = HEIGHT.clip_bridge_mouths(polygon,pieces,index,topology)
			if polygon.size() >= 3: result.append(polygon)
	return result

func triangulated(polygons: Array[PackedVector2Array], clipper: RefCounted) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for i: int in range(0,indices.size(),3):
			var triangle := PackedVector2Array([polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]]])
			if clipper == null: result.append(triangle)
			else: clipper._add_triangle(triangle,Vector3.ZERO)
	if clipper != null:
		var lists: Dictionary = {}
		for i: int in range(clipper.triangles.size()):
			for polygon: PackedVector2Array in clipper._fragments(i,clipper.triangles[i],lists):
				var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
				for j: int in range(0,indices.size(),3): result.append(PackedVector2Array([polygon[indices[j]],polygon[indices[j+1]],polygon[indices[j+2]]]))
	return result

func intervals(polygon: PackedVector2Array, y: float) -> Array[Vector2]:
	var hits: Array[float] = []
	for i: int in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		if not ((a.y <= y and b.y > y) or (b.y <= y and a.y > y)): continue
		hits.append(float(a.x)+(y-float(a.y))*(float(b.x)-a.x)/(float(b.y)-a.y))
	hits.sort()
	var result: Array[Vector2] = []
	for i: int in range(0,hits.size()-1,2): result.append(Vector2(hits[i],hits[i+1]))
	return result

func rows(polygons: Array[PackedVector2Array]) -> Dictionary:
	var result: Dictionary = {}
	for polygon: PackedVector2Array in polygons:
		var low: float = INF
		var high: float = -INF
		for point: Vector2 in polygon: low = minf(low,point.y); high = maxf(high,point.y)
		for row: int in range(ceili((low-0.071)/SPACING),ceili((high-0.071)/SPACING)):
			if not result.has(row): result[row] = []
			result[row].append_array(intervals(polygon,row*SPACING+0.071))
	return result

func merged(values: Array) -> Array[Vector2]:
	values.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x < b.x)
	var result: Array[Vector2] = []
	for value: Vector2 in values:
		if value.y <= value.x: continue
		if result.is_empty() or value.x > result[-1].y: result.append(value)
		elif value.y > result[-1].y: result[-1].y = value.y
	return result

func boundary_bins(polygons: Array[PackedVector2Array]) -> Dictionary:
	var result: Dictionary = {}
	for polygon: PackedVector2Array in polygons:
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i+1)%polygon.size()]
			var bounds := Rect2(a,Vector2.ZERO).expand(b).grow(EDGE_PRECISION)
			for y: int in range(floori(bounds.position.y/4),floori(bounds.end.y/4)+1):
				for x: int in range(floori(bounds.position.x/4),floori(bounds.end.x/4)+1):
					var key := Vector2i(x,y)
					if not result.has(key): result[key] = PackedVector4Array()
					result[key].append(Vector4(a.x,a.y,b.x,b.y))
	return result

func gap_distance(gap: Dictionary, bins: Dictionary) -> float:
	# A near-horizontal boundary amplifies a microscopic perpendicular error
	# into a longer horizontal interval. Measure distance to the actual mesh,
	# retaining the same fixed 0.1 mm allowance used by the Ajorata regression.
	var maximum: float = 0.0
	for fraction: float in [-0.25,0.0,0.25]:
		var point := Vector2(gap.point[0]+fraction*float(gap.width_m),gap.point[1])
		var nearest: float = INF
		for edge: Vector4 in bins.get(Vector2i(floori(point.x/4),floori(point.y/4)),PackedVector4Array()):
			nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(edge.x,edge.y),Vector2(edge.z,edge.w))))
		maximum = maxf(maximum,nearest)
	return maximum

func compare(expected: Dictionary, actual: Array[PackedVector2Array]) -> Dictionary:
	var actual_rows: Dictionary = rows(actual)
	var gaps: Array[Dictionary] = []
	var area: float = 0.0
	var numeric: int = 0
	var numeric_width: float = 0.0
	for row: int in expected:
		var visible: Array[Vector2] = merged(actual_rows.get(row,[]))
		for wanted: Vector2 in expected[row]:
			var cursor: float = wanted.x
			for interval: Vector2 in visible:
				if interval.y <= cursor: continue
				if interval.x >= wanted.y: break
				if interval.x > cursor:
					var width: float = minf(interval.x,wanted.y)-cursor
					if width > EDGE_PRECISION:
						gaps.append({"point":[(cursor+minf(interval.x,wanted.y))*0.5,row*SPACING+0.071],"width_m":width})
						area += width*SPACING
					else: numeric += 1; numeric_width = maxf(numeric_width,width)
				cursor = maxf(cursor,interval.y)
				if cursor >= wanted.y: break
			if cursor < wanted.y:
				var width: float = wanted.y-cursor
				if width > EDGE_PRECISION:
					gaps.append({"point":[(cursor+wanted.y)*0.5,row*SPACING+0.071],"width_m":width}); area += width*SPACING
				else: numeric += 1; numeric_width = maxf(numeric_width,width)
	var bins: Dictionary = boundary_bins(actual) if not gaps.is_empty() else {}
	var significant: Array[Dictionary] = []
	var max_distance: float = 0.0
	var raw_area: float = area
	area = 0.0
	for gap: Dictionary in gaps:
		var distance: float = gap_distance(gap,bins)
		gap["mesh_distance_m"] = distance if is_finite(distance) else -1.0
		if distance <= EDGE_PRECISION:
			numeric += 1; numeric_width = maxf(numeric_width,gap.width_m); max_distance = maxf(max_distance,distance)
		else: significant.append(gap); area += float(gap.width_m)*SPACING
	significant.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.width_m > b.width_m)
	return {"triangles":actual.size(),"rows":expected.size(),"gap_intervals":significant.size(),"sampled_missing_area_m2":area,"raw_horizontal_missing_area_m2":raw_area,"widest_gaps":significant.slice(0,12),"numerical_edge_intervals":numeric,"max_numerical_horizontal_width_m":numeric_width,"max_numerical_mesh_distance_m":max_distance}

func packet_triangles(packet: Dictionary, height: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for part: Dictionary in packet.parts:
		if part.role != "road" or not part.arguments[5] or part.arguments[6]: continue
		var vertices: PackedVector3Array = part.arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(0,vertices.size(),3):
			if absf(vertices[i].y-height)>0.00001 or absf(vertices[i+1].y-height)>0.00001 or absf(vertices[i+2].y-height)>0.00001: continue
			result.append(PackedVector2Array([Vector2(vertices[i].x,-vertices[i].z),Vector2(vertices[i+1].x,-vertices[i+1].z),Vector2(vertices[i+2].x,-vertices[i+2].z)]))
	return result

func run() -> void:
	var geometry_only: bool = "--geometry-only" in OS.get_cmdline_user_args()
	var drafts: bool = "--drafts" in OS.get_cmdline_user_args()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/catalog-road-review-2026-10-16/"+("supplemental-manifest.json" if drafts else "manifest.json")))
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/ajorata-road-2026-10-16/before-source/shoulder_mesh.gd").replace("class_name ShoulderMesh","")
	assert(original.reload() == OK)
	for entry: Dictionary in manifest.entries:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.path))
		var frozen: PackedByteArray = var_to_bytes(document)
		var polygons: Array[PackedVector2Array] = surfaces(document)
		var expected: Dictionary = rows(polygons)
		for row: int in expected: expected[row] = merged(expected[row])
		var union_road: bool = document.theme != "winter"
		var before: Dictionary = compare(expected,triangulated(polygons,original.new() if union_road else null))
		var current: Dictionary = compare(expected,triangulated(polygons,ShoulderMesh.new() if union_road else null))
		var result: Dictionary = {"name":entry.name,"theme":entry.theme,"document_sha256":entry.document_sha256,"source_polygons":polygons.size(),"before":before,"current":current}
		if not geometry_only:
			var track: NativeTrack = TrackCompiler.compile(document)
			var canonical: PackedByteArray = var_to_bytes([track.cells,track.kerbs.triangles,track.route])
			var packet: Dictionary = PREPARATION.prepare(track,true)
			result["native_hash"] = track.content_hash
			result["prepared"] = compare(expected,packet_triangles(packet,0.012+(HEIGHT.RISE if HEIGHT.is_asphalt(track) else 0.0)))
			result["canonical_unchanged"] = canonical == var_to_bytes([track.cells,track.kerbs.triangles,track.route])
			if not result.canonical_unchanged or result.prepared.gap_intervals > 0: failures += 1
		if var_to_bytes(document) != frozen or current.gap_intervals > 0: failures += 1
		results.append(result)
		print("CATALOG_ROAD ",entry.name," old_gaps=",before.gap_intervals," current_gaps=",current.gap_intervals," prepared_gaps=",result.get("prepared",{}).get("gap_intervals",-1))
		var file := FileAccess.open(OUTPUT+("supplemental-" if drafts else "")+("geometry" if geometry_only else "prepared")+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"tracks":results.size(),"failures":failures,"scan_spacing_m":SPACING,"numerical_edge_allowance_m":EDGE_PRECISION,"results":results},"\t")); file.close()
		await process_frame
	print("CATALOG_ROAD_REVIEW: ",results.size()," tracks, ",failures," failures")
	quit(1 if failures else 0)
