class_name NativeTrackVisual
extends Node3D
## Original matte track kit derived solely from native surface geometry.

const VERSION: String = "track-kit-106"
const STANDARD_FINISH_COLORS: Array[Color] = [Color("d4d5c5"), Color("252f32")]
const WINTER_FINISH_COLORS: Array[Color] = [Color("d1dee5"), Color("647987")]
const DESERT_FINISH_COLORS: Array[Color] = [Color("938267"), Color("635b4b")]
const SURFACE_FACTORS: Texture2D = preload("res://assets/textures/surface_factors_v1.png")
const WINTER_ICE: Texture2D = preload("res://assets/textures/winter_ice_v1.png")
const WINTER_SNOW: Texture2D = preload("res://assets/textures/winter_snow_v1.png")
const COLORS: Array[Color] = TrackTheme.PINE # Legacy geometry-debug palette.
const GRASS_TEXTURE: Texture2D = preload("res://assets/textures/painted_grass_v1.png")
const GRASS_ALBEDO: Texture2D = preload("res://assets/textures/meadow_grass_v2.png")
const GRASS_MACRO: Texture2D = preload("res://assets/textures/grass_macro_mask.png")
const GRASS_NORMAL: Texture2D = preload("res://assets/textures/grass_normal.png")
const DUNE_FACTORS: Texture2D = preload("res://assets/textures/desert_dunes_v1.png")
const DESERT_APRON: Texture2D = preload("res://assets/textures/desert_apron_v1.png")
const DUNE_ALBEDO: Texture2D = preload("res://assets/textures/desert_sand_v2.png")

const TERRAIN_SHADER: Shader = preload("res://track/terrain.gdshader")
const CREATOR_ROAD_SHADER: Shader = preload("res://track/creator_road.gdshader")
const NIGHT_TILE_SIZE: float = 16.0
const NIGHT_ROAD_GROUP_SIZE: float = 16.0
var partition_night_ground: bool = true
var _menu_slices: bool = false
var _slice_started: int = 0
var theme_id: String = "pine"
var editor_preview: bool = false
var colors: Array[Color] = []
var relief: GroundRelief
var tyre_instances: MultiMeshInstance3D
var _tyre_positions := PackedVector2Array()
var _tyre_spins: Array[float] = []
var light_instances: Array[Node3D] = []
var scenic_count: int = 0
var editor_objects: NativeTrackVisual
var editor_cover: NativeTrackVisual
var cache_road_meshes: bool = true
var persist_road_meshes: bool = true
const ROAD_DISK_CACHE = preload("res://track/road_mesh_disk_cache.gd")
const ROAD_CACHE_BUDGET: int = 32 * 1024 * 1024
static var _road_mesh_cache: Array[Dictionary] = []
static var _pending_road_bakes: Dictionary = {}


func _bind_grass(material: ShaderMaterial) -> void:
	material.set_shader_parameter("winter_snow",theme_id == "winter")
	material.set_shader_parameter("snow_albedo",WINTER_SNOW)
	material.set_shader_parameter("ice_albedo",WINTER_ICE)
	material.set_shader_parameter("desert_dunes",theme_id == "desert")
	material.set_shader_parameter("dune_factors",DUNE_FACTORS)
	material.set_shader_parameter("desert_apron",DESERT_APRON)
	material.set_shader_parameter("dune_albedo",DUNE_ALBEDO)
	material.set_shader_parameter("hybrid_grass",theme_id in ["pine","storm"])
	material.set_shader_parameter("grass_albedo",GRASS_ALBEDO)
	material.set_shader_parameter("grass_macro_mask",GRASS_MACRO)
	material.set_shader_parameter("grass_normal",GRASS_NORMAL)


func build(track: NativeTrack, bridge: BridgePresentation, menu_slices: bool = false) -> void:
	_menu_slices = menu_slices
	_slice_started = Time.get_ticks_usec() if menu_slices else 0
	theme_id = TrackTheme.normalized(str(track.metadata.get("theme", "pine")))
	colors = TrackTheme.palette(theme_id)
	relief = GroundRelief.for_track(track)
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://track/ground.gdshader")
	ground.set_shader_parameter("surface_factors", SURFACE_FACTORS)
	ground.set_shader_parameter("ground_color", colors[1])
	ground.set_shader_parameter("painted_grass_texture", GRASS_TEXTURE)
	_bind_grass(ground)
	VisualGeometry.box(self, Vector3(1000, 0.1, 1000), Vector3(0, -0.15, 0), ground)
	if theme_id == "night_city" and partition_night_ground and _lamps_inside_terrain(track):
		# This backdrop is hidden by the opaque terrain wherever lamps reach.
		# Keep moon/ambient light, but exclude pointless point-light evaluation.
		(get_child(get_child_count()-1) as MeshInstance3D).layers = 2
	await _build_terrain(track)
	if _menu_slices and not is_inside_tree(): return
	await _build_creator_roads(track)
	if _menu_slices and not is_inside_tree(): return
	if track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): await _build_kerbs(track)
	await _build_barriers(track)
	if _menu_slices and not is_inside_tree(): return
	if editor_preview:
		await refresh_editor_objects(track,true,_menu_slices)
	else:
		await _build_low_cover(track)
		await _build_placed_objects(track)
	bridge.build(self)
	_build_finish(track)
	_build_snow_banks(track)


func refresh_editor_objects(track: NativeTrack, refresh_cover: bool = true, sliced: bool = false) -> void:
	if theme_id == "night_city" and partition_night_ground and get_child_count() > 0 and get_child(0) is MeshInstance3D:
		# Moving/scaling a lamp in the editor can expose the outer backdrop.
		(get_child(0) as MeshInstance3D).layers = 2 if _lamps_inside_terrain(track) else 1
	if editor_objects != null:
		remove_child(editor_objects)
		editor_objects.queue_free()
	editor_objects = NativeTrackVisual.new()
	editor_objects.editor_preview = true
	editor_objects._menu_slices = sliced
	editor_objects._slice_started = Time.get_ticks_usec()
	editor_objects.theme_id = theme_id
	editor_objects.colors = colors
	editor_objects.relief = relief
	add_child(editor_objects)
	if refresh_cover:
		if editor_cover != null:
			remove_child(editor_cover)
			editor_cover.queue_free()
		editor_cover = NativeTrackVisual.new()
		editor_cover.editor_preview = true
		editor_cover._menu_slices = sliced
		editor_cover._slice_started = Time.get_ticks_usec()
		editor_cover.theme_id = theme_id
		editor_cover.colors = colors
		editor_cover.relief = relief
		add_child(editor_cover)
		await editor_cover._build_low_cover(track)
		if sliced and not is_inside_tree(): return
	await editor_objects._build_placed_objects(track)


func _build_terrain(track: NativeTrack) -> void:
	var low := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGBA8)
	var high := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGBA8)
	low.fill(Color(0,0,0,0))
	high.fill(Color(0,0,0,0))
	var hide_boundary: bool = _hide_creator_boundary(track)
	var object_ground: PackedByteArray = _authored_barrier_cells(track)
	for y: int in range(track.grid_height):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
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
	surface.shader = preload("res://track/storm_terrain.gdshader") if theme_id == "storm" else TERRAIN_SHADER
	surface.set_shader_parameter("surface_factors", SURFACE_FACTORS)
	surface.set_shader_parameter("icy_road", theme_id == "winter")
	surface.set_shader_parameter("wet_road", theme_id == "storm")
	surface.set_shader_parameter("packed_sand", theme_id == "desert")
	surface.set_shader_parameter("painted_grass_texture", GRASS_TEXTURE)
	_bind_grass(surface)
	surface.set_shader_parameter("surface_low", ImageTexture.create_from_image(low))
	surface.set_shader_parameter("surface_high", ImageTexture.create_from_image(high))
	surface.set_shader_parameter("map_texel", Vector2(1.0 / track.grid_width, 1.0 / track.grid_height))
	for i: int in range(colors.size()):
		# Terrain sand uses the exact same theme tint as the road shoulder.
		surface.set_shader_parameter("color_" + str(i), colors[i].darkened(0.20) if i == 2 else colors[i])
	if relief != null and not relief.meshes.is_empty():
		for terrain_mesh: ArrayMesh in relief.meshes:
			var terrain := MeshInstance3D.new()
			terrain.name = "MeadowRelief"
			terrain.mesh = terrain_mesh
			terrain.material_override = surface
			terrain.position.y = -0.06 if not track.metadata.get("creator_document",{}).get("pieces",[]).is_empty() else 0.0
			terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(terrain,true)
		return
	var plane := PlaneMesh.new()
	plane.size = track.half_extent * 2.0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = surface
	if not track.metadata.get("creator_document",{}).get("pieces",[]).is_empty():
		ground.position.y = -0.06
	# The flat coverage sheet must not cast a rectangular map-border shadow.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if theme_id == "night_city" and partition_night_ground:
		_add_lit_terrain_tiles(track,surface,ground.position.y)
		ground.free()
	else:
		add_child(ground)

