extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func fixture(points: PackedVector2Array, surface: int = 0) -> NativeTrack:
	var track := NativeTrack.new()
	track.route = points
	track.finish_center = points[0]
	track.finish_forward = (points[1] - points[0]).normalized()
	track.finish_half_width = 5.0
	track.cell_size = 0.5
	track.grid_width = 240
	track.grid_height = 160
	track.half_extent = Vector2(60, 40)
	track.cells.resize(track.grid_width * track.grid_height)
	track.cells.fill(1)
	track.metadata = {"representative_width_m":6.0}
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			var point := Vector2((x + 0.5) * 0.5 - 60, 40 - (y + 0.5) * 0.5)
			for i: int in range(points.size()):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[i], points[(i + 1) % points.size()])) <= 3.0:
					track.cells[y * track.grid_width + x] = surface
					break
	track._build_route_distance()
	track._build_validation_route()
	return track

func drive(session: TrackSession, track: NativeTrack, path: PackedVector2Array, spacing: float = 0.2, bogus_hint: int = 0) -> void:
	for i: int in range(path.size() - 1):
		var steps: int = maxi(1, ceili(path[i].distance_to(path[i + 1]) / spacing))
		for j: int in range(steps):
			session.advance(track, path[i].lerp(path[i + 1], float(j) / steps), path[i].lerp(path[i + 1], float(j + 1) / steps), bogus_hint)

