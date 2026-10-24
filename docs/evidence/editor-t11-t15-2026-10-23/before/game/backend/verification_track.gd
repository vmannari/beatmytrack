extends NativeTrack
## Exact read-only query acceleration for server-owned immutable compiled tracks.
## Editor/playable tracks keep NativeTrack's live-cell implementation.

const TILE: int = 16
var _tile_width: int = 0
var _tile_height: int = 0
var _solid_ground := PackedByteArray()
var _solid_deck := PackedByteArray()
var _water := PackedByteArray()
var _local_route := PackedVector2Array()
var _kerb_near: Dictionary = {}
var _kerb_margin: float = 0.0
var _soft_props: Array = []
var _jump_objects: Array = []
var _fluid_objects: Array = []

static func frozen(source: NativeTrack) -> NativeTrack:
	var track := new()
	for property: Dictionary in source.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			track.set(property.name,source.get(property.name))
	track._build_query_index()
	return track

func _build_query_index() -> void:
	_tile_width = ceili(float(grid_width)/TILE)
	_tile_height = ceili(float(grid_height)/TILE)
	_solid_ground.resize(_tile_width*_tile_height)
	_solid_deck.resize(_solid_ground.size())
	_water.resize(_solid_ground.size())
	for y: int in range(grid_height):
		var tile_row: int = (y/TILE)*_tile_width
		for x: int in range(grid_width):
			var index: int = y*grid_width+x
			var tile: int = tile_row+x/TILE
			if cells[index] == 4: _solid_ground[tile] = 1
			if deck_cells[index] == 4: _solid_deck[tile] = 1
			if cells[index] in [3,6]: _water[tile] = 1
	# Same 25 candidates and tie order as NativeTrack, with modulo moved to setup.
	_local_route.resize(route.size()+24)
	for index: int in range(_local_route.size()):
		_local_route[index] = route[posmod(index-8,route.size())]
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		_kerb_margin = maxf(_kerb_margin,(config.wheelbase+config.track_width)*0.5)
	var reach: int = ceili(_kerb_margin/RoadKerbs.BUCKET)
	for key: Vector2i in kerbs.buckets:
		for y: int in range(-reach,reach+1):
			for x: int in range(-reach,reach+1): _kerb_near[key+Vector2i(x,y)] = true
	for object: Dictionary in hazard_objects:
		if object.kind in CreatorCatalog.SOFT: _soft_props.append(object)
		if object.kind == "jump": _jump_objects.append(object)
		if object.kind in ["oil","puddle"]: _fluid_objects.append(object)

func nearest_route(point: Vector2, previous: int = -1) -> int:
	if previous < 0: return super.nearest_route(point,previous)
	var best: int = 0
	var distance: float = INF
	for offset: int in range(25):
		var d: float = _local_route[previous+offset].distance_squared_to(point)
		if d < distance:
			distance = d
			best = offset
	return posmod(previous+best-8,route.size())

func _clear_tiles(mask: PackedByteArray, first_x: int, first_y: int, end_x: int, end_y: int) -> bool:
	for y: int in range(maxi(0,first_y)/TILE,mini(grid_height-1,end_y)/TILE+1):
		for x: int in range(maxi(0,first_x)/TILE,mini(grid_width-1,end_x)/TILE+1):
			if mask[y*_tile_width+x] != 0: return false
	return true

func _contact(point: Vector2, radius: float, elevated: bool) -> Vector3:
	var cx: int = floori((point.x+half_extent.x)/cell_size)
	var cy: int = floori((half_extent.y-point.y)/cell_size)
	var reach: int = ceili(radius/cell_size)+1
	# Out-of-grid cells are solid. A positive tile uses the original exact sweep.
	if cx-reach >= 0 and cy-reach >= 0 and cx+reach < grid_width and cy+reach < grid_height:
		if _clear_tiles(_solid_deck if elevated else _solid_ground,cx-reach,cy-reach,cx+reach,cy+reach):
			return Vector3.ZERO
	return super._contact(point,radius,elevated)

func water_depth(point: Vector2) -> float:
	# All 81 bilinear footprints fit inside this conservative box. Exterior
	# cells are solid, never water; any wet tile falls back to identical arithmetic.
	var radius: float = 1.4+2.0*cell_size
	var first_x: int = floori((point.x-radius+half_extent.x)/cell_size)
	var end_x: int = floori((point.x+radius+half_extent.x)/cell_size)
	var first_y: int = floori((half_extent.y-point.y-radius)/cell_size)
	var end_y: int = floori((half_extent.y-point.y+radius)/cell_size)
	if _clear_tiles(_water,first_x,first_y,end_x,end_y): return 0.0
	return super.water_depth(point)

func kerb_heights(state: VehicleState, config: HandlingConfig) -> Vector4:
	if (config.wheelbase+config.track_width)*0.5 <= _kerb_margin:
		if not _kerb_near.has(Vector2i((state.position/RoadKerbs.BUCKET).floor())): return Vector4.ZERO
	return super.kerb_heights(state,config)

func step_props(state: VehicleState, from: Vector2, config: HandlingConfig, step_seconds: float) -> void:
	if not tyre_origins.is_empty(): LooseTyres.step(state,tyre_origins,_contact,from,config,step_seconds)
	if not _soft_props.is_empty(): LightProps.step(state,_soft_props,_contact,from,step_seconds,config.mass,config.collision_radius)

func launch_jump(state: VehicleState, previous: Vector2) -> void:
	if not _jump_objects.is_empty(): TrackHazards.launch(state,previous,_jump_objects)

func surface_factors(state: VehicleState) -> Vector2:
	var base: Vector2 = _native_surface_factors(state)
	if _fluid_objects.is_empty(): return base
	var hazard: Vector2 = TrackHazards.factors(state,_fluid_objects)
	return Vector2(base.x*hazard.x,base.y+hazard.y)