func _lamps_inside_terrain(track: NativeTrack) -> bool:
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
		if object.kind != "light": continue
		var scale_value: float = float(object.get("scale",1.0))
		var center := Vector2(object.position[0],object.position[1])
		# Conservative horizontal bound including the offset lamp head.
		var reach: float = 15.4*scale_value
		if absf(center.x)+reach > track.half_extent.x or absf(center.y)+reach > track.half_extent.y: return false
	return true

func _add_lit_terrain_tiles(track: NativeTrack, surface: Material, height: float) -> void:
	var extent: Vector2 = track.half_extent
	var columns: int = ceili(extent.x*2.0/NIGHT_TILE_SIZE)
	var rows: int = ceili(extent.y*2.0/NIGHT_TILE_SIZE)
	for row: int in range(rows):
		for column: int in range(columns):
			var low := Vector2(column*NIGHT_TILE_SIZE-extent.x,row*NIGHT_TILE_SIZE-extent.y)
			var high := (low+Vector2.ONE*NIGHT_TILE_SIZE).min(extent)
			var mesh := SurfaceTool.new()
			mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
			for corner: Vector2 in [low,high,Vector2(low.x,high.y),low,Vector2(high.x,low.y),high]:
				mesh.set_normal(Vector3.UP)
				mesh.set_uv((corner+extent)/(extent*2.0))
				mesh.add_vertex(Vector3(corner.x,height,corner.y))
			var tile := MeshInstance3D.new()
			tile.name = "LitTerrainTile"
			tile.mesh = mesh.commit()
			tile.material_override = surface
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tile)


func _build_creator_roads(track: NativeTrack) -> void:
	var document: Dictionary = track.metadata.get("creator_document",{})
	var pieces: Array = document.get("pieces",[])
	if pieces.is_empty(): return
	var cache_key: Array = [track.content_hash,VERSION,theme_id,colors,partition_night_ground]
	if cache_road_meshes and _restore_road_meshes(cache_key): return
	if cache_road_meshes and persist_road_meshes and not editor_preview:
		var stored: Dictionary = ROAD_DISK_CACHE.read_entry(cache_key)
		if not stored.is_empty():
			_admit_road_entry(stored)
			if _restore_road_meshes(cache_key): return
	var first_child: int = get_child_count()
	var mask: Image = _creator_overlay_mask(track,document.get("paint",[]))
	var texture: ImageTexture = ImageTexture.create_from_image(mask)
	var road_texture: ImageTexture = ImageTexture.create_from_image(_creator_road_mask(track))
	var winter_bank := SurfaceTool.new()
	winter_bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	var winter_sections: int = 0
	var winter_piles: Dictionary = {}
	var shoulders := SurfaceTool.new()
	var shoulder_mesh := preload("res://track/shoulder_mesh.gd").new()
	var asphalt := SurfaceTool.new()
	var asphalt_fringe := SurfaceTool.new()
	var markings := SurfaceTool.new()
	var ground_skirt := SurfaceTool.new()
	ground_skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ground_count: int = 0
	for tool: SurfaceTool in [shoulders,asphalt,asphalt_fringe,markings]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts: Array[int] = [0,0,0]
	var fringe_count: int = 0
	var sand_clods: int = 0
	var outlines: Array[Dictionary] = []
	for index: int in range(pieces.size()):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
		if pieces[index].kind == "bridge": continue
		for polygon: PackedVector2Array in [RoadPieces.section_outline(pieces,index)]:
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon: bounds = bounds.expand(point)
			outlines.append({"index":index,"polygon":polygon,"bounds":bounds})
	for index: int in range(pieces.size()):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
		var piece: Dictionary = pieces[index]
		if piece.kind == "bridge": continue
		var points: PackedVector2Array = RoadPieces.samples(piece)
		# Exact repeated vertices share road UV queries only within this piece.
		var axis_cache: Dictionary = {}
		var road_join: Dictionary = preload("res://track/visual_road_join.gd").build(pieces,index)
		var marking_join: Dictionary = preload("res://track/visual_road_join.gd").build(pieces,index,-0.20)
		var cuts: Array[Dictionary] = marking_join.cuts
		var road_outline: PackedVector2Array = road_join.polygon
		# A 0.36 m cover hides the maximum corner protrusion of a 0.5 m
		# raster cell (sqrt(2)*0.25). The white line stays inside authored width.
		for polygon: PackedVector2Array in Geometry2D.offset_polygon(road_outline,3.7 if theme_id == "desert" else 1.8,Geometry2D.JOIN_ROUND):
			ground_count += _road_polygon(ground_skirt,polygon,-0.04)
		for polygon: PackedVector2Array in Geometry2D.offset_polygon(road_outline,0.16,Geometry2D.JOIN_ROUND):
			counts[1] += _road_polygon(asphalt,polygon,0.012,points,axis_cache)
		var dirt: bool = document.get("surface","asphalt") == "dirt"
		for raw_polygon: PackedVector2Array in [marking_join.polygon]:
			var polygon: PackedVector2Array = raw_polygon
			for edge: int in range(polygon.size()):
				if _menu_yield_due():
					await get_tree().process_frame
					if not is_inside_tree(): return
					_slice_started = Time.get_ticks_usec()
				var a: Vector2 = polygon[edge]
				var b: Vector2 = polygon[(edge+1)%polygon.size()]
				if _on_join_cut(a,b,cuts): continue
				var normal_a: Vector2 = _roadside_miter(polygon,edge,cuts)
				var normal_b: Vector2 = _roadside_miter(polygon,(edge+1)%polygon.size(),cuts)
				var steps: int = maxi(1,ceili(a.distance_to(b)/0.20))
				for step: int in range(steps):
					if _menu_yield_due():
						await _yield_build()
						if not is_inside_tree(): return
					var p: Vector2 = a.lerp(b,float(step)/steps)
					var q: Vector2 = a.lerp(b,float(step+1)/steps)
					var normal_p: Vector2 = normal_a.lerp(normal_b,float(step)/steps)
					var normal_q: Vector2 = normal_a.lerp(normal_b,float(step+1)/steps)
					var across: Vector2 = (q-p).normalized().orthogonal()*0.085
					var midpoint: Vector2 = (p+q)*0.5
					var outward: Vector2 = across*5.0
					if Geometry2D.is_point_in_polygon(midpoint+outward,polygon): outward = -outward
					# Probe beyond this road edge. Testing the stripe itself would
					# leave a gap where adjacent sections' rounded end caps overlap.
					if not _road_edge_exposed(midpoint+outward,index,outlines,pieces): continue
					if theme_id == "winter" and not dirt:
						_winter_bank_section(winter_bank,p,q,normal_p,normal_q,points)
						winter_sections += 1
						_winter_deposit(winter_bank,(p+q)*0.5,(normal_p+normal_q)*0.5,winter_piles)
					_asphalt_fringe_quad(asphalt_fringe,
						p+normal_p*(-0.55 if theme_id == "desert" else 0.36),q+normal_q*(-0.55 if theme_id == "desert" else 0.36),
						p+normal_p*(0.92 if theme_id == "desert" else 0.56),q+normal_q*(0.92 if theme_id == "desert" else 0.56),points,axis_cache)
					fringe_count += 1
					var is_kerb: bool = not dirt and not _on_join_plane(a,b,cuts) and _inner_bend_distance(midpoint,points) >= 0.0
					# Continuous sand beneath the tapered kerb ends.
					# Only the outer contour varies; road/paint stay fixed.
					var outer_p: Vector2 = p+normal_p*_shoulder_width(p)
					var outer_q: Vector2 = q+normal_q*_shoulder_width(q)
					shoulder_mesh.add_quad(p,q,outer_p,outer_q)
					counts[0] += 1
					if theme_id == "desert" and sand_clods < 1800:
						var seed_value: int = absi(int(midpoint.x*1731.0+midpoint.y*7919.0))
						var taper: float = _berm_envelope(midpoint,points) if is_kerb else 0.0
						if seed_value%100 < (52 if is_kerb else 4) and (not is_kerb or taper > 0.08):
							var normal: Vector2 = (normal_p+normal_q)*0.5
							var center: Vector2 = midpoint+normal*(1.0+float(seed_value%13)*0.032)
							var size: float = (0.95+float(seed_value%11)*0.06)*(sqrt(taper) if is_kerb else 0.40)
							_sand_clod(shoulders,center,(q-p).angle(),size,seed_value,1.65 if is_kerb else 1.0)
							sand_clods += 1
					# Retain the authored road-edge marking and keep it smooth;
					# only the asphalt/sand colour transition receives subtle breakup.
					if dirt or theme_id in ["desert","winter"]: continue
					_quad(markings,VisualGeometry.world(p-normal_p*0.085)+Vector3.UP*0.018,VisualGeometry.world(q-normal_q*0.085)+Vector3.UP*0.018,
						VisualGeometry.world(q+normal_q*0.085)+Vector3.UP*0.018,VisualGeometry.world(p+normal_p*0.085)+Vector3.UP*0.018)
					counts[2] += 1
	if winter_sections > 0:
		_commit_winter_bank(winter_bank,texture,track.half_extent)
		set_meta("winter_smooth_sections",winter_sections)
		set_meta("winter_deposits",winter_piles.size())
	await shoulder_mesh.emit(shoulders,_yield_build if _menu_slices else Callable())
	if _menu_slices and not is_inside_tree(): return
	set_meta("desert_clod_count",sand_clods)
	await _build_kerbs(track)
	if counts[0]: await _commit_creator_road(shoulders,Color("99805e") if theme_id == "desert" else colors[2].darkened(0.20),texture,road_texture,track.half_extent,true)
	if counts[1]: await _commit_creator_road(asphalt,colors[2] if document.get("surface","asphalt") == "dirt" else colors[0],texture,road_texture,track.half_extent,false,false,false,document.get("surface","asphalt") == "asphalt")
	if fringe_count and theme_id != "winter" and document.get("surface","asphalt") == "asphalt": await _commit_creator_road(asphalt_fringe,colors[0],texture,road_texture,track.half_extent,false,false,false,true,true)
	if counts[2] and theme_id not in ["desert","winter"]: await _commit_creator_road(markings,Color("c8ccc2"),texture,road_texture,track.half_extent,false,false,false,false,false,true)
	if ground_count: await _commit_creator_road(ground_skirt,colors[1],texture,road_texture,track.half_extent,false,true)
	if cache_road_meshes and (not _menu_slices or is_inside_tree()):
		_remember_road_meshes(cache_key,first_child,track)


