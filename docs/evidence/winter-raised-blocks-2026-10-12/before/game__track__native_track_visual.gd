class_name NativeTrackVisual
extends Node3D
## Original matte track kit derived solely from native surface geometry.

const VERSION: String = "track-kit-142"
const STANDARD_FINISH_COLORS: Array[Color] = [Color("d4d5c5"), Color("252f32")]
const WINTER_FINISH_COLORS: Array[Color] = [Color("d1dee5"), Color("647987")]
const DESERT_FINISH_COLORS: Array[Color] = [Color("938267"), Color("635b4b")]
const WORN_ASPHALT_FINISH_COLORS: Array[Color] = [Color("b8b9ad"), Color("42494a")]
const SURFACE_FACTORS: Texture2D = preload("res://assets/textures/surface_factors_v1.png")
const WINTER_ICE: Texture2D = preload("res://assets/textures/winter_ice_v1.png")
const WINTER_ICE_FINISH: Texture2D = preload("res://assets/textures/winter_ice_finish_v3.png")
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
var tyre_instances: MultiMeshInstance3D
var _tyre_positions := PackedVector2Array()
var _tyre_spins: Array[float] = []
var light_instances: Array[Node3D] = []
var scenic_count: int = 0
var editor_objects: NativeTrackVisual
var editor_cover: NativeTrackVisual
var editor_scenery: NativeTrackVisual
var _editor_scenery_sources: Array = []
var _editor_object_revision: int = 0
var cache_road_meshes: bool = true
var persist_road_meshes: bool = true
var cache_race_world: bool = false
const PREPARED_WORLDS = preload("res://track/prepared_world_cache.gd")
const ROAD_DISK_CACHE = preload("res://track/road_mesh_disk_cache.gd")
const ROAD_CACHE_BUDGET: int = 32 * 1024 * 1024
static var _road_mesh_cache: Array[Dictionary] = []
static var _pending_road_bakes: Dictionary = {}


func _bind_grass(material: ShaderMaterial) -> void:
	material.set_shader_parameter("winter_snow",theme_id == "winter")
	material.set_shader_parameter("snow_albedo",WINTER_SNOW)
	material.set_shader_parameter("ice_albedo",WINTER_ICE)
	material.set_shader_parameter("surface_factors",SURFACE_FACTORS)
	material.set_shader_parameter("ice_finish",WINTER_ICE_FINISH)
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
	var world_key: Array = [track.content_hash,VERSION,ContactShading.VERSION,theme_id,colors,partition_night_ground]
	var reuse_world: bool = cache_race_world and not editor_preview and not menu_slices
	if reuse_world and PREPARED_WORLDS.restore(world_key,self): return
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://track/ground.gdshader")
	ground.set_shader_parameter("surface_factors", SURFACE_FACTORS)
	ground.set_shader_parameter("ground_color", colors[1])
	ground.set_shader_parameter("painted_grass_texture", GRASS_TEXTURE)
	_bind_grass(ground)
	VisualGeometry.box(self, Vector3(1000, 0.1, 1000), Vector3(0, -0.15, 0), ground)
	SurfaceShaderVariants.specialize(ground)
	if theme_id == "night_city" and partition_night_ground and _lamps_inside_terrain(track):
		# This backdrop is hidden by the opaque terrain wherever lamps reach.
		# Keep moon/ambient light, but exclude pointless point-light evaluation.
		(get_child(get_child_count()-1) as MeshInstance3D).layers = 2
	await _build_terrain(track)
	if _menu_slices and not is_inside_tree(): return
	await _build_creator_roads(track)
	if _menu_slices and not is_inside_tree(): return
	if track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): await _build_kerbs(track)
	if _menu_slices and not is_inside_tree(): return
	await _build_barriers(track)
	if _menu_slices and not is_inside_tree(): return
	if editor_preview:
		await refresh_editor_objects(track,true,_menu_slices)
	else:
		await _build_low_cover(track)
		await _build_placed_objects(track)
	if _menu_slices and not is_inside_tree(): return
	bridge.build(self)
	_build_finish(track)
	_build_snow_banks(track)
	if reuse_world: PREPARED_WORLDS.remember(world_key,self,track)


