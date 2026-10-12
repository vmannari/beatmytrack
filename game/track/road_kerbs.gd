class_name RoadKerbs
extends RefCounted
## Versioned, deterministic low kerb geometry. No nodes, rendering or runtime I/O.

const HEIGHT: float = 0.10
const BUCKET: float = 4.0
var maximum_height: float = HEIGHT
var triangles: Array[Dictionary] = []
var buckets: Dictionary = {}
var blocked := PackedByteArray()
var extent := Vector2.ZERO
var cell_size: float = 0.5
var grid := Vector2i.ZERO


func build(track: NativeTrack) -> void:
	triangles.clear()
	buckets.clear()
	extent = track.half_extent
	cell_size = track.cell_size
	grid = Vector2i(track.grid_width,track.grid_height)
	var document: Dictionary = track.metadata.get("creator_document",{})
	blocked = exclusion_mask(track,document.get("paint",[]))
	var segments: Array[Dictionary] = creator_segments(document)
	var first: int = 0
	while first < segments.size():
		var last: int = first
		while last+1 < segments.size():
			var a: Dictionary = segments[last]
			var b: Dictionary = segments[last+1]
			if a.piece != b.piece or absf(float(a.end)-float(b.start)) > 0.0001 or Vector2(a.b).distance_to(b.a) > 0.001: break
			last += 1
		var origin: float = segments[first].start
		var length: float = float(segments[last].end)-origin
		for i: int in range(first,last+1):
			var segment: Dictionary = segments[i]
			_strip(segment.a,segment.b,segment.outer_a,segment.outer_b,float(segment.start)-origin,float(segment.end)-origin,length)
		first = last+1
	# Native source kerbs remain in remixes, outside new piece scenery. Raster
	# shoulders generated for new pieces are not an additional ring of kerbs.
	var pieces: Array = document.get("pieces",[])
	if not pieces.is_empty() and document.get("base_track","") == "": return
	var covered: Array[PackedVector2Array] = []
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		for polygon: PackedVector2Array in Geometry2D.offset_polygon(RoadPieces.section_outline(pieces,index),1.8,Geometry2D.JOIN_ROUND): covered.append(polygon)
	var selected := PackedByteArray()
	selected.resize(track.cells.size())
	var indices: Array[Vector2i] = []
	for y: int in range(grid.y):
		for x: int in range(grid.x):
			if track.cells[y*grid.x+x] != 5 or blocked[y*grid.x+x] != 0: continue
			var near_road: bool = false
			for offset: Vector2i in [Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
				var q: Vector2i = Vector2i(x,y)+offset
				if q.x >= 0 and q.y >= 0 and q.x < grid.x and q.y < grid.y and track.cells[q.y*grid.x+q.x] == 0: near_road = true
			if not near_road: continue
			var midpoint := Vector2((x+0.5)*cell_size-extent.x,extent.y-(y+0.5)*cell_size)
			var hidden: bool = false
			for polygon: PackedVector2Array in covered:
				if Geometry2D.is_point_in_polygon(midpoint,polygon): hidden = true; break
			if hidden: continue
			selected[y*grid.x+x] = 1
			indices.append(Vector2i(x,y))
	for cell: Vector2i in indices:
		var p := Vector2(cell.x*cell_size-extent.x,extent.y-cell.y*cell_size)
		var center: Vector2 = p+Vector2(cell_size,-cell_size)*0.5
		var corners: Array[Vector2] = [p,p+Vector2(cell_size,0),p+Vector2(cell_size,-cell_size),p+Vector2(0,-cell_size)]
		var nodes: Array[Vector2i] = [cell,cell+Vector2i(1,0),cell+Vector2i(1,1),cell+Vector2i(0,1)]
		for edge: int in range(4):
			var a: Vector2 = corners[edge]
			var b: Vector2 = corners[(edge+1)%4]
			_add(a,b,center,_native_vertex_height(nodes[edge],selected),_native_vertex_height(nodes[(edge+1)%4],selected),HEIGHT,Vector2((a.x-a.y)*0.8,-1),Vector2((b.x-b.y)*0.8,-1),Vector2((center.x-center.y)*0.8,-1))


func _native_vertex_height(node: Vector2i, selected: PackedByteArray) -> float:
	# Adjacent cells share a level crown. Only the outside boundary slopes down.
	for offset: Vector2i in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i.ZERO]:
		var cell: Vector2i = node+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y or selected[cell.y*grid.x+cell.x] == 0: return 0.0
	return HEIGHT