func _restore_road_meshes(key: Array) -> bool:
	for index: int in range(_road_mesh_cache.size()):
		var entry: Dictionary = _road_mesh_cache[index]
		if entry.key != key: continue
		_road_mesh_cache.remove_at(index)
		_road_mesh_cache.append(entry)
		for data: Dictionary in entry.meshes:
			# Only immutable road resources are shared. Every scene owns new nodes.
			var instance := MeshInstance3D.new()
			instance.mesh = data.mesh
			instance.material_override = data.material
			instance.transform = data.transform
			instance.layers = data.layers
			instance.cast_shadow = data.shadow
			add_child(instance)
		for name: String in entry.metadata: set_meta(name,entry.metadata[name])
		return true
	return false


func _remember_road_meshes(key: Array, first_child: int, track: NativeTrack) -> void:
	var meshes: Array[Dictionary] = []
	# Conservative vertex/index plus CPU/GPU mask allowance; cap both bytes
	# and entries. Oversized roads still use the ordinary uncached builder.
	var bytes: int = track.grid_width * track.grid_height * 16
	if bytes > ROAD_CACHE_BUDGET: return
	for index: int in range(first_child,get_child_count()):
		var instance: MeshInstance3D = get_child(index) as MeshInstance3D
		if instance == null or not instance.mesh is ArrayMesh: return
		var mesh: ArrayMesh = instance.mesh
		for surface: int in range(mesh.get_surface_count()):
			bytes += mesh.surface_get_array_len(surface)*96 + mesh.surface_get_array_index_len(surface)*4
		meshes.append({"mesh":instance.mesh,"material":instance.material_override,"transform":instance.transform,"layers":instance.layers,"shadow":instance.cast_shadow})
	if meshes.is_empty() or bytes > ROAD_CACHE_BUDGET: return
	var metadata: Dictionary = {}
	for name: String in ["winter_smooth_sections","winter_deposits","desert_clod_count"]:
		if has_meta(name): metadata[name] = get_meta(name)
	var entry: Dictionary = {"key":key.duplicate(true),"meshes":meshes,"metadata":metadata,"bytes":bytes}
	_admit_road_entry(entry)
	var id: String = ROAD_DISK_CACHE.identity(key)
	if persist_road_meshes and (not editor_preview or _pending_road_bakes.has(id)):
		ROAD_DISK_CACHE.write_entry(entry)
		_pending_road_bakes.erase(id)


static func request_saved_road_bake(track: NativeTrack) -> void:
	# Saving can reuse the completed editor road, or its pending sliced build.
	# Never rebuild scenery synchronously in the Save handler.
	if track == null or ROAD_DISK_CACHE.directory.is_empty(): return
	var theme: String = TrackTheme.normalized(str(track.metadata.get("theme","pine")))
	var key: Array = [track.content_hash,VERSION,theme,TrackTheme.palette(theme),true]
	for entry: Dictionary in _road_mesh_cache:
		if entry.key == key:
			ROAD_DISK_CACHE.write_entry(entry)
			_pending_road_bakes.erase(ROAD_DISK_CACHE.identity(key))
			return
	if _pending_road_bakes.size() >= 8: _pending_road_bakes.erase(_pending_road_bakes.keys()[0])
	_pending_road_bakes[ROAD_DISK_CACHE.identity(key)] = true


static func _admit_road_entry(entry: Dictionary) -> void:
	for index: int in range(_road_mesh_cache.size()-1,-1,-1):
		if _road_mesh_cache[index].key == entry.key: _road_mesh_cache.remove_at(index)
	var total: int = int(entry.bytes)
	for existing: Dictionary in _road_mesh_cache: total += int(existing.bytes)
	while not _road_mesh_cache.is_empty() and (_road_mesh_cache.size() >= 2 or total > ROAD_CACHE_BUDGET):
		total -= int(_road_mesh_cache.pop_front().bytes)
	_road_mesh_cache.append(entry)



func _join_cuts(pieces: Array, index: int) -> Array[Dictionary]:
	return RoadEdges._join_cuts(pieces,index)


func _trim_join_outline(source: PackedVector2Array, cuts: Array[Dictionary]) -> PackedVector2Array:
	return RoadEdges._trim_join_outline(source,cuts)


func _trim_side_tip(side: PackedVector2Array, cut: Dictionary) -> PackedVector2Array:
	return RoadEdges._trim_side_tip(side,cut)


func _on_join_cut(a: Vector2, b: Vector2, cuts: Array[Dictionary]) -> bool:
	return RoadEdges._on_join_cut(a,b,cuts)


func _on_join_plane(a: Vector2, b: Vector2, cuts: Array[Dictionary]) -> bool:
	return RoadEdges._on_join_plane(a,b,cuts)


