extends SceneTree
## Runs unchanged inside the actually staged, data-only verification project.
var failures: int = 0
var comparisons: int = 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for profile: String in JumpProfiles.IDS:
		var doc: Dictionary = TrackDocument.create_blank()
		doc["automatic_scenery"] = false
		var road: Dictionary = RoadPieces.create("straight",Vector2(-55,0),0,12)
		road.length=110.0; doc.pieces=[road]
		doc.objects=[{"kind":"jump","jump_profile":profile,"position":[0,0],"rotation":0}]
		var track: NativeTrack = TrackCompiler.compile(doc)
		if track == null:
			failures+=1; print("FAIL: staged compiler rejects ",profile); continue
		var frozen: NativeTrack = preload("res://backend/verification_track.gd").frozen(track)
		for car: String in VehicleCatalog.IDS:
			var config: HandlingConfig = VehicleCatalog.config(car)
			var a:=VehicleSimulation.new(config); var b:=VehicleSimulation.new(config)
			a.reset(Vector2(-8,0),PI*0.5); b.reset(a.state.position,a.state.heading)
			a.state.velocity=Vector2(14,0); b.state.velocity=a.state.velocity
			var same: bool = true
			for tick: int in range(300):
				var frame:=DriveFrame.new(); frame.throttle=255
				a.step(frame,track); b.step(frame,frozen)
				comparisons+=1; same = same and a.state.snapshot() == b.state.snapshot()
			if not same:
				failures+=1; print("FAIL: staged worker differs for ",profile,"/",car)
	print("JUMP_WORKER: %d exact state comparisons, %d failures" % [comparisons,failures])
	quit(0 if failures == 0 else 1)
