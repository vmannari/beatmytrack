extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fixture() -> NativeTrack:
	var track := NativeTrack.new()
	track.route = PackedVector2Array([Vector2(0,0),Vector2(40,0),Vector2(40,40),Vector2(0,40)])
	track.finish_center = Vector2.ZERO
	track.finish_forward = Vector2.RIGHT
	track.finish_half_width = 6.0
	track._build_route_distance()
	for p: Vector2 in [Vector2(20,0),Vector2(40,20),Vector2(20,40),Vector2(0,20)]: track.checkpoints.append(Rect2(p-Vector2(6,6),Vector2(12,12)))
	return track
func drive(session: TrackSession, track: NativeTrack, path: PackedVector2Array, spacing: float = 0.5) -> bool:
	var warned: bool = false
	for i: int in range(path.size()-1):
		var count: int = maxi(1,ceili(path[i].distance_to(path[i+1])/spacing))
		for j: int in range(count):
			var a: Vector2 = path[i].lerp(path[i+1],float(j)/count)
			var b: Vector2 = path[i].lerp(path[i+1],float(j+1)/count)
			session.advance(track,a,b,track.nearest_route(b),track.elevated_at(b,track.nearest_route(b)))
			warned = warned or session.missed_checkpoint >= 0
	return warned