func _roadside_miter(polygon: PackedVector2Array, index: int, cuts: Array[Dictionary]) -> Vector2:
	var point: Vector2 = polygon[index]
	var before: Vector2 = polygon[(index+polygon.size()-1)%polygon.size()]
	var after: Vector2 = polygon[(index+1)%polygon.size()]
	if not _on_join_cut(before,point,cuts) and not _on_join_cut(point,after,cuts):
		return RoadEdges._edge_miter(polygon,index)
	for cut: Dictionary in cuts:
		if absf((point-Vector2(cut.point)).dot(cut.normal)) < 0.001:
			var normal: Vector2 = Vector2(cut.normal).orthogonal()
			if normal.dot(point-Vector2(cut.point)) < 0: normal = -normal
			return normal
	return RoadEdges._roadside_miter(polygon,index,cuts)


func _clean_outline(source: PackedVector2Array) -> PackedVector2Array:
	return RoadEdges._clean_outline(source)


func _edge_miter(polygon: PackedVector2Array, index: int) -> Vector2:
	return RoadEdges._edge_miter(polygon,index)


func _shoulder_width(point: Vector2) -> float:
	# Broad erosion lobes instead of a serrated fringe. World position keeps
	# neighbouring sections continuous; only the cosmetic outer edge moves.
	# Bounded to 1.05-1.65 m, inside the existing 1.8 m grass skirt.
	return (3.0 if theme_id == "desert" else 1.35) + sin(point.x*0.43+point.y*0.19)*0.20 + sin(point.y*0.91-point.x*0.57)*0.08 + sin(point.x*2.1+point.y*1.7)*0.02


func _berm_envelope(point: Vector2, points: PackedVector2Array) -> float:
	if points.size() < 3: return 0.0
	var distances: Array[float] = [0.0]
	var nearest: int = 0
	var best: float = INF
	for i: int in range(points.size()):
		if i > 0: distances.append(distances[-1]+points[i-1].distance_to(points[i]))
		var squared: float = point.distance_squared_to(points[i])
		if squared < best:
			best = squared
			nearest = i
	if nearest == 0 or nearest == points.size()-1: return 0.0
	var first: int = nearest
	var last: int = nearest
	while first > 1 and _sand_bend_sample(points,first-1): first -= 1
	while last < points.size()-2 and _sand_bend_sample(points,last+1): last += 1
	var start: float = (distances[first-1]+distances[first])*0.5
	var finish: float = (distances[last]+distances[last+1])*0.5
	var along: float = _sand_coordinates(point,points).x
	return smoothstep(0.0,3.0,along-start)*smoothstep(0.0,3.0,finish-along)


func _sand_bend_sample(points: PackedVector2Array, index: int) -> bool:
	return ((points[index+1]-points[index]).normalized()-(points[index]-points[index-1]).normalized()).length_squared() >= 0.0001


func _sand_clod(tool: SurfaceTool, center: Vector2, turn: float, size: float, seed_value: int, height_scale: float) -> void:
	# Independent low collapsed sand clods: eighteen opaque facets, no raised ribbon.
	var ring := PackedVector3Array()
	var origin: Vector3 = VisualGeometry.world(center)+Vector3.UP*-0.012
	for i: int in range(6):
		var angle: float = TAU*float(i)/6.0
		var irregular: float = 0.82+float((seed_value+i*17)%11)*0.025
		var offset := Vector2(cos(angle)*0.28,sin(angle)*0.22).rotated(turn)*size*irregular
		ring.append(origin+Vector3(offset.x,0.018,-offset.y))
	var crown: Vector3 = origin+Vector3(0.025,0.20*size*height_scale,0.01)
	for i: int in range(6):
		var next: int = (i+1)%6
		var middle: Vector3 = (ring[i]+ring[next]+crown)/3.0+Vector3.UP*(0.025*size)
		for vertex: Vector3 in [ring[i],ring[next],middle,ring[next],crown,middle, crown,ring[i],middle]:
			tool.set_uv(Vector2(-1.0,0.35))
			tool.add_vertex(vertex)


func _asphalt_fringe_quad(tool: SurfaceTool, inner_a: Vector2, inner_b: Vector2, outer_a: Vector2, outer_b: Vector2, points: PackedVector2Array, axis_cache: Dictionary = {}) -> void:
	var vertices: Array[Vector2] = [inner_a,outer_b,inner_b,inner_a,outer_a,outer_b]
	var across: Array[float] = [0.0,1.0,0.0,0.0,1.0,1.0]
	for i: int in range(6):
		tool.set_uv(Vector2(0.0,across[i]))
		tool.set_uv2(_cached_asphalt_axis(vertices[i],points,axis_cache))
		tool.add_vertex(VisualGeometry.world(vertices[i])+Vector3.UP*0.013)


func _inner_bend_distance(point: Vector2, points: PackedVector2Array) -> float:
	return RoadEdges._inner_bend_distance(point,points)


func _cached_asphalt_axis(point: Vector2, points: PackedVector2Array, cache: Dictionary) -> Vector2:
	if not cache.has(point): cache[point] = _asphalt_axis(point,points)
	return cache[point]


func _asphalt_axis(point: Vector2, points: PackedVector2Array) -> Vector2:
	# Double-angle encoding treats forward/backward as the same grain axis.
	# Interpolation remains continuous where headings wrap or pieces reverse.
	var nearest: float = INF
	var axis := Vector2.ZERO
	for i: int in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var distance: float = point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,a,b))
		if distance < nearest and a.distance_squared_to(b) > 0.000001:
			nearest = distance
			var direction: Vector2 = (b-a).normalized()
			# VisualGeometry maps simulation Y to negative world Z.
			axis = Vector2(direction.x*direction.x-direction.y*direction.y,-2.0*direction.x*direction.y)
	return axis


func _sand_coordinates(point: Vector2, points: PackedVector2Array) -> Vector2:
	var best: float = INF
	var result := Vector2.ZERO
	var distance_along: float = 0.0
	for i: int in range(points.size()-1):
		var delta: Vector2 = points[i+1]-points[i]
		var length: float = delta.length()
		if length < 0.00001: continue
		var direction: Vector2 = delta/length
		var projected: float = clampf((point-points[i]).dot(direction),0.0,length)
		var nearest: Vector2 = points[i]+direction*projected
		var distance: float = point.distance_squared_to(nearest)
		if distance < best:
			best = distance
			result = Vector2(distance_along+projected,(point-nearest).dot(direction.orthogonal()))
		distance_along += length
	return result


func _road_polygon(tool: SurfaceTool, polygon: PackedVector2Array, height: float, points: PackedVector2Array = PackedVector2Array(), axis_cache: Dictionary = {}) -> int:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	var sand_cache: Dictionary = {}
	if theme_id in ["desert","winter"] and not points.is_empty():
		for i: int in range(0,indices.size(),3):
			_sand_triangle(tool,polygon[indices[i]],polygon[indices[i+1]],polygon[indices[i+2]],height,points,0,axis_cache,sand_cache)
	else:
		for index: int in indices:
			tool.set_uv2(_cached_asphalt_axis(polygon[index],points,axis_cache))
			tool.add_vertex(VisualGeometry.world(polygon[index])+Vector3.UP*height)
	return indices.size()/3


func _sand_triangle(tool: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, height: float, points: PackedVector2Array, depth: int, axis_cache: Dictionary, sand_cache: Dictionary) -> void:
	var ab: float = a.distance_squared_to(b)
	var bc: float = b.distance_squared_to(c)
	var ca: float = c.distance_squared_to(a)
	if maxf(ab,maxf(bc,ca)) > 4.0 and depth < 12:
		if bc >= ab and bc >= ca:
			_sand_triangle(tool,b,c,a,height,points,depth+1,axis_cache,sand_cache)
		elif ca > ab:
			_sand_triangle(tool,c,a,b,height,points,depth+1,axis_cache,sand_cache)
		else:
			var middle: Vector2 = (a+b)*0.5
			_sand_triangle(tool,a,middle,c,height,points,depth+1,axis_cache,sand_cache)
			_sand_triangle(tool,middle,b,c,height,points,depth+1,axis_cache,sand_cache)
		return
	for point: Vector2 in [a,b,c]:
		if not sand_cache.has(point): sand_cache[point] = _sand_coordinates(point,points)
		tool.set_uv(sand_cache[point])
		tool.set_uv2(_cached_asphalt_axis(point,points,axis_cache))
		tool.add_vertex(VisualGeometry.world(point)+Vector3.UP*height)



