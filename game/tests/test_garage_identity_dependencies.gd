extends SceneTree
## Thumbnail identity must not import another car's construction scripts.
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("GARAGE_IDENTITY_FAIL ",label)
func run() -> void:
	var paths: Array[String]=["res://vehicle/electric_reference_mesh.gd","res://vehicle/electric_kits.gd","res://vehicle/electric_body_kits.gd"]
	for path: String in paths: check(not ResourceLoader.has_cached(path),"builder starts unloaded "+path)
	var cache: Script=load("res://ui/garage_preview_cache.gd")
	var service: Node=cache.new()
	var view:=CarShowroom.new()
	view.vehicle_id="electric"
	view.livery=VehicleLivery.defaults("electric")
	view.condition={}
	view.customisation=VehicleCustomisation.defaults()
	var first: String=service.identity(view)
	check(first.length()==64 and first==service.identity(view),"appearance identity is stable")
	var hashes: Array[String]=[]
	for path: String in paths:
		hashes.append(FileAccess.get_sha256(path))
		check(not ResourceLoader.has_cached(path),"identity leaves builder unloaded "+path)
	check(cache._electric_source_revision=="volt-source-1:"+":".join(hashes),"checkout identity guards all three complete sources")
	view.livery.colors.body="2b83c7"
	check(service.identity(view)!=first,"saved paint changes identity")
	view.free()
	service.free()
	print("GARAGE_IDENTITY_DEPENDENCIES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