func run() -> void:
	var route := PackedVector2Array([Vector2(0,0),Vector2(40,0),Vector2(40,8),Vector2(0,8),Vector2(-20,8),Vector2(-20,-20),Vector2(0,-20)])
	var track := fixture(route)
	var legal := PackedVector2Array([Vector2(0,0),Vector2(35,0),Vector2(38,2),Vector2(38,6),Vector2(35,8),Vector2(-20,8),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)])
	var inner := PackedVector2Array([Vector2(0,0),Vector2(8,4.2),Vector2(35,4.2),Vector2(40,4),Vector2(35,8),Vector2(-20,8),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)])
	var outer := PackedVector2Array([Vector2(0,0),Vector2(50,0),Vector2(50,18),Vector2(20,18),Vector2(20,8),Vector2(-20,8),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)])
	for line: PackedVector2Array in [legal,inner,outer]:
		for spacing: float in [0.1,1.0,4.0]:
			var session := TrackSession.new(120,1)
			drive(session,track,line,spacing,track.route.size()-1)
			check(session.finished and session.shortcut_count == 0,"legal/inner kerb/wide off-road line completes without penalty, spacing="+str(spacing)+" line="+str(line[1]))
	var cut := PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(12,8),Vector2(-20,8),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)])
	for rate: int in [60,120,240]:
		var session := TrackSession.new(rate,1)
		drive(session,track,PackedVector2Array([Vector2(0,0),Vector2(12,0)]),24.0/rate)
		var position := Vector2(12,0)
		var warning_y: float = -1.0
		for tick: int in range(rate):
			var next: Vector2 = position + Vector2(0,24.0/rate)
			session.advance(track,position,next,0)
			position = next
			if session.shortcut_count > 0:
				warning_y = position.y
				break
		check(warning_y > 0.0 and warning_y <= 6.5,"cut warns during crossing before reaching next centreline, rate="+str(rate))
		check(session.shortcut_notice_active(),"shortcut has a persistent visible notice immediately")
		print("CUT_WARNING rate=",rate," crossing_y=",warning_y," seconds_after_leaving_kerb_corridor=",maxf(0.0,warning_y-5.0)/24.0)
		drive(session,track,PackedVector2Array([position,Vector2(12,8),Vector2(-20,8),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)]))
		check(session.finished and session.completed_laps == 1 and session.shortcut_count == 1,"cut counts lap with one time penalty instead of rejecting it")
		check(is_equal_approx(session.race_time_seconds(),session.lap_times[0]) and session.penalty_seconds == 5.0,"penalty is included once in both lap and race totals")
	var session := TrackSession.new(120,1)
	drive(session,track,cut,0.01)
	check(session.finished and session.shortcut_count == 1,"slow cut is detected without time/distance confirmation delay")
	session = TrackSession.new(120,1)
	drive(session,track,cut,100.0)
	print("FAST_CUT finished=",session.finished," cuts=",session.shortcut_count," progress=",session.route_distance)
	check(session.finished and session.shortcut_count == 1,"high-speed shortcut gets exactly one penalty")
	session = TrackSession.new(120,1)
	for i: int in range(30): drive(session,track,PackedVector2Array([Vector2(0,0),Vector2(18,0),Vector2(0,0)]))
	drive(session,track,PackedVector2Array([Vector2(-1,0),Vector2(1,0)]))
	check(not session.finished and session.shortcut_count == 0,"backtracking cannot manufacture a lap or cause a cut penalty")
	session = TrackSession.new(120,1)
	for i: int in range(100): session.advance(track,Vector2.ZERO,Vector2.ZERO,4)
	check(session.route_distance == 0.0 and session.shortcut_count == 0,"stationary car cannot change route progress")
	session.advance(track,Vector2(-1,0),Vector2(1,0),0)
	check(not session.finished and session.shortcut_count == 0,"initial finish crossing does not reject a lap or warn")
	var eight := PackedVector2Array([Vector2(-30,-10),Vector2(-40,-20),Vector2(-40,20),Vector2(0,0),Vector2(40,-20),Vector2(40,20),Vector2(0,0)])
	var crossing := fixture(eight)
	var full := eight.duplicate()
	full.append(eight[0]); full.append(eight[0].lerp(eight[1],0.1))
	session = TrackSession.new(120,1)
	drive(session,crossing,full)
	check(session.finished and session.shortcut_count == 0,"figure eight preserves crossing branches")
	var skip_loop := PackedVector2Array([eight[0],eight[1],eight[2],eight[3],eight[0],eight[0].lerp(eight[1],0.1)])
	session = TrackSession.new(120,1)
	drive(session,crossing,skip_loop)
	check(session.shortcut_count > 0,"skipped junction loop is detected")
	session = TrackSession.new(120,5)
	for lap: int in range(5): drive(session,track,legal)
	check(session.finished and session.completed_laps == 5 and session.shortcut_count == 0,"five valid laps complete without hidden coverage rejection")
	var frozen: int = session.elapsed_ticks
	drive(session,track,cut)
	check(session.elapsed_ticks == frozen,"finished session stays frozen")
	var mirrored_route := PackedVector2Array()
	var mirrored_line := PackedVector2Array()
	for point: Vector2 in route: mirrored_route.append(Vector2(-point.x,point.y))
	for point: Vector2 in inner: mirrored_line.append(Vector2(-point.x,point.y))
	var mirrored := fixture(mirrored_route)
	session = TrackSession.new(120,1)
	drive(session,mirrored,mirrored_line)
	check(session.finished and session.shortcut_count == 0,"mirrored inside kerb line is legal")
	var dense_route := PackedVector2Array()
	for i: int in range(40): dense_route.append(route[0].lerp(route[1],float(i)/40.0))
	for i: int in range(1,route.size()): dense_route.append(route[i])
	var dense := fixture(dense_route)
	session = TrackSession.new(120,1)
	drive(session,dense,inner)
	check(session.finished and session.shortcut_count == 0,"nonuniform vertex density preserves legal hairpin")
	var dirt := fixture(route,2)
	session = TrackSession.new(120,1)
	drive(session,dirt,inner)
	check(session.finished and session.shortcut_count == 0,"dirt circuit uses the same corner tolerance")
	var outside_track := fixture(PackedVector2Array([Vector2(0,0),Vector2(40,0),Vector2(40,40),Vector2(-20,40),Vector2(-20,-20),Vector2(0,-20)]))
	var wide_path := PackedVector2Array([Vector2(35,0),Vector2(55,0),Vector2(55,40),Vector2(40,40)])
	check(not outside_track.has_cut_gap(35.0,45.0,wide_path),"missing the centreline on the OUTSIDE is not spatial proof of a shortcut")
	var inside_path := PackedVector2Array([Vector2(12,0),Vector2(40,28)])
	check(outside_track.has_cut_gap(12.0,56.0,inside_path),"bypassing the INSIDE still supplies spatial shortcut proof")
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var rotated_route := PackedVector2Array()
		var rotated_outside := PackedVector2Array()
		var rotated_inside := PackedVector2Array()
		for point: Vector2 in outside_track.route: rotated_route.append(point.rotated(angle))
		for point: Vector2 in wide_path: rotated_outside.append(point.rotated(angle))
		for point: Vector2 in inside_path: rotated_inside.append(point.rotated(angle))
		var rotated := fixture(rotated_route)
		check(not rotated.has_cut_gap(35.0,45.0,rotated_outside),"rotated outside bypass is not shortcut evidence")
		check(rotated.has_cut_gap(12.0,56.0,rotated_inside),"rotated inside bypass remains detectable")
		var wide_session := TrackSession.new(120,1)
		var wide_lap := PackedVector2Array()
		for point: Vector2 in [Vector2(0,0),Vector2(35,0),Vector2(55,0),Vector2(55,40),Vector2(40,40),Vector2(-20,40),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)]: wide_lap.append(point.rotated(angle))
		drive(wide_session,rotated,wide_lap)
		check(wide_session.finished and wide_session.shortcut_count == 0,"outside excursion and rejoin complete without a delayed charge")
		var cut_session := TrackSession.new(120,1)
		var inside_lap := PackedVector2Array()
		for point: Vector2 in [Vector2(0,0),Vector2(12,0),Vector2(40,28),Vector2(40,40),Vector2(-20,40),Vector2(-20,-20),Vector2(0,-20),Vector2(0,0),Vector2(1,0)]: inside_lap.append(point.rotated(angle))
		drive(cut_session,rotated,inside_lap)
		check(cut_session.shortcut_count == 1,"rotated inside shortcut receives one penalty")
		check(cut_session.finished,"penalized rotated lap still counts")
	print("ROUTE_VALIDATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