func refresh_editor_objects(track: NativeTrack, refresh_cover: bool = true, sliced: bool = false) -> void:
	_editor_object_revision += 1
	var revision: int = _editor_object_revision
	if theme_id == "night_city" and partition_night_ground and get_child_count() > 0 and get_child(0) is MeshInstance3D:
		# Moving/scaling a lamp in the editor can expose the outer backdrop.
		(get_child(0) as MeshInstance3D).layers = 2 if _lamps_inside_terrain(track) else 1
	var objects := NativeTrackVisual.new()
	objects.editor_preview = true
	objects._menu_slices = sliced
	objects._slice_started = Time.get_ticks_usec()
	objects.theme_id = theme_id
	objects.colors = colors
	objects.visible = false
	add_child(objects)
	# Authored props are small, immediate edits. Generated scenery has its own
	# stable batch, so placing one tyre does not recreate every meadow tree.
	var authored := NativeTrack.new()
	authored.metadata = {"creator_document":track.metadata.get("creator_document",{}),"scenery_objects":[]}
	authored.tyre_origins = track.tyre_origins
	await objects._build_placed_objects(authored)
	if sliced and not is_inside_tree(): return
	if revision != _editor_object_revision:
		objects.queue_free()
		return
	if editor_objects != null:
		remove_child(editor_objects)
		editor_objects.queue_free()
	editor_objects = objects
	objects.visible = true
	if refresh_cover:
		var cover := NativeTrackVisual.new()
		cover.editor_preview = true
		cover._menu_slices = sliced
		cover._slice_started = Time.get_ticks_usec()
		cover.theme_id = theme_id
		cover.colors = colors
		cover.visible = false
		add_child(cover)
		await cover._build_low_cover(track)
		if sliced and not is_inside_tree(): return
		if revision != _editor_object_revision:
			cover.queue_free()
			return
		if editor_cover != null:
			remove_child(editor_cover)
			editor_cover.queue_free()
		editor_cover = cover
		cover.visible = true
	var scenery: Array = track.metadata.get("scenery_objects",[])
	if editor_scenery == null or scenery != _editor_scenery_sources:
		var scenery_batch := NativeTrackVisual.new()
		scenery_batch.editor_preview = true
		scenery_batch._menu_slices = sliced
		scenery_batch._slice_started = Time.get_ticks_usec()
		scenery_batch.theme_id = theme_id
		scenery_batch.colors = colors
		scenery_batch.visible = false
		add_child(scenery_batch)
		var generated := NativeTrack.new()
		generated.metadata = {"creator_document":{"objects":[]},"scenery_objects":scenery}
		await scenery_batch._build_placed_objects(generated)
		if sliced and not is_inside_tree(): return
		if revision != _editor_object_revision:
			scenery_batch.queue_free()
			return
		if editor_scenery != null:
			remove_child(editor_scenery)
			editor_scenery.queue_free()
		editor_scenery = scenery_batch
		scenery_batch.visible = true
		_editor_scenery_sources = scenery.duplicate(true)


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
	SurfaceShaderVariants.specialize(surface)
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
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	for index: int in range(pieces.size()):
		if _menu_yield_due():
			await get_tree().process_frame
			if not is_inside_tree(): return
			_slice_started = Time.get_ticks_usec()
		if pieces[index].kind == "bridge": continue
		var exposed: Array[PackedVector2Array] = []
		if pieces[index].kind == "spline": exposed = RoadEdges.section_contours(pieces,index,0.0,topology)
		else:
			var shape: Dictionary = VisualRoadJoin._base_shape(pieces,index,0.0,topology)
			if shape.swept: exposed = shape.contours
			else: exposed.append(RoadPieces.section_outline(pieces,index,0.0,topology))
		for polygon: PackedVector2Array in exposed:
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for point: Vector2 in polygon: bounds = bounds.expand(point)
			var swept: bool = pieces[index].kind == "spline" or topology.get("visual_folded",{}).get(index,false)
			outlines.append({"index":index,"polygon":polygon,"bounds":bounds,"hole":swept and Geometry2D.is_polygon_clockwise(polygon)})
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
		if theme_id == "winter":
			axis_cache["winter_bank_uvs"] = {}
			var geometry: Dictionary = RoadPieces.section_geometry(pieces,index,topology)
			points = geometry.points
			axis_cache["winter_widths"] = geometry.widths
			var distances := PackedFloat32Array([0.0])
			for i: int in range(1,points.size()): distances.append(distances[-1]+points[i-1].distance_to(points[i]))
			axis_cache["winter_distances"] = distances
		var road_join: Dictionary = {} if piece.kind == "spline" else preload("res://track/visual_road_join.gd").build(pieces,index,0.0,topology)
		var marking_join: Dictionary = {} if piece.kind == "spline" else preload("res://track/visual_road_join.gd").build(pieces,index,-0.20,topology)
		var swept: bool = piece.kind == "spline" or road_join.get("swept",false)
		var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index,topology) if piece.kind == "spline" else marking_join.cuts
		var road_contours: Array[PackedVector2Array] = []
		if piece.kind == "spline": road_contours = RoadEdges.section_contours(pieces,index,0.0,topology)
		else: road_contours = road_join.contours
		# A 0.36 m cover hides the maximum corner protrusion of a 0.5 m
		# raster cell (sqrt(2)*0.25). The white line stays inside authored width.
		var skirt_margin: float = 3.7 if theme_id == "desert" else 1.8
		var skirts: Array[PackedVector2Array] = SplineBorders.surface(SplineBorders.offset(road_contours,skirt_margin)) if swept else Geometry2D.offset_polygon(road_contours[0],skirt_margin,Geometry2D.JOIN_ROUND)
		for polygon: PackedVector2Array in skirts:
			ground_count += _road_polygon(ground_skirt,polygon,-0.04)
		var surfaces: Array[PackedVector2Array] = SplineBorders.surface(SplineBorders.offset(road_contours,0.16)) if swept else Geometry2D.offset_polygon(road_contours[0],0.16,Geometry2D.JOIN_ROUND)
		for polygon: PackedVector2Array in surfaces:
			counts[1] += _road_polygon(asphalt,polygon,0.012,points,axis_cache)
		var dirt: bool = document.get("surface","asphalt") == "dirt"
		var border_contours: Array[PackedVector2Array] = []
		if piece.kind == "spline": border_contours = RoadEdges.presentation_contours(pieces,index,-0.20,topology)
		else: border_contours = marking_join.contours
		for polygon: PackedVector2Array in border_contours:
			var hole: bool = swept and Geometry2D.is_polygon_clockwise(polygon)
			for edge: int in range(polygon.size()):
				if _menu_yield_due():
					await get_tree().process_frame
					if not is_inside_tree(): return
					_slice_started = Time.get_ticks_usec()
				var a: Vector2 = polygon[edge]
				var b: Vector2 = polygon[(edge+1)%polygon.size()]
				if _on_join_cut(a,b,cuts) or (swept and RoadEdges._on_join_cap(a,b,cuts)): continue
				var normal_a: Vector2 = RoadEdges._roadside_miter(polygon,edge,cuts,true) if swept else _roadside_miter(polygon,edge,cuts)
				var normal_b: Vector2 = RoadEdges._roadside_miter(polygon,(edge+1)%polygon.size(),cuts,true) if swept else _roadside_miter(polygon,(edge+1)%polygon.size(),cuts)
				if hole: normal_a = -normal_a; normal_b = -normal_b
				# More cross-bank samples replace along-bank oversampling in Winter.
				var steps: int = maxi(1,ceili(a.distance_to(b)/(0.28 if theme_id == "winter" else 0.20)))
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
					if Geometry2D.is_point_in_polygon(midpoint+outward,polygon) != hole: outward = -outward
					# Probe beyond this road edge. Testing the stripe itself would
					# leave a gap where adjacent sections' rounded end caps overlap.
					if not RoadEdges._road_edge_exposed(midpoint+outward,index,outlines,pieces,topology): continue
					if theme_id == "winter" and not dirt:
						_winter_bank_section(winter_bank,p,q,normal_p,normal_q,points,axis_cache.winter_bank_uvs)
						winter_sections += 1
						_winter_deposit(winter_bank,(p+q)*0.5,(normal_p+normal_q)*0.5,winter_piles)
					_asphalt_fringe_quad(asphalt_fringe,
						p+normal_p*(-0.55 if theme_id == "desert" else 0.36),q+normal_q*(-0.55 if theme_id == "desert" else 0.36),
						p+normal_p*(0.92 if theme_id == "desert" else 0.56),q+normal_q*(0.92 if theme_id == "desert" else 0.56),points,axis_cache)
					fringe_count += 1
					# Continuous sand transition around the road.
					# Only the outer contour varies; road/paint stay fixed.
					var outer_p: Vector2 = p+normal_p*_shoulder_width(p)
					var outer_q: Vector2 = q+normal_q*_shoulder_width(q)
					shoulder_mesh.add_quad(p,q,outer_p,outer_q)
					counts[0] += 1
					# Desert edges are a flat compacted-to-loose sand transition.
					# Authored contacts remain canonical; no decorative raised clods.
					# Retain the authored road-edge marking and keep it smooth;
					# only the asphalt/sand colour transition receives subtle breakup.
					if dirt or theme_id in ["desert","winter"]: continue
					_quad(markings,VisualGeometry.world(p-normal_p*0.085)+Vector3.UP*0.018,VisualGeometry.world(q-normal_q*0.085)+Vector3.UP*0.018,
						VisualGeometry.world(q+normal_q*0.085)+Vector3.UP*0.018,VisualGeometry.world(p+normal_p*0.085)+Vector3.UP*0.018)
					counts[2] += 1
	if winter_sections > 0:
		_commit_winter_bank(winter_bank,texture,track.half_extent,road_texture)
		set_meta("winter_smooth_sections",winter_sections)
		set_meta("winter_deposits",winter_piles.size())
	await shoulder_mesh.emit(shoulders,_yield_build if _menu_slices else Callable())
	if _menu_slices and not is_inside_tree(): return
	set_meta("desert_clod_count",sand_clods)
	await _build_kerbs(track)
	if _menu_slices and not is_inside_tree(): return
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
		if theme_id == "winter": tool.set_color(Color(_winter_half_width(Vector2(sand_cache[point]).x,axis_cache)/32.0+0.5/255.0,0,0,1))
		tool.add_vertex(VisualGeometry.world(point)+Vector3.UP*height)