static func creator_segments(document: Dictionary, selected_kind: String = "", presentation: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if document.get("surface","asphalt") == "dirt": return result
	var pieces: Array = document.get("pieces",[])
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var polygons: Array[PackedVector2Array] = []
		if pieces[index].kind == "spline":
			polygons = RoadEdges.section_contours(pieces,index,0.0,topology)
		else:
			polygons.append(RoadPieces.section_outline(pieces,index,0.0,topology))
		for polygon: PackedVector2Array in polygons:
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon: bounds = bounds.expand(point)
			outlines.append({"index":index,"polygon":polygon,"bounds":bounds,"hole":pieces[index].kind == "spline" and Geometry2D.is_polygon_clockwise(polygon)})
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		if not selected_kind.is_empty() and pieces[index].kind != selected_kind: continue
		var points: PackedVector2Array = RoadPieces.samples(pieces[index])
		var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index,topology)
		var border_contours: Array[PackedVector2Array] = RoadEdges.presentation_contours(pieces,index,-0.20,topology) if presentation else RoadEdges.section_contours(pieces,index,-0.20,topology)
		for polygon: PackedVector2Array in border_contours:
			var hole: bool = pieces[index].kind == "spline" and Geometry2D.is_polygon_clockwise(polygon)
			var distance: float = 0.0
			for edge: int in range(polygon.size()):
				var a: Vector2 = polygon[edge]
				var b: Vector2 = polygon[(edge+1)%polygon.size()]
				if RoadEdges._on_join_cut(a,b,cuts) or (presentation and RoadEdges._on_join_cap(a,b,cuts)): continue
				var na: Vector2 = RoadEdges._roadside_miter(polygon,edge,cuts,presentation)
				var nb: Vector2 = RoadEdges._roadside_miter(polygon,(edge+1)%polygon.size(),cuts,presentation)
				if hole: na = -na; nb = -nb
				if pieces[index].kind == "spline":
					na = SplineBorders.kerb_normal(polygon,edge,na)
					nb = SplineBorders.kerb_normal(polygon,(edge+1)%polygon.size(),nb)
				var steps: int = maxi(1,ceili(a.distance_to(b)/0.20))
				for step: int in range(steps):
					var p: Vector2 = a.lerp(b,float(step)/steps)
					var q: Vector2 = a.lerp(b,float(step+1)/steps)
					var np: Vector2 = na.lerp(nb,float(step)/steps)
					var nq: Vector2 = na.lerp(nb,float(step+1)/steps)
					var start: float = distance
					distance += (p+np*0.375).distance_to(q+nq*0.375)
					var midpoint: Vector2 = (p+q)*0.5
					var outward: Vector2 = (q-p).normalized().orthogonal()*0.425
					if Geometry2D.is_point_in_polygon(midpoint+outward,polygon) != hole: outward = -outward
					if not RoadEdges._road_edge_exposed(midpoint+outward,index,outlines,pieces,topology): continue
					var curved: bool = SplineBorders.curved_edge(polygon,edge,points) if pieces[index].kind == "spline" else RoadEdges._inner_bend_distance(midpoint,points) >= 0.0
					if not RoadEdges._on_join_plane(a,b,cuts) and curved:
						result.append({"a":p,"b":q,"outer_a":p+np*0.75,"outer_b":q+nq*0.75,"start":start,"end":distance,"piece":index})
	return result


func _strip(a: Vector2, b: Vector2, outer_a: Vector2, outer_b: Vector2, start: float, end: float, length: float) -> void:
	var block: float = length/maxf(1.0,2.0*floorf(length/3.0)+1.0)
	var tip_a: float = smoothstep(0.0,minf(block,1.8),minf(start,length-start))
	var tip_b: float = smoothstep(0.0,minf(block,1.8),minf(end,length-end))
	outer_a = a.lerp(outer_a,lerpf(0.12,1.0,tip_a))
	outer_b = b.lerp(outer_b,lerpf(0.12,1.0,tip_b))
	var profile: Array[float] = [0.0,0.25,0.80,1.0]
	var heights: Array[float] = [0.0,HEIGHT*0.85,HEIGHT,0.0]
	for i: int in range(3):
		var p: Vector2 = a.lerp(outer_a,profile[i])
		var q: Vector2 = b.lerp(outer_b,profile[i])
		var r: Vector2 = a.lerp(outer_a,profile[i+1])
		var t: Vector2 = b.lerp(outer_b,profile[i+1])
		_add(p,q,t,heights[i]*tip_a,heights[i]*tip_b,heights[i+1]*tip_b,Vector2(start,length),Vector2(end,length),Vector2(end,length))
		_add(p,t,r,heights[i]*tip_a,heights[i+1]*tip_b,heights[i+1]*tip_a,Vector2(start,length),Vector2(end,length),Vector2(start,length))