func run() -> void:
	_sharp_joins()
	var track := fixture()
	var loop := PackedVector2Array([Vector2(1,0),Vector2(40,0),Vector2(40,40),Vector2(0,40),Vector2(0,0),Vector2(1,0)])
	for spacing: float in [0.1,0.5,3.0,50.0]:
		var session := TrackSession.new()
		for lap: int in range(5):
			drive(session,track,loop,spacing)
			check(session.completed_laps == lap+1,"ordered full lap at spacing "+str(spacing))
		check(session.finished and session.lap_times.size() == 5,"five laps finish")
		var ticks: int = session.elapsed_ticks
		session.advance(track,Vector2.ZERO,Vector2.ONE,0)
		check(session.elapsed_ticks == ticks,"finish freezes official time")
		check(is_equal_approx(session.race_time_seconds(),session.lap_times.reduce(func(total: float,v: float) -> float: return total+v,0.0)),"lap times equal race clock without penalty")
	var missed := TrackSession.new(120,1)
	drive(missed,track,PackedVector2Array([Vector2(1,0),Vector2(40,20),Vector2(40,40),Vector2(0,40),Vector2(0,0),Vector2(1,0)]))
	check(not missed.finished and missed.completed_laps == 0 and missed.next_checkpoint < missed.checkpoint_count(),"skipped gate blocks the finish and cannot be credited out of order")
	check(missed.missed_checkpoint == missed.next_checkpoint,"missing road section is highlighted")
	check(missed.penalty_seconds == 0 and missed.shortcut_count == 0,"no shortcut penalty under checkpoint rules")
	var before_recovery: int = missed.elapsed_ticks
	drive(missed,track,loop)
	check(missed.finished and missed.missed_checkpoint == -1,"returning through all required gates recovers the lap")
	check(missed.lap_times[0] > before_recovery/120.0,"recovery time remains in the lap")
	var reverse := TrackSession.new(120,1)
	drive(reverse,track,PackedVector2Array([Vector2(30,0),Vector2(10,0)]))
	check(reverse.next_checkpoint == 0,"reverse crossing does not consume a forward gate")
	for i: int in range(1000): reverse.advance(track,Vector2(20,0),Vector2(20,0),0)
	check(reverse.next_checkpoint == 0 and not reverse.finished,"stationary overlap cannot manufacture progress")
	var sweep := TrackSession.new(120,1)
	drive(sweep,track,PackedVector2Array([Vector2(-10,0),Vector2(30,0)]),100.0)
	check(sweep.next_checkpoint >= 2,"swept high-speed gate crossing cannot tunnel")
	var outside := TrackSession.new(120,1)
	drive(outside,track,PackedVector2Array([Vector2(0,12),Vector2(30,12)]),100.0)
	check(outside.next_checkpoint == 0 and outside.missed_checkpoint == 0,"passing beside the gate is a miss")
	var sparse := fixture()
	sparse.checkpoints.clear()
	var automatic := TrackSession.new(120,1)
	drive(automatic,sparse,loop)
	check(automatic.finished and automatic.checkpoint_count() >= 8 and automatic.checkpoint_count() <= 16,"native routes get ordered gates with redundant apex neighbours removed")
	check(RaceRules.KEY == "standing-5-road-gates-v19","spline corner checkpoints use a new rules key")
	# Real creator hairpins: a cut must block the eventual finish, even when
	# the car rejoins and follows the rest of the route correctly.
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/silmukka.json"))
	var real_track: NativeTrack = TrackCompiler.compile(document)
	var clean := TrackSession.new(120,1)
	var full := real_track.route.duplicate()
	full.append(real_track.route[0])
	full.append(real_track.route[1])
	drive(clean,real_track,full)
	check(clean.finished,"complete real hairpin route finishes")
	for start: int in [50,55,60,65]:
		for end: int in [85,90,95,100]:
			var cut := TrackSession.new(120,1)
			var path := PackedVector2Array()
			for i: int in range(start+1): path.append(real_track.route[i])
			for i: int in range(end,real_track.route.size()): path.append(real_track.route[i])
			path.append(real_track.route[0])
			path.append(real_track.route[1])
			drive(cut,real_track,path)
			check(not cut.finished and cut.missed_checkpoint >= 0,"hairpin shortcut blocks finish %d -> %d" % [start,end])
			drive(cut,real_track,full)
			check(cut.finished,"return to missed hairpin section recovers %d -> %d" % [start,end])
	# Tight continuous hairpins: legal inner/outer lines at up to 240 m/s
	# equivalent sweep lengths, including gate-plane intersections in infield.
	for radius: float in [6.0,10.0]:
		var bend := NativeTrack.new()
		for i: int in range(128): bend.route.append(Vector2.from_angle(TAU*i/128)*radius)
		bend.route_widths.resize(128)
		bend.route_widths.fill(10.0)
		bend.finish_center = bend.route[0]
		bend.finish_forward = Vector2(0,1)
		bend.finish_half_width = 6.0
		bend._build_route_distance()
		for offset: float in [-4.0,0.0,4.0,10.0]:
			for spacing: float in [0.1,0.5,2.0]:
				var arc := PackedVector2Array()
				var samples: int = maxi(8,ceili(TAU*(radius+offset)/spacing))
				for i: int in range(samples+2):
					# Rejoin the road for the independently bounded finish line.
					var fraction: float = float(i)/samples
					var excursion: float = offset if fraction > 0.12 and fraction < 0.88 else minf(offset,4.0)
					arc.append(Vector2.from_angle(TAU*i/samples)*(radius+excursion))
				var legal := TrackSession.new(120,1)
				var warned: bool = drive(legal,bend,arc,spacing)
				check(legal.finished and not warned,"tight hairpin legal radius %s offset %s sweep %s" % [radius,offset,spacing])
		var cut := TrackSession.new(120,1)
		var diagonal := PackedVector2Array([bend.route[0],bend.route[64]])
		for i: int in range(65,130): diagonal.append(bend.route[i%128])
		drive(cut,bend,diagonal)
		check(not cut.finished and cut.missed_checkpoint >= 0,"tight hairpin diameter shortcut rejected")
	# Gentle bends allow a three-metre inside recovery margin in either direction.
	for winding: float in [-1.0,1.0]:
		var gentle := NativeTrack.new()
		for i: int in range(256): gentle.route.append(Vector2.from_angle(winding*TAU*i/256)*40.0)
		gentle.route_widths.resize(256)
		gentle.route_widths.fill(10.0)
		gentle.finish_center = gentle.route[0]
		gentle.finish_forward = Vector2(0,winding)
		gentle.finish_half_width = 6.0
		gentle._build_route_distance()
		for lateral: float in [7.5,11.0,-7.5,-10.5,-13.0]:
			var recovery := TrackSession.new(120,1)
			recovery._configure(gentle)
			var center: Vector2 = recovery._centers[0]
			var tangent: Vector2 = recovery._directions[0]
			var point: Vector2 = center-center.normalized()*lateral
			recovery.advance(gentle,point-tangent,point+tangent,0)
			check((recovery.next_checkpoint > 0) == (lateral in [7.5,-7.5,-10.5]),"inside and outside recovery allowed; excessive excursions bounded")
			var marker_center: Vector2 = recovery.checkpoint_position(gentle)
			var normal: Vector2 = recovery.checkpoint_direction(gentle).orthogonal()
			var half_span: float = recovery.checkpoint_width(gentle)*0.5
			check(recovery._inside(recovery.next_checkpoint,marker_center-normal*(half_span-0.01)) and recovery._inside(recovery.next_checkpoint,marker_center+normal*(half_span-0.01)),"visible marker matches asymmetric accepted span")
	var measured := TrackSession.new(120,100000)
	measured.advance(track,Vector2.ZERO,Vector2(1,0),0)
	var start: int = Time.get_ticks_usec()
	for i: int in range(12000): measured.advance(track,Vector2(1,0),Vector2(1.2,0),0)
	print("CHECKPOINT_CPU_US_PER_TICK: ",(Time.get_ticks_usec()-start)/12000.0)
	print("CHECKPOINT_TESTS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)

func _sharp_joins() -> void:
	# A closed parallelogram made from real straight pieces, with a start
	# halfway along a straight. Offset vertices use the road's mitred joins.
	for angle: float in [60.0,90.0,120.0]:
		for winding: float in [-1.0,1.0]:
			var edge := Vector2.RIGHT.rotated(deg_to_rad(angle)*winding)*60.0
			var vertices := PackedVector2Array([Vector2(-30,-20),Vector2(30,-20),Vector2(30,-20)+edge,Vector2(-30,-20)+edge])
			var doc: Dictionary = TrackDocument.create_blank()
			for i: int in range(4):
				var delta: Vector2 = vertices[(i+1)%4]-vertices[i]
				var piece: Dictionary = RoadPieces.create("straight",vertices[i],fposmod(rad_to_deg(delta.angle()),360.0),10.0)
				piece.length = delta.length()
				doc.pieces.append(piece)
			doc = RoadPieces.route_from_pieces(doc).document
			doc["start_line"] = {"position":[0.0,-20.0],"heading":0.0}
			var track: NativeTrack = TrackCompiler.compile(doc)
			check(track != null,"sharp join fixture compiles: "+str(TrackDocument.validate(doc)))
			if track == null: continue
			var reverse_doc: Dictionary = doc.duplicate(true)
			reverse_doc.start_line.heading = 180.0
			var reverse_track: NativeTrack = TrackCompiler.compile(reverse_doc)
			if angle == 120.0 and winding == 1.0:
				var artifact := FileAccess.open("res://../build/sharp-join-fixture.json",FileAccess.WRITE)
				artifact.store_string(JSON.stringify(doc,"\t"))
			var cut_path := PackedVector2Array([Vector2(1,-20),vertices[1]+edge.normalized()*30.0,vertices[2],vertices[3],vertices[0],Vector2(1,-20)])
			var cut := TrackSession.new(120,1)
			drive(cut,track,cut_path)
			check(not cut.finished and cut.missed_checkpoint >= 0,"off-road sharp corner cut blocks finish %s/%s" % [angle,winding])
			var recovery := PackedVector2Array([Vector2(1,-20),vertices[1],vertices[2],vertices[3],vertices[0],Vector2(1,-20)])
			drive(cut,track,recovery)
			check(cut.finished,"returning through sharp join recovers the lap")
			for offset: float in [-3.8,0.0,3.8]:
				var path := PackedVector2Array([Vector2(1,-20+offset)])
				for step: int in range(1,5):
					var i: int = step%4
					var incoming: Vector2 = (vertices[i]-vertices[posmod(i-1,4)]).normalized()
					var outgoing: Vector2 = (vertices[(i+1)%4]-vertices[i]).normalized()
					var normal: Vector2 = Vector2(-(incoming+outgoing).y,(incoming+outgoing).x).normalized()
					if offset*winding < 0.0:
						# Raster roads round the outer tip. Follow that road area,
						# rather than the decorative outer miter extension.
						path.append(vertices[i]+Vector2(-incoming.y,incoming.x)*offset)
						path.append(vertices[i]+Vector2(-outgoing.y,outgoing.x)*offset)
					else:
						path.append(vertices[i]+normal*offset/maxf(0.25,normal.dot(Vector2(-incoming.y,incoming.x))))
				path.append(Vector2(1,-20+offset))
				var on_road: bool = true
				for i: int in range(path.size()-1):
					var samples: int = ceili(path[i].distance_to(path[i+1])/0.25)
					for j: int in range(samples+1):
						var point: Vector2 = path[i].lerp(path[i+1],float(j)/samples)
						on_road = on_road and track.cell_at(point,false) in [0,5]
				check(on_road,"sharp join path stays on compiled road %s/%s/%s" % [angle,winding,offset])
				for spacing: float in [0.1,0.5,2.0]:
					var session := TrackSession.new(120,1)
					var warned: bool = drive(session,track,path,spacing)
					check(session.finished and not warned,"sharp join legal lap %s/%s/%s/%s gate %s" % [angle,winding,offset,spacing,session.next_checkpoint])
					var reverse_path: PackedVector2Array = path.duplicate()
					reverse_path.reverse()
					reverse_path[0] = Vector2(-1,-20+offset)
					reverse_path[-1] = reverse_path[0]
					var reverse_session := TrackSession.new(120,1)
					var reverse_warned: bool = drive(reverse_session,reverse_track,reverse_path,spacing)
					check(reverse_session.finished and not reverse_warned,"reversed start respects sharp join gate direction %s/%s/%s/%s" % [angle,winding,offset,spacing])
