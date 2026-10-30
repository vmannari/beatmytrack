extends RefCounted
## Small imported PNGs, baked offline. The header never builds a car or viewport.
const SIZE := Vector2i(176,112)
const DIRECTORY: String = "res://assets/menu/header_cars_v1/"
static var images: Dictionary = {}
static var texture_loads: int = 0

static func texture(vehicle: String) -> Texture2D:
	var id: String = VehicleCatalog.valid_id(vehicle)
	if not images.has(id):
		images[id] = load(DIRECTORY+id+".png") as Texture2D
		texture_loads += 1
	return images[id]
