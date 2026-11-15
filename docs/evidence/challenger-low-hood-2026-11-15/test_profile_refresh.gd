extends SceneTree
var checks: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	assert(ok,label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path: String=SuperRallyModel.ROOT+"hood_profile.json"
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var old_path: String="res://../docs/evidence/challenger-low-hood-2026-11-15/controls/hood_profile.json"
	var stale: JSON=ResourceLoader.load(old_path,"JSON",ResourceLoader.CACHE_MODE_IGNORE)
	verify(stale.data!=expected,"fixture contains preceding higher bonnet profile")
	SuperRallyModel.hood_profile=expected.duplicate(true)
	var expected_height: float=SuperRallyModel._hood_height(.60,-1.45)
	stale.take_over_path(path)
	var legacy:=GDScript.new()
	legacy.source_code=FileAccess.get_file_as_string("res://../docs/evidence/challenger-low-hood-2026-11-15/controls/super_rally_model.gd").replace("class_name SuperRallyModel","")
	verify(legacy.reload()==OK,"actual preceding builder compiles as a private control")
	legacy.set("hood_profile",stale.data.duplicate(true))
	var old_height: float=legacy.call("_hood_height",.60,-1.45)
	verify(old_height-expected_height>.040,"preceding cached profile reproduces the higher fitting surface")
	SuperRallyModel.hood_profile=stale.data.duplicate(true)
	SuperRallyModel._asset_revision="previous-revision"
	var car:=CarVisual.new();car.simple_model=true
	var part:=Node3D.new();car.add_child(part)
	var roles: Array[String]=["chrome"]
	SuperRallyModel._asset(car,part,"body",roles,StandardMaterial3D.new())
	verify(SuperRallyModel.hood_profile.is_empty(),"revision clears preceding fitting profile")
	verify(absf(SuperRallyModel._hood_height(.60,-1.45)-expected_height)<.000001,"new builder restores the current native fitting height")
	verify(SuperRallyModel.hood_profile==expected,"complete current fitting profile replaces the stale engine JSON cache")
	car.free();legacy.set("hood_profile",{});legacy=null
	await process_frame
	print("CHALLENGER_PROFILE_REFRESH ",checks," checks, 0 failures; actual preceding profile rejected")
	quit()
