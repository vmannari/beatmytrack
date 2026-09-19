class_name VehicleCatalog
extends RefCounted
## Authored local cars; no unlocks or purchases. IDs pin handling and artwork.
const IDS: Array[String] = ["compact", "pickup", "classic", "formula", "kart"]
const NAMES: Array[String] = ["COMPACT / 01", "HAULER / 02", "REARSPORT / 03", "FORMULA / 04", "KART / 05"]
const CLASSES: Array[String] = ["Compact", "Pick-up", "Classic Sports", "Formula", "Go-kart"]
const DESCRIPTIONS: Array[String] = [
	"Agile and forgiving. A versatile choice for mixed circuits.",
	"Heavy power and loose-surface traction. Plan ahead: rotation and braking take longer.",
	"Rear-heavy traction for fast exits. Lift in a corner to rotate; catch the rear early.",
	"Precise asphalt grip. Low top speed, abrupt slides and harsh off-road penalties.",
	"Quick off the line. Tight turns and strong grip; low speed on long straights."]
static var selected: String = "compact"

static func valid_id(id: String) -> String:
	return id if id in IDS else "compact"

static func title(id: String = "") -> String:
	return NAMES[IDS.find(valid_id(selected if id.is_empty() else id))]

static func description(id: String = "") -> String:
	return DESCRIPTIONS[IDS.find(valid_id(selected if id.is_empty() else id))]

static func config(id: String, compact_profile: int = 4) -> HandlingConfig:
	if valid_id(id) == "compact":
		return (load(HandlingSelection.PROFILE_PATHS[clampi(compact_profile,0,4)]) as HandlingConfig).duplicate() as HandlingConfig
	return (load("res://resources/cars/" + id + ".tres") as HandlingConfig).duplicate() as HandlingConfig

static func artwork(id: String) -> Texture2D:
	var file: String = "compact_illustration_v1" if valid_id(id) == "compact" else id + "_illustration_v1"
	return load("res://assets/menu/" + file + ".png") as Texture2D
