extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	CompactCoachwork.use_baked=false
	for simple: bool in [false,true]:
		CompactCoachwork.meshes.clear()
		var car:=CarVisual.new();car.simple_model=simple;car.body=Node3D.new();car.add_child(car.body);root.add_child(car)
		CompactCoachwork.build_nose(car,CompactFinish.paint(Color.WHITE))
		var key: String="front_coachwork_simple" if simple else "front_coachwork"
		var directory: String=RacingCarModels.COACH_ROOT if simple else CompactCoachwork.ASSET_ROOT
		assert(ResourceSaver.save(CompactCoachwork.meshes[key],directory.path_join(key+".res"),ResourceSaver.FLAG_COMPRESS)==OK)
		print("RGC_NATIVE_BAKE ",key," ",(CompactCoachwork.meshes[key] as Mesh).get_faces().size()/3)
		car.free();await process_frame
	quit()
