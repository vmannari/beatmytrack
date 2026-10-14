extends SceneTree
## Real canonical contacts, replay/rewind, bounded debris and shared rendering.
var checks: int = 0
var failures: int = 0
var config: HandlingConfig
var CLEAR: Callable = _clear

static func _clear(_p: Vector2, _radius: float, _deck: bool) -> Vector3: return Vector3.ZERO
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func object(kind: String, scale: float = 1.0) -> Dictionary:
	return {"kind":kind,"position":[0,0],"rotation":25,"scale":scale}

func step(state: VehicleState, objects: Array, from: Vector2) -> void:
	LightProps.step(state,objects,CLEAR,from,VehicleSimulation.STEP,config.mass,config.collision_radius)
	state.tick += 1

func impact(state: VehicleState, objects: Array, speed: float) -> void:
	var p: Vector2 = Vector2.ZERO if state.light_props.is_empty() else Vector2(state.light_props[0][0],state.light_props[0][1])
	state.position = p-Vector2(0.25,0); state.velocity = Vector2(speed,0); state.heading = PI*0.5
	step(state,objects,p-Vector2(0.65,0))

func separate(state: VehicleState, objects: Array) -> void:
	state.position = Vector2(100,100); state.velocity = Vector2.ZERO
	# Let the outgoing object settle before striking it again. A car following
	# an already moving crate at equal speed is not another heavy impact.
	for tick: int in range(400): step(state,objects,state.position)

