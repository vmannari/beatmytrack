extends RefCounted
## Header widgets only display textures. Equipped appearances are cached by App.
const Build = preload("res://core/build_identity.gd")
const VERSION: String = "header-equipped-1"
const CUSTOM_LIMIT: int = 14
const SIZE := Vector2i(176,112)
const DIRECTORY: String = "res://assets/menu/header_cars_v1/"
static var images: Dictionary = {}
static var texture_loads: int = 0
static var customized: Dictionary = {}

static func texture(vehicle: String, records: LocalRecords = null) -> Texture2D:
	var id: String = VehicleCatalog.valid_id(vehicle)
	if records != null:
		var key: String = appearance_key(id,records)
		if customized.has(key): return customized[key]
	if not images.has(id):
		images[id] = load(DIRECTORY+id+".png") as Texture2D
		texture_loads += 1
	return images[id]

static func appearance_key(vehicle: String, records: LocalRecords) -> String:
	return JSON.stringify([VERSION,Build.ID,RenderingServer.get_current_rendering_method(),records.path,vehicle,VehicleLivery.for_car(records.settings,vehicle),VehicleCustomisation.for_car(records.settings,vehicle)],"",true).sha256_text()

static func publish(key: String, pixels: Image) -> void:
	pixels.generate_mipmaps()
	if customized.size() >= CUSTOM_LIMIT: customized.erase(customized.keys()[0])
	customized[key] = ImageTexture.create_from_image(pixels)