func _add(a: Vector2, b: Vector2, c: Vector2, ha: float, hb: float, hc: float, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	if absf((b-a).cross(c-a)) < 0.0000001: return
	var index: int = triangles.size()
	triangles.append({"points":PackedVector2Array([a,b,c]),"heights":PackedFloat32Array([ha,hb,hc]),"uv":PackedVector2Array([ua,ub,uc])})
	var lo: Vector2i = Vector2i((a.min(b).min(c)/BUCKET).floor())
	var hi: Vector2i = Vector2i((a.max(b).max(c)/BUCKET).floor())
	for y: int in range(lo.y,hi.y+1):
		for x: int in range(lo.x,hi.x+1):
			var key := Vector2i(x,y)
			if not buckets.has(key): buckets[key] = []
			buckets[key].append(index)


func height_at(point: Vector2) -> float:
	var cell := Vector2i(floori((point.x+extent.x)/cell_size),floori((extent.y-point.y)/cell_size))
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y or blocked[cell.y*grid.x+cell.x] != 0: return 0.0
	var height: float = 0.0
	for index: int in buckets.get(Vector2i((point/BUCKET).floor()),[]):
		var t: Dictionary = triangles[index]
		var p: PackedVector2Array = t.points
		var d: float = (p[1]-p[0]).cross(p[2]-p[0])
		var b: float = (point-p[0]).cross(p[2]-p[0])/d
		var c: float = (p[1]-p[0]).cross(point-p[0])/d
		if b >= -0.00001 and c >= -0.00001 and b+c <= 1.00001:
			height = maxf(height,clampf((1.0-b-c)*t.heights[0]+b*t.heights[1]+c*t.heights[2],0.0,maximum_height))
	return height


static func exclusion_mask(track: NativeTrack, paint: Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(track.cells.size())
	for index: int in range(track.cells.size()):
		if track.cells[index] in [4,7]: mask[index] = 1
	for authored: Dictionary in paint:
		var stroke: Dictionary = SurfacePaint.prepared(authored)
		if stroke.get("protect_road",false): continue
		if stroke.get("mode","") == "area":
			var polygon: PackedVector2Array = SurfacePaint.contour(authored.points,"area")
			var bounds: Rect2i = SurfacePaint.cell_bounds(polygon,track.half_extent,track.cell_size,Vector2i(track.grid_width,track.grid_height))
			for y: int in range(bounds.position.y,bounds.end.y):
				for x: int in range(bounds.position.x,bounds.end.x):
					var point := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
					if Geometry2D.is_point_in_polygon(point,polygon): mask[y*track.grid_width+x] = 1
			continue
		var radius: float = float(stroke.width)*0.5
		for index: int in range(stroke.points.size()):
			var p: Array = stroke.points[index]
			var q: Array = stroke.points[maxi(0,index-1)]
			var a := Vector2(p[0],p[1])
			var b := Vector2(q[0],q[1])
			var lo: Vector2 = a.min(b)-Vector2.ONE*radius
			var hi: Vector2 = a.max(b)+Vector2.ONE*radius
			for y: int in range(maxi(0,floori((track.half_extent.y-hi.y)/track.cell_size)),mini(track.grid_height,ceili((track.half_extent.y-lo.y)/track.cell_size))):
				for x: int in range(maxi(0,floori((lo.x+track.half_extent.x)/track.cell_size)),mini(track.grid_width,ceili((hi.x+track.half_extent.x)/track.cell_size))):
					var point := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
					var delta: Vector2 = point-Geometry2D.get_closest_point_to_segment(point,a,b)
					var hit: bool = delta.length_squared() <= radius*radius if stroke.shape == "round" else maxf(absf(delta.x),absf(delta.y)) <= radius
					if hit: mask[y*track.grid_width+x] = 1
	return mask
