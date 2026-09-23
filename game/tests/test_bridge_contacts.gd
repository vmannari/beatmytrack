extends SceneTree
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _initialize() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
	var track: NativeTrack = TrackCompiler.compile(doc)
	for reverse: bool in [false,true]:
		for offset: float in [-1.0,0.0,1.0]:
			_knit(track,reverse,offset)
	# The isolated first span has both open ends and a clear central tunnel.
	var span: Dictionary = track.creator_bridges[0]
	var origin := Vector2(span.position[0],span.position[1])
	var axis := Vector2.RIGHT.rotated(deg_to_rad(span.heading))
	var normal := axis.orthogonal()
	var config: HandlingConfig = load("res://resources/balanced.tres")
	for u: float in [3.0,float(span.length)-3.0]:
		var target: Vector2 = origin+axis*u
		check(track.overlaps_obstacle(target,0.1,false),"low underside is solid on ground")
		check(not track.overlaps_obstacle(target,config.collision_radius,true),"same ramp asphalt stays drivable above")
		var from: Vector2 = origin+axis*float(span.length)*0.5
		var state := VehicleState.new()
		state.position = target
		state.velocity = (target-from).normalized()*30.0
		track.resolve(state,from,config)
		check(state.collision_count > 0 and not state.track_elevated,"swept tunnel-to-ramp contact cannot teleport upstairs")
		check(state.position.distance_to(target) > config.collision_radius,"underside blocks full car footprint")
	var middle: Vector2 = origin+axis*float(span.length)*0.5
	var under := VehicleState.new()
	under.position = middle+normal*8.0
	under.velocity = normal*25.0
	track.resolve(under,middle-normal*8.0,config)
	check(under.collision_count == 0 and not under.track_elevated,"central underpass crosses both rails without collision")
	var rail := VehicleState.new()
	rail.track_elevated = true
	rail.position = middle+normal*8.0
	rail.velocity = normal*25.0
	track.resolve(rail,middle,config)
	check(rail.collision_count > 0,"upper rail still blocks driving off the deck")
	print("BRIDGE_CONTACT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _knit(track: NativeTrack, reverse: bool, lateral: float) -> void:
	var config: HandlingConfig = load("res://resources/balanced.tres")
	var points: PackedVector2Array = track.route.duplicate()
	if reverse: points.reverse()
	for i: int in range(points.size()):
		var index: int = points.size()-1-i if reverse else i
		var tangent: Vector2 = (track.route[(index+1)%points.size()]-track.route[posmod(index-1,points.size())]).normalized()
		points[i] += tangent.orthogonal()*lateral
	var state := VehicleState.new()
	state.position = points[0]
	state.route_index = track.nearest_route(state.position)
	state.track_elevated = track.elevated_at(state.position,state.route_index)
	var hits: int = 0
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		for j: int in range(1,11):
			var from: Vector2 = state.position
			state.position = a.lerp(b,j/10.0)
			state.velocity = (b-a).normalized()*10.0
			var count: int = state.collision_count
			track.resolve(state,from,config)
			if state.collision_count > count:
				if hits < 3: print("HIT i=",i," point=",state.position," upper=",state.track_elevated)
				hits += 1
				state.position = a.lerp(b,j/10.0)
	print("KNIT reverse=",reverse," offset=",lateral," hits=",hits)
	check(hits == 0,"Knit continuous route remains clear in both directions and across driving line")
