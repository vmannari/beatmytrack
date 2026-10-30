extends "res://tests/analyze_shallow_collisions.gd"
var body_checks: int = 0
var body_failures: int = 0
class ObservedAudio extends "res://tests/fixtures/bridge_audio_before/vehicle_audio.gd":
	var simulation: VehicleSimulation
	var emitted: Array[Dictionary] = []
	var bypass_surface: bool = false
	func _observe_surfaces(state: VehicleState, track: NativeTrack, incoming: Vector2, previous: Vector2, heading: float) -> void:
		if not bypass_surface: super._observe_surfaces(state,track,incoming,previous,heading)
	func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
		emitted.append({"tick":simulation.state.tick,"clip":clip,"pitch":pitch,"amplitude":amplitude,
			"physical_impulse":simulation.state.collision_impulse.length(),"visible_touching":visible_contact.touching,
			"visible_normal":[visible_contact.normal.x,visible_contact.normal.y]})
		super._event(clip,amplitude,pitch,debris)

func expect(ok: bool, message: String) -> void:
	body_checks += 1
	if not ok:
		body_failures += 1
		print("FAIL: "+message)

func run() -> void:
	var game: Node = load("res://core/game.tscn").instantiate()
	game.vehicle_id = "compact"
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.production_mode = false
	var wall: NativeTrack = make_wall(Vector2(0,-1),.5)
	game.native_track = wall
	game.yard = wall
	game.vehicle_audio.free()
	var audio := ObservedAudio.new()
	audio.bypass_surface = OS.get_cmdline_user_args().has("--without-surface-observer")
	game.add_child(audio)
	audio.configure("compact",game.handling,game.car)
	print("CONTACT_OUTLINE: ",JSON.stringify({"points":audio.visible_contact.outline.size(),
		"meshes":game.car.find_children("*","MeshInstance3D",true,false).size(),
		"multimeshes":game.car.find_children("*","MultiMeshInstance3D",true,false).size()}))
	audio.simulation = game.sim
	game.vehicle_audio = audio
	var front: float = 0.0
	for point: Vector2 in audio.visible_contact.outline: front = maxf(front,point.y)
	# A 45-degree direct impact has substantial inward velocity and is not a
	# shallow wall scrape. Its remaining forward travel drives a normal downshift.
	var heading: float = PI*.25
	game.sim.reset(Vector2(0,-front-3),heading)
	game.sim.state.velocity = Vector2(sin(heading),cos(heading))*30
	game.previous_heading = heading
	game.previous_position = game.sim.state.position
	# Warm the real presentation drivetrain at driving speed, then take a direct
	# head-on collision through the unchanged actual Game physics callback.
	for warm: int in range(144): game._process(VehicleSimulation.STEP)
	expect(audio.model.gear>1,"drivetrain is in a normal driving gear before the direct hit")
	audio.emitted.clear()
	var physical: int = -1
	for tick: int in range(100):
		game._physics_process(VehicleSimulation.STEP)
		if physical<0 and game.sim.state.collision_impulse!=Vector2.ZERO: physical = game.sim.state.tick
		game._process(VehicleSimulation.STEP)
		if physical>0 and game.sim.state.tick>physical+48: break
	var hits: Array[Dictionary] = []
	var shifts: Array[Dictionary] = []
	for event: Dictionary in audio.emitted:
		if event.clip in VehicleAudio.IMPACTS: hits.append(event)
		if event.clip=="chassis" and is_equal_approx(float(event.pitch),1.32) and int(event.tick)>=physical: shifts.append(event)
	expect(physical>0 and hits.size()==1,"direct hard collision produces one primary hit")
	expect(not shifts.is_empty(),"actual impact deceleration produces the accompanying chassis/gear thud")
	expect("chassis" in VehicleAudio.BODY_CLIPS,"the accompanying thud now uses the shared fast body route")
	expect(audio.events.size()==4 and audio.debris_events.size()==2,"shared body routing preserves the existing voice budget")
	print("DIRECT_HIT_BODY_EVENTS: ",JSON.stringify({"physical_tick":physical,"impact":hits,"chassis_after_hit":shifts}))
	game.free()
	await create_timer(.2).timeout
	print("DIRECT_HIT_BODY_AUDIO: %d checks, %d failures"%[body_checks,body_failures])
	quit(1 if body_failures>0 else 0)
