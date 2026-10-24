extends SceneTree
## Read-only contact diagnosis on a supplied current-format bridge document.
var output: String = "res://../build/compact-bridge-impact-2026-10-23/matrix"
var document_path: String = "res://../docs/evidence/compact-bridge-impact-2026-10-23/knot.json"
var baseline: bool = false

func _initialize() -> void: run.call_deferred()

func full_outline(audio: VehicleAudio, state: VehicleState, track: NativeTrack, incoming: Vector2) -> Dictionary:
	var found: bool = false
	var eligible: bool = false
	var span: int = CreatorBridges.span_at(track.creator_bridges,state.position) if state.track_elevated else -1
	var outline: PackedVector2Array = audio.visible_contact.outline
	for index: int in range(outline.size()-1):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[index+1]
		var steps: int = maxi(1,ceili(a.distance_to(b)/.05))
		for step: int in range(steps+1):
			var local: Vector2 = a.lerp(b,float(step)/steps)
			var point: Vector2 = state.position+state.right()*local.x+state.forward()*local.y
			if not audio.visible_contact._solid_at(state,track,point,span): continue
			found = true
			var x: int = floori((point.x+track.half_extent.x)/track.cell_size)
			var y: int = floori((track.half_extent.y-point.y)/track.cell_size)
			var center := Vector2((x+.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+.5)*track.cell_size)
			for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if audio.visible_contact._solid_at(state,track,center+direction*track.cell_size,span): continue
				var inward: float = -incoming.dot(direction)
				if inward>1.2 and inward/maxf(incoming.length(),.001)>.35: eligible = true
	return {"touch":found,"eligible":eligible}

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="): document_path = argument.trim_prefix("--document=")
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
		if argument=="--baseline": baseline = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(document_path))
	var track: NativeTrack = TrackCompiler.compile(document)
	assert(track!=null and not track.creator_bridges.is_empty())
	var car := CarVisual.new()
	car.vehicle_id = "compact"
	root.add_child(car)
	var audio := VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	audio.configure("compact",config,car)
	if baseline:
		var original: String = FileAccess.get_file_as_string("res://../docs/evidence/compact-bridge-impact-2026-10-23/before/game/vehicle/visible_contact_audio.gd")
		var method: String = original.substr(original.find("func sample("))
		method = method.substr(0,method.find("func _solid_at("))
		var script := GDScript.new()
		script.source_code = "extends VisibleContactAudio\n\n"+method
		assert(script.reload()==OK,"The exact original sample method must compile as the baseline control.")
		audio.visible_contact = script.new()
		audio.visible_contact.configure(car,true)
	var front: float = 0.0
	var probes: int = 0
	for i: int in range(audio.visible_contact.outline.size()-1):
		front = maxf(front,audio.visible_contact.outline[i].y)
		probes += maxi(1,ceili(audio.visible_contact.outline[i].distance_to(audio.visible_contact.outline[i+1])/maxf(.10,track.cell_size*.5)))+1
	var rows: Array[Dictionary] = []
	for span_index: int in range(track.creator_bridges.size()):
		var bridge: Dictionary = track.creator_bridges[span_index]
		var origin := Vector2(bridge.position[0],bridge.position[1])
		var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(bridge.heading)))
		var normal: Vector2 = axis.orthogonal()
		var length: float = bridge.length
		var cases: Array[Dictionary] = []
		for side: float in [-1.0,1.0]:
			for u: float in [3.0,length-3.0]:
				cases.append({"kind":"low_side","start":origin+axis*u+normal*side*(float(bridge.width)*.5+CreatorBridges.RAIL+front+.3),"direction":-normal*side,"upper":false,"side":side,"u":u})
			cases.append({"kind":"upper_rail","start":origin+axis*length*.5,"direction":normal*side,"upper":true,"side":side,"u":length*.5})
			cases.append({"kind":"underside","start":origin+axis*(10.0 if side<0 else length-10.0),"direction":axis*side,"upper":false,"side":side,"u":10.0 if side<0 else length-10.0})
			for reverse: bool in [false,true]:
				for offset: float in [-.8,-.3,.2,.65,1.0]:
					cases.append({"kind":"rail_end","start":origin+axis*(length+front+.7 if reverse else -front-.7)+normal*side*(float(bridge.width)*.5+offset),"direction":axis*(-1.0 if reverse else 1.0),"upper":false,"side":side,"u":length if reverse else 0.0})
		for test: Dictionary in cases:
			for speed: float in [5.0,15.0,30.0]:
				var direction: Vector2 = test.direction
				var sim := VehicleSimulation.new(config)
				var plain := VehicleSimulation.new(config)
				sim.reset(test.start,atan2(direction.x,direction.y))
				plain.reset(sim.state.position,sim.state.heading)
				sim.state.track_elevated = test.upper
				plain.state.track_elevated = test.upper
				sim.state.velocity = direction*speed
				plain.state.velocity = sim.state.velocity
				audio.reset()
				var row: Dictionary = {"span":span_index,"kind":test.kind,"side":test.side,"u":test.u,"initial_speed":speed,"touch":-1,"full_touch":-1,"eligible":-1,"cue":-1,"physical":-1,"incoming_at_cue":0.0,"normal":[0,0],"equivalent":true,"cue_count":0}
				for tick: int in range(400):
					var incoming: Vector2 = sim.state.velocity
					var previous: Vector2 = sim.state.position
					sim.step(DriveFrame.new(),track)
					plain.step(DriveFrame.new(),track)
					if int(row.eligible)<0:
						var footprint: Dictionary = full_outline(audio,sim.state,track,incoming)
						if footprint.touch and int(row.full_touch)<0: row.full_touch = sim.state.tick
						if footprint.eligible: row.eligible = sim.state.tick
					audio.begin_physics_feedback()
					audio.resolved_contact(sim.state,track,incoming,previous,sim.state.heading)
					if audio.visible_contact.touching and int(row.touch)<0: row.touch = sim.state.tick
					if audio.impact_count>0 and int(row.cue)<0:
						row.cue = sim.state.tick
						row.incoming_at_cue = incoming.length()
						row.normal = [audio.visible_contact.normal.x,audio.visible_contact.normal.y]
					row.equivalent = bool(row.equivalent) and sim.state.snapshot()==plain.state.snapshot()
					if sim.state.collision_impulse!=Vector2.ZERO:
						row.physical = sim.state.tick
						break
					if tick%4==0: audio.present(sim.state,DriveFrame.new(),track,VehicleSimulation.STEP*4,false)
				row.cue_count = audio.impact_count
				assert(row.equivalent,"Contact sound must leave the exact simulation unchanged.")
				rows.append(row)
				print("COMPACT_BRIDGE_CONTACT: ",JSON.stringify(row))
			await process_frame
	var file := FileAccess.open(output.path_join("matrix.json"),FileAccess.WRITE)
	var outline_rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		var model := CarVisual.new()
		model.vehicle_id = id
		root.add_child(model)
		var observer := VisibleContactAudio.new()
		observer.configure(model,true)
		var required: int = 0
		for index: int in range(observer.outline.size()-1): required += maxi(1,ceili(observer.outline[index].distance_to(observer.outline[index+1])/maxf(.10,track.cell_size*.5)))
		outline_rows.append({"car":id,"vertices":observer.outline.size(),"unique_probes":required,"original_probes":required+observer.outline.size()-1})
		model.free()
	file.store_string(JSON.stringify({"name":document.get("name",""),"car":"compact","baseline":baseline,"front":front,"outline_points":audio.visible_contact.outline.size(),"unbounded_probe_count":probes,"outlines":outline_rows,"rows":rows},"\t"))
	file.close()
	audio.free()
	car.free()
	await create_timer(.2).timeout
	print("COMPACT_BRIDGE_MATRIX: %d cases"%rows.size())
	quit()
