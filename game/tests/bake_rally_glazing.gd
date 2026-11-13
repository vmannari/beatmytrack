extends SceneTree
## Rebuild only the four front glazing meshes; other authored surfaces stay exact.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var glazing = preload("res://vehicle/compact_glazing.gd")
	glazing.use_baked = false
	glazing.sheets.clear()
	var trim: Material = VisualGeometry.material(Color("263039"))
	for simple: bool in [false, true]:
		var car := CarVisual.new()
		car.simple_model = simple
		car.body = Node3D.new()
		car.add_child(car.body)
		glazing.sheet(car, true, trim)
		for glass: bool in [false, true]:
			var key: String = ("front_glass" if glass else "front_seal") + ("_simple" if simple else "")
			var directory: String = RacingCarModels.COACH_ROOT if simple else CompactCoachwork.ASSET_ROOT
			var path: String = directory.path_join(key + ".res")
			var error: Error = ResourceSaver.save(glazing.sheets[key], path, ResourceSaver.FLAG_COMPRESS)
			print("RALLY_GLAZING_BAKE ", path, " ", error)
			if error != OK:
				car.free()
				quit(1)
				return
		car.free()
	quit()
