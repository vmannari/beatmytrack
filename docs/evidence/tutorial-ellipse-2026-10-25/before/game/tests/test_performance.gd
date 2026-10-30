extends SceneTree
## Regression checks for retained HUD drawing and bounded collision damage.
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var cracks := ImpactCracks.new()
	root.add_child(cracks)
	for i: int in range(100): cracks.show_impact(Vector2(20,0))
	check(cracks.side_damage == Vector4.ONE,"saturated collision damage terminates and stays bounded")
	cracks.clear_effect()
	check(cracks.side_damage == Vector4.ZERO and not cracks.visible,"restart clears saturated glass")
	cracks.free()
	var panel := PanelContainer.new()
	panel.size = Vector2(200,140)
	var instrument := HUDFrame.attach(panel,"speed")
	root.add_child(panel)
	for i: int in range(4): await process_frame
	var initial: int = instrument.draw_count
	var tick_draws: Dictionary = {"count":0}
	instrument.speed_ticks.draw.connect(func() -> void: tick_draws.count += 1)
	for i: int in range(90):
		instrument.speed_fraction = (i%61)/60.0
		await process_frame
	check(instrument.draw_count == initial,"changing speed retains the static backing and arcs")
	check(tick_draws.count > 60,"speed ticks still redraw as the displayed speed changes")
	panel.size = Vector2(240,160)
	for i: int in range(4): await process_frame
	check(instrument.draw_count > initial,"resizing rebuilds the instrument geometry")
	panel.free()
	var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var state := VehicleState.new()
	state.position = track.spawn
	state.velocity = Vector2(8,30)
	state.route_index = track.nearest_route(state.position)
	var frame := DriveFrame.new()
	var dust := SandDust.new()
	root.add_child(dust)
	var particle: GPUParticles3D = dust.smoke_emitters[0]
	dust._configure(particle,Vector3(2,0,3),Vector2(0,20),0.4)
	check(particle.emitting and is_equal_approx(particle.amount_ratio,0.4),"active wheel retains emission strength")
	dust._configure(particle,Vector3(4,0,5),Vector2(0,20),-1.0)
	check(not particle.emitting and particle.amount_ratio == 0.0,"surface change stops new particles")
	var stopped: Transform3D = particle.transform
	for i: int in range(100): dust._configure(particle,Vector3(i,0,0),Vector2(1,20),-1.0)
	check(particle.transform == stopped,"inactive emitters avoid transform uploads")
	dust._configure(particle,Vector3(4,0,5),Vector2(0,20),0.4)
	check(particle.emitting and particle.position == Vector3(4,0,5),"reactivation moves emission to the current contact")
	# Optional session-local before source: never required by regression checks.
	var baseline: String = "res://../build/performance-2026-09-21/dust-before.gd"
	if FileAccess.file_exists(baseline):
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(baseline).replace("\r\n","\n").replace("class_name SandDust\n","")
		check(script.reload() == OK,"baseline effect compiles")
		if failures: quit(1); return
		var before: Node3D = script.new()
		root.add_child(before)
		for effect: Node3D in [before,dust]:
			var times: Array[int] = []
			for repeat: int in range(5):
				var begin: int = Time.get_ticks_usec()
				for i: int in range(2000): effect.sample(state,frame,track)
				times.append(Time.get_ticks_usec()-begin)
			times.sort()
			print("PARTICLE_SAMPLE_US ","before" if effect == before else "after"," median=",times[2]/2000.0)
		before.free()
	dust.free()
	var trail_baseline: String = "res://../build/performance-2026-09-21/trails-before.gd"
	if FileAccess.file_exists(trail_baseline):
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(trail_baseline).replace("\r\n","\n").replace("class_name SkidTrails\n","")
		check(script.reload() == OK,"baseline trails compile")
		if failures: quit(1); return
		var before: Node3D = script.new()
		var after := SkidTrails.new()
		root.add_child(before)
		root.add_child(after)
		var bridge := BridgePresentation.new(track)
		frame.brake = 255
		for effect: Node3D in [before,after]:
			var times: Array[int] = []
			for repeat: int in range(5):
				effect.clear()
				var begin: int = Time.get_ticks_usec()
				for i: int in range(2000):
					state.position = track.spawn+Vector2(sin(i*0.01)*3,i*0.04)
					state.route_index = track.nearest_route(state.position,state.route_index)
					effect.sample(state,frame,bridge,track)
				times.append(Time.get_ticks_usec()-begin)
			times.sort()
			print("TRAIL_SAMPLE_US ","before" if effect == before else "after"," median=",times[2]/2000.0)
		check(before.cursor == after.cursor,"early distance rejection preserves mark count")
		check(before.mark_colors == after.mark_colors and before.mark_custom == after.mark_custom and before.mark_transforms == after.mark_transforms,"early distance rejection preserves every mark exactly")
		before.free()
		after.free()
	var haptics = preload("res://platform/steering_haptics.gd")
	var gate := Semaphore.new()
	haptics._submit(func() -> void: gate.wait())
	var pending: int = haptics.pending_task
	check(not WorkerThreadPool.is_task_completed(pending),"slow haptic service does not block caller")
	haptics._submit(func() -> void: pass)
	check(haptics.pending_task == pending,"busy haptic worker drops extra pulses without queue growth")
	gate.post()
	while not WorkerThreadPool.is_task_completed(pending): await process_frame
	haptics._submit(func() -> void: pass)
	check(haptics.pending_task != pending,"completed task is reaped before accepting a fresh pulse")
	WorkerThreadPool.wait_for_task_completion(haptics.pending_task)
	haptics.pending_task = -1
	print("PERFORMANCE_TESTS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
