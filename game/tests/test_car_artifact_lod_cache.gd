extends SceneTree
## CMA04: an obsolete optional cache must never break a fresh-source producer.
const WORK: String="res://../build/car-model-artifacts-2026-11-14/lod-cache"
var checks: int=0
var failures: int=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("LOD_CACHE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder: String=WORK.path_join("baseline" if "--baseline" in OS.get_cmdline_user_args() else "fixed")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var mesh:=BoxMesh.new()
	var mesh_path: String=folder.path_join("retired.res")
	check(ResourceSaver.save(mesh,mesh_path)==OK,"create owned old dependency")
	var holder:=Node3D.new();var part:=MeshInstance3D.new()
	part.mesh=load(mesh_path);holder.add_child(part);part.owner=holder
	var scene:=PackedScene.new();check(scene.pack(holder)==OK,"pack old scene")
	var scene_path: String=folder.path_join("old.scn")
	check(ResourceSaver.save(scene,scene_path)==OK,"save old scene")
	check(not ResourceLoader.get_dependencies(scene_path).is_empty(),"old scene really references an external mesh")
	holder.free()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(mesh_path))==OK,"retire owned old dependency")
	var errors=preload("res://tests/support/asset_bake_errors.gd").new();OS.add_logger(errors)
	var helper=load("res://../build/car-model-artifacts-2026-11-14/before/game/tests/support/car_refinement_lods.gd" if "--baseline" in OS.get_cmdline_user_args() else "res://tests/support/car_refinement_lods.gd").new()
	helper.remember(scene_path)
	check(not errors.failed() and helper.previous.is_empty(),"obsolete optional cache is skipped without an engine error")
	OS.remove_logger(errors)
	print("LOD_CACHE_TEST ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
