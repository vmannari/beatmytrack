extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ajorata.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	var support: RefCounted = preload("res://track/road_surface_height.gd").new(track)
	var union: RefCounted = preload("res://track/desert_road_union.gd").new()
	for polygon: PackedVector2Array in support.floors: union.add(polygon,PackedVector2Array())
	var invalid: Array = []
	var lists: Dictionary = {}
	for i: int in range(union.clipping.triangles.size()):
		for polygon: PackedVector2Array in union.clipping._fragments(i,union.clipping.triangles[i],lists):
			if Geometry2D.triangulate_polygon(polygon).is_empty():
				var vertices: Array = []
				for p: Vector2 in polygon: vertices.append([p.x,p.y])
				invalid.append({"triangle":i,"vertices":vertices})
	print("AJORATA_INVALID ",JSON.stringify(invalid))
	var probe := Vector2(-14,-41)
	for i: int in range(union.clipping.triangles.size()):
		var source: Dictionary = union.clipping.triangles[i]
		if not Geometry2D.is_point_in_polygon(probe,source.polygon): continue
		var candidates: Dictionary = {}
		for cell: Vector2i in union.clipping._cells(source.bounds):
			for j: int in union.clipping.bins[cell]: candidates[j] = true
		var fragments: Array[PackedVector2Array] = [source.polygon]
		for j: int in candidates:
			if j >= i: continue
			var rival: Dictionary = union.clipping.triangles[j]
			if not Rect2(source.bounds).intersects(rival.bounds): continue
			var next: Array[PackedVector2Array] = []
			for fragment: PackedVector2Array in fragments:
				var result: Array[PackedVector2Array] = union.clipping._subtract_convex(fragment,rival.polygon)
				var lost: bool = Geometry2D.is_point_in_polygon(probe,fragment)
				for p: PackedVector2Array in result: lost = lost and not Geometry2D.is_point_in_polygon(probe,p)
				if lost:
					var points: Array = []
					var cutter: Array = []
					for p: Vector2 in fragment: points.append([p.x,p.y])
					for p: Vector2 in rival.polygon: cutter.append([p.x,p.y])
					print("AJORATA_LOST ",JSON.stringify({"source":i,"rival":j,"fragment":points,"cutter":cutter,"inside":Geometry2D.is_point_in_polygon(probe,rival.polygon)}))
				next.append_array(result)
			fragments = next
	var packet: Dictionary = preload("res://editor/road_preparation.gd").prepare(track,true)
	var bins: Dictionary = {}
	var triangles: Array[PackedVector2Array] = []
	for part: Dictionary in packet.parts:
		if part.role != "road" or not part.arguments[5] or part.arguments[6]: continue
		var vertices: PackedVector3Array = part.arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(0,vertices.size(),3):
			if absf(vertices[i].y-0.062) > 0.00001 or absf(vertices[i+1].y-0.062) > 0.00001 or absf(vertices[i+2].y-0.062) > 0.00001: continue
			var p := PackedVector2Array([Vector2(vertices[i].x,-vertices[i].z),Vector2(vertices[i+1].x,-vertices[i+1].z),Vector2(vertices[i+2].x,-vertices[i+2].z)])
			var bounds := Rect2(p[0],Vector2.ZERO).expand(p[1]).expand(p[2])
			var slot: int = triangles.size()
			triangles.append(p)
			for y: int in range(floori(bounds.position.y/4),floori(bounds.end.y/4)+1):
				for x: int in range(floori(bounds.position.x/4),floori(bounds.end.x/4)+1):
					var key := Vector2i(x,y)
					if not bins.has(key): bins[key] = []
					bins[key].append(slot)
	var missing: Array = []
	var sampled: int = 0
	for y: int in range(-190,225):
		for x: int in range(-190,190):
			var point := Vector2(x*0.25+0.037,y*0.25+0.071)
			if not support.on_floor(point): continue
			sampled += 1
			var covered: bool = false
			for slot: int in bins.get(Vector2i(floori(point.x/4),floori(point.y/4)),[]):
				if Geometry2D.is_point_in_polygon(point,triangles[slot]): covered = true; break
			if not covered: missing.append([point.x,point.y])
	print("AJORATA_SCAN ",JSON.stringify({"hash":track.content_hash,"triangles":triangles.size(),"sampled":sampled,"missing_count":missing.size(),"missing":missing.slice(0,100)}))
	for row: Array in missing:
		var point := Vector2(row[0],row[1])
		var nearest: float = INF
		for floor: PackedVector2Array in support.floors:
			if not Geometry2D.is_point_in_polygon(point,floor): continue
			for j: int in range(floor.size()): nearest = minf(nearest,point.distance_to(Geometry2D.get_closest_point_to_segment(point,floor[j],floor[(j+1)%floor.size()])))
		var mesh_distance: float = INF
		for triangle: PackedVector2Array in triangles:
			for j: int in range(3): mesh_distance = minf(mesh_distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,triangle[j],triangle[(j+1)%3])))
		print("AJORATA_EDGE ",point," support_distance=",nearest," mesh_distance=",mesh_distance)
	var file := FileAccess.open("res://../docs/evidence/ajorata-road-2026-10-16/scan.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"sampled":sampled,"missing":missing},"\t")); file.close()
	quit()
