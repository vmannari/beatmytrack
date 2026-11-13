extends SceneTree
## New-car identity, matched-speed Rally controls, power, exact replay and saves.
var checks: int = 0
var failures: int = 0
var metrics: Dictionary = {}
var output: String = "res://../docs/evidence/super-rally-2026-11-08"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var rally: HandlingConfig = VehicleCatalog.config("compact")
	var sport: HandlingConfig = VehicleCatalog.config("super_rally")
	check(sport.vehicle_id == "super_rally" and sport.version == "super-rally-1","separate canonical identity")
	check(VehicleCatalog.IDS.back() == "super_rally" and VehicleCatalog.ALL_IDS.back() == "super_rally","append-only selection and achievement identities")
	check(VehicleCatalog.IDS.size() == VehicleCatalog.NAMES.size() and VehicleCatalog.IDS.size() == VehicleCatalog.CLASSES.size() and VehicleCatalog.IDS.size() == VehicleCatalog.DESCRIPTIONS.size(),"catalogue arrays agree")
	var original: Dictionary = rally.snapshot()
	var variant: Dictionary = sport.snapshot()
	for field: String in ["vehicle_id","version","profile_name","engine_force","maximum_speed"]:
		original.erase(field)
		variant.erase(field)
	check(original == variant,"every steering, grip, mass, brake and surface setting matches Rally")
	check(is_equal_approx(sport.engine_force,rally.engine_force*1.2) and sport.maximum_speed == 55.0,"20 percent more power and 198 km/h speed cap")
	# Matched-speed coast, braking and handbrake maneuvers must remain bit exact.
	for speed: float in [3.0,15.0,28.0,44.0]:
		for steer: float in [-1.0,-0.4,0.4,1.0]:
			for pedals: Vector2 in [Vector2.ZERO,Vector2(0.6,0),Vector2(0,0.7)]:
				var a := VehicleSimulation.new(rally)
				var b := VehicleSimulation.new(sport)
				a.state.velocity = Vector2(0,speed)
				b.state.velocity = a.state.velocity
				for tick: int in range(120):
					var input := DriveFrame.sample(steer,0,pedals.x,pedals.y)
					a.step(input)
					b.step(input)
					if a.state.velocity.length() < 0.15: break # Stop before held brake engages powered reverse.
				check(a.state.snapshot() == b.state.snapshot(),"matched-speed coast/brake/handbrake %s/%s/%s" % [speed,steer,pedals])
	var launch: Dictionary = {}
	for id: String in ["compact","super_rally"]:
		var sim := VehicleSimulation.new(VehicleCatalog.config(id))
		var hundred: int = 0
		var five_seconds: float = 0.0
		for tick: int in range(3600):
			sim.step(DriveFrame.sample(0,1,0))
			if hundred == 0 and sim.state.velocity.length() >= 100.0/3.6: hundred = tick+1
			if tick == 599: five_seconds = sim.state.position.y
		launch[id] = {"zero_to_100_seconds":hundred*VehicleSimulation.STEP,"five_second_metres":five_seconds,"top_kph":sim.state.velocity.length()*3.6}
	check(launch.super_rally.zero_to_100_seconds < launch.compact.zero_to_100_seconds,"quicker actual 0 to 100")
	check(launch.super_rally.five_second_metres > launch.compact.five_second_metres,"more distance in actual five-second launch")
	check(launch.super_rally.top_kph > launch.compact.top_kph*1.19 and launch.super_rally.top_kph <= sport.maximum_speed*3.6+0.0001,"higher actual top speed within cap")
	metrics.launch = launch
	var frames: Array[Array] = []
	var sim := VehicleSimulation.new(sport)
	var saved: Dictionary = {}
	for tick: int in range(3600):
		var frame := DriveFrame.sample(sin(tick*0.012)*0.65,1.0 if tick%600<430 else 0.0,0.65 if tick%600>=500 else 0.0,0.4 if tick%600 in range(460,480) else 0.0)
		frames.append(frame.packed())
		sim.step(frame)
		check(sim.state.velocity.is_finite() and sim.state.velocity.length() <= sport.maximum_speed+0.000001,"bounded mixed-input state")
		if tick == 1799: saved = RewindHistory.pack_state(sim.state)
	var replay := VehicleSimulation.new(sport)
	var resumed := VehicleSimulation.new(sport)
	RewindHistory.restore(resumed.state,saved)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	for tick: int in range(decoded.size()):
		var frame := DriveFrame.sample(float(decoded[tick][0])/127,float(decoded[tick][1])/255,float(decoded[tick][2])/255,float(decoded[tick][3])/255 if decoded[tick].size()>3 else 0.0)
		replay.step(frame)
		if tick >= 1800: resumed.step(frame)
	check(sim.state.snapshot() == replay.state.snapshot(),"serialized mixed-input replay is exact")
	check(sim.state.snapshot() == resumed.state.snapshot(),"restored midpoint replay is exact")
	DirAccess.make_dir_recursive_absolute("user://super-rally-tests")
	var records := LocalRecords.new("user://super-rally-tests/records.json")
	records.load_records()
	var track := NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_arto4_test.json")
	check(records.key_for(track,rally) != records.key_for(track,sport),"personal records have separate rules")
	check(records.record(track,sport,100.0,[20.0,20.0,20.0,20.0,20.0]) == OK,"new car PB saves")
	check(records.best_for(track,rally) == 0.0,"new car PB cannot replace Rally PB")
	records.settings.selected_car = "super_rally"
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "scoop"
	records.settings.vehicle_customisation = {}
	for id: String in VehicleCatalog.IDS: records.settings.vehicle_customisation[id] = parts.duplicate() if id in ["compact","super_rally"] else VehicleCustomisation.defaults()
	records.settings.vehicle_liveries = {"super_rally":VehicleLivery.defaults("super_rally"),"compact":VehicleLivery.defaults("compact")}
	check(VehicleCustomisation.valid_collection(records.settings.vehicle_customisation),"all six car designs fit the saved collection")
	check(records.save_records() == OK,"new car selection and designs save")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	check(reopened.settings.selected_car == "super_rally" and VehicleCustomisation.for_car(reopened.settings,"super_rally").hood == "scoop","new selection and fitted parts survive reload")
	check(VehicleLivery.for_car(reopened.settings,"compact") != VehicleLivery.for_car(reopened.settings,"super_rally"),"separate paint survives reload")
	check(LiveryCatalog.projection("super_rally").hood == Vector4(-0.72,-1.94,1.44,1.12) and LiveryCatalog.projection("super_rally").roof == Vector4(-0.48,-0.24,0.96,1.16) and LiveryCatalog.has_roof("super_rally"),"stickers map to the imported Challenger hood and roof")
	var bases = preload("res://vehicle/modular_car_base.gd")
	var kits = preload("res://vehicle/modular_car_kits.gd")
	var base_hits: int = bases.hits
	var kit_hits: int = kits.hits
	for editable: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "super_rally"
		car.editable_kits = editable
		car.livery = VehicleLivery.defaults("super_rally")
		root.add_child(car)
		while not car.model_ready: await process_frame
		check(car.model_id == "super_rally" and car.chassis_id == "compact" and car.vehicle_id == "super_rally" and car.rolling_wheels.size() == 4 and car.front_wheels.size() == 2,"complete Rally chassis retains variant identity")
		check(car.paint_materials.body.albedo_color == Color(VehicleLivery.defaults("super_rally").colors.body),"new factory paint on actual model")
		car.set_night_headlights(true)
		check(car.headlights != null,"Rally night lamps work")
		if editable:
			car.change_kit_parts(parts)
			check(car.customisation.hood == "scoop" and not car.kit_frames.hood.is_empty(),"Rally fitted hood replaces on variant")
		car.free()
	if "--prepared" in OS.get_cmdline_user_args():
		check(bases.hits >= base_hits+2 and kits.hits > kit_hits,"variant restores both prepared stock bases and the fitted Rally module")
	var cars: Array[CarVisual] = []
	for id: String in ["compact","super_rally"]:
		var car := CarVisual.new()
		car.vehicle_id = id
		car.livery = VehicleLivery.defaults(id)
		root.add_child(car)
		while not car.model_ready: await process_frame
		cars.append(car)
	check(cars[0].wheel_rest_positions == cars[1].wheel_rest_positions and cars[0].wheel_radii == cars[1].wheel_radii,"both variants retain identical physical wheel placement")
	check(cars[0].paint_materials.body != cars[1].paint_materials.body,"shared chassis owns separate mutable paint")
	var old_paint: Color = cars[0].paint_materials.body.albedo_color
	var paint: Dictionary = VehicleLivery.defaults("super_rally")
	paint.colors.body = "446688"
	cars[1].apply_livery(paint)
	check(cars[0].paint_materials.body.albedo_color == old_paint,"painting Super rally cannot repaint Rally")
	for car: CarVisual in cars: car.free()
	var report := FileAccess.open(output.path_join("acceptance.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	report.close()
	print("SUPER_RALLY: %d checks, %d failures; %s" % [checks,failures,JSON.stringify(metrics)])
	quit(1 if failures else 0)
