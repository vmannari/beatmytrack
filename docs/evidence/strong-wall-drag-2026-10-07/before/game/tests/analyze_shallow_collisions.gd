extends SceneTree
## Read-only physics diagnostic: calls shipping response; never changes tuning.

var checks: int = 0
var failures: int = 0

class ObservedWall extends NativeTrack:
	var impacts: Array[Dictionary] = []
	func _bounce(state: VehicleState, normal: Vector2, config: HandlingConfig) -> void:
		var before: Vector2 = state.velocity
		super._bounce(state,normal,config)
		impacts.append({"normal": [normal.x,normal.y],"inward_mps": -before.dot(normal),"before_mps": before.length(),"after_bounce_mps": state.velocity.length(),"position": [state.position.x,state.position.y]})

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool) -> void:
	checks += 1
	if not ok: failures += 1

func run() -> void:
	var report: Dictionary = {"physics": VehicleSimulation.PHYSICS_VERSION, "angle_convention": "degrees from wall tangent; velocity aligned with chassis", "single_contacts": [], "wall_traces": []}
	var response := PlaygroundData.new()
	for car: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(car)
		for speed: float in [10.0,20.0,30.0,40.0]:
			for angle: float in [0.1,0.5,1.0,2.0,3.0,5.0,10.0,30.0,90.0]:
				var state := VehicleState.new()
				state.heading = deg_to_rad(angle)
				state.velocity = state.forward()*speed
				var before: Vector2 = state.velocity
				response._bounce(state,Vector2.LEFT,config)
				var energy: float = config.mass*state.velocity.length_squared()+config.rotational_inertia*state.yaw_rate*state.yaw_rate
				check(energy <= config.mass*speed*speed+0.01)
				var mirror := VehicleState.new()
				mirror.heading = -deg_to_rad(angle)
				mirror.velocity = mirror.forward()*speed
				response._bounce(mirror,Vector2.RIGHT,config)
				check(is_equal_approx(mirror.velocity.x,-state.velocity.x) and is_equal_approx(mirror.yaw_rate,-state.yaw_rate))
				report.single_contacts.append({"car": car, "speed_kmh": speed*3.6, "angle_deg": angle, "inward_mps": before.x, "tangent_loss_percent": (1.0-state.velocity.y/maxf(before.y,0.000001))*100.0, "speed_loss_percent": (1.0-state.velocity.length()/speed)*100.0, "recoil_mps": -state.velocity.x, "yaw_deg_s": rad_to_deg(state.yaw_rate), "velocity_change_mps": state.velocity.distance_to(before)})
	for cell_size: float in [0.25,TrackCompiler.CELL_SIZE]:
		for wall_angle: float in [0.0,30.0,45.0]:
			var normal: Vector2 = Vector2.LEFT.rotated(deg_to_rad(wall_angle))
			var tangent := Vector2(normal.y,-normal.x)
			var wall: NativeTrack = make_wall(normal,cell_size)
			for angle: float in [0.5,1.0,2.0,3.0,5.0]:
				for powered: bool in [false,true]:
					var result: Dictionary = trace_wall(wall,normal,tangent,angle,powered)
					var repeat: Dictionary = trace_wall(wall,normal,tangent,angle,powered)
					check(result == repeat)
					result["wall_angle_deg"] = wall_angle
					result["cell_size_m"] = cell_size
					report.wall_traces.append(result)
	var folder: String = ProjectSettings.globalize_path("res://../build/shallow-collision-analysis")
	DirAccess.make_dir_recursive_absolute(folder)
	var output := FileAccess.open(folder+"/measurements.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	for row: Dictionary in report.single_contacts:
		if row.car == "compact" and row.speed_kmh == 108.0:
			print("CONTACT angle=%.1f inward=%.3f tangent_loss=%.2f%% speed_loss=%.2f%% recoil=%.3f yaw=%.2f impulse=%.3f" % [row.angle_deg,row.inward_mps,row.tangent_loss_percent,row.speed_loss_percent,row.recoil_mps,row.yaw_deg_s,row.velocity_change_mps])
	for row: Dictionary in report.wall_traces:
		print("WALL cell=%.2f rotation=%.0f angle=%.1f powered=%s contacts=%d speed=%.2f free_speed=%.2f progress=%.3f free_progress=%.3f max_hit_loss=%.2f%% min_normal_dot=%.3f" % [row.cell_size_m,row.wall_angle_deg,row.angle_deg,row.powered,row.contacts,row.final_speed_kmh,row.free_speed_kmh,row.progress_m,row.free_progress_m,row.max_contact_speed_loss_percent,row.min_normal_dot])
	print("SHALLOW_COLLISION_ANALYSIS: %d checks, %d failures; %s" % [checks,failures,folder+"/measurements.json"])
	quit(1 if failures else 0)

func make_wall(normal: Vector2, cell_size: float, offset: float = 0.0) -> NativeTrack:
	var wall := ObservedWall.new()
	wall.cell_size = cell_size
	wall.grid_width = roundi(80.0/cell_size)
	wall.grid_height = wall.grid_width
	wall.half_extent = Vector2(40,40)
	wall.cells.resize(wall.grid_width*wall.grid_height)
	wall.deck_cells.resize(wall.cells.size())
	wall.deck_cells.fill(-1)
	wall.route = PackedVector2Array([Vector2(-20,-20),Vector2(-20,20)])
	wall._build_route_distance()
	for y: int in range(wall.grid_height):
		for x: int in range(wall.grid_width):
			var center := Vector2((x+0.5)*cell_size-40.0,40.0-(y+0.5)*cell_size)
			if center.dot(normal) < offset: wall.cells[y*wall.grid_width+x] = 4
	return wall

func trace_wall(wall: NativeTrack, normal: Vector2, tangent: Vector2, angle: float, powered: bool, vehicle: String = "compact", speed: float = 30.0, ticks: int = 120) -> Dictionary:
	var config: HandlingConfig = VehicleCatalog.config(vehicle)
	var lo: float = 0.0
	var hi: float = 3.0
	for i: int in range(24):
		var mid: float = (lo+hi)*0.5
		if wall._contact(normal*mid,config.collision_radius,false).z > 0.0: lo = mid
		else: hi = mid
	var start: Vector2 = normal*(hi+0.002)
	var velocity: Vector2 = (tangent*cos(deg_to_rad(angle))-normal*sin(deg_to_rad(angle)))*speed
	var sim := VehicleSimulation.new(config)
	var free := VehicleSimulation.new(config)
	sim.reset(start,atan2(velocity.x,velocity.y))
	free.reset(start,sim.state.heading)
	sim.state.velocity = velocity
	free.state.velocity = velocity
	var frame := DriveFrame.new()
	frame.throttle = 255 if powered else 0
	var max_loss: float = 0.0
	var min_dot: float = 1.0
	var peak_impulse: float = 0.0
	var minimum_travel_fraction: float = 1.0
	var events: Array[Dictionary] = []
	(wall as ObservedWall).impacts.clear()
	for tick: int in range(ticks):
		var count: int = sim.state.collision_count
		var old: Vector2 = sim.state.velocity
		var previous_position: Vector2 = sim.state.position
		sim.step(frame,wall)
		free.step(frame)
		check(is_finite(sim.state.velocity.x) and is_finite(sim.state.position.y))
		# A steady drag increase may lower final speed. Detect a snag by lost
		# movement on an individual tick instead of a tuning-dependent speed floor.
		var expected_travel: float = old.dot(tangent)*VehicleSimulation.STEP
		if expected_travel > 0.01:
			minimum_travel_fraction = minf(minimum_travel_fraction,(sim.state.position-previous_position).dot(tangent)/expected_travel)
		if sim.state.velocity.length() < old.length()*0.8 or ((wall as ObservedWall).impacts.size() > 0 and events.size() < 8):
			events.append({"tick": tick,"before_mps": old.length(),"after_resolve_mps": sim.state.velocity.length(),"position": [sim.state.position.x,sim.state.position.y],"bounce_calls": (wall as ObservedWall).impacts.duplicate(true)})
		(wall as ObservedWall).impacts.clear()
		if sim.state.collision_count > count:
			max_loss = maxf(max_loss,(1.0-sim.state.velocity.length()/maxf(old.length(),0.000001))*100.0)
			peak_impulse = maxf(peak_impulse,sim.state.velocity.distance_to(old))
			# Face-normal diagnostic at a 2 cm inward probe of resolved position;
			# this is not an exact record of the normal used by resolve().
			var contact: Vector3 = wall._contact(sim.state.position-normal*0.02,config.collision_radius,false)
			var contact_normal := Vector2(contact.x,contact.y)
			if contact_normal != Vector2.ZERO: min_dot = minf(min_dot,contact_normal.dot(normal))
	return {"angle_deg": angle,"powered": powered,"contacts": sim.state.collision_count,"final_speed_kmh": sim.state.velocity.length()*3.6,"free_speed_kmh": free.state.velocity.length()*3.6,"progress_m": (sim.state.position-start).dot(tangent),"free_progress_m": (free.state.position-start).dot(tangent),"max_contact_speed_loss_percent": max_loss,"peak_velocity_change_mps": peak_impulse,"min_normal_dot": min_dot,"minimum_travel_fraction": minimum_travel_fraction,"final_heading_change_deg": rad_to_deg(angle_difference(atan2(velocity.x,velocity.y),sim.state.heading)),"events": events}