func _winter_half_width(along: float, cache: Dictionary) -> float:
	if not cache.has("winter_widths"): return 5.0
	var widths: PackedFloat32Array = cache.winter_widths
	var distances: PackedFloat32Array = cache.winter_distances
	var low: int = 0
	var high: int = distances.size()-1
	while high-low > 1:
		var middle: int = (low+high)/2
		if distances[middle] <= along: low = middle
		else: high = middle
	var fraction: float = clampf((along-distances[low])/maxf(distances[high]-distances[low],0.0001),0,1)
	return lerpf(widths[low],widths[high],fraction)*0.5



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
	if track.editor_overlay_mask != null and paint == track.metadata.get("creator_document",{}).get("paint",[]): return track.editor_overlay_mask
	return CreatorPreviewMasks.overlay(track,paint)


func _creator_road_mask(track: NativeTrack) -> Image:
	return track.editor_road_mask if track.editor_road_mask != null else CreatorPreviewMasks.road(track)



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
	var vertex_colors := PackedColorArray()
	if arrays[Mesh.ARRAY_COLOR] != null: vertex_colors = arrays[Mesh.ARRAY_COLOR]
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
			if not vertex_colors.is_empty(): flat.set_color(vertex_colors[index])
			flat.add_vertex(vertices[index])
	var instance := MeshInstance3D.new()
	instance.mesh = flat.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/storm_creator_road.gdshader") if theme_id == "storm" and not grass and not gravel else CREATOR_ROAD_SHADER
	if theme_id == "winter": material.shader = preload("res://track/winter_creator_road.gdshader")
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
	material.set_shader_parameter("winter_width_data",theme_id == "winter" and asphalt_surface and not edge_fringe)
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
	if theme_id == "winter":
		WinterScenery.build_cover(self,track)
		return
	# Owner rejected standing grass blades; meadow uses the static surface only.
	var scenery := SurfaceTool.new()
	scenery.begin(Mesh.PRIMITIVE_TRIANGLES)
	if theme_id == "desert":
		# Refreshes replace the batch, so its diagnostics describe this build only.
		for key: String in ["desert_stones","desert_large_stones","desert_scrub","desert_roadside_stones"]:
			set_meta(key,0)
		await _desert_roadside_cover(scenery,track)
		if _menu_slices and not is_inside_tree(): return
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
		if not _cover_clear(track, cell, 1.2 if theme_id == "desert" else 1.3): continue
		accepted_sites += 1
		# Preserve the original site budget and stone population while replacing grass.
		if theme_id in ["pine","storm"] and seed_value % 4 != 0: continue
		var center := Vector3((cell.x+0.5)*track.cell_size-track.half_extent.x, 0.014, (cell.y+0.5)*track.cell_size-track.half_extent.y)
		var scale_value: float = 0.8 + (seed_value % 11) * 0.035
		var turn: float = (seed_value % 37) * 0.17
		if theme_id == "desert":
			_desert_cover(scenery,center,seed_value,turn)
			scenic_count += 1
			continue
		# Trees are exclusively compiled solid objects; tiny cover is decorative.
		var color: Color = stone if seed_value % 4 == 0 else foliage
		var height: float = 0.08 if seed_value % 4 == 0 else 0.22
		_mound(scenery, center, Vector3(0.18 if seed_value % 4 == 0 else 0.4, height, 0.14 if seed_value % 4 == 0 else 0.3) * scale_value, turn, color)
		_mound(scenery, center + Vector3(0.5, 0, 0.25), Vector3(0.10 if seed_value % 4 == 0 else 0.24, height * 0.6, 0.08 if seed_value % 4 == 0 else 0.2), turn+1.2, color.darkened(0.08))
		scenic_count += 1
	if scenic_count or int(get_meta("desert_roadside_stones",0)) > 0:
		scenery.generate_normals()
		var instance := MeshInstance3D.new()
		instance.name = "DesertLowCover" if theme_id == "desert" else "LowCover"
		instance.mesh = scenery.commit()
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		# Tiny rocks and stems need soft diffuse planes, not black toon dots.
		if theme_id == "desert": material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		if theme_id != "desert": VisualGeometry.ink(material)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
		add_child(instance)


