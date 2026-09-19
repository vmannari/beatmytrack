class_name HandlingSelection
extends RefCounted
## Session UI preference, separate from the canonical handling Resource.
static var index: int = 4
const PROFILE_PATHS: Array[String] = ["res://resources/stable.tres", "res://resources/balanced.tres", "res://resources/loose.tres", "res://resources/baseline.tres", "res://resources/original_slide.tres"]

static func config() -> HandlingConfig:
	return VehicleCatalog.config(VehicleCatalog.selected, index)
