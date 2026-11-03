extends SceneTree

func _initialize() -> void:
	var progress = preload("res://persistence/daily_progress.gd")
	var ok: bool = "pickup" not in VehicleCatalog.IDS and "pickup" in VehicleCatalog.ALL_IDS
	ok = ok and VehicleCatalog.valid_id("pickup") == "compact"
	ok = ok and VehicleCatalog.IDS.size() == VehicleCatalog.NAMES.size() and VehicleCatalog.IDS.size() == VehicleCatalog.CLASSES.size() and VehicleCatalog.IDS.size() == VehicleCatalog.DESCRIPTIONS.size()
	ok = ok and VehicleCatalog.title("kart") == "KART" and VehicleCatalog.title("electric") == "VOLT"
	ok = ok and VehicleCatalog.config("pickup").profile_name == "Hauler"
	ok = ok and progress.valid({"day":1,"passed":1,"best_ms":1000,"version":"v1","vehicle":"pickup"})
	print("Hauler retirement: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
