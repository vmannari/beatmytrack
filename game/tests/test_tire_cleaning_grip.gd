extends SceneTree
## Owner's grass-to-road cleaning and traction behavior, with exact replay.
const OUTPUT: String = "res://../docs/evidence/tire-cleaning-grip-2026-10-14"
var checks: int = 0
var failures: int = 0
var previous: GDScript
var metrics: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func field(kind: int) -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.cells.fill(kind)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	return track

func run() -> void:
	previous = GDScript.new()
	previous.source_code = FileAccess.get_file_as_string(OUTPUT+"/before/vehicle_simulation.gd.txt").replace("\r\n","\n").replace("class_name VehicleSimulation\n","")
	check(previous.reload() == OK,"saved .58 canonical simulation loads")
	var road: NativeTrack = field(0)
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		behavior(config,road)
		cleaning(config,road)
		for kind: int in [0,1,2]:
			var ground: NativeTrack = field(kind)
			var current := VehicleSimulation.new(config)
			var old: RefCounted = previous.new(config)
			current.state.velocity = Vector2(0,20)
			old.state.velocity = current.state.velocity
			var exact: bool = true
			for tick: int in range(600):
				var frame: DriveFrame = DriveFrame.sample(sin(tick*0.031)*0.35,0.6,0)
				current.step(frame,ground)
				old.step(frame,ground)
				exact = exact and current.state.snapshot() == old.state.snapshot()
			check(exact,id+" retains clean road and original loose-ground snapshots, kind "+str(kind))
	var trails := SkidTrails.new()
	root.add_child(trails)
	for kind: int in [0,9]:
		for pressure: float in [0.3,1.0]:
			var last: float = INF
			for coating: float in [1.0,0.75,0.5,0.25,0.025,0.01,0.0001]:
				var style: Vector4 = trails._surface_style(kind,coating,pressure)
				check(style.w < last,"road mud continuously fades through the old colour cutoff under rolling/braking")
				last = style.w
			check(last < 0.0001,"road mud approaches zero opacity at clean contact")
		trails.clear()
		trails._mark(Vector3.ZERO,Vector3(0,0,0.4),1.0,kind,0.8,0)
		var deposited: Color = trails.mark_colors[0]
		var pose: Transform3D = trails.mark_transforms[0]
		trails._mark(Vector3(0,0,0.4),Vector3(0,0,0.8),0.5,kind,0.8,0)
		check(trails.mark_colors[0] == deposited and trails.mark_transforms[0] == pose,"cleaning changes fresh deposits and retains the existing race trail")
		check(trails.mark_colors[1].a < deposited.a,"new deposits get lighter as the tires clean")
		check(trails.mark_custom[0].b < 0.5 and trails.mark_custom[0].b > 0.0,"road mud retains hard-surface shading inside the original custom format")
	trails.clear()
	var state := VehicleState.new()
	state.velocity = Vector2(0,16)
	for i: int in range(60):
		state.position.y = i*0.4
		trails.sample(state,DriveFrame.new(),null,road)
	check(trails.cursor == 0,"clean straight rolling leaves no fresh road tracks")
	check(trails.instances.instance_count == 16384 and trails.instances.mesh.surface_get_array_len(0) == 4 and trails.instances.mesh.surface_get_array_index_len(0) == 6,"original bounded two-triangle ribbon ring is retained")
	trails.free()
	var output := FileAccess.open(OUTPUT+"/measurements.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics,"\t"))
	print("TIRE_CLEANING_GRIP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func behavior(config: HandlingConfig, road: NativeTrack) -> void:
	for coating: float in [0.125,0.5,1.0]:
		var current := VehicleSimulation.new(config)
		var old: RefCounted = previous.new(config)
		current.state.velocity = Vector2(7,24)
		current.state.tire_dirt = coating
		old.state.velocity = current.state.velocity
		old.state.tire_dirt = coating
		current.step(DriveFrame.new(),road)
		old.step(DriveFrame.new(),road)
		var current_scrub: float = 7.0-current.state.velocity.x
		var old_scrub: float = 7.0-old.state.velocity.x
		check(current_scrub < old_scrub*0.9,config.vehicle_id+" dirty tires lose visibly more lateral traction after short/full exposure")
		# Isolate tire-limited braking; several original profiles' brake forces
		# are below either traction budget and therefore do not saturate it.
		var braking: HandlingConfig = config.duplicate() as HandlingConfig
		braking.braking_force = config.longitudinal_grip*config.mass*1.5
		var dirty := VehicleSimulation.new(braking)
		var old_brake: RefCounted = previous.new(braking)
		dirty.state.velocity = Vector2(0,24)
		dirty.state.tire_dirt = coating
		old_brake.state.velocity = dirty.state.velocity
		old_brake.state.tire_dirt = coating
		dirty.step(DriveFrame.sample(0,0,1),road)
		old_brake.step(DriveFrame.sample(0,0,1),road)
		check(dirty.state.velocity.y > old_brake.state.velocity.y,config.vehicle_id+" dirty tires reduce braking traction more")
		metrics.append({"car":config.vehicle_id,"dirt":coating,"old_road_grip":1.0-coating*config.dirty_tire_grip_loss,"road_grip":1.0-VehicleSimulation.dirt_grip_loss(coating,config.dirty_tire_grip_loss),"lateral_scrub_ratio":current_scrub/old_scrub})
	var dirty := VehicleSimulation.new(config)
	dirty.state.tire_dirt = 1.0
	for tick: int in range(240): dirty.step(DriveFrame.sample(0,1,0),road)
	check(dirty.state.position.y > 10.0,config.vehicle_id+" fully dirty tires retain powered escape from rest")
	var stationary := VehicleSimulation.new(config)
	stationary.state.tire_dirt = 0.5
	for tick: int in range(240): stationary.step(DriveFrame.new(),road)
	check(stationary.state.tire_dirt == 0.5,"waiting does not clean dirt or grant grip")

func cleaning(config: HandlingConfig, road: NativeTrack) -> void:
	for direction: float in [-1.0,1.0]:
		var current := VehicleSimulation.new(config)
		var replay := VehicleSimulation.new(config)
		current.state.tire_dirt = 1.0
		replay.state.tire_dirt = 1.0
		var distance: float = 0.0
		var last_grip: float = 0.0
		var exact: bool = true
		for tick: int in range(3000):
			current.state.velocity = Vector2(0,16*direction)
			replay.state.velocity = current.state.velocity
			var before: Vector2 = current.state.position
			current.step(DriveFrame.new(),road)
			replay.step(DriveFrame.new(),road)
			distance += current.state.position.distance_to(before)
			var grip: float = 1.0-VehicleSimulation.dirt_grip_loss(current.state.tire_dirt,config.dirty_tire_grip_loss)
			exact = exact and current.state.snapshot() == replay.state.snapshot() and grip >= last_grip
			last_grip = grip
			if tick == 43: RewindHistory.restore(replay.state,RewindHistory.properties(current.state))
			if current.state.tire_dirt == 0.0: break
		check(exact,config.vehicle_id+" recovers grip monotonically with exact replay/rewind in forward/reverse")
		check(absf(distance-config.tire_clean_distance)<0.2 and last_grip==1.0,config.vehicle_id+" retains its configured cleaning distance and restores full grip")