func _road_edge_exposed(point: Vector2, index: int, outlines: Array[Dictionary], pieces: Array = []) -> bool:
	return RoadEdges._road_edge_exposed(point,index,outlines,pieces)


func _piece_end_joined(pieces: Array, index: int, endpoint: Vector2) -> bool:
	for other: int in range(pieces.size()):
		if other == index: continue
		var piece: Dictionary = pieces[other]
		if endpoint.distance_to(Vector2(piece.position[0],piece.position[1])) <= RoadPieces.JOIN_DISTANCE: return true
		if endpoint.distance_to(RoadPieces.end_pose(piece).position) <= RoadPieces.JOIN_DISTANCE: return true
	return false


func _creator_overlay_mask(track: NativeTrack, paint: Array) -> Image:
	var excluded: PackedByteArray = RoadKerbs.exclusion_mask(track,paint)
	# Only authored paint may replace the decorative verge. Native road/kerb
	# cells must keep their skirt, which conceals the coarse raster boundary.
	var painted := PackedInt32Array()
	painted.resize(track.cells.size())
	painted.fill(-1)
	var paint_mask := PackedInt32Array()
	paint_mask.resize(track.cells.size())
	paint_mask.fill(1)
	var overlays: Array = paint.duplicate(true)
	for stroke: Dictionary in overlays: stroke.protect_road = false
	TrackCompiler._paint(overlays,painted,Vector2i(track.grid_width,track.grid_height),track.half_extent,track.cell_size,paint_mask)
	var mask := Image.create(track.grid_width,track.grid_height,false,Image.FORMAT_RGB8)
	mask.fill(Color.WHITE)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			# Road protection preserves asphalt/markings; authored non-grass
			# paint replaces only the decorative verge beneath its footprint.
			var index: int = y*track.grid_width+x
			mask.set_pixel(x,y,Color(1.0 if excluded[index] == 0 else 0.0,1.0 if painted[index] in [-1,1] else 0.0,1.0 if painted[index] == 2 else 0.0,1.0))
	return mask


func _creator_road_mask(track: NativeTrack) -> Image:
	var mask := Image.create(track.grid_width,track.grid_height,false,Image.FORMAT_L8)
	mask.fill(Color.BLACK)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if track.cells[y*track.grid_width+x] == 0:
				mask.set_pixel(x,y,Color.WHITE)
	return mask



func _commit_creator_road(tool: SurfaceTool, color: Color, mask: Texture2D, road_mask: Texture2D, extent: Vector2, gravel: bool = false, grass: bool = false, kerb: bool = false, asphalt_surface: bool = false, edge_fringe: bool = false, road_marking: bool = false) -> void:
	# Polygon triangulation and edge strips can have opposite winding. All
	# these surfaces are horizontal: normalize clockwise top faces and use
	# explicit up normals instead of inferring lighting from polygon order.
	var source: ArrayMesh = tool.commit()
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null: uv = arrays[Mesh.ARRAY_TEX_UV]
	var uv2 := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV2] != null: uv2 = arrays[Mesh.ARRAY_TEX_UV2]
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: int in range(0,vertices.size(),3):
		if _menu_yield_due():
			if not await _yield_build(): return
		var order: Array[int] = [triangle,triangle+1,triangle+2]
		if (vertices[order[1]]-vertices[order[0]]).cross(vertices[order[2]]-vertices[order[0]]).y > 0.0:
			order = [triangle,triangle+2,triangle+1]
		for index: int in order:
			flat.set_normal((vertices[order[2]]-vertices[order[0]]).cross(vertices[order[1]]-vertices[order[0]]).normalized() if theme_id == "desert" and gravel else Vector3.UP)
			if not uv.is_empty(): flat.set_uv(uv[index])
			if not uv2.is_empty(): flat.set_uv2(uv2[index])
			flat.add_vertex(vertices[index])
	var instance := MeshInstance3D.new()
	instance.mesh = flat.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/storm_creator_road.gdshader") if theme_id == "storm" and not grass and not gravel else CREATOR_ROAD_SHADER
	material.set_shader_parameter("surface_factors", SURFACE_FACTORS)
	material.set_shader_parameter("painted_grass_texture", GRASS_TEXTURE)
	_bind_grass(material)
	material.set_shader_parameter("grass_color", colors[1])
	material.set_shader_parameter("overlay_mask",mask)
	material.set_shader_parameter("verge_blend_mask",mask)
	material.set_shader_parameter("road_mask",road_mask)
	material.set_shader_parameter("road_mask_texel",Vector2(1.0/road_mask.get_width(),1.0/road_mask.get_height()))
	material.set_shader_parameter("sand_color",Color("99805e") if theme_id == "desert" else colors[2].darkened(0.20))
	material.set_shader_parameter("map_extent",extent)
	material.set_shader_parameter("road_color",color)
	material.set_shader_parameter("asphalt_base_color",colors[0])
	material.set_shader_parameter("icy_road",theme_id == "winter" and color == colors[0] and not gravel and not grass and not kerb)
	material.set_shader_parameter("wet_road",theme_id == "storm" and not gravel and not grass and (asphalt_surface or road_marking or kerb))
	material.set_shader_parameter("gravel",gravel)
	material.set_shader_parameter("packed_sand",theme_id == "desert")
	material.set_shader_parameter("grass",grass)
	material.set_shader_parameter("kerb",kerb)
	material.set_shader_parameter("asphalt_surface",asphalt_surface)
	material.set_shader_parameter("edge_fringe",edge_fringe)
	material.set_shader_parameter("road_marking",road_marking)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if theme_id == "night_city" and partition_night_ground:
		_add_lit_road_parts(instance)
		instance.free()
	else:
		add_child(instance)

func _add_lit_road_parts(source: MeshInstance3D) -> void:
	# Keep every triangle and its attributes. Smaller spatial groups allow the
	# Compatibility renderer to associate local lamps with each road section.
	var arrays: Array = source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	if arrays[Mesh.ARRAY_TEX_UV] != null: uv = arrays[Mesh.ARRAY_TEX_UV]
	if arrays[Mesh.ARRAY_TEX_UV2] != null: uv2 = arrays[Mesh.ARRAY_TEX_UV2]
	var groups: Dictionary = {}
	for first: int in range(0,vertices.size(),3):
		var center: Vector3 = (vertices[first]+vertices[first+1]+vertices[first+2])/3.0
		var cell := Vector2i(floori(center.x/NIGHT_ROAD_GROUP_SIZE),floori(center.z/NIGHT_ROAD_GROUP_SIZE))
		if not groups.has(cell):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[cell] = tool
		var tool: SurfaceTool = groups[cell]
		for index: int in range(first,first+3):
			tool.set_normal(normals[index])
			if not uv.is_empty(): tool.set_uv(uv[index])
			if not uv2.is_empty(): tool.set_uv2(uv2[index])
			tool.add_vertex(vertices[index])
	for cell: Vector2i in groups:
		var part := MeshInstance3D.new()
		part.name = "LitRoadSection"
		part.mesh = (groups[cell] as SurfaceTool).commit()
		part.material_override = source.material_override
		part.cast_shadow = source.cast_shadow
		add_child(part)


