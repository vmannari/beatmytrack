extends SceneTree

var checks: int = 0
var failures: int = 0
var first_warning: int = -1

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func drive(session: TrackSession, track: NativeTrack, a: Vector2, b: Vector2, hint: int) -> int:
	var steps: int = maxi(1,ceili(a.distance_to(b)/(24.0/session.tick_rate)))
	for step: int in range(steps):
		var previous: Vector2 = a.lerp(b,float(step)/steps)
		var current: Vector2 = a.lerp(b,float(step+1)/steps)
		hint = track.nearest_route(current,hint)
		session.advance(track,previous,current,hint)
		if first_warning < 0 and session.shortcut_count > 0: first_warning = session.elapsed_ticks
	return hint

func run() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/silmukka.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	print("SCREENSHOT_BOUNDARY old_symmetric_m=",track.route_radii[75]+1.0," inside_m=",track.route_cut_radii[75]+1.0)
	for rate: int in [60,120,240]:
		for start: int in range(20,350,40):
			for skip: int in [40,80]:
				var end: int = start+skip
				var a: Vector2 = track.route[start]
				var b: Vector2 = track.route[end]
				var saved: float = track.route_cumulative[end]-track.route_cumulative[start]-a.distance_to(b)
				if saved < 12.0: continue
				var session := TrackSession.new(rate,1)
				var hint: int = 0
				first_warning = -1
				for i: int in range(start): hint = drive(session,track,track.route[i],track.route[i+1],hint)
				check(session.shortcut_count == 0,"Silmukka clean approach")
				hint = drive(session,track,a,b,hint)
				var rejoin_tick: int = session.elapsed_ticks
				for i: int in range(end,mini(end+10,track.route.size()-1)): hint = drive(session,track,track.route[i],track.route[i+1],hint)
				var delay: float = float(first_warning-rejoin_tick)/rate
				check(session.shortcut_count == 1,"one penalty per Silmukka cut %d -> %d at %d Hz; actual %d" % [start,end,rate,session.shortcut_count])
				check(first_warning >= 0 and delay <= 0.35,"Silmukka warning during cut or within 0.35s of rejoin")
				print("SILMUKKA rate=",rate," start=",start," end=",end," saved=",saved," cuts=",session.shortcut_count," warning_after_rejoin_s=",delay)
	# Screenshot hairpin: narrower cuts, including the grass crossing missed by v6.
	for start: int in [50,55,60,65]:
		for end: int in [85,90,95,100]:
			var narrow := TrackSession.new(120,1)
			var route_hint: int = 0
			first_warning = -1
			for i: int in range(start): route_hint = drive(narrow,track,track.route[i],track.route[i+1],route_hint)
			check(narrow.shortcut_count == 0,"clean approach to screenshot hairpin")
			route_hint = drive(narrow,track,track.route[start],track.route[end],route_hint)
			# Constructed geometry proves even the shortest line crosses the island.
			var expected: int = 1
			check(narrow.shortcut_count == expected,"narrow grass/kerb line %d -> %d classified before rejoin" % [start,end])
			print("SCREENSHOT_CUT start=",start," end=",end," cuts=",narrow.shortcut_count)
	# Real constructed small hairpins, including the screenshot beside the bridge.
	for index: int in [7,9]:
		var piece: Dictionary = document.pieces[index]
		var origin := Vector2(piece.position[0],piece.position[1])
		var angle: float = deg_to_rad(float(piece.heading))
		var radius: float = piece.radius
		var x: float = float(piece.length)+0.25
		var a: Vector2 = origin+Vector2(x,0).rotated(angle)
		var b: Vector2 = origin+Vector2(x,2.0*radius).rotated(angle)
		var tight := TrackSession.new(120,1)
		var tight_hint: int = track.nearest_route(a)
		tight_hint = drive(tight,track,a,b,tight_hint)
		check(tight.shortcut_count == 1,"constructed tight hairpin infield crossing %d" % index)
		for rate: int in [60,240]:
			var at_rate := TrackSession.new(rate,1)
			var rate_hint: int = track.nearest_route(a)
			rate_hint = drive(at_rate,track,a,b,rate_hint)
			check(at_rate.shortcut_count == 1,"tight hairpin crossing at %d Hz" % rate)
		var paused := TrackSession.new(120,1)
		var paused_hint: int = track.nearest_route(a)
		var inside: Vector2 = a.lerp(b,0.4)
		paused_hint = drive(paused,track,a,inside,paused_hint)
		for tick: int in range(240): paused.advance(track,inside,inside,paused_hint)
		paused_hint = drive(paused,track,inside,a.lerp(b,0.6),paused_hint)
		check(paused.shortcut_count == 1 and paused.shortcut_notice_active(),"stopped tight-hairpin grass crossing warns before rejoin")

		for offset: float in [-0.4,2.0]:
			var legal := TrackSession.new(120,1)
			var arc_radius: float = radius-float(piece.width)*0.5+offset if offset < 0.0 else radius+float(piece.width)*0.5+offset
			var previous: Vector2 = origin+Vector2(float(piece.length),radius-arc_radius).rotated(angle)
			var legal_hint: int = track.nearest_route(previous)
			var approach: Vector2 = origin+Vector2(float(piece.length),0).rotated(angle)
			legal_hint = drive(legal,track,approach,previous,legal_hint)
			for sample: int in range(1,101):
				var theta: float = -PI*0.5+PI*sample/100.0
				var current: Vector2 = origin+Vector2(float(piece.length)+arc_radius*cos(theta),radius+arc_radius*sin(theta)).rotated(angle)
				legal_hint = drive(legal,track,previous,current,legal_hint)
				previous = current
			check(legal.shortcut_count == 0,"actual tight hairpin kerb/outside arc %d offset %s" % [index,offset])

	# Test the visible road geometry, not only the independently smoothed lap route.
	for index: int in range(document.pieces.size()):
		var geometry: Dictionary = RoadPieces.section_geometry(document.pieces,index)
		var points: PackedVector2Array = geometry.points
		for offset: float in [-4.0,0.0,4.0]:
			var previous := Vector2.ZERO
			var crossed: bool = false
			for sample: int in range(points.size()):
				var tangent: Vector2 = (points[mini(sample+1,points.size()-1)]-points[maxi(sample-1,0)]).normalized()
				var current: Vector2 = points[sample]+tangent.orthogonal()*offset
				if sample > 0 and track.crosses_hairpin_infield(previous,current): crossed = true
				previous = current
			check(not crossed,"constructed road centre/edge never crosses forbidden island: piece %d offset %s" % [index,offset])
	var stopped := TrackSession.new(120,1)
	var stopped_hint: int = 0
	for i: int in range(55): stopped_hint = drive(stopped,track,track.route[i],track.route[i+1],stopped_hint)
	var grass: Vector2 = track.route[55].lerp(track.route[85],0.5)
	stopped_hint = drive(stopped,track,track.route[55],grass,stopped_hint)
	for tick: int in range(240): stopped.advance(track,grass,grass,stopped_hint)
	stopped_hint = drive(stopped,track,grass,track.route[85],stopped_hint)
	check(stopped.shortcut_count == 1,"stopping on the inside grass cannot erase the cut")
	var race := TrackSession.new(120,5)
	var race_hint: int = 0
	for lap: int in range(5):
		for i: int in range(65): race_hint = drive(race,track,track.route[i],track.route[i+1],race_hint)
		race_hint = drive(race,track,track.route[65],track.route[90],race_hint)
		check(race.shortcut_count == lap+1,"narrow cut re-arms each lap including fourth lap")
		for i: int in range(90,track.route.size()): race_hint = drive(race,track,track.route[i],track.route[(i+1)%track.route.size()],race_hint)
		race_hint = drive(race,track,track.route[0],track.route[0]+track.finish_forward*0.1,race_hint)
	check(race.finished and race.penalty_seconds == 25.0,"five repeated cuts count five laps and five penalties")
	# Previous laps must not supply evidence that this lap's skipped road was driven.
	var repeated := TrackSession.new(120,2)
	var hint: int = 0
	for i: int in range(track.route.size()): hint = drive(repeated,track,track.route[i],track.route[(i+1)%track.route.size()],hint)
	hint = drive(repeated,track,track.route[0],track.route[1],hint)
	check(repeated.completed_laps == 1 and repeated.shortcut_count == 0,"clean first lap")
	for i: int in range(1,100): hint = drive(repeated,track,track.route[i],track.route[i+1],hint)
	hint = drive(repeated,track,track.route[100],track.route[180],hint)
	check(repeated.shortcut_count == 1,"previous clean lap cannot conceal next lap's cut")
	print("SILMUKKA_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
