class_name VehicleCatalog
extends RefCounted
## Authored local cars; no unlocks or purchases. IDs pin handling and artwork.
const IDS: Array[String] = ["compact", "pickup", "kart", "forklift", "electric", "hovercraft"]
# Append only: persistence and achievement bits keep their historical identities.
const ALL_IDS: Array[String] = ["compact", "pickup", "classic", "formula", "kart", "forklift", "electric", "hovercraft"]
const NAMES: Array[String] = ["COMPACT / 01", "HAULER / 02", "KART / 05", "FORKLIFT / 06", "VOLT / 07", "HOVER / 08"]
const CLASSES: Array[String] = ["Compact", "Pick-up", "Go-kart", "Forklift", "Electric", "Hovercraft"]
const DESCRIPTIONS: Array[String] = [
	"Agile and forgiving. A versatile choice for mixed circuits.",
	"Heavy power and loose-surface traction. Plan ahead: rotation and braking take longer.",
	"Quick off the line. Tight turns and strong grip; low speed on long straights.",
	"Rear-wheel steering swings the tail wide. Tight turns and heavy traction; a low top speed.",
	"Instant rear-wheel power with responsive steering. Feed in the accelerator for a controlled slide; release to brake and stop. Select D or R while stopped. One pedal, no handbrake.",
	"Fan-powered air cushion with long, flowing slides. Steer early and brake to settle the drift. Hold the brake while stopped to reverse. No handbrake."]
static var selected: String = "compact"

static func valid_id(id: String) -> String:
	return id if id in IDS else "compact"

static func title(id: String = "") -> String:
	return NAMES[IDS.find(valid_id(selected if id.is_empty() else id))]

static func description(id: String = "") -> String:
	return DESCRIPTIONS[IDS.find(valid_id(selected if id.is_empty() else id))]

static func config(id: String, compact_profile: int = 4) -> HandlingConfig:
	if id not in ALL_IDS: id = "compact"
	if id == "compact":
		return (load(HandlingSelection.PROFILE_PATHS[clampi(compact_profile,0,HandlingSelection.PROFILE_PATHS.size()-1)]) as HandlingConfig).duplicate() as HandlingConfig
	return (load("res://resources/cars/" + id + ".tres") as HandlingConfig).duplicate() as HandlingConfig

static func artwork(id: String) -> Texture2D:
	id = valid_id(id)
	var file: String = "compact_illustration_v1" if valid_id(id) == "compact" else id + "_illustration_v1"
	return load("res://assets/menu/" + file + ".png") as Texture2D