func _desert_cover(tool: SurfaceTool, center: Vector3, seed_value: int, turn: float) -> void:
	# Sparse, uneven stone groups and shrubs; no repeated four-bead clusters.
	# Their full footprint fits the checked 1.2 m radius, in one opaque batch.
	var mixed: int = (seed_value^(seed_value>>13))&0x7fffffff
	var shades: Array[Color] = [Color("b5b0a3"),Color("bfb9ab"),Color("aaa89f"),Color("cac2b1")]
	var scrub: bool = (mixed>>6)%5 == 0
	var stones: int = [1,1,2,3][(mixed>>4)%4]
	if scrub: stones = 1 if mixed%3 == 0 else 0
	for i: int in range(stones):
		var variation: int = ((mixed>>(i*3))^(mixed*(i+7)))&0x7fffffff
		var angle: float = turn+float(i)*2.399
		var offset := Vector3((float((variation>>7)%21)-10.0)*0.045,0,(float((variation>>13)%21)-10.0)*0.040)
		var dimensions := Vector3(0.18+float((variation>>5)%9)*0.024,0.10+float((variation>>9)%7)*0.016,0.14+float((variation>>15)%7)*0.023)
		if i > 0: dimensions *= 0.52+float((variation>>19)%5)*0.06
		# Occasional larger weathered stone; still low and outside road/deck cells.
		if i == 0 and mixed%13 == 0:
			dimensions = Vector3(0.48,0.27,0.31)
			set_meta("desert_large_stones",int(get_meta("desert_large_stones",0))+1)
		_desert_rock(tool,center+offset,dimensions,angle,variation,shades[(variation>>7)%shades.size()].srgb_to_linear())
		set_meta("desert_stones",int(get_meta("desert_stones",0))+1)
	if scrub:
		_desert_scrub(tool,center,1.0+float((mixed>>11)%5)*0.09,turn,mixed)
		set_meta("desert_scrub",int(get_meta("desert_scrub",0))+1)


