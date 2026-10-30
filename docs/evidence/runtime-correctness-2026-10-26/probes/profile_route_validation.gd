extends SceneTree
func _initialize() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	for pass_index: int in range(2):
		var began: int = Time.get_ticks_usec()
		var route: Dictionary = RoadPieces.route_from_pieces(doc)
		print("ROUTE_VALIDATION ",pass_index," ok=",route.ok," us=",Time.get_ticks_usec()-began)
	quit()