func _authored_barrier_cells(track: NativeTrack) -> PackedByteArray:
	var mask := PackedByteArray()
	# Low bridge undersides already have their ramp/fascia mesh. Never add
	# generic 65 cm barrier blocks that protrude through the ramp asphalt.
	if not track.creator_bridges.is_empty():
		mask.resize(track.cells.size())
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				if track.cells[y*track.grid_width+x] != 4: continue
				var point := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
				for span: Dictionary in track.creator_bridges:
					if CreatorBridges.blocks_ground(span,point): mask[y*track.grid_width+x] = 1
	if _hide_creator_boundary(track):
		# The finite creator perimeter still blocks the car, but an empty map
		# is presented as open terrain rather than a walled enclosure.
		mask.resize(track.cells.size())
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				if _boundary_cell(track,x,y): mask[y*track.grid_width+x] = 1
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
		if CreatorCatalog.family(object.kind).is_empty() or object.kind in CreatorCatalog.DECORATIVE or object.kind in CreatorCatalog.SOFT: continue
		if mask.is_empty(): mask.resize(track.cells.size())
		var center := Vector2(object.position[0],object.position[1])
		var reach: float = CreatorObjects.size_of(object).length()*0.5
		for y: int in range(maxi(0,floori((track.half_extent.y-center.y-reach)/track.cell_size)),mini(track.grid_height,ceili((track.half_extent.y-center.y+reach)/track.cell_size))):
			for x: int in range(maxi(0,floori((center.x-reach+track.half_extent.x)/track.cell_size)),mini(track.grid_width,ceili((center.x+reach+track.half_extent.x)/track.cell_size))):
				var point := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
				if CreatorObjects.solid_contains(object,point): mask[y*track.grid_width+x] = 1
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
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
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
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
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
	# Owner rejected standing grass blades; meadow uses the static surface only.
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
	var accepted_sites: int = 0
	for site: Vector2i in _scenery_sites(track,stride):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
		if accepted_sites >= 480: break
		var seed_value: int = (site.x * 73856093 ^ site.y * 19349663) & 0x7fffffff
		var cell := Vector2i(site.x+(seed_value%(jitter*2+1))-jitter,site.y+((seed_value/11)%(jitter*2+1))-jitter)
		if not _cover_clear(track, cell, 1.3): continue
		accepted_sites += 1
		# Preserve the original site budget and stone population while replacing grass.
		if theme_id in ["pine","storm"] and seed_value % 4 != 0: continue
		var center := Vector3((cell.x+0.5)*track.cell_size-track.half_extent.x, 0.014, (cell.y+0.5)*track.cell_size-track.half_extent.y)
		if relief != null: center.y += relief.height_at(Vector2(center.x,-center.z))
		var scale_value: float = 0.8 + (seed_value % 11) * 0.035
		var turn: float = (seed_value % 37) * 0.17
		# Grid strides are multiples of four, so low seed bits always selected
		# stones here. Use higher bits for sparse desert scrub (about one in five).
		var desert_scrub: bool = theme_id == "desert" and (seed_value >> 8) % 5 == 0
		# Trees are exclusively compiled solid objects; tiny cover is decorative.
		var color: Color = stone if seed_value % 4 == 0 else foliage
		var height: float = 0.08 if seed_value % 4 == 0 else 0.22
		if desert_scrub:
			_desert_scrub(scenery,center,scale_value,turn)
			scenic_count += 1
			continue
		_mound(scenery, center, Vector3(0.18 if seed_value % 4 == 0 else 0.4, height, 0.14 if seed_value % 4 == 0 else 0.3) * scale_value, turn, color)
		var secondary: Vector3 = center+Vector3(0.5,0,0.25)
		if relief != null: secondary.y = 0.014+relief.height_at(Vector2(secondary.x,-secondary.z))
		_mound(scenery, secondary, Vector3(0.10 if seed_value % 4 == 0 else 0.24, height * 0.6, 0.08 if seed_value % 4 == 0 else 0.2), turn+1.2, color.darkened(0.08))
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


func _desert_scrub(tool: SurfaceTool, center: Vector3, size: float, turn: float) -> void:
	# Sparse original 3D dry grass fans; 18 opaque triangles per existing site.
	# Dark roots and straw tips replace the rounded green low-cover mounds.
	for blade: int in range(9):
		var angle: float = turn+float(blade)*2.399
		var axis := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-axis.z,0,axis.x)*0.036*size
		var base: Vector3 = center+axis*0.04*size
		var knee: Vector3 = center+(axis*0.13+Vector3.UP*0.19)*size
		var tip: Vector3 = center+(axis*(0.28+float(blade%3)*0.04)+Vector3.UP*(0.13+float(blade%4)*0.04))*size
		for vertex: Vector3 in [base-side,knee,tip,knee,base+side,tip]:
			var factor: float = clampf((vertex-center).length()/(0.35*size),0.0,1.0)
			tool.set_color(Color("575d32").lerp(Color("b1a36a"),factor))
			tool.add_vertex(vertex)


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
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
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
	ContactShading.build_props(self,track,relief)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	var ink_tool := SurfaceTool.new()
	ink_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ink_count: int = 0
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
		var center := Vector3(float(object.position[0]),0.014,-float(object.position[1]))
		if relief != null: center.y += relief.height_at(Vector2(center.x,-center.z))
		var object_scale: float = float(object.get("scale",1.0))
		if object.kind == "light" and theme_id == "night_city":
			var lamp := OmniLight3D.new()
			lamp.name = "StreetLamp"
			lamp.position = center+(Vector3(0.4,4.65,0)*object_scale).rotated(Vector3.UP,deg_to_rad(float(object.rotation)))
			lamp.light_color = Color("ffda98")
			lamp.light_energy = 5.0
			lamp.omni_range = 15.0*object_scale
			lamp.omni_attenuation = 1.2
			lamp.shadow_enabled = false
			lamp.light_cull_mask = 1
			add_child(lamp)
			var glow := VisualGeometry.material(Color("ffe3ae"))
			glow.emission_enabled = true
			glow.emission = Color("ffda98")
			VisualGeometry.box(self,Vector3(0.8,0.06,0.32)*object_scale,lamp.position,glow)
		if object.kind in CreatorCatalog.SOFT:
			var node := Node3D.new()
			add_child(node)
			node.position = center
			node.rotation.y = deg_to_rad(float(object.rotation))
			var prop_tool := SurfaceTool.new()
			prop_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			CreatorPropVisual.append(prop_tool,self,object.kind,Vector3.ZERO,object_scale,0)
			_finish_prop_mesh(prop_tool,node)
			light_instances.append(node)
			continue
		if object.kind in ["tree","broadleaf","bush","barrier","rock","boulder","slate","cliff"]:
			if object.kind == "tree": _pine(ink_tool,center,1.25*object_scale,-deg_to_rad(float(object.rotation)),TrackTheme.foliage(theme_id))
			else: CreatorPropVisual.append(ink_tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation)))
			ink_count += 1
			continue
		if CreatorPropVisual.append(tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation))):
			count += 1
			continue
		if object.kind == "tree":
			_pine(tool,center,1.25*object_scale,-deg_to_rad(float(object.rotation)),TrackTheme.foliage(theme_id))
		elif object.kind == "rock":
			_mound(tool,center,Vector3(0.95,0.5,0.9)*object_scale,deg_to_rad(float(object.rotation)),TrackTheme.stone(theme_id))
		elif object.kind in ["boulder","slate","cliff"]:
			var size: Vector2 = CreatorObjects.size_of(object)
			var height: float = {"boulder":2.0,"slate":0.65,"cliff":3.4}[object.kind]*object_scale
			var turn: float = deg_to_rad(float(object.rotation))
			_mound(tool,center,Vector3(size.x*0.5,height,size.y*0.5),turn,TrackTheme.stone(theme_id))
			if object.kind == "cliff":
				for x: float in [-0.3,0.1,0.35]:
					_mound(tool,center+Vector3(size.x*x,0,0).rotated(Vector3.UP,turn),Vector3(size.x*0.19,height*(0.8+x),size.y*0.47),turn+x,TrackTheme.stone(theme_id).darkened(0.08))
		elif object.kind in ["oil","puddle","jump"]:
			HazardVisual.build(self,object)
			continue
		elif object.kind in ["tyre_wall","tyre_stack"]: continue # Shared instanced mesh below.
		elif object.kind == "fence":
			var turn: float = deg_to_rad(float(object.rotation))
			for x: float in [-2.8,0.0,2.8]:
				_colored_box(tool,center+(Vector3(x,0.64,0)*object_scale).rotated(Vector3.UP,turn),Vector3(0.20,1.28,0.20)*object_scale,turn,Color("706b5b"))
			for height: float in [0.42,1.02]:
				_colored_box(tool,center+Vector3(0,height*object_scale,0),Vector3(6,0.16,0.16)*object_scale,turn,Color("898373"))
		else: continue # Barrier/water/dirt already rendered from exact native cells.
		count += 1
	if count > 0:
		tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = tool.commit()
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		# Small roof seams and foliage use their silhouettes, not intersecting ink hulls.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		add_child(mesh)

	if ink_count > 0:
		ink_tool.generate_normals()
		var ink_mesh := MeshInstance3D.new()
		ink_mesh.mesh = ink_tool.commit()
		var ink_material := VisualGeometry.material(Color.WHITE)
		ink_material.vertex_color_use_as_albedo = true
		ink_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		VisualGeometry.ink(ink_material)
		ink_mesh.material_override = ink_material
		add_child(ink_mesh)

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
		_tyre_positions.clear()
		_tyre_spins.clear()
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
		var angle: float = TAU * i / 7.0
		var radial: Vector3 = Vector3(cos(angle) * dimensions.x, 0, sin(angle) * dimensions.z).rotated(Vector3.UP,turn)
		lower.append(center + radial * (0.91 + (i%3)*0.06))
		upper.append(center + radial * 0.57 + Vector3(0.06, dimensions.y * (0.7+(i%2)*0.14), 0.03))
	var top: Vector3 = center + Vector3(0.1, dimensions.y, -0.03)
	for i: int in range(7):
		var j: int = (i+1)%7
		tool.set_color(color.darkened(0.08 if i%3 == 0 else 0.0))
		_quad(tool, lower[j], lower[i], upper[i], upper[j])
		tool.set_color(color.lightened(0.045))
		for v: Vector3 in [upper[j], top, upper[i]]: tool.add_vertex(v)


