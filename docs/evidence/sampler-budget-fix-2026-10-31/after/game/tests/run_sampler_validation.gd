extends SceneTree
## Enter through dev.ps1 once; all children use that validated executable and
## explicit crash-dialog suppression. No repeated shipping-asset hash scans.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var evidence: String = OS.get_environment("BMT_SAMPLER_EVIDENCE")
	if evidence.is_empty(): push_error("Explicit evidence folder required"); quit(1); return
	var repository: String = ProjectSettings.globalize_path("res://..").simplify_path()
	var jobs: Array = [
		["component-final","test_sampler_pruning.gd",""],
		["component-mobile","test_sampler_pruning.gd","mobile"],
		["samplers","test_terrain_sampler_budget.gd",""],
		["consolidation","test_shader_variant_consolidation.gd",""],
		["compatibility","review_sampler_pruning.gd","gl_compatibility"],
		["compatibility-final","review_sampler_pruning.gd","gl_compatibility"],
		["mobile","review_sampler_pruning.gd","mobile"],
		["mobile-final","review_sampler_pruning.gd","mobile"],
		["first-draw","profile_sampler_first_draw.gd","gl_compatibility"]]
	var selected: PackedStringArray = OS.get_environment("BMT_SAMPLER_JOBS").split(",",false)
	for job: Array in jobs:
		var label: String = job[0]
		if not selected.is_empty() and not selected.has(label): continue
		var profile: String = repository.path_join("build/sampler-budget-fix-20261031/suite-"+label)
		DirAccess.make_dir_recursive_absolute(profile)
		OS.set_environment("APPDATA",profile)
		OS.set_environment("BMT_API_URL","")
		OS.set_environment("BMT_SAMPLER_AUDIT","")
		OS.set_environment("BMT_SAMPLER_OUTPUT",evidence.path_join(label+".json"))
		OS.set_environment("BMT_VARIANT_FOLDER",evidence.path_join(label))
		OS.set_environment("BMT_VARIANT_OUTPUT",evidence.path_join(label+".json"))
		OS.set_environment("BMT_VARIANT_FINAL","1")
		OS.set_environment("BMT_VARIANT_THEMES","desert,storm,night_city" if label == "first-draw" else "pine,winter,desert,storm,night_city")
		if label == "mobile-final": OS.set_environment("BMT_VARIANT_THEMES","winter")
		if label == "compatibility-final": OS.set_environment("BMT_VARIANT_THEMES","pine,desert,storm")
		if label == "first-draw" and not OS.get_environment("BMT_SAMPLER_TIMING_THEMES").is_empty(): OS.set_environment("BMT_VARIANT_THEMES",OS.get_environment("BMT_SAMPLER_TIMING_THEMES"))
		var engine_log: String = evidence.path_join(label+"-engine-"+str(Time.get_ticks_usec())+".log")
		var arguments: PackedStringArray = [repository.path_join("scripts/run_no_crash_dialog.py"),"--",OS.get_executable_path(),"--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/"+job[1],"--log-file",engine_log]
		if job[2] == "": arguments.append("--headless")
		else: arguments.append_array(["--rendering-method",job[2]])
		var output: Array = []
		var code: int = OS.execute("python",arguments,output,true,false)
		# A Windows GUI Godot executable can leave captured stdout empty.
		var content: String = FileAccess.get_file_as_string(engine_log) if FileAccess.file_exists(engine_log) else "\n".join(output)
		FileAccess.open(evidence.path_join(label+".log"),FileAccess.WRITE).store_string(content)
		var errors: bool = content.contains("SCRIPT ERROR:") or content.contains("SHADER ERROR:") or content.contains("\nERROR:")
		var marker: String = {"component-final":"SAMPLER_PRUNING:","component-mobile":"SAMPLER_PRUNING:","samplers":"TERRAIN_SAMPLER_BUDGET:","consolidation":"SHADER_CONSOLIDATION:","compatibility":"VARIANT_RENDER_CHECKS","compatibility-final":"VARIANT_RENDER_CHECKS","mobile":"VARIANT_RENDER_CHECKS","mobile-final":"VARIANT_RENDER_CHECKS","first-draw":"FIRST_DRAW"}[label]
		errors = errors or not content.contains(marker)
		print("SAMPLER_SUITE ",label," exit=",code," errors=",errors)
		if code != 0 or errors: quit(1); return
	quit()
