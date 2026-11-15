extends RefCounted
## Header widgets only display textures. Equipped appearances are cached by App.
const Build = preload("res://core/build_identity.gd")
const VERSION: String = "shared-car-picture-512-v1"
const CUSTOM_LIMIT: int = 14
const SIZE := Vector2i(512,288)
const DIRECTORY: String = "res://assets/menu/header_cars_v1/"
static var images: Dictionary = {}
static var texture_loads: int = 0
static var customized: Dictionary = {}
static var _visual_revision: String = ""

static func texture(vehicle: String, records: LocalRecords = null) -> Texture2D:
	var id: String = VehicleCatalog.valid_id(vehicle)
	if records != null:
		var key: String = appearance_key(id,records)
		if customized.has(key): return customized[key]
		# A factory picture misrepresents a saved design while its image loads.
		if not stock_appearance(id,records): return null
	if not images.has(id):
		images[id] = load(DIRECTORY+id+".png") as Texture2D
		texture_loads += 1
	return images[id]

static func stock_appearance(vehicle: String, records: LocalRecords) -> bool:
	return VehicleLivery.for_car(records.settings,vehicle) == VehicleLivery.defaults(vehicle) and VehicleCustomisation.for_car(records.settings,vehicle) == VehicleCustomisation.defaults()

static func ready(vehicle: String, records: LocalRecords) -> bool:
	return records != null and (stock_appearance(vehicle,records) or customized.has(appearance_key(vehicle,records)))

static func appearance_key(vehicle: String, records: LocalRecords) -> String:
	# Old or manually opened projects may not have regenerated build metadata.
	# Fall back to the full source identity rather than risking stale pictures.
	if _visual_revision.is_empty():
		var script: Script = Build
		_visual_revision = _source_revision(script)
	var picture_version: String = VERSION+"-kart-cloth-1" if vehicle == "kart" else VERSION
	return JSON.stringify([picture_version,_visual_revision,RenderingServer.get_current_rendering_method(),records.path,vehicle,VehicleLivery.for_car(records.settings,vehicle),VehicleCustomisation.for_car(records.settings,vehicle)],"",true).sha256_text()

static func _source_revision(script: Script) -> String:
	var constants: Dictionary = script.get_script_constant_map()
	var fallback: String = str(constants.get("ID",Build.ID))
	var revision: String = str(constants.get("HEADER_PREVIEW_SHA256",fallback))
	return revision if revision.length() == 64 and revision.is_valid_hex_number() else fallback

static func publish(key: String, pixels: Image) -> void:
	if pixels == null or pixels.get_size() != SIZE: return
	pixels.generate_mipmaps()
	if customized.size() >= CUSTOM_LIMIT: customized.erase(customized.keys()[0])
	customized[key] = ImageTexture.create_from_image(pixels)
