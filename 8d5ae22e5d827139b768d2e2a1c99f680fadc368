extends SceneTree
## OMO01-OMO03: all production cars ignore both historical preference values.
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("OPTIMISED_POLICY_FAIL ",label)
func lod_meshes(car: CarVisual) -> int:
	var count: int=0
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh is ArrayMesh: continue
		for surface: Dictionary in mesh.mesh.get("_surfaces"):
			if not surface.get("lods",[]).is_empty(): count+=1; break
	return count
func run() -> void:
	Engine.time_scale=0.0
	var records:=LocalRecords.new("user://optimised-policy/records.json")
	DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
	var track: NativeTrack=NativeTrack.read("res://resources/tracks/ellipse.json")
	for id: String in VehicleCatalog.IDS:
		var wash_bounds: Array[AABB]=[]
		for legacy: bool in [false,true]:
			records.settings={"simple_car_models":legacy}
			var game: Node=load("res://core/game.tscn").instantiate()
			game.vehicle_id=id; game.initial_track=track; game.preference_records=records
			game.production_mode=true; game.attempt_practice=true; game.hitch_diagnostics_enabled=false
			root.add_child(game)
			game.paused=true; game.set_physics_process(false)
			while game.car==null or not game.car.model_ready: await process_frame
			check(not game.car.simple_model,id+" ignores historical preference "+str(legacy))
			check(lod_meshes(game.car)>0,id+" uses prepared optimised geometry "+str(legacy))
			var state: Array=game.sim.state.snapshot()
			game.call("_process",0.0)
			check(game.sim.state.snapshot()==state,id+" presentation retains canonical state")
			check(game.track_session.target_laps==RaceRules.LAPS,id+" retains ordinary lap count")
			var context: Dictionary=preload("res://rendering/biome_shader_profile.gd").context_for(game)
			check(not context.simple,id+" native preparation context uses the actual standard model")
			wash_bounds.append(game.car_weathering.bounds)
			game.free(); await process_frame
		check(wash_bounds[0]==wash_bounds[1],id+" historical preference cannot change condition mapping")
	print("OPTIMISED_MODEL_POLICY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