func _pine(tool: SurfaceTool, center: Vector3, scale_value: float, turn: float, color: Color) -> void:
	CreatorPropVisual.pine(tool,self,center,scale_value,turn,color)


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
	var authored: bool = not RoadPieces.road_frame(track.metadata.get("creator_document",{}).get("pieces",[]),track.finish_center,track.finish_forward).is_empty()
	if authored: widths = Vector2.ONE*track.finish_half_width
	if theme_id in ["desert","winter"]:
		_build_faded_finish(track,side,widths)
		return
	for row: int in range(2):
		for i: int in range(ceili(track.finish_half_width * 2 / size)):
			var offset: float = -track.finish_half_width + (i + 0.5) * size
			if not authored and (offset - size * 0.5 < -widths.x or offset + size * 0.5 > widths.y):
				continue
			var low: float = maxf(-widths.x,offset-size*0.5)
			var high: float = minf(widths.y,offset+size*0.5)
			var point: Vector2 = track.finish_center + side * ((low+high)*0.5) + track.finish_forward * (row - 0.5) * size
			if not authored and track.cell_at(point) not in [0, 2, 5, 6]:
				continue
			var center: Vector3 = VisualGeometry.world(point) + Vector3.UP * 0.024
			var across_half: float = (high-low) * 0.5
			var along_half: float = size * 0.5
			var across: Vector3 = VisualGeometry.world(side) * across_half
			var along: Vector3 = VisualGeometry.world(track.finish_forward) * along_half
			var parity: int = (row+i)%2
			_quad(light if parity == 0 else dark, center-across-along, center+across-along, center+across+along, center-across+along)
			counts[parity] += 1
	if counts[0]: _commit(light, STANDARD_FINISH_COLORS[0], "FinishLight")
	if counts[1]: _commit(dark, STANDARD_FINISH_COLORS[1], "FinishDark")


func _build_faded_finish(track: NativeTrack, side: Vector2, widths: Vector2) -> void:
	var palette: Array[Color] = WINTER_FINISH_COLORS if theme_id == "winter" else DESERT_FINISH_COLORS
	var prefix: String = "WinterSnowFinish" if theme_id == "winter" else "DesertSandFinish"
	var pale := SurfaceTool.new()
	var dark := SurfaceTool.new()
	pale.begin(Mesh.PRIMITIVE_TRIANGLES)
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell: float = 0.54
	var columns: int = ceili((widths.x+widths.y)/cell)
	# Muted mineral pigment is worked into the road surface. Small deterministic
	# gaps and uneven edges let the packed sand show through like a worn marking.
	for row: int in range(2):
		for column: int in range(columns):
			var low: float = -widths.x+column*cell
			var high: float = minf(widths.y,low+cell)
			if high <= low: continue
			var edge_wear: float = 0.006+float((column*5+row*7)%4)*0.003
			var along_half: float = cell*0.5-edge_wear
			var across_half: float = (high-low)*0.5-edge_wear*0.7
			var across_wear: float = (float((column*7+row*3)%5)-2.0)*0.008
			var along_wear: float = (float((column*3+row*5)%5)-2.0)*0.007
			var center2: Vector2 = track.finish_center+side*((low+high)*0.5+across_wear)+track.finish_forward*((float(row)-0.5)*cell+along_wear)
			var center: Vector3 = VisualGeometry.world(center2)+Vector3.UP*(0.030 if theme_id == "winter" else 0.017)
			var across: Vector3 = VisualGeometry.world(side)*maxf(0.02,across_half)
			var along: Vector3 = VisualGeometry.world(track.finish_forward)*maxf(0.02,along_half)
			var tool: SurfaceTool = pale if (column+row)%2 == 0 else dark
			var corners: Array[Vector3] = [center-across-along,center+across-along,center+across+along,center-across+along]
			var texcoords: Array[Vector2] = [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
			for index: int in [0,2,1,0,3,2]:
				tool.set_uv(texcoords[index])
				tool.add_vertex(corners[index])
	_commit(pale,palette[0],prefix+"Pale")
	_commit(dark,palette[1],prefix+"Dark")
	for marking_name: String in [prefix+"Pale",prefix+"Dark"]:
		var marking := get_node(marking_name) as MeshInstance3D
		var pigment := ShaderMaterial.new()
		pigment.shader = preload("res://track/desert_finish.gdshader")
		pigment.set_shader_parameter("pigment_color",palette[0 if marking_name.ends_with("Pale") else 1])
		pigment.set_shader_parameter("wear_texture",SURFACE_FACTORS)
		marking.material_override = pigment
		marking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a,c,b,a,d,c]: tool.add_vertex(v)


func _commit(tool: SurfaceTool, color: Color, node_name: String = "") -> void:
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	var material := VisualGeometry.material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if theme_id == "storm" and node_name in ["FinishLight","FinishDark"]:
		material.albedo_color = color.darkened(0.10)
		material.roughness = 0.24
		material.metallic_specular = 0.5
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	instance.material_override = material
	if not node_name.is_empty(): instance.name = node_name
	add_child(instance)

func update_tyres(state: VehicleState, origins: PackedVector2Array) -> void:
	if tyre_instances == null: return
	if _tyre_positions.size() != origins.size():
		_tyre_positions.resize(origins.size())
		_tyre_spins.resize(origins.size())
		_tyre_spins.fill(NAN)
	for i: int in range(origins.size()):
		var p: Vector2 = origins[i]
		var spin: float = 0.0
		if i < state.loose_tyres.size():
			var tyre: Array = state.loose_tyres[i]
			p = Vector2(tyre[0],tyre[1])
			spin = tyre[4]
		# Only presentation data is cached. Reset and moving tyres still upload
		# their exact transforms; resting stacks do not dirty the GPU buffer.
		if _tyre_positions[i] == p and _tyre_spins[i] == spin: continue
		_tyre_positions[i] = p
		_tyre_spins[i] = spin
		var ground_height: float = relief.height_at(p) if relief != null else 0.0
		tyre_instances.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,spin),VisualGeometry.world(p)+Vector3.UP*(0.014+ground_height)))

func _finish_prop_mesh(tool: SurfaceTool, parent: Node3D) -> void:
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := VisualGeometry.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)

func update_light_props(state: VehicleState) -> void:
	for index: int in range(mini(light_instances.size(),state.light_props.size())):
		var row: Array = state.light_props[index]
		light_instances[index].position.x = row[0]
		light_instances[index].position.z = -float(row[1])
		light_instances[index].position.y = 0.014+(relief.height_at(Vector2(row[0],row[1])) if relief != null else 0.0)
		light_instances[index].rotation.z = float(row[4])*0.9