func _desert_roadside_cover(tool: SurfaceTool, track: NativeTrack) -> void:
	# Uniform route stations distribute at most 768 small weathered pebbles. Check
	# full footprints against roads, decks, hazards and authored solid scenery.
	var count: int = mini(track.route.size(),192)
	for station: int in range(count):
		if _menu_yield_due():
			await _yield_build()
			if not is_inside_tree(): return
		var index: int = station*track.route.size()/count
		var point: Vector2 = track.route[index]
		var tangent: Vector2 = (track.route[(index+1)%track.route.size()]-track.route[(index-1+track.route.size())%track.route.size()]).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		var width: float = track.route_widths[index]*0.5 if track.route_widths.size() == track.route.size() else 5.0
		var seed_value: int = absi(int(point.x*1731.0+point.y*7919.0))
		for side: int in [-1,1]:
			var center: Vector2 = point+normal*side*(width+0.85+float(seed_value%11)*0.10)
			var cell := Vector2i(floori((center.x+track.half_extent.x)/track.cell_size),floori((track.half_extent.y-center.y)/track.cell_size))
			if not _cover_clear(track,cell,0.48): continue
			for stone_index: int in range(1+(seed_value>>11)%2):
				var radius: float = 0.07+float((seed_value>>(stone_index*4))%7)*0.011
				var origin: Vector3 = VisualGeometry.world(center+tangent*(float(stone_index)*0.24-0.12))+Vector3.UP*0.014
				var color: Color = Color("b1aa9d").lerp(Color("c1bbad"),float((seed_value>>4)%9)/8.0).srgb_to_linear()
				_desert_rock(tool,origin,Vector3(radius*1.2,radius*0.48,radius*0.76),float(seed_value%31)*0.2,seed_value+stone_index*23,color)
				set_meta("desert_roadside_stones",int(get_meta("desert_roadside_stones",0))+1)


func _desert_rock(tool: SurfaceTool, center: Vector3, dimensions: Vector3, turn: float, seed_value: int, color: Color) -> void:
	# Asymmetric, flattened weathered stones with broad worn top planes and
	# irregular bevels; distinct lengths/widths avoid round polygon pellets.
	var lower: Array[Vector3] = []
	var upper: Array[Vector3] = []
	var angles: Array[float] = [0.0,0.65,1.55,2.25,3.3,4.0,4.95,5.65]
	var radial: Array[float] = [1.0,0.79,1.08,0.83,0.91,1.12,0.82,1.03]
	for i: int in range(8):
		var angle: float = angles[i]+turn
		var variation: int = ((seed_value>>(i%4)*5)^(seed_value*(i+3)))&0x7fffffff
		var radius: float = radial[(i+seed_value%8)%8]*(0.94+float(variation%7)*0.014)
		var offset := Vector3(cos(angle)*dimensions.x*radius,0,sin(angle)*dimensions.z*radius)
		lower.append(center+offset+Vector3.UP*0.004)
		upper.append(center+offset*(0.66+float((variation>>5)%7)*0.018)+Vector3(dimensions.x*0.12,dimensions.y*(0.65+float((variation>>11)%7)*0.035),-dimensions.z*0.12))
	var crown: Vector3 = center+Vector3(dimensions.x*0.08,dimensions.y*0.86,-dimensions.z*0.08)
	tool.set_smooth_group(0)
	tool.set_color(color)
	for i: int in range(8):
		var next: int = (i+1)%8
		_quad(tool,lower[next],lower[i],upper[i],upper[next])
		for vertex: Vector3 in [upper[next],crown,upper[i]]: tool.add_vertex(vertex)


func _desert_scrub(tool: SurfaceTool, center: Vector3, size: float, turn: float, seed_value: int) -> void:
	# Fine bent stems, twig forks and narrow straw tips form a dry scrub bush;
	# no broad radial leaf triangles or green star-shaped rosettes.
	var stem: Color = Color("b3a88d").srgb_to_linear()
	var straw: Color = Color("cfc3a3").srgb_to_linear()
	for branch: int in range(5):
		var variation: int = ((seed_value>>(branch*3))^(seed_value*(branch+3)))&0x7fffffff
		var angle: float = turn+float(variation%101)*0.0622
		var axis := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-axis.z,0,axis.x)
		var root: Vector3 = center+axis*0.045*size
		var knee: Vector3 = center+(axis*0.10+Vector3.UP*(0.16+float(variation%5)*0.018))*size
		var tip: Vector3 = center+(axis*(0.19+float((variation>>7)%5)*0.024)+Vector3.UP*(0.28+float((variation>>12)%5)*0.024))*size
		_desert_twig(tool,root,knee,0.016*size,0.011*size,stem)
		_desert_twig(tool,knee,tip,0.011*size,0.004*size,stem.lerp(straw,0.40))
		var fork: Vector3 = knee+(axis*0.12+side*0.075+Vector3.UP*0.09)*size
		_desert_twig(tool,knee,fork,0.008*size,0.002*size,straw)
		_desert_straw_bundle(tool,tip,size,angle,straw)
		_desert_straw_bundle(tool,fork,size*0.72,angle+0.6,straw)


