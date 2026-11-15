extends RefCounted
## Shared artwork; no geometry-builder dependencies.
static var SURFACE_FACTORS: Texture2D:
	get: return _texture("res://assets/textures/surface_factors_v1.png")
static var WINTER_ICE: Texture2D:
	get: return _texture("res://assets/textures/winter_ice_v1.png")
static var WINTER_ICE_FINISH: Texture2D:
	get: return _texture("res://assets/textures/winter_ice_seam_finish_v4.png")
static var WINTER_SNOW: Texture2D:
	get: return _texture("res://assets/textures/winter_snow_v1.png")
const COLORS: Array[Color] = TrackTheme.PINE # Legacy geometry-debug palette.
static var GRASS_TEXTURE: Texture2D:
	get: return _texture("res://assets/textures/painted_grass_v1.png")
static var GRASS_ALBEDO: Texture2D:
	get: return _texture("res://assets/textures/meadow_grass_v2.png")
static var GRASS_MACRO: Texture2D:
	get: return _texture("res://assets/textures/grass_macro_mask.png")
static var GRASS_NORMAL: Texture2D:
	get: return _texture("res://assets/textures/grass_normal.png")
static var DUNE_FACTORS: Texture2D:
	get: return _texture("res://assets/textures/desert_dunes_v1.png")
static var DESERT_APRON: Texture2D:
	get: return _texture("res://assets/textures/desert_apron_v1.png")
static var DUNE_ALBEDO: Texture2D:
	get: return _texture("res://assets/textures/desert_sand_v2.png")
static var DESERT_ROAD_ALBEDO: Texture2D:
	get: return _texture("res://assets/textures/desert_compacted_road_v3.png")
static var NIGHT_GROUND_ALBEDO: Texture2D:
	get: return _texture("res://assets/textures/night_industrial_ground_v1.png")
static var NIGHT_ASPHALT_WEAR: Texture2D:
	get: return _texture("res://assets/textures/night_asphalt_wear_v1.png")
static var _reference_ready: bool = false
static var _reference: Vector2
static var desert_road_reference: Vector2:
	get:
		if not _reference_ready:
			_reference = _desert_road_reference()
			_reference_ready = true
		return _reference

static func _desert_road_reference() -> Vector2:
	var artwork: Image = DESERT_ROAD_ALBEDO.get_image()
	if artwork.is_compressed(): artwork.decompress()
	var reference := Vector2.ZERO
	for y: int in range(32):
		for x: int in range(32):
			var color: Color = artwork.get_pixel((x*artwork.get_width()+artwork.get_width()/2)/32,(y*artwork.get_height()+artwork.get_height()/2)/32)
			var linear: Color = color.srgb_to_linear()
			reference += Vector2(color.r*0.2126+color.g*0.7152+color.b*0.0722,linear.r*0.2126+linear.g*0.7152+linear.b*0.0722)
	return reference/1024.0


static var _textures: Dictionary = {}
static func _texture(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = load(path)
	return _textures[path]
