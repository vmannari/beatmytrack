extends SceneTree
## A previous in-memory ArrayMesh must not mask a newly published model revision.
var checks: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	assert(ok,label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path: String=SuperRallyModel.ROOT+"simple_body_chrome.res"
	var old_path: String="res://../build/challenger-front-crown-2026-11-15/before/game/assets/vehicles/challenger_hellcat_v1/simple_body_chrome.res"
	var expected: ArrayMesh=ResourceLoader.load(path,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE)
	var expected_bytes: PackedByteArray=var_to_bytes(expected.surface_get_arrays(0))
	var stale: ArrayMesh=ResourceLoader.load(old_path,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE)
	var stale_bytes: PackedByteArray=var_to_bytes(stale.surface_get_arrays(0))
	verify(stale_bytes!=expected_bytes,"fixture contains the actual preceding exhaust/front mesh")
	stale.take_over_path(path)
	var legacy:=GDScript.new()
	legacy.source_code=FileAccess.get_file_as_string("res://../build/challenger-front-crown-2026-11-15/before/game/vehicle/super_rally_model.gd").replace("class_name SuperRallyModel","")
	verify(legacy.reload()==OK,"actual preceding builder compiles as a private control")
	legacy.set("assets",{path:stale})
	var car:=CarVisual.new();car.simple_model=true
	var parent:=Node3D.new();car.add_child(parent)
	var roles: Array[String]=["chrome"]
	legacy.call("_asset",car,parent,"body",roles,StandardMaterial3D.new())
	verify(var_to_bytes((parent.get_child(0) as MeshInstance3D).mesh.surface_get_arrays(0))==stale_bytes,"actual old builder reproduces the stale native asset")
	SuperRallyModel.assets={path:stale}
	SuperRallyModel._asset_revision="previous-revision"
	var corrected:=Node3D.new();car.add_child(corrected)
	SuperRallyModel._asset(car,corrected,"body",roles,StandardMaterial3D.new())
	var loaded: ArrayMesh=(corrected.get_child(0) as MeshInstance3D).mesh
	verify(var_to_bytes(loaded.surface_get_arrays(0))==expected_bytes,"new builder replaces the actual cached resource with current native arrays")
	var next:=Node3D.new();car.add_child(next)
	SuperRallyModel._asset(car,next,"body",roles,StandardMaterial3D.new())
	verify((next.get_child(0) as MeshInstance3D).mesh==loaded,"current native mesh is shared after its one-time revision load")
	verify(SuperRallyModel.assets.size()==1,"only the current native generation remains retained")
	car.free();legacy.set("assets",{});legacy=null
	await process_frame
	print("CHALLENGER_NATIVE_REFRESH ",checks," checks, 0 failures; original stale-control reproduced")
	quit()