func _desert_straw_bundle(tool: SurfaceTool, center: Vector3, size: float, turn: float, color: Color) -> void:
	# Small frayed bundles, with narrow curved blades instead of flat broad leaves.
	for blade: int in range(5):
		var angle: float = turn+float(blade)*2.399
		var axis := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-axis.z,0,axis.x)*0.007*size
		var end: Vector3 = center+(axis*(0.060+float(blade%3)*0.020)+Vector3.UP*(0.065+float(blade%4)*0.019))*size
		var bend: Vector3 = center.lerp(end,0.55)+axis*0.020*size
		tool.set_color(color)
		for vertex: Vector3 in [center-side,bend,end,bend,center+side,end]: tool.add_vertex(vertex)


func _desert_twig(tool: SurfaceTool, a: Vector3, b: Vector3, start_radius: float, end_radius: float, color: Color) -> void:
	var direction: Vector3 = (b-a).normalized()
	var side: Vector3 = direction.cross(Vector3.RIGHT).normalized()
	var other: Vector3 = direction.cross(side).normalized()
	for face: int in range(3):
		var angle: float = float(face)*TAU/3.0
		var next: float = float(face+1)*TAU/3.0
		var radial: Vector3 = side*cos(angle)+other*sin(angle)
		var next_radial: Vector3 = side*cos(next)+other*sin(next)
		tool.set_color(color)
		_quad(tool,a+radial*start_radius,a+next_radial*start_radius,b+next_radial*end_radius,b+radial*end_radius)


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
	ContactShading.build_props(self,track)
	if theme_id == "winter": WinterScenery.build_authored(self,track)
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
		if theme_id == "winter" and str(object.kind) in WinterScenery.TYPES: continue
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
			else: CreatorPropVisual.append(ink_tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation)),float(object.get("length",-1.0)))
			ink_count += 1
			continue
		if CreatorPropVisual.append(tool,self,object.kind,center,object_scale,deg_to_rad(float(object.rotation)),float(object.get("length",-1.0))):
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
		elif object.kind in ["oil","puddle","jump","speed_bump"]:
			HazardVisual.build(self,object)
			continue
		elif object.kind in ["tyre_wall","tyre_stack"]: continue # Shared instanced mesh below.
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
	_build_faded_finish(track,side,widths)


func _build_faded_finish(track: NativeTrack, side: Vector2, widths: Vector2) -> void:
	var palette: Array[Color] = WINTER_FINISH_COLORS if theme_id == "winter" else DESERT_FINISH_COLORS if theme_id == "desert" else WORN_ASPHALT_FINISH_COLORS
	var prefix: String = "WinterSnowFinish" if theme_id == "winter" else "DesertSandFinish" if theme_id == "desert" else "WornAsphaltFinish"
	var pale := SurfaceTool.new()
	var dark := SurfaceTool.new()
	pale.begin(Mesh.PRIMITIVE_TRIANGLES)
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell: float = 0.54
	var columns: int = ceili((widths.x+widths.y)/cell)
	# Muted pigment is worked into the road surface in every biome. Small
	# deterministic gaps and uneven edges reveal the surface under the paint.
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
		tyre_instances.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,spin),VisualGeometry.world(p)+Vector3.UP*0.014))

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
		light_instances[index].rotation.z = float(row[4])*0.9


func _build_kerbs(track: NativeTrack) -> void:
	if theme_id == "winter": return # Ploughed snow covers the retained canonical kerbs.
	if track.kerbs.triangles.is_empty(): return
	if theme_id == "desert" and not track.metadata.get("creator_document",{}).get("pieces",[]).is_empty(): return
	var document: Dictionary = track.metadata.get("creator_document",{})
	var triangles: Array[Dictionary] = track.kerbs.triangles
	var pieces: Array = document.get("pieces",[])
	var fair: bool = pieces.size() > 1
	if pieces.size() == 1 and pieces[0].kind not in ["spline","bridge"]:
		fair = VisualRoadJoin._base_shape(pieces,0,0.0,RoadPieces.prepare_endpoints(pieces)).swept
	# Ordinary solitary pieces retain their canonical kerb; folded ones need
	# the same exposed cosmetic border as their road surface.
	if fair and document.get("base_track","") == "" and document.get("surface","asphalt") != "dirt":
		triangles = await preload("res://track/visual_road_join.gd").kerb_triangles(document,_yield_build if _menu_slices else Callable())
		if _menu_slices and not is_inside_tree(): return
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


static var _winter_drift_noise: FastNoiseLite = _make_winter_drift_noise()
static var _winter_pack_noise: FastNoiseLite = _make_winter_pack_noise()

static func _make_winter_pack_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 9371
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 1.85
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.cellular_jitter = 1.0
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	return noise

static func _make_winter_drift_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 4127
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return noise

func _winter_bank_offset(anchor: Vector2, t: float) -> float:
	return _winter_shape_offset(_winter_bank_shape(anchor),t)

