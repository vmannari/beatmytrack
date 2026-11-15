extends SceneTree
## CPR01: many historical looks cannot evict current cars from the bounded cache.
const Cache = preload("res://ui/header_car_appearance_cache.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",label)
func count_pictures(path: String) -> int:
	var count: int=0
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".png") and file.trim_suffix(".png").length()==64: count += 1
	return count
func run() -> void:
	var folder: String
	var output: String
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--records-root="): folder=argument.trim_prefix("--records-root=")
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	var seed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("seed.json")))
	var directory: String=folder.path_join("header_appearance_icons")
	var control: String=folder.path_join("old-policy-control")
	var keep := PackedStringArray(seed.saved_keys)
	var pixels := Image.create(Cache.SIZE.x,Cache.SIZE.y,false,Image.FORMAT_RGBA8)
	pixels.fill(Color("224466"))
	for index: int in range(18):
		var key: String=("historical-paint-"+str(index)).sha256_text()
		Cache._write(func() -> bool: return false,control,key,pixels)
		Cache._write(func() -> bool: return false,directory,key,pixels,keep)
	var control_evicted: int=0
	for id: String in ["compact","kart"]:
		var name: String=seed.cars[id].key+".png"
		check(FileAccess.file_exists(directory.path_join(name)),"current car survives eighteen newer looks "+id)
		check(FileAccess.get_sha256(directory.path_join(name))==seed.cars[id].png_sha256,"protected PNG stays byte exact "+id)
		if not FileAccess.file_exists(control.path_join(name)): control_evicted += 1
	check(control_evicted==2,"former unprotected policy evicts both oldest current pictures")
	check(count_pictures(directory)==Cache.FILE_LIMIT,"protected cache retains the unchanged fourteen-file bound")
	check(count_pictures(control)==Cache.FILE_LIMIT,"former policy control has the same fourteen-file bound")
	var report: Dictionary={"checks":checks,"failures":failures,"historical_looks":18,"protected_png_count":count_pictures(directory),"old_policy_current_evictions":control_evicted}
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAR_PICTURE_RETENTION ",JSON.stringify(report))
	quit(1 if failures else 0)
