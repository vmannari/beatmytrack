extends "res://tests/test_checkpoint_rules.gd"
## A missed section must be reported at the bypass, not at a later gate.

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	_wrong_layer_notices()
	_hairpin_notices()
	_unrelated_bridge_crossing()
	_lateral_notices()
	_finish_notices()
	print("CHECKPOINT_NOTICE_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func _wrong_layer_notices() -> void:
	for name: String in ["dust_cloud","over_and_under"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/"+name+".json"))
		var track: NativeTrack = TrackCompiler.compile(document)
		var session := TrackSession.new(120,1)
		session._configure(track)
		for gate: int in range(session.checkpoint_count()):
			var center: Vector2 = session._centers[gate]
			var direction: Vector2 = session._directions[gate]
			var hint: int = track.nearest_route(center)
			session.next_checkpoint = gate
			session.missed_checkpoint = -1
			session.advance(track,center-direction*0.05,center+direction*0.05,hint,not session._layers[gate])
			check(session.next_checkpoint == gate and session.missed_checkpoint == gate,"wrong layer warns in the crossing tick %s/%d" % [name,gate])
			session.advance(track,center-direction*0.05,center+direction*0.05,hint,session._layers[gate])
			check(session.next_checkpoint > gate and session.missed_checkpoint == -1,"correct recovery clears the warning %s/%d" % [name,gate])

func _hairpin_notices() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/silmukka.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	for start: int in [50,55,60,65]:
		for end: int in [85,90,95,100]:
			var session := TrackSession.new(120,1)
			var approach := PackedVector2Array()
			for i: int in range(start+1): approach.append(track.route[i])
			var walked: Dictionary = _continuous_path(session,track,approach,track.nearest_route(approach[0]))
			check(not walked.warned,"legal hairpin approach stays clear %d/%d" % [start,end])
			var bypass := PackedVector2Array([track.route[start],track.route[end]])
			_continuous_path(session,track,bypass,int(walked.hint))
			check(session.missed_checkpoint == session.next_checkpoint,"hairpin bypass warns by road reentry %d/%d" % [start,end])

func _continuous_path(session: TrackSession, track: NativeTrack, path: PackedVector2Array, hint: int) -> Dictionary:
	var warned: bool = false
	for i: int in range(path.size()-1):
		var count: int = maxi(1,ceili(path[i].distance_to(path[i+1])/0.25))
		for j: int in range(count):
			var before: Vector2 = path[i].lerp(path[i+1],float(j)/count)
			var after: Vector2 = path[i].lerp(path[i+1],float(j+1)/count)
			hint = track.nearest_route(after,hint)
			session.advance(track,before,after,hint)
			warned = warned or session.missed_checkpoint >= 0
	return {"hint":hint,"warned":warned}

func _unrelated_bridge_crossing() -> void:
	var track := NativeTrack.new()
	track.route = PackedVector2Array([Vector2(0,-20),Vector2(0,20),Vector2(-20,20),Vector2(-20,0),Vector2(20,0),Vector2(20,-20)])
	track.finish_center = track.route[0]
	track.finish_forward = Vector2(0,1)
	track._build_route_distance()
	track.creator_bridges = [{"position":[-5.0,0.0],"heading":0.0,"length":10.0,"width":8.0}]
	var session := TrackSession.new(120,1)
	session._configure(track)
	session._centers = PackedVector2Array([Vector2(0,-2),Vector2.ZERO])
	session._directions = PackedVector2Array([Vector2(0,1),Vector2.RIGHT])
	session._layers.assign([false,true])
	session._widths.assign([Vector2(5,5),Vector2(5,5)])
	session._progress = PackedFloat32Array([18,100])
	session._notice_reach = PackedFloat32Array([1,1])
	session.next_checkpoint = 1
	session.advance(track,Vector2(-0.1,-0.2),Vector2(0.1,0.2),0,false,0)
	check(session.next_checkpoint == 1 and session.missed_checkpoint == -1,"crossing beneath a future bridge gate stays quiet on the earlier route branch")
	session.advance(track,Vector2(-0.1,0),Vector2(0.1,0),3,false,0)
	check(session.next_checkpoint == 1 and session.missed_checkpoint == 1,"the same wrong layer warns immediately on the intended bridge approach")

func _lateral_notices() -> void:
	var track := fixture()
	for speed: float in [30.0,60.0,120.0,200.0]:
		for phase: float in [0.05,0.5,0.95]:
			for side: int in [-1,1]:
				var session := TrackSession.new(120,1)
				session._configure(track)
				var saved: Dictionary = RewindHistory.properties(session,true)
				var direction: Vector2 = session._directions[0]
				var span: float = session._widths[0].x if side < 0 else session._widths[0].y
				var point: Vector2 = session._centers[0]+direction.orthogonal()*(span+0.05)*side
				var distance: float = speed/3.6/120.0
				var before: Vector2 = point-direction*distance*phase
				var after: Vector2 = point+direction*distance*(1.0-phase)
				session.advance(track,before,after,0)
				check(session.next_checkpoint == 0 and session.missed_checkpoint == 0 and session.elapsed_ticks == 1,"outside-span miss warns in its first tick %s/%s/%s" % [speed,phase,side])
				var expected: Dictionary = RewindHistory.properties(session,true)
				RewindHistory.restore(session,saved)
				check(session.missed_checkpoint == -1 and session.elapsed_ticks == 0,"rewind before the miss clears its warning")
				session.advance(track,before,after,0)
				check(RewindHistory.properties(session,true) == expected,"replaying the miss reproduces its exact notice state")
				session.advance(track,after,before,0)
				check(session.missed_checkpoint == 0 and session.next_checkpoint == 0,"returning backwards retains the required gate and warning")
				session.advance(track,session._centers[0]-direction*0.1,session._centers[0]+direction*0.1,0)
				check(session.missed_checkpoint == -1 and session.next_checkpoint == 1 and session.penalty_seconds == 0,"forward recovery immediately clears the notice without a penalty")
	var grid := TrackSession.new(120,1)
	grid.advance(track,Vector2(-3,0),Vector2(-2.5,0),0)
	check(grid.next_checkpoint == 0 and grid.missed_checkpoint == -1,"departure behind the start stays quiet")

func _finish_notices() -> void:
	var track := fixture()
	for wrong_layer: bool in [false,true]:
		var session := TrackSession.new(120,1)
		session._configure(track)
		session.next_checkpoint = session.checkpoint_count()
		session.finish_armed = true
		var lateral: float = 0.0 if wrong_layer else track.finish_half_width+1.6
		session.advance(track,Vector2(-0.1,lateral),Vector2(0.1,lateral),0,wrong_layer)
		check(not session.finished and session.missed_checkpoint == session.checkpoint_count(),"rejected finish immediately highlights the required finish gate layer=%s" % wrong_layer)
		session.advance(track,Vector2(-0.1,0),Vector2(0.1,0),0,false)
		check(session.finished and session.missed_checkpoint == -1,"valid finish recovery clears the last-gate notice")
