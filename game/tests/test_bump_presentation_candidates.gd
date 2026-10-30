extends SceneTree
## Compare the presentation broad phase against the original full scans.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	var track := NativeTrack.new()
	for index: int in range(640):
		track.speed_bump_objects.append({"kind":"speed_bump","position":[float(index%32)*16.0-256.0,float(index/32)*16.0-160.0],"rotation":float((index*37)%360),"scale":0.5+float(index%5)*0.5,"span":3.0+float(index%8)*3.0})
	# Overlap and negative-cell boundaries, plus a wide rotated bump.
	track.speed_bump_objects.append({"kind":"speed_bump","position":[-8.0,-8.0],"rotation":37.0,"scale":2.0,"span":24.0})
	track.speed_bump_objects.append({"kind":"speed_bump","position":[-8.0,-8.0],"rotation":117.0,"scale":1.0,"span":8.0})
	var car := CarVisual.new()
	var selected_total: int = 0
	for id: String in VehicleCatalog.IDS:
		car.vehicle_id = id
		var config: HandlingConfig = VehicleCatalog.config(id)
		var reach: float = maxf(config.wheelbase+config.track_width,ContactShading.car_support_reach(car))
		for index: int in range(160):
			var point := Vector2(float((index*73)%517)-258.0,float((index*97)%341)-170.0)
			if index < 20: point = Vector2(-8,-8)+Vector2(float(index-10)*0.7,float((index*13)%17)-8.0)
			var heading: float = float(index)*0.37
			var candidates: Array = track.nearby_speed_bumps(point,reach)
			selected_total += candidates.size()
			check(SpeedBumps.contacts(point,heading,config,candidates) == SpeedBumps.contacts(point,heading,config,track.speed_bump_objects),id+" wheel contacts "+str(index))
			var axle := Vector2(sin(heading),cos(heading))*ContactShading.car_support_reach(car)
			check(SpeedBumps.height(point+axle,candidates) == SpeedBumps.height(point+axle,track.speed_bump_objects) and SpeedBumps.height(point-axle,candidates) == SpeedBumps.height(point-axle,track.speed_bump_objects),id+" shadow support "+str(index))
	check(selected_total < VehicleCatalog.IDS.size()*160*track.speed_bump_objects.size()/8,"broad phase excludes distant bumps")
	# A bounded headless microbenchmark includes index validation once per frame.
	# It measures these queries only, not renderer or whole-game frame time.
	var config: HandlingConfig = VehicleCatalog.config("compact")
	car.vehicle_id = "compact"
	var reach: float = maxf(config.wheelbase+config.track_width,ContactShading.car_support_reach(car))
	var timings: Array = []
	for indexed: bool in [false,true]:
		var start: int = Time.get_ticks_usec()
		for index: int in range(160):
			var point := Vector2(float((index*73)%517)-258.0,float((index*97)%341)-170.0)
			var heading: float = float(index)*0.37
			if indexed: track.begin_creator_queries()
			var bumps: Array = track.nearby_speed_bumps(point,reach) if indexed else track.speed_bump_objects
			SpeedBumps.contacts(point,heading,config,bumps)
			var axle := Vector2(sin(heading),cos(heading))*ContactShading.car_support_reach(car)
			SpeedBumps.height(point+axle,bumps); SpeedBumps.height(point-axle,bumps)
			if indexed: track.end_creator_queries()
		timings.append((Time.get_ticks_usec()-start)/160.0)
	print("BUMP_QUERY_US full=%.1f indexed=%.1f objects=%d" % [timings[0],timings[1],track.speed_bump_objects.size()])
	track.speed_bump_objects.append({"kind":"speed_bump","position":[1000.0,1000.0],"rotation":45.0,"scale":1.0,"span":16.0})
	check(SpeedBumps.height(Vector2(1000,1000),track.nearby_speed_bumps(Vector2(1000,1000),4.0)) == SpeedBumps.HEIGHT,"in-place source mutation refreshes index")
	var document: Dictionary = TrackDocument.create_default()
	document.objects = [{"kind":"speed_bump","position":[0.0,0.0],"rotation":45.0,"scale":1.0,"span":16.0}]
	var compiled: NativeTrack = TrackCompiler.compile(document)
	compiled.nearby_speed_bumps(Vector2.ZERO,4.0) # Prime source's derived index.
	var prepared = preload("res://editor/prepared_track_cache.gd")
	var cache: Dictionary = {}
	prepared.remember(document,compiled,cache)
	var restored: NativeTrack = prepared.restore(document,cache)
	check(restored != null and SpeedBumps.height(Vector2.ZERO,restored.nearby_speed_bumps(Vector2.ZERO,4.0)) == SpeedBumps.HEIGHT,"restored track rebuilds its index")
	if restored != null:
		restored.speed_bump_objects[0].position = [1000.0,1000.0]
		check(restored.nearby_speed_bumps(Vector2.ZERO,4.0).is_empty() and SpeedBumps.height(Vector2(1000,1000),restored.nearby_speed_bumps(Vector2(1000,1000),4.0)) == SpeedBumps.HEIGHT,"restored track invalidates its index after in-place edit")
		check(SpeedBumps.height(Vector2.ZERO,compiled.nearby_speed_bumps(Vector2.ZERO,4.0)) == SpeedBumps.HEIGHT,"restored index and objects do not mutate the source")
	car.free()
	print("BUMP_PRESENTATION: %d checks, %d failures; %d selected candidates" % [checks,failures,selected_total])
	quit(1 if failures else 0)
