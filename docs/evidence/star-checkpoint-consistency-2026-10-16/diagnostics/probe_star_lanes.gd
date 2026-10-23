extends "res://tests/test_star_gate_tolerance.gd"
func run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	print("WIDTHS ",track.route_widths.size()," ",Array(track.route_widths).min()," ",Array(track.route_widths).max()," route=",track.route.size())
	var a: PackedVector2Array = edge_lane(track,5.0)
	var b: PackedVector2Array = SplineGateCorridor.lane(track,5.0/6.0)
	print("LANES ",a.size()," ",b.size())
	for offset: float in [-1.0,-0.75,0.75,1.0]:
		var path: PackedVector2Array = SplineGateCorridor.lane(track,offset)
		print("BOUNDARY ",offset," shallow=",shallow_excursion(track,path)," offroad=",offroad_samples(track,path))
	for i: int in range(mini(a.size(),b.size())):
		if a[i] != b[i]: print("DIFF ",i," ",a[i]," ",b[i]," width=",track.route_widths[mini(i,track.route.size()-1)]); break
	quit()
