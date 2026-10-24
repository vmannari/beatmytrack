extends SceneTree
var checks: int = 0
var failures: int = 0
class ReferenceTrack extends NativeTrack:
	var original_tyres: GDScript
	var original_props: GDScript
	func step_props(state: VehicleState, from: Vector2, config: HandlingConfig, seconds: float) -> void:
		original_tyres.step(state,tyre_origins,_contact,from,config,seconds)
		original_props.step(state,hazard_objects,_contact,from,seconds,config.mass,config.collision_radius)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",message)
func reference(name: String, declaration: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/gameplay_f01_f03_before/"+name+".gd.txt").replace("\r\n","\n").replace("class_name "+declaration+"\n","")
	check(script.reload() == OK,"original reference compiles: "+name)
	return script
func run() -> void:
	var old_tyres: GDScript = reference("loose_tyres","LooseTyres")
	var old_props: GDScript = reference("light_props","LightProps")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var random := RandomNumberGenerator.new(); random.seed = 20261023
	var wall: Callable = func(p: Vector2, radius: float, _e: bool) -> Vector3: return Vector3(1,0,1) if p.x+radius > 8.0 else Vector3.ZERO
	for scenario: int in range(16):
		var origins := PackedVector2Array()
		for index: int in range(24): origins.append(Vector2((index%6)*1.05-3,(index/6)*1.05))
		var objects: Array = []
		for index: int in range(24): objects.append({"kind":CreatorCatalog.SOFT[index%CreatorCatalog.SOFT.size()],"position":[-5+(index%8)*1.4,2+(index/8)*1.4],"rotation":0,"scale":1.0})
		var a := VehicleState.new(); var b := VehicleState.new()
		a.position = Vector2(0,-7); b.position = a.position
		var saved: Dictionary = {}
		for tick: int in range(120):
			var from: Vector2 = a.position
			a.velocity = Vector2(random.randf_range(-5,5),8 if tick%40 < 25 else -4)
			b.velocity = a.velocity
			a.position += a.velocity*VehicleSimulation.STEP; b.position += b.velocity*VehicleSimulation.STEP
			a.track_elevated = scenario%4 == 0; b.track_elevated = a.track_elevated
			old_tyres.step(a,origins,wall,from,config,VehicleSimulation.STEP)
			LooseTyres.step(b,origins,wall,from,config,VehicleSimulation.STEP)
			old_props.step(a,objects,wall,from,VehicleSimulation.STEP,config.mass,config.collision_radius)
			LightProps.step(b,objects,wall,from,VehicleSimulation.STEP,config.mass,config.collision_radius)
			check(var_to_bytes(a.snapshot()) == var_to_bytes(b.snapshot()),"byte-exact tyre/prop state scenario %d tick %d" % [scenario,tick])
			if failures > 0: quit(1); return
			if tick == 30: saved = RewindHistory.properties(a)
			if tick == 60:
				RewindHistory.restore(a,saved); RewindHistory.restore(b,saved)
			if tick == 80:
				# In-place edits of canonical rows and descriptors must invalidate work.
				a.loose_tyres[0][0] += 0.03; b.loose_tyres[0][0] += 0.03
				objects[0].scale = 2.0
			if tick == 90:
				a.loose_tyres.append([20.0,20.0,0.0,0.0,0.0]); b.loose_tyres.append([20.0,20.0,0.0,0.0,0.0])
			a.tick += 1; b.tick += 1
	var state := VehicleState.new(); state.position = Vector2(-30,-30)
	var calls: Array[int] = [0]
	var clear: Callable = func(_p: Vector2,_r: float,_e: bool) -> Vector3: calls[0] += 1; return Vector3.ZERO
	LightProps.step(state,[{"kind":"cone","position":[10,10],"rotation":0}],clear,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(calls[0] == 0,"distant resting simple prop makes no world contact query")
	check(not RewindHistory.properties(state).has("light_prop_work"),"derived work is excluded from rewind properties")
	# Full canonical driving, all five cars/biomes, with the task-original prop
	# solvers substituted only on the reference track. Keep exact byte checks.
	for biome: String in TrackTheme.IDS:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = biome
		var track: NativeTrack = TrackCompiler.compile(doc)
		track.tyre_origins.clear(); track.hazard_objects.clear()
		for index: int in range(24):
			track.tyre_origins.append(track.spawn+Vector2((index%6)*1.05-2.6,4+(index/6)*1.05))
			var position: Vector2 = track.spawn+Vector2((index%8)*1.4-5,10+(index/8)*1.4)
			track.hazard_objects.append({"kind":CreatorCatalog.SOFT[index%CreatorCatalog.SOFT.size()],"position":[position.x,position.y],"rotation":0})
		var prior_track := ReferenceTrack.new()
		for property: Dictionary in track.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: prior_track.set(property.name,track.get(property.name))
		prior_track.original_tyres = old_tyres; prior_track.original_props = old_props
		for car: String in VehicleCatalog.IDS:
			var prior := VehicleSimulation.new(VehicleCatalog.config(car)); var current := VehicleSimulation.new(VehicleCatalog.config(car))
			prior.reset(track.spawn,0.0); current.reset(track.spawn,0.0)
			var saved: Dictionary = {}
			for tick: int in range(600):
				var frame := DriveFrame.new(); frame.throttle = 255 if tick%120 < 95 else 0; frame.brake = 128 if tick%120 >= 95 else 0; frame.steer = 24 if tick%180 < 90 else -24
				frame.handbrake = 255 if tick%160 > 145 else 0
				prior.step(frame,prior_track); current.step(frame,track)
				check(var_to_bytes(prior.state.snapshot()) == var_to_bytes(current.state.snapshot()),"full physics exact: %s/%s tick %d" % [biome,car,tick])
				if failures > 0: quit(1); return
				if tick == 250: saved = RewindHistory.properties(prior.state)
				if tick == 400: RewindHistory.restore(prior.state,saved); RewindHistory.restore(current.state,saved)
	print("DYNAMIC_PROP_WORK checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
