class_name NativeTrackVisual
extends Node3D
## Original matte track kit derived solely from native surface geometry.

const VERSION: String = "track-kit-6"
const COLORS: Array[Color] = TrackTheme.PINE # Legacy geometry-debug palette.
const TERRAIN_SHADER: Shader = preload("res://track/terrain.gdshader")
const CREATOR_ROAD_SHADER: Shader = preload("res://track/creator_road.gdshader")
var theme_id: String = "pine"
var editor_preview: bool = false
var colors: Array[Color] = []
var tyre_instances: MultiMeshInstance3D
var scenic_count: int = 0


func build(track: NativeTrack, bridge: BridgePresentation) -> void:
	theme_id = TrackTheme.normalized(str(track.metadata.get("theme", "pine")))
	colors = TrackTheme.palette(theme_id)
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://track/ground.gdshader")
	ground.set_shader_parameter("ground_color", colors[1])
	VisualGeometry.box(self, Vector3(1000, 0.1, 1000), Vector3(0, -0.15, 0), ground)
	_build_terrain(track)
	_build_creator_roads(track)
	_build_barriers(track)
	_build_low_cover(track)
	_build_placed_objects(track)
	bridge.build(self)
	_build_finish(track)


func _build_terrain(track: NativeTrack) -> void:
	var low := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGBA8)
	var high := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGBA8)
	low.fill(Color(0,0,0,0))
	high.fill(Color(0,0,0,0))
	var hide_boundary: bool = _hide_creator_boundary(track)
	var object_ground: PackedByteArray = _authored_barrier_cells(track)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			var kind: int = track.cells[y * track.grid_width + x]
			# Object collision footprints are not concrete paving beneath foliage.
			if kind == 4 and not object_ground.is_empty() and object_ground[y*track.grid_width+x] == 1: kind = 1
			if hide_boundary and _boundary_cell(track,x,y): kind = 1
			var weights := Color(0,0,0,0)
			weights[kind % 4] = 1.0
			if kind < 4: low.set_pixel(x, y, weights)
			else: high.set_pixel(x, y, weights)
	var surface := ShaderMaterial.new()
	surface.shader = TERRAIN_SHADER
	surface.set_shader_parameter("surface_low", ImageTexture.create_from_image(low))
	surface.set_shader_parameter("surface_high", ImageTexture.create_from_image(high))
	surface.set_shader_parameter("map_texel", Vector2(1.0 / track.grid_width, 1.0 / track.grid_height))
	for i: int in range(colors.size()): surface.set_shader_parameter("color_" + str(i), colors[i])
	var plane := PlaneMesh.new()
	plane.size = track.half_extent * 2.0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = surface
	# The flat coverage sheet must not cast a rectangular map-border shadow.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_creator_roads(track: NativeTrack) -> void:
	var document: Dictionary = track.metadata.get("creator_document",{})
	var pieces: Array = document.get("pieces",[])
	if pieces.is_empty(): return
	var mask: Image = _creator_overlay_mask(track,document.get("paint",[]))
	var texture: ImageTexture = ImageTexture.create_from_image(mask)
	var shoulders := SurfaceTool.new()
	var asphalt := SurfaceTool.new()
	var markings := SurfaceTool.new()
	var red_kerbs := SurfaceTool.new()
	var pale_kerbs := SurfaceTool.new()
	red_kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	pale_kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerb_counts: Array[int] = [0,0]
	for tool: SurfaceTool in [shoulders,asphalt,markings]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts: Array[int] = [0,0,0]
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var points: PackedVector2Array = RoadPieces.samples(pieces[index])
		for polygon: PackedVector2Array in Geometry2D.offset_polyline(points,float(pieces[index].width)*0.5,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon: bounds = bounds.expand(point)
			outlines.append({"index":index,"polygon":polygon,"bounds":bounds})
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		if piece.kind == "bridge": continue
		var points: PackedVector2Array = RoadPieces.samples(piece)
		var half: float = float(piece.width)*0.5
		var joined_start: bool = _piece_end_joined(pieces,index,points[0])
		var joined_end: bool = _piece_end_joined(pieces,index,points[-1])
		# A 0.36 m cover hides the maximum corner protrusion of a 0.5 m
		# raster cell (sqrt(2)*0.25). The white line stays inside authored width.
		for polygon: PackedVector2Array in Geometry2D.offset_polyline(points,half+1.36,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			counts[0] += _road_polygon(shoulders,polygon,0.006)
		for polygon: PackedVector2Array in Geometry2D.offset_polyline(points,half+0.36,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			counts[1] += _road_polygon(asphalt,polygon,0.012)
		if document.get("surface","asphalt") == "dirt": continue
		for polygon: PackedVector2Array in Geometry2D.offset_polyline(points,half-0.20,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			for edge: int in range(polygon.size()):
				var a: Vector2 = polygon[edge]
				var b: Vector2 = polygon[(edge+1)%polygon.size()]
				var steps: int = maxi(1,ceili(a.distance_to(b)/0.5))
				for step: int in range(steps):
					var p: Vector2 = a.lerp(b,float(step)/steps)
					var q: Vector2 = a.lerp(b,float(step+1)/steps)
					var across: Vector2 = (q-p).normalized().orthogonal()*0.085
					var midpoint: Vector2 = (p+q)*0.5
					if joined_start and midpoint.distance_to(points[0]) <= half+0.5 and (midpoint-points[0]).dot(points[1]-points[0]) < -0.001: continue
					if joined_end and midpoint.distance_to(points[-1]) <= half+0.5 and (midpoint-points[-1]).dot(points[-1]-points[-2]) > 0.001: continue
					var outward: Vector2 = across*5.0
					if Geometry2D.is_point_in_polygon(midpoint+outward,polygon): outward = -outward
					# Probe beyond this road edge. Testing the stripe itself would
					# leave a gap where adjacent sections' rounded end caps overlap.
					if not _road_edge_exposed(midpoint+outward,index,outlines): continue
					var bend_distance: float = _inner_bend_distance(midpoint,points)
					if bend_distance >= 0.0:
						var stripe: int = int(floor(bend_distance/1.5))%2
						var curb: SurfaceTool = red_kerbs if stripe == 0 else pale_kerbs
						var lip: Vector2 = outward.normalized()*0.75
						_quad(curb,VisualGeometry.world(p)+Vector3.UP*0.025,VisualGeometry.world(q)+Vector3.UP*0.025,
							VisualGeometry.world(q+lip)+Vector3.UP*0.025,VisualGeometry.world(p+lip)+Vector3.UP*0.025)
						kerb_counts[stripe] += 1
					_quad(markings,VisualGeometry.world(p-across)+Vector3.UP*0.018,VisualGeometry.world(q-across)+Vector3.UP*0.018,
						VisualGeometry.world(q+across)+Vector3.UP*0.018,VisualGeometry.world(p+across)+Vector3.UP*0.018)
					counts[2] += 1
	if counts[0]: _commit_creator_road(shoulders,colors[2].darkened(0.20),texture,track.half_extent,true)
	if counts[1]: _commit_creator_road(asphalt,colors[2] if document.get("surface","asphalt") == "dirt" else colors[0],texture,track.half_extent)
	if counts[2]: _commit_creator_road(markings,Color("c8ccc2"),texture,track.half_extent)
	if kerb_counts[0]: _commit_creator_road(red_kerbs,Color("a63e30"),texture,track.half_extent)
	if kerb_counts[1]: _commit_creator_road(pale_kerbs,Color("c8c2aa"),texture,track.half_extent)


func _inner_bend_distance(point: Vector2, points: PackedVector2Array) -> float:
	# Curbs only on the inside of locally curved sections, never straight ends.
	var nearest: int = 0
	var best: float = INF
	var distance: float = 0.0
	var nearest_distance: float = 0.0
	for i: int in range(points.size()):
		if i > 0: distance += points[i-1].distance_to(points[i])
		var squared: float = point.distance_squared_to(points[i])
		if squared < best:
			best = squared
			nearest = i
			nearest_distance = distance
	if nearest == 0 or nearest == points.size()-1: return -1.0
	var inward: Vector2 = (points[nearest+1]-points[nearest]).normalized()-(points[nearest]-points[nearest-1]).normalized()
	if inward.length_squared() < 0.0001 or (point-points[nearest]).dot(inward) <= 0.0: return -1.0
	return nearest_distance


func _road_polygon(tool: SurfaceTool, polygon: PackedVector2Array, height: float) -> int:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for index: int in indices: tool.add_vertex(VisualGeometry.world(polygon[index])+Vector3.UP*height)
	return indices.size()/3


func _road_edge_exposed(point: Vector2, index: int, outlines: Array[Dictionary]) -> bool:
	for outline: Dictionary in outlines:
		if int(outline.index) == index or not Rect2(outline.bounds).has_point(point): continue
		if Geometry2D.is_point_in_polygon(point,outline.polygon): return false
	return true


func _piece_end_joined(pieces: Array, index: int, endpoint: Vector2) -> bool:
	for other: int in range(pieces.size()):
		if other == index: continue
		var piece: Dictionary = pieces[other]
		if endpoint.distance_to(Vector2(piece.position[0],piece.position[1])) <= RoadPieces.JOIN_DISTANCE: return true
		if endpoint.distance_to(RoadPieces.end_pose(piece).position) <= RoadPieces.JOIN_DISTANCE: return true
	return false


func _creator_overlay_mask(track: NativeTrack, paint: Array) -> Image:
	var mask := Image.create(track.grid_width,track.grid_height,false,Image.FORMAT_R8)
	mask.fill(Color.WHITE)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if track.cells[y*track.grid_width+x] in [4,7]: mask.set_pixel(x,y,Color.BLACK)
	# Match the compiler's painted-cell coverage, including square stamps.
	# This also removes edge paint through newly painted junctions.
	for stroke: Dictionary in paint:
		if stroke.get("protect_road",false): continue
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
					if hit: mask.set_pixel(x,y,Color.BLACK)
	return mask


func _commit_creator_road(tool: SurfaceTool, color: Color, mask: Texture2D, extent: Vector2, gravel: bool = false) -> void:
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = CREATOR_ROAD_SHADER
	material.set_shader_parameter("overlay_mask",mask)
	material.set_shader_parameter("map_extent",extent)
	material.set_shader_parameter("road_color",color)
	material.set_shader_parameter("gravel",gravel)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _authored_barrier_cells(track: NativeTrack) -> PackedByteArray:
	var mask := PackedByteArray()
	if _hide_creator_boundary(track):
		# The finite creator perimeter still blocks the car, but an empty map
		# is presented as open terrain rather than a walled enclosure.
		mask.resize(track.cells.size())
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				if _boundary_cell(track,x,y): mask[y*track.grid_width+x] = 1
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[]):
		if object.kind not in ["tree","rock","tyre_wall","fence"]: continue
		if mask.is_empty(): mask.resize(track.cells.size())
		var center := Vector2(object.position[0],object.position[1])
		var reach: float = CreatorObjects.dimensions(object.kind).length()*0.5
		for y: int in range(maxi(0,floori((track.half_extent.y-center.y-reach)/track.cell_size)),mini(track.grid_height,ceili((track.half_extent.y-center.y+reach)/track.cell_size))):
			for x: int in range(maxi(0,floori((center.x-reach+track.half_extent.x)/track.cell_size)),mini(track.grid_width,ceili((center.x+reach+track.half_extent.x)/track.cell_size))):
				var point := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
				if CreatorObjects.contains(object,point): mask[y*track.grid_width+x] = 1
	return mask


func _hide_creator_boundary(track: NativeTrack) -> bool:
	var document: Dictionary = track.metadata.get("creator_document",{})
	return editor_preview and not document.is_empty() and document.get("base_track","") == "" and document.get("layout",{}).is_empty()


func _boundary_cell(track: NativeTrack, x: int, y: int) -> bool:
	return x < 2 or y < 2 or x >= track.grid_width-2 or y >= track.grid_height-2


func _build_barriers(track: NativeTrack) -> void:
	var cap := SurfaceTool.new()
	var sides := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	var authored: PackedByteArray = _authored_barrier_cells(track)
	# Merged top faces and exposed perimeter only: no interior wall seams.
	for r: Array in track.rectangles:
		if int(r[4]) != 4:
			continue
		var x: float = float(r[0]) * track.cell_size - track.half_extent.x
		var z: float = float(r[1]) * track.cell_size - track.half_extent.y
		var w: float = float(r[2]) * track.cell_size
		var h: float = float(r[3]) * track.cell_size
		if authored.is_empty():
			_quad(cap, Vector3(x, 0.65, z), Vector3(x+w, 0.65, z), Vector3(x+w, 0.65, z+h), Vector3(x, 0.65, z+h))
			count += 1
		else:
			# Exclude authored prop meshes and the new-map safety boundary.
			# Other barriers retain their exact native tops and perimeter.
			for row: int in range(int(r[1]),int(r[1]+r[3])):
				var start: int = int(r[0])
				for column: int in range(start,int(r[0]+r[2])+1):
					if column == int(r[0]+r[2]) or authored[row*track.grid_width+column] != 0:
						if column > start:
							var p := Vector3(start*track.cell_size-track.half_extent.x,0.65,row*track.cell_size-track.half_extent.y)
							var span: float = (column-start)*track.cell_size
							_quad(cap,p,p+Vector3.RIGHT*span,p+Vector3(span,0,track.cell_size),p+Vector3.BACK*track.cell_size)
							count += 1
						start = column+1
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if track.cells[y * track.grid_width + x] != 4:
				continue
			if not authored.is_empty() and authored[y*track.grid_width+x] != 0: continue
			var a := Vector3(x * track.cell_size - track.half_extent.x, 0.65, y * track.cell_size - track.half_extent.y)
			var corners: Array[Vector3] = [a, a+Vector3.RIGHT*track.cell_size, a+Vector3(1,0,1)*track.cell_size, a+Vector3.BACK*track.cell_size]
			var neighbors: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
			for edge: int in range(4):
				var n: Vector2i = Vector2i(x,y) + neighbors[edge]
				if n.x >= 0 and n.y >= 0 and n.x < track.grid_width and n.y < track.grid_height and track.cells[n.y * track.grid_width + n.x] == 4:
					continue
				var p: Vector3 = corners[edge]
				var q: Vector3 = corners[(edge+1)%4]
				_quad(sides, p, q, q-Vector3.UP*0.65, p-Vector3.UP*0.65)
	if count:
		_commit(cap, colors[4].lightened(0.17))
		_commit(sides, colors[4].darkened(0.16))


func _build_low_cover(track: NativeTrack) -> void:
	var scenery := SurfaceTool.new()
	scenery.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foliage: Color = TrackTheme.foliage(theme_id)
	var stone: Color = TrackTheme.stone(theme_id)
	# Jittered sites are visited in deterministic mixed order across the map,
	# so the fixed budget cannot fill the top rows and leave the bottom bare.
	# This stays presentation-only, with no per-frame work or simulation RNG.
	# Baked vertex colors reduce the entire prop kit to one mesh/material.
	var stride: int = maxi(1, ceili(3.7 / track.cell_size))
	var jitter: int = maxi(1,floori(stride*0.4))
	for site: Vector2i in _scenery_sites(track,stride):
		if scenic_count >= 480: break
		var seed_value: int = (site.x * 73856093 ^ site.y * 19349663) & 0x7fffffff
		var cell := Vector2i(site.x+(seed_value%(jitter*2+1))-jitter,site.y+((seed_value/11)%(jitter*2+1))-jitter)
		if not _cover_clear(track, cell, 1.3): continue
		var center := Vector3((cell.x+0.5)*track.cell_size-track.half_extent.x, 0.014, (cell.y+0.5)*track.cell_size-track.half_extent.y)
		var scale_value: float = 0.8 + (seed_value % 11) * 0.035
		var turn: float = (seed_value % 37) * 0.17
		if theme_id == "pine" and seed_value % 3 == 1 and _cover_clear(track, cell, 4.4):
			# Mature narrow pines, safely beyond their projected road envelope.
			_pine(scenery, center, scale_value, turn, foliage)
		else:
			var color: Color = stone if seed_value % 4 == 0 else foliage
			var height: float = 0.08 if seed_value % 4 == 0 else 0.22
			_mound(scenery, center, Vector3(0.18 if seed_value % 4 == 0 else 0.4, height, 0.14 if seed_value % 4 == 0 else 0.3) * scale_value, turn, color)
			_mound(scenery, center + Vector3(0.5, 0, 0.25), Vector3(0.10 if seed_value % 4 == 0 else 0.24, height * 0.6, 0.08 if seed_value % 4 == 0 else 0.2), turn+1.2, color.darkened(0.08))
		scenic_count += 1
	if scenic_count:
		scenery.generate_normals()
		var instance := MeshInstance3D.new()
		instance.mesh = scenery.commit()
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		VisualGeometry.ink(material)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
		add_child(instance)


func _scenery_sites(track: NativeTrack, stride: int) -> Array[Vector2i]:
	var ordered: Array[Vector3i] = []
	for y: int in range(stride,track.grid_height-stride,stride):
		for x: int in range(stride,track.grid_width-stride,stride):
			var seed_value: int = (x*73856093 ^ y*19349663)&0x7fffffff
			if track.cells[y*track.grid_width+x] not in [1,7] or seed_value%3 == 0: continue
			var priority: int = ((seed_value^(seed_value>>16))*0x45d9f3b)&0x7fffffff
			priority = ((priority^(priority>>16))*0x45d9f3b)&0x7fffffff
			ordered.append(Vector3i(priority^(priority>>16),x,y))
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.z < b.z)
	var sites: Array[Vector2i] = []
	for value: Vector3i in ordered: sites.append(Vector2i(value.y,value.z))
	return sites


func _cover_clear(track: NativeTrack, cell: Vector2i, radius: float) -> bool:
	var point := Vector2((cell.x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(cell.y+0.5)*track.cell_size)
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[]):
		if point.distance_to(Vector2(object.position[0],object.position[1])) < radius+3.0: return false
	# Check the whole square footprint, including bridges. A tree must never
	# hide a corner, gate, ramp or native barrier. Low cover remains passable.
	var extent: int = ceili(radius / track.cell_size)
	if cell.x < extent or cell.y < extent or cell.x + extent >= track.grid_width or cell.y + extent >= track.grid_height:
		return false
	for y: int in range(cell.y - extent, cell.y + extent + 1):
		for x: int in range(cell.x - extent, cell.x + extent + 1):
			var index: int = y * track.grid_width + x
			if track.cells[index] not in [1, 7] or track.deck_cells[index] >= 0:
				return false
	return true


func _build_placed_objects(track: NativeTrack) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[]):
		var center := Vector3(float(object.position[0]),0.014,-float(object.position[1]))
		if object.kind == "tree":
			_pine(tool,center,0.65,-deg_to_rad(float(object.rotation)),TrackTheme.foliage(theme_id))
		elif object.kind == "rock":
			_mound(tool,center,Vector3(0.95,0.5,0.9),-deg_to_rad(float(object.rotation)),TrackTheme.stone(theme_id))
		elif object.kind == "tyre_wall": continue # Shared instanced mesh below.
		elif object.kind == "fence":
			var turn: float = deg_to_rad(float(object.rotation))
			for x: float in [-2.8,0.0,2.8]:
				_colored_box(tool,center+Vector3(x,0.64,0).rotated(Vector3.UP,turn),Vector3(0.20,1.28,0.20),turn,Color("706b5b"))
			for height: float in [0.42,1.02]:
				_colored_box(tool,center+Vector3(0,height,0),Vector3(6,0.16,0.16),turn,Color("898373"))
		else: continue # Barrier/water/dirt already rendered from exact native cells.
		count += 1
	if count > 0:
		tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = tool.commit()
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		VisualGeometry.ink(material)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		add_child(mesh)

	if not track.tyre_origins.is_empty():
		var stack := SurfaceTool.new()
		stack.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tyre(stack,Vector3.ZERO)
		_tyre(stack,Vector3.UP*0.30)
		stack.generate_normals()
		tyre_instances = MultiMeshInstance3D.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = stack.commit()
		instances.instance_count = track.tyre_origins.size()
		tyre_instances.multimesh = instances
		var rubber := VisualGeometry.material(Color.WHITE)
		rubber.vertex_color_use_as_albedo = true
		rubber.cull_mode = BaseMaterial3D.CULL_DISABLED
		tyre_instances.material_override = rubber
		add_child(tyre_instances)
		update_tyres(VehicleState.new(),track.tyre_origins)


func _tyre(tool: SurfaceTool, center: Vector3) -> void:
	# Open centers and two restrained sidewall tones make the stack readable
	# from overhead without textures or an unrelated asset style.
	for index: int in range(12):
		var a: float = TAU*index/12.0
		var b: float = TAU*(index+1)/12.0
		var p := Vector3(cos(a),0,sin(a))
		var q := Vector3(cos(b),0,sin(b))
		tool.set_color(Color("333a3b"))
		_quad(tool,center+p*0.48+Vector3.UP*0.04,center+q*0.48+Vector3.UP*0.04,
			center+q*0.48+Vector3.UP*0.29,center+p*0.48+Vector3.UP*0.29)
		tool.set_color(Color("474d4d"))
		_quad(tool,center+p*0.48+Vector3.UP*0.29,center+q*0.48+Vector3.UP*0.29,
			center+q*0.24+Vector3.UP*0.29,center+p*0.24+Vector3.UP*0.29)
		tool.set_color(Color("252c2d"))
		_quad(tool,center+p*0.24+Vector3.UP*0.29,center+q*0.24+Vector3.UP*0.29,
			center+q*0.24,center+p*0.24)


func _colored_box(tool: SurfaceTool, center: Vector3, dimensions: Vector3, turn: float, color: Color) -> void:
	var vertices := PackedVector3Array()
	for y: int in range(2):
		for z: int in range(2):
			for x: int in range(2):
				vertices.append(center+((Vector3(x,y,z)-Vector3.ONE*0.5)*dimensions).rotated(Vector3.UP,turn))
	var faces: Array[Array] = [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
	for index: int in range(faces.size()):
		var face: Array = faces[index]
		tool.set_color(color.lightened(0.04 if index == 1 else 0.0).darkened(0.07 if index > 3 else 0.0))
		_quad(tool,vertices[face[0]],vertices[face[1]],vertices[face[2]],vertices[face[3]])


func _mound(tool: SurfaceTool, center: Vector3, dimensions: Vector3, turn: float, color: Color) -> void:
	# Two irregular bevel rings create broad stone / scrub planes, no spheres.
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	for i: int in range(7):
		var angle: float = turn + TAU * i / 7.0
		var radial := Vector3(cos(angle) * dimensions.x, 0, sin(angle) * dimensions.z)
		lower.append(center + radial * (0.91 + (i%3)*0.06))
		upper.append(center + radial * 0.57 + Vector3(0.06, dimensions.y * (0.7+(i%2)*0.14), 0.03))
	var top: Vector3 = center + Vector3(0.1, dimensions.y, -0.03)
	for i: int in range(7):
		var j: int = (i+1)%7
		tool.set_color(color.darkened(0.08 if i%3 == 0 else 0.0))
		_quad(tool, lower[i], lower[j], upper[j], upper[i])
		tool.set_color(color.lightened(0.045))
		for v: Vector3 in [upper[i], top, upper[j]]: tool.add_vertex(v)


func _pine(tool: SurfaceTool, center: Vector3, scale_value: float, turn: float, color: Color) -> void:
	# Layered branch masses with blunt, uneven ends, not repeated star cones.
	_mound(tool, center, Vector3(0.12, 1.65, 0.12) * scale_value, turn, Color("514533"))
	for tier: int in range(5):
		var y: float = 0.65 + tier*0.48
		var radius: float = 0.75 - tier*0.12
		for branch: int in range(4):
			var angle: float = turn + branch*TAU/4.0 + tier*1.7
			var offset := Vector3(cos(angle)*radius*0.8,y+sin(angle*3.0)*0.12,sin(angle)*radius*0.8)
			var shade: Color = color.lightened(0.025*tier).darkened(0.10 if branch%3 == 0 else 0.0)
			_mound(tool,center+offset*scale_value,Vector3(radius*0.70,0.40,radius*0.48)*scale_value,angle,shade)
	_mound(tool,center+Vector3(0,2.8,0)*scale_value,Vector3(0.20,0.40,0.18)*scale_value,turn,color.lightened(0.08))


func _build_finish(track: NativeTrack) -> void:
	var side := Vector2(track.finish_forward.y, -track.finish_forward.x)
	var light := SurfaceTool.new()
	var dark := SurfaceTool.new()
	light.begin(Mesh.PRIMITIVE_TRIANGLES)
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts: Array[int] = [0, 0]
	var size: float = 0.5
	# Paint the local finish road, not every disconnected lane intersected by
	# the deliberately broad practice gate. Gate timing data stays unchanged.
	var road_kind: int = track.cell_at(track.finish_center)
	var widths := Vector2.ZERO
	for direction: int in [-1,1]:
		for step: int in range(1, ceili(track.finish_half_width / track.cell_size) + 1):
			var distance: float = step * track.cell_size
			if track.cell_at(track.finish_center + side * distance * direction) != road_kind:
				break
			widths[0 if direction < 0 else 1] = distance
	for row: int in range(2):
		for i: int in range(ceili(track.finish_half_width * 2 / size)):
			var offset: float = -track.finish_half_width + (i + 0.5) * size
			if offset - size * 0.5 < -widths.x or offset + size * 0.5 > widths.y:
				continue
			var point: Vector2 = track.finish_center + side * offset + track.finish_forward * (row - 0.5) * size
			if track.cell_at(point) not in [0, 2, 5, 6]:
				continue
			var center: Vector3 = VisualGeometry.world(point) + Vector3.UP * 0.024
			var across: Vector3 = VisualGeometry.world(side) * size * 0.5
			var along: Vector3 = VisualGeometry.world(track.finish_forward) * size * 0.5
			var parity: int = (row+i)%2
			_quad(light if parity == 0 else dark, center-across-along, center+across-along, center+across+along, center-across+along)
			counts[parity] += 1
	if counts[0]: _commit(light, Color("d4d5c5"))
	if counts[1]: _commit(dark, Color("252f32"))


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a,c,b,a,d,c]: tool.add_vertex(v)


func _commit(tool: SurfaceTool, color: Color) -> void:
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	var material := VisualGeometry.material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	add_child(instance)

func update_tyres(state: VehicleState, origins: PackedVector2Array) -> void:
	if tyre_instances == null: return
	for i: int in range(origins.size()):
		var p: Vector2 = origins[i]
		var spin: float = 0.0
		if i < state.loose_tyres.size():
			var tyre: Array = state.loose_tyres[i]
			p = Vector2(tyre[0],tyre[1])
			spin = tyre[4]
		tyre_instances.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,spin),VisualGeometry.world(p)+Vector3.UP*0.014))