func _winter_bank_shape(anchor: Vector2) -> PackedFloat64Array:
	var drift: float = _winter_drift_noise.get_noise_2dv(anchor*0.43)
	var chips: float = _winter_drift_noise.get_noise_2dv(anchor*0.95+Vector2(71,13))
	var crown: float = 0.78+drift*0.25+chips*0.12
	# Vary the actual snow toe, not just a colour gradient on a circular ribbon.
	var toe: float = -0.50+drift*0.24+chips*0.16
	return PackedFloat64Array([toe,crown,4.4+drift*0.8,_winter_drift_noise.get_noise_2dv(anchor*0.23)])

func _winter_shape_offset(shape: PackedFloat64Array, t: float) -> float:
	return lerpf(shape[0],shape[1],t/0.42) if t <= 0.42 else lerpf(shape[1],shape[2],(t-0.42)/0.58)

func _winter_bank_section(tool: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, points: PackedVector2Array, uv_cache: Dictionary = {}) -> void:
	# Compact ploughed crown and a broad downhill apron which sinks into terrain.
	var rows: Array[Dictionary] = [_winter_bank_row(a,na,points,uv_cache),_winter_bank_row(b,nb,points,uv_cache)]
	for band: int in range(11):
		for corner: Vector2i in [Vector2i(0,band),Vector2i(1,band+1),Vector2i(1,band),Vector2i(0,band),Vector2i(0,band+1),Vector2i(1,band+1)]:
			var row: Dictionary = rows[corner.x]
			tool.set_normal(row.normals[corner.y])
			tool.set_uv(Vector2(row.fractions[corner.y],0.0))
			tool.set_uv2(row.uvs[corner.y])
			tool.set_color(row.color)
			tool.add_vertex(row.vertices[corner.y])


func _winter_bank_row(anchor: Vector2, outward: Vector2, points: PackedVector2Array, cache: Dictionary) -> Dictionary:
	# Samples concentrate on the compacted face, rather than its buried apron.
	# Exact inputs/attributes are cached only inside this authored road piece.
	var key := Vector4(anchor.x,anchor.y,outward.x,outward.y)
	if cache.has(key): return cache[key]
	if not cache.has(anchor): cache[anchor] = _sand_coordinates(anchor,points)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var fractions := PackedFloat32Array([0.0,0.08,0.16,0.24,0.32,0.40,0.48,0.56,0.64,0.75,0.87,1.0])
	var tangent: Vector2 = outward.normalized().orthogonal()
	# The same three anchor profiles serve every sample and normal in this
	# row. Retain 64-bit values so this reuse preserves exact mesh buffers.
	var shape: PackedFloat64Array = _winter_bank_shape(anchor)
	var left_anchor: Vector2 = anchor-tangent*0.16
	var right_anchor: Vector2 = anchor+tangent*0.16
	var left_shape: PackedFloat64Array = _winter_bank_shape(left_anchor)
	var right_shape: PackedFloat64Array = _winter_bank_shape(right_anchor)
	for t: float in fractions:
		var offset: float = _winter_shape_offset(shape,t)
		var point: Vector2 = anchor+outward*offset
		var height: float = _winter_shape_height(anchor,t,outward,shape)
		# Match normals to the mesh sample footprint. Infinitesimal noise
		# derivatives exaggerate grooves the geometry cannot actually resolve.
		var slope: float = (_winter_shape_height(anchor,t+0.06,outward,shape)-_winter_shape_height(anchor,t-0.06,outward,shape))/(_winter_shape_offset(shape,t+0.06)-_winter_shape_offset(shape,t-0.06))
		var along: float = (_winter_shape_height(right_anchor,t,outward,right_shape)-_winter_shape_height(left_anchor,t,outward,left_shape))/0.32
		var gradient: Vector2 = outward.normalized()*slope+tangent*along
		normals.append(Vector3(-gradient.x,1.0,gradient.y).normalized())
		if not cache.has(point): cache[point] = _sand_coordinates(point,points)
		uvs.append(cache[point])
		vertices.append(VisualGeometry.world(point)+Vector3.UP*height)
	var row: Dictionary = {"vertices":vertices,"normals":normals,"uvs":uvs,"fractions":fractions,"color":Color(absf(Vector2(cache[anchor]).y)/32.0+0.5/255.0,0,0,1)}
	cache[key] = row
	return row


func _commit_winter_bank(tool: SurfaceTool, mask: Texture2D, extent: Vector2, road_mask: Texture2D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "WinterSnowBanks"
	# Shared corners retain identical position/normal/UV/colour; avoid running
	# the vertex shader six times for the same bank-grid point.
	tool.index()
	mesh.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://track/winter_bank.gdshader")
	material.set_shader_parameter("snow_albedo",WINTER_SNOW)
	material.set_shader_parameter("ice_albedo",WINTER_ICE)
	material.set_shader_parameter("smooth_road_bank",true)
	material.set_shader_parameter("overlay_mask",mask)
	material.set_shader_parameter("road_mask",road_mask)
	material.set_shader_parameter("map_extent",extent)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh)


func _winter_pile_height(anchor: Vector2, t: float, outward: Vector2 = Vector2.RIGHT) -> float:
	return _winter_shape_height(anchor,t,outward,_winter_bank_shape(anchor))

