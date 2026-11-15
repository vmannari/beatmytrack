extends RefCounted
## Section inputs include exposed neighbours, joins and connected wear phases.
const SECTIONS = preload("res://editor/road_sections.gd")

static func prepare(visual: NativeTrackVisual, track: NativeTrack, index: int, ctx: Dictionary) -> Dictionary:
	if not ctx.has("outline_index"):
		var spatial = preload("res://editor/spatial_bounds.gd").new()
		var by_piece: Dictionary = {}
		for outline: Dictionary in ctx.outlines:
			spatial.add(outline.bounds)
			by_piece[outline.index] = by_piece[outline.index].merge(outline.bounds) if by_piece.has(outline.index) else outline.bounds
		ctx["outline_index"] = spatial
		ctx["outline_bounds"] = by_piece
	if not ctx.outline_bounds.has(index): return await visual._prepare_road_piece(track,index,ctx)
	# Covers shoulders, deposits, normal queries, fringes and crossing blends.
	var bounds: Rect2 = ctx.outline_bounds[index].grow(12.0)
	var neighbours: Array = []
	for candidate: int in ctx.outline_index.query(bounds):
		var outline: Dictionary = ctx.outlines[candidate]
		if bounds.intersects(outline.bounds):
			neighbours.append([outline.polygon,outline.bounds,outline.hole,outline.index == index,ctx.pieces[outline.index],ctx.phases.get(outline.index,{})])
	var piece: Dictionary = ctx.pieces[index]
	var geometry: Dictionary = RoadPieces.section_geometry(ctx.pieces,index,ctx.topology)
	var joins: Array = []
	for endpoint: int in range(2):
		for link: Array in RoadPieces._matches(ctx.topology,index,endpoint): joins.append([endpoint,link[1],ctx.pieces[int(link[0])]])
	var banks: RefCounted = ctx.sand_banks
	var nearby_sites: Dictionary = {}
	for site: Vector2i in banks.sites:
		if bounds.has_point(Vector2(site)*1.1): nearby_sites[site] = true
	var piles: Dictionary = {}
	for site: Vector2i in ctx.winter_piles:
		if bounds.has_point(Vector2(site)*2.7): piles[site] = ctx.winter_piles[site]
	var cells := PackedByteArray()
	if visual.theme_id == "desert":
		var first := Vector2i(floori((bounds.position.x+track.half_extent.x)/track.cell_size),floori((track.half_extent.y-bounds.end.y)/track.cell_size))
		var last := Vector2i(ceili((bounds.end.x+track.half_extent.x)/track.cell_size),ceili((track.half_extent.y-bounds.position.y)/track.cell_size))
		for y: int in range(maxi(0,first.y),mini(track.grid_height,last.y+1)):
			for x: int in range(maxi(0,first.x),mini(track.grid_width,last.x+1)): cells.append(1 if track.cells[y*track.grid_width+x] == 0 else 0)
	var key: String = "piece/"+SECTIONS.digest([preload("res://track/track_visual_identity.gd").VERSION,visual.theme_id,piece,geometry,joins,neighbours,ctx.phases.get(index,{}),ctx.raised,track.metadata.creator_document.get("surface","asphalt"),track.cell_size,cells,nearby_sites,piles])
	var cached: Variant = visual.road_sections.read(key)
	if cached is Dictionary:
		var chip_capacity: bool = banks.count == int(cached.input_chips) if cached.chip_saturated else banks.count+int(cached.chips) <= banks.CHIP_LIMIT
		var pile_capacity: bool = ctx.winter_piles.size() == int(cached.input_piles) if cached.pile_saturated else ctx.winter_piles.size()+cached.piles.size() <= 80
		if chip_capacity and pile_capacity:
			_replay(ctx,cached,index)
			return cached.output
		visual.road_sections.reject(key)
	var starts: Array[int] = [ctx.shoulder_mesh.triangles.size(),ctx.road_union.clipping.triangles.size(),ctx.fringe_mesh.clipping.triangles.size()]
	var old_count: int = banks.count
	var old_sections: int = banks.sections
	var old_sites: Dictionary = banks.sites.duplicate()
	var old_piles: Dictionary = ctx.winter_piles.duplicate()
	var output: Dictionary = await visual._prepare_road_piece(track,index,ctx)
	if visual._cpu_cancelled() or output.is_empty(): return {}
	var sites: Dictionary = {}
	for site: Vector2i in banks.sites:
		if not old_sites.has(site): sites[site] = true
	var added_piles: Dictionary = {}
	for site: Vector2i in ctx.winter_piles:
		if not old_piles.has(site): added_piles[site] = true
	var union_settings: Array = []
	for settings: Dictionary in ctx.road_union.phase_by_triangle.slice(starts[1]):
		var plain: Dictionary = {}
		for name: String in ["desert_phase","desert_sign","desert_scale","desert_piece_index","winter_widths"]:
			if settings.has(name): plain[name] = settings[name]
		union_settings.append(plain)
	var fringe_settings: Array = []
	for settings: Dictionary in ctx.fringe_mesh.settings.slice(starts[2]):
		var plain: Dictionary = {}
		for name: String in ["desert_phase","desert_sign","desert_scale","desert_piece_index"]:
			if settings.has(name): plain[name] = settings[name]
		fringe_settings.append(plain)
	visual.road_sections.write(key,{"output":output,"shoulders":ctx.shoulder_mesh.triangles.slice(starts[0]),"union":ctx.road_union.clipping.triangles.slice(starts[1]),"union_points":ctx.road_union.points_by_triangle.slice(starts[1]),"union_settings":union_settings,"fringe":ctx.fringe_mesh.clipping.triangles.slice(starts[2]),"fringe_points":ctx.fringe_mesh.points.slice(starts[2]),"fringe_settings":fringe_settings,"sites":sites,"chips":banks.count-old_count,"bank_sections":banks.sections-old_sections,"piles":added_piles,"input_chips":old_count,"input_piles":old_piles.size(),"chip_saturated":banks.count >= banks.CHIP_LIMIT,"pile_saturated":ctx.winter_piles.size() >= 80})
	return output

static func _replay(ctx: Dictionary, cached: Dictionary, index: int) -> void:
	for triangle: Dictionary in cached.shoulders: ctx.shoulder_mesh.append_triangle(triangle)
	for triangle: Dictionary in cached.union: ctx.road_union.clipping.append_triangle(triangle)
	ctx.road_union.points_by_triangle.append_array(cached.union_points)
	for settings: Dictionary in cached.union_settings:
		var bound: Dictionary = settings.duplicate(); bound.desert_piece_index = index
		ctx.road_union.phase_by_triangle.append(bound)
	for triangle: Dictionary in cached.fringe: ctx.fringe_mesh.clipping.append_triangle(triangle)
	ctx.fringe_mesh.points.append_array(cached.fringe_points)
	for settings: Dictionary in cached.fringe_settings:
		var bound: Dictionary = settings.duplicate(); bound.desert_blend_sampler = ctx.road_union
		bound.desert_piece_index = index
		ctx.fringe_mesh.settings.append(bound)
	ctx.sand_banks.count += int(cached.chips); ctx.sand_banks.sections += int(cached.bank_sections)
	ctx.sand_banks.sites.merge(cached.sites)
	ctx.winter_piles.merge(cached.piles)
