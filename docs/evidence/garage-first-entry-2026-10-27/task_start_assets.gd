extends SceneTree
func _initialize() -> void:
	# Replay exact archived binary resources only in this isolated process.
	var script: Script=load("res://ui/garage_car_cache.gd")
	script.source_code=FileAccess.get_file_as_string("res://ui/garage_car_cache.gd").replace('const DIRECTORY: String="res://assets/garage/cars_v1/"','const DIRECTORY: String="res://../docs/evidence/garage-first-entry-2026-10-27/before/game/assets/garage/cars_v1/"')
	assert(script.reload(true)==OK)
	run.call_deferred()

func run() -> void:
	var cache: Script=load("res://ui/garage_car_cache.gd")
	var failures: int=0
	for id: String in VehicleCatalog.IDS:
		var car:=CarVisual.new()
		car.vehicle_id=id;car.editable_kits=id=="compact"
		car.customisation=VehicleCustomisation.defaults()
		if not cache.restore(car):
			failures+=1;print("FAIL: archived prepared native resource rejected ",id)
		car.free()
	print("ARCHIVED_ASSETS 7 checks, ",failures," failures")
	quit(1 if failures else 0)
