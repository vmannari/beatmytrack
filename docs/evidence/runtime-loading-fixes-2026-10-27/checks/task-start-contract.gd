extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	var root_path: String="res://../build/runtime-loading-fixes-2026-10-27/before/game/vehicle/"
	var trails:=GDScript.new()
	trails.source_code=FileAccess.get_file_as_string(root_path+"skid_trails.gd.txt").replace("class_name SkidTrails","")
	assert(trails.reload()==OK)
	var first: Node3D=trails.new();var second: Node3D=trails.new()
	var a: ShaderMaterial=first._trail_material();var b: ShaderMaterial=second._trail_material()
	var shared: bool=a.shader==b.shader
	first.free();second.free()
	var detail:=GDScript.new()
	detail.source_code=FileAccess.get_file_as_string(root_path+"compact_detail.gd.txt").replace("class_name CompactDetail","")
	assert(detail.reload()==OK)
	var cooperative: bool=false
	for method: Dictionary in detail.get_script_method_list():
		if method.name=="_front":cooperative=method.args.size()>=6
	var effects:=GDScript.new()
	effects.source_code=FileAccess.get_file_as_string(root_path+"effect_render_preparation.gd.txt")
	assert(effects.reload()==OK)
	var staged: bool=effects.has_method("prepare")
	var report: Dictionary={"shared_trail_shader":shared,"staged_preparation":staged,"cooperative_front":cooperative,"expected_missing":3}
	FileAccess.open("res://../build/runtime-loading-fixes-2026-10-27/task-start-contract.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TASK_START_CONTRACT ",JSON.stringify(report))
	quit(1 if shared or staged or cooperative else 0)