func _build_kerbs(track: NativeTrack) -> void:
	if theme_id == "winter": return # Ploughed snow covers the retained canonical kerbs.
	if track.kerbs.triangles.is_empty(): return
	if theme_id == "desert" and not track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): return
	var document: Dictionary = track.metadata.get("creator_document",{})
	var triangles: Array[Dictionary] = track.kerbs.triangles
	if not document.get("pieces",[]).is_empty() and document.get("base_track","") == "" and document.get("surface","asphalt") != "dirt":
		triangles = preload("res://track/visual_road_join.gd").kerb_triangles(document)
	if triangles.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: Dictionary in triangles:
		if _menu_yield_due():
			if not await _yield_build(): return
		var vertices := PackedVector3Array()
		for i: int in range(3):
			var point: Vector3 = VisualGeometry.world(triangle.points[i])
			var height: float = triangle.heights[i]
			if theme_id == "desert":
				# Keep the canonical footprint; irregular low sand crowns are cosmetic.
				var rough: float = sin(point.x*8.1+point.z*3.7)*sin(point.z*9.3-point.x*2.1)
				height *= 1.25+rough*0.55
			vertices.append(point+Vector3.UP*(0.018+height))
		var normal: Vector3 = (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
		var order: Array = [0,1,2] if normal.y >= 0.0 else [0,2,1]
		if normal.y < 0.0: normal = -normal
		for i: int in order:
			tool.set_normal(normal)
			tool.set_uv(triangle.uv[i])
			tool.add_vertex(vertices[i])
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/kerb.gdshader")
	material.set_shader_parameter("surface_factors",SURFACE_FACTORS)
	if theme_id == "desert":
		material.set_shader_parameter("sand_berm",true)
		material.set_shader_parameter("red",Color("ad8955"))
		material.set_shader_parameter("pale_color",Color("bbae91"))
	var mask := Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_R8,track.kerbs.blocked)
	# Canonical bytes are 0/1; shader samples normalized bytes.
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if track.kerbs.blocked[y*track.grid_width+x] != 0: mask.set_pixel(x,y,Color.WHITE)
	material.set_shader_parameter("exclusion",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("map_extent",track.half_extent)
	mesh.material_override = material
	add_child(mesh)


func _build_snow_banks(track: NativeTrack) -> void:
	if has_meta("winter_smooth_sections"): return
	if track.snow_banks.triangles.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: Dictionary in track.snow_banks.triangles:
		var points := PackedVector3Array()
		for i: int in range(3): points.append(VisualGeometry.world(triangle.points[i])+Vector3.UP*(0.025+triangle.heights[i]*(0.94+0.12*sin(triangle.points[i].x*0.65)*sin(triangle.points[i].y*0.51))))
		var normal: Vector3 = (points[2]-points[0]).cross(points[1]-points[0]).normalized()
		var order: Array = [0,1,2] if normal.y >= 0.0 else [0,2,1]
		if normal.y < 0.0: normal = -normal
		for i: int in order:
			tool.set_normal(normal)
			tool.add_vertex(points[i])
	var mesh := MeshInstance3D.new()
	mesh.name = "WinterSnowBanks"
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/winter_bank.gdshader")
	material.set_shader_parameter("snow_albedo",WINTER_SNOW)
	mesh.material_override = material
	tool.index()
	tool.generate_normals()
	mesh.mesh = tool.commit()
	add_child(mesh)


func _menu_yield_due() -> bool:
	return _menu_slices and Time.get_ticks_usec()-_slice_started >= 6000


func _winter_bank_section(tool: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, points: PackedVector2Array) -> void:
	# Analytic road edge instead of raster contour: broad drift variation, rounded profile.
	for band: int in range(8):
		for corner: Vector2i in [Vector2i(0,band),Vector2i(1,band+1),Vector2i(1,band),Vector2i(0,band),Vector2i(0,band+1),Vector2i(1,band+1)]:
			var anchor: Vector2 = a if corner.x == 0 else b
			var outward: Vector2 = na if corner.x == 0 else nb
			var t: float = float(corner.y)/8.0
			var drift: float = sin(anchor.x*0.55+anchor.y*0.31)*sin(anchor.y*0.43-anchor.x*0.24)
			var offset: float = lerpf(-0.62,1.65,t)+drift*0.10*sin(t*PI)
			var point: Vector2 = anchor+outward*offset
			var height: float = _winter_pile_height(anchor,t)
			var slope: float = (_winter_pile_height(anchor,t+0.01)-_winter_pile_height(anchor,t-0.01))/0.0454
			var tangent: Vector2 = outward.normalized().orthogonal()
			var along: float = (_winter_pile_height(anchor+tangent*0.04,t)-_winter_pile_height(anchor-tangent*0.04,t))/0.08
			var gradient: Vector2 = outward.normalized()*slope+tangent*along
			tool.set_normal(Vector3(-gradient.x,1.0,gradient.y).normalized())
			tool.set_uv(Vector2(t,0.0))
			tool.set_uv2(_sand_coordinates(point,points))
			tool.add_vertex(VisualGeometry.world(point)+Vector3.UP*height)


func _commit_winter_bank(tool: SurfaceTool, mask: Texture2D, extent: Vector2) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "WinterSnowBanks"
	mesh.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/winter_bank.gdshader")
	material.set_shader_parameter("snow_albedo",WINTER_SNOW)
	material.set_shader_parameter("ice_albedo",WINTER_ICE)
	material.set_shader_parameter("smooth_road_bank",true)
	material.set_shader_parameter("overlay_mask",mask)
	material.set_shader_parameter("map_extent",extent)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _winter_pile_height(anchor: Vector2, t: float) -> float:
	# Deposited snow masses vary along/across the crown; the road toe stays smooth.
	var rise: float = sin(clampf((t-0.28)/0.72,0.0,1.0)*PI)
	var broad: float = sin(anchor.x*1.13+anchor.y*0.79)+sin(anchor.y*1.47-anchor.x*0.67)
	var chunks: float = sin(anchor.x*3.1+anchor.y*2.3+t*9.0)*sin(anchor.y*2.9-anchor.x*1.7-t*7.0)
	return 0.022+rise*rise*(0.40+broad*0.085+chunks*0.12)


func _winter_deposit(tool: SurfaceTool, anchor: Vector2, outward: Vector2, occupied: Dictionary) -> void:
	var center: Vector2 = anchor+outward*1.0
	var key := Vector2i(floori(center.x/0.72),floori(center.y/0.72))
	if occupied.has(key) or occupied.size() >= 1800: return
	var seed_value: int = absi(key.x*73856093 ^ key.y*19349663)
	if seed_value%10 < 1: return
	occupied[key] = true
	center += outward*(float(seed_value%13)/13.0-0.5)*0.22
	var radius: float = 0.22+float(seed_value%17)*0.018
	var origin: Vector3 = VisualGeometry.world(center)+Vector3.UP*0.22
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	for i: int in range(7):
		var angle: float = TAU*float(i)/7.0+float(seed_value%31)
		var irregular: float = 0.80+float((seed_value+i*11)%17)*0.022
		var radial := Vector3(cos(angle)*radius*irregular,0,sin(angle)*radius*irregular)
		lower.append(origin+radial)
		upper.append(origin+radial*0.70+Vector3(radius*0.12,radius*(0.60+float((seed_value+i*7)%9)*0.035),0))
	var top: Vector3 = origin+Vector3(-radius*0.1,radius*0.94,radius*0.08)
	for i: int in range(7):
		var j: int = (i+1)%7
		for face: Array in [[lower[i],lower[j],upper[j]],[lower[i],upper[j],upper[i]],[upper[i],upper[j],top]]:
			var normal: Vector3 = (Vector3(face[2])-Vector3(face[0])).cross(Vector3(face[1])-Vector3(face[0])).normalized()
			tool.set_normal(normal.lerp(Vector3.UP,0.42).normalized())
			tool.set_uv(Vector2(0.70,0.0))
			tool.set_uv2(Vector2.ZERO)
			for point: Vector3 in face: tool.add_vertex(point)

func _yield_build() -> bool:
	if not is_inside_tree(): return false
	if _menu_yield_due():
		await get_tree().process_frame
		_slice_started = Time.get_ticks_usec()
	return is_inside_tree()