func _winter_shape_height(anchor: Vector2, t: float, outward: Vector2, shape: PackedFloat64Array) -> float:
	# Independent variation across AND along the bank prevents comb-like ridges.
	# This field is baked into the mesh once; the material does not run noise.
	var broad: float = shape[3]
	var point: Vector2 = anchor+outward*_winter_shape_offset(shape,t)
	# Uneven packed cells form interlocking fragments rather than smooth
	# periodic noise humps; low-frequency drift still supplies the bulk.
	var packed: float = clampf((_winter_pack_noise.get_noise_2dv(point)+1.0)*1.5,0.0,1.0)
	# A steep plough face supports a broken, broad upper shelf. A symmetric
	# hill profile produces the rejected row of inflated rounded cushions.
	var peak: float = 0.24+broad*0.06
	var profile: float = smoothstep(0.0,peak,t)*(1.0-smoothstep(peak+0.15,0.95,t))
	var crest: float = 0.60+broad*0.18+packed*0.22
	var base: float = lerpf(0.018,-0.065,smoothstep(0.65,1.0,t))
	return base+crest*profile


func _winter_deposit(tool: SurfaceTool, anchor: Vector2, outward: Vector2, occupied: Dictionary) -> void:
	var center: Vector2 = anchor+outward*0.95
	var key := Vector2i(floori(center.x/2.7),floori(center.y/2.7))
	if occupied.has(key) or occupied.size() >= 80: return
	var seed_value: int = absi(key.x*73856093 ^ key.y*19349663)
	if seed_value%5 == 0: return
	occupied[key] = true
	# Unequal buried fragments occupy irregular patches of the bank face.
	# No evenly spaced triplets and no identical rounded caps.
	for lobe: int in range(2+seed_value%2):
		_winter_deposit_lobe(tool,anchor,outward,seed_value+lobe*23,lobe)


func _winter_deposit_lobe(tool: SurfaceTool, anchor: Vector2, outward: Vector2, seed_value: int, lobe: int) -> void:
	var t: float = 0.12+float(seed_value%41)/41.0*0.48
	var shifted: Vector2 = anchor+outward.normalized().orthogonal()*(float((seed_value/41)%37)/37.0-0.5)*1.8
	var center: Vector2 = shifted+outward*_winter_bank_offset(shifted,t)
	var radius: float = 0.16+float(seed_value%29)/29.0*0.30
	var height: float = 0.12+float((seed_value/29)%31)/31.0*0.20
	var origin: Vector3 = VisualGeometry.world(center)+Vector3.UP*_winter_pile_height(shifted,t,outward)
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	var sides: int = 5+seed_value%3
	var turn: float = float(seed_value%101)*0.0622
	var stretch: float = 0.60+float((seed_value/31)%19)/19.0*0.85
	var bank_span: float = (_winter_bank_offset(shifted,t+0.01)-_winter_bank_offset(shifted,t-0.01))/0.02
	var tangent: Vector2 = outward.normalized().orthogonal()
	for i: int in range(sides):
		var angle: float = TAU*float(i)/sides+turn
		var irregular: float = 0.70+float(absi(seed_value ^ (i*92821))%97)/97.0*0.55
		var radial := Vector3(cos(angle)*radius*irregular,0,sin(angle)*radius*irregular*stretch)
		# Each fragment grows out of its actual slope: its foot is never a
		# horizontal floating ring or a repeated dark notch in the bank.
		var delta2 := Vector2(radial.x,-radial.z)
		var sample_anchor: Vector2 = shifted+tangent*delta2.dot(tangent)
		var sample_t: float = clampf(t+delta2.dot(outward.normalized())/bank_span,0.0,1.0)
		var foot: float = _winter_pile_height(sample_anchor,sample_t,outward)
		lower.append(VisualGeometry.world(center)+radial+Vector3.UP*(foot-0.04))
		var bevel: float = 0.60+float(absi(seed_value ^ (i*19391))%83)/83.0*0.27
		upper.append(origin+radial*bevel+Vector3(radius*0.13,height*(0.73+bevel*0.14)+(foot-origin.y)*bevel,-radius*0.1))
	var top: Vector3 = origin+Vector3(radius*0.19,height*0.93,-radius*0.14)
	for i: int in range(sides):
		var j: int = (i+1)%sides
		for face: Array in [[lower[i],lower[j],upper[j]],[lower[i],upper[j],upper[i]],[upper[i],upper[j],top]]:
			var normal: Vector3 = (Vector3(face[2])-Vector3(face[0])).cross(Vector3(face[1])-Vector3(face[0])).normalized()
			for point: Vector3 in face:
				var delta: Vector3 = point-origin
				var soft: Vector3 = Vector3(delta.x/(radius*radius),maxf(0.35,delta.y/height)/height,delta.z/(radius*radius*stretch*stretch)).normalized()
				tool.set_normal(soft.lerp(normal,0.12).normalized())
				tool.set_uv(Vector2(0.65,0.0))
				tool.set_uv2(Vector2.ZERO)
				tool.add_vertex(point)

func _yield_build() -> bool:
	if not is_inside_tree(): return false
	if _menu_yield_due():
		await get_tree().process_frame
		_slice_started = Time.get_ticks_usec()
	return is_inside_tree()
