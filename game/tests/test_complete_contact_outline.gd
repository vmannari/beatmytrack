extends SceneTree
## Every real body vertex must be observable within the existing probe budget.
var checks: int = 0
var failures: int = 0
var baseline: bool = false

class CountedObserver extends VisibleContactAudio:
	var seen: Array[Vector2] = []
	func _solid_at(state: VehicleState, track: NativeTrack, point: Vector2, span_index: int) -> bool:
		seen.append(point)
		return super._solid_at(state,track,point,span_index)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func make_observer() -> VisibleContactAudio:
	if not baseline: return CountedObserver.new()
	var original: String = FileAccess.get_file_as_string("res://../docs/evidence/compact-bridge-impact-2026-10-23/before/game/vehicle/visible_contact_audio.gd")
	var method: String = original.substr(original.find("func sample("))
	method = method.substr(0,method.find("func _solid_at("))
	var script := GDScript.new()
	script.source_code = "extends VisibleContactAudio\nvar seen: Array[Vector2] = []\n"+method+"\nfunc _solid_at(state: VehicleState, track: NativeTrack, point: Vector2, span_index: int) -> bool:\n\tseen.append(point)\n\treturn super._solid_at(state,track,point,span_index)\n"
	assert(script.reload()==OK)
	return script.new()

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var track := NativeTrack.new()
	track.cell_size = .5
	track.grid_width = 64
	track.grid_height = 64
	track.half_extent = Vector2(16,16)
	track.cells.resize(4096)
	track.cells.fill(0)
	track.deck_cells.resize(4096)
	track.deck_cells.fill(-1)
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [false,true]:
			var car := CarVisual.new()
			car.vehicle_id = id
			car.simple_model = simple
			root.add_child(car)
			var observer: VisibleContactAudio = make_observer()
			observer.configure(car,true)
			for angle: float in [0.0,.75,PI*.5,PI]:
				var state := VehicleState.new()
				state.position = Vector2(1.5,-.75)
				state.heading = angle
				var before: Array = state.snapshot()
				observer.reset()
				observer.get("seen").clear()
				var impulse: Vector2 = observer.sample(state,track,state.forward()*5)
				var seen: Array = observer.get("seen")
				check(seen.size()<=VisibleContactAudio.MAX_PROBES,"bounded observation: "+id+str(simple))
				var complete: bool = true
				for index: int in range(observer.outline.size()-1):
					var local: Vector2 = observer.outline[index]
					var vertex: Vector2 = state.position+state.right()*local.x+state.forward()*local.y
					if not seen.any(func(point: Vector2) -> bool: return point.distance_to(vertex)<.00001): complete = false
				check(complete,"every real hull vertex is observed: "+id+str(simple))
				check(impulse==Vector2.ZERO and not observer.touching,"clear geometry stays silent: "+id)
				check(state.snapshot()==before,"observer preserves exact driving state: "+id)
			car.free()
			await process_frame
	await create_timer(.2).timeout
	print("COMPLETE_CONTACT_OUTLINE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