func run() -> void:
	config = VehicleCatalog.config("compact")
	for biome: String in TrackTheme.IDS:
		check(not CreatorCatalog.filtered("Props","Hay bale",[],biome).is_empty(),"hay available in "+biome)
	var doc: Dictionary = TrackDocument.create_default(); doc["automatic_scenery"] = false
	doc.objects = [object("hay_bale"),object("crate")]
	check(TrackDocument.validate(doc).is_empty(),"both bounded object documents validate")
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null and track.cell_at(Vector2.ZERO) != 4,"movable breakables never become baked walls")
	var hay := VehicleState.new(); var hay_objects: Array = [object("hay_bale")]
	impact(hay,hay_objects,10)
	check(float(hay.prop_destruction[0][0]) < 1.0 and hay.prop_fragments.size() == 2,"first hay impact sheds visible loose hay")
	var initial_fraction: float = hay.prop_destruction[0][0]
	var initial_hits: int = hay.prop_destruction[0][2]
	# Stay in contact; high relative speed alone cannot count as multiple crashes.
	impact(hay,hay_objects,10)
	check(hay.prop_destruction[0][0] == initial_fraction and hay.prop_destruction[0][2] == initial_hits,"sustained contact is latched")
	separate(hay,hay_objects); impact(hay,hay_objects,10)
	check(float(hay.prop_destruction[0][0]) < initial_fraction,"separate later impact progressively deforms the bale")
	for fraction: float in [1.0,0.5,0.15]:
		check(BreakableProps.mass("hay_bale",1,fraction) == BreakableProps.HAY_MASS*fraction,"remaining hay controls actual mass")
	var full := VehicleState.new(); var small := VehicleState.new()
	step(small,hay_objects,Vector2(100,100)); small.prop_destruction[0][0] = 0.15
	impact(full,hay_objects,8); impact(small,hay_objects,8)
	check(small.velocity.x > full.velocity.x and float(small.light_props[0][2]) > float(full.light_props[0][2]),"smaller bale causes less car speed loss and is pushed faster")
	for hit: int in range(8): separate(hay,hay_objects); impact(hay,hay_objects,22)
	check(hay.prop_destruction[0][0] == 0.0,"repeated strong hits completely disperse the hay core")
	var before: Array = hay.snapshot().slice(0,23)
	hay.position = Vector2.ZERO; hay.velocity = Vector2(10,1)
	before = hay.snapshot().slice(0,23)
	BreakableProps.step_fragments(hay,CLEAR,Vector2(-1,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(hay.snapshot().slice(0,23) == before,"all loose hay has zero car/collision/grip/contamination effect")
	var crate := VehicleState.new(); var crates: Array = [object("crate")]
	impact(crate,crates,2)
	check(crate.prop_destruction[0][0] == 1.0 and float(crate.light_props[0][2]) > 0,"light contact moves an intact crate without damaging it")
	var reverse := VehicleState.new(); reverse.heading = PI*0.5; reverse.velocity = Vector2(-2,0)
	step(reverse,crates,Vector2.ZERO)
	check(float(reverse.light_props[0][2]) < 0 and reverse.prop_destruction[0][0] == 1.0,"centred reverse contact pushes the crate in the actual travel direction")
	for hit: int in range(6): separate(crate,crates); impact(crate,crates,2)
	check(crate.prop_destruction[0][0] == 1.0 and crate.prop_fragments.is_empty(),"repeated gentle contacts do not eventually destroy crates")
	separate(crate,crates); impact(crate,crates,12)
	check(float(crate.prop_destruction[0][0]) > 0 and float(crate.prop_destruction[0][0]) < 1,"first heavy crash visibly damages crate")
	separate(crate,crates); impact(crate,crates,12)
	check(crate.prop_destruction[0][0] == 0.0 and crate.prop_fragments.size() == BreakableProps.WOOD_PIECES,"repeated heavy crashes break crate into six persistent planks")
	var fragment_count: int = crate.prop_fragments.size()
	separate(crate,crates); impact(crate,crates,24)
	check(crate.prop_fragments.size() == fragment_count,"broken crates cannot produce duplicate wood")
	var wood := VehicleState.new(); wood.position = Vector2(-0.60,0); wood.velocity = Vector2(10,0); wood.heading = PI*0.5
	wood.prop_fragments = [[BreakableProps.WOOD,0,0.0,0.0,0.0,0.0,0.0,0.0,0.8,0.13,3.6,1.0]]
	BreakableProps.step_fragments(wood,CLEAR,Vector2(-0.95,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(wood.velocity.x < 10 and wood.velocity.x > 9.96 and float(wood.prop_fragments[0][4]) > 0,"loose wood gives a small dissipative bump and is movable")
	var glancing := VehicleState.new(); glancing.position = Vector2(-0.43,-0.13); glancing.velocity = Vector2(10,2); glancing.heading = PI*0.5
	glancing.prop_fragments = [[BreakableProps.WOOD,0,0.0,0.0,0.0,0.0,0.0,0.0,0.8,0.13,3.6,1.0]]
	BreakableProps.step_fragments(glancing,CLEAR,Vector2(-0.80,-0.2),VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(glancing.yaw_rate != 0 and glancing.velocity.length() < Vector2(10,2).length(),"off-centre wood contact slightly deflects the car without a speed boost")
	for elevated: bool in [false,true]:
		var airborne := VehicleState.new(); airborne.track_elevated = elevated; airborne.jump_height = 0 if elevated else 1
		impact(airborne,crates,24)
		check(airborne.prop_destruction[0][0] == 1.0,"ground crate does not damage under bridge/airborne car")
	# Exact canonical rewind restores loose fragments and contact latches too.
	var saved: Dictionary = RewindHistory.properties(crate)
	var saved_snapshot: Array = crate.snapshot()
	for tick: int in range(40): step(crate,crates,crate.position)
	var final: Array = crate.snapshot()
	RewindHistory.restore(crate,saved)
	check(crate.snapshot() == saved_snapshot,"rewind restores exact damage, fragments and contact state")
	for tick: int in range(40): step(crate,crates,crate.position)
	check(crate.snapshot() == final,"restored destruction branch reproduces exact later fragment state")
	var sim := VehicleSimulation.new(config); sim.state = crate; sim.reset(Vector2.ZERO)
	check(sim.state.prop_destruction.is_empty() and sim.state.prop_fragments.is_empty() and sim.state.light_props.is_empty(),"new attempt restores intact props and removes loose material")
	for car: String in VehicleCatalog.IDS: await replay_drive(car)
	var visual := NativeTrackVisual.new(); root.add_child(visual); visual._build_placed_objects(track)
	var snapshot: Array = hay.snapshot(); visual.update_light_props(hay)
	check(not visual.light_instances[0].visible and hay.snapshot() == snapshot,"dispersed bale is invisible and presentation cannot change physics")
	visual.update_light_props(VehicleState.new())
	check(visual.light_instances[0].visible and visual.light_instances[1].visible,"new attempt immediately restores intact visible objects before first simulation tick")
	# Earlier state with valid light rows restores intact prepared meshes.
	var intact := VehicleState.new(); intact.light_props = [[0,0,0,0,0],[0,0,0,0,0]]; intact.prop_destruction = [[1,false,0],[1,false,0]]
	visual.update_light_props(intact)
	check(visual.light_instances[0].visible and visual.light_instances[1].visible,"intact snapshot restores both previously damaged visual cores")
	visual.queue_free(); await process_frame
	var dense: Array = []
	for i: int in range(96): dense.append({"kind":"crate","position":[-33+(i%12)*6,-21+(i/12)*6],"rotation":0})
	var maximum := VehicleState.new(); maximum.position = Vector2(100,100)
	step(maximum,dense,maximum.position)
	for i: int in range(dense.size()):
		var p := Vector2(maximum.light_props[i][0],maximum.light_props[i][1])
		maximum.position = p-Vector2(0.25,0); maximum.velocity = Vector2(24,0)
		BreakableProps.step_one(maximum,dense,i,CLEAR,maximum.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(maximum.prop_fragments.size() == 576,"maximum 96 authored crates have a bounded six-piece expansion")
	for i: int in range(80): BreakableProps._shed_hay(maximum,0,Vector2.ZERO,Vector2.ZERO,Vector2.RIGHT,1,0.1,i)
	check(maximum.prop_fragments.size() == 704,"cosmetic hay cap retains every physical wood fragment")
	var wood_count: int = 0
	for row: Array in maximum.prop_fragments:
		if int(row[0]) == BreakableProps.WOOD: wood_count += 1
	check(wood_count == 576,"hay replacement never discards driving-affecting debris")
	maximum.position = Vector2(100,100); maximum.velocity = Vector2.ZERO
	var start: int = Time.get_ticks_usec()
	for tick: int in range(240): step(maximum,dense,maximum.position)
	print("BREAKABLE_STRESS_MS: ",(Time.get_ticks_usec()-start)/1000.0," total for 240 canonical steps / 704 fragments; desktop only")
	check(maximum.prop_fragments.size() == 704,"settled material persists through later race ticks")
	print("BREAKABLE_PROPS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func replay_drive(car: String) -> void:
	var document: Dictionary = TrackDocument.create_default(); document["automatic_scenery"] = false
	document.paint = [{"surface":0,"width":30.0,"shape":"square","points":[[-20,0],[20,0]]}]
	document.objects = [{"kind":"hay_bale","position":[-3,0],"rotation":0},{"kind":"crate","position":[3,0],"rotation":0}]
	var track: NativeTrack = TrackCompiler.compile(document)
	var first := VehicleSimulation.new(VehicleCatalog.config(car)); first.reset(Vector2(-14,0),PI*0.5)
	var second := VehicleSimulation.new(VehicleCatalog.config(car)); second.reset(Vector2(-14,0),PI*0.5)
	var frames: Array = []
	for tick: int in range(480):
		var frame := DriveFrame.new(); frame.throttle = 255
		frames.append(frame.packed()); first.step(frame,track)
	var decoded: Array = JSON.parse_string(JSON.stringify(frames))
	for values: Array in decoded:
		var frame := DriveFrame.new(); frame.steer = values[0]; frame.throttle = values[1]; frame.brake = values[2]; frame.handbrake = values[3] if values.size() > 3 else 0
		second.step(frame,track)
	check(first.state.snapshot() == second.state.snapshot(),car+" full approach input JSON replay exactly reproduces destruction/debris")
	check(not first.state.prop_fragments.is_empty(),car+" actual driven approach sheds hay or breaks wood")
