extends SceneTree
## Real blocked native resource reads; no owner state or threaded script loading.
var checks: int = 0
var failures: int = 0

class BlockingFormat extends ResourceFormatLoader:
	var entered := Semaphore.new()
	var release := Semaphore.new()
	var fail: bool = false
	func _get_recognized_extensions() -> PackedStringArray: return PackedStringArray(["garagecleanupfixture"])
	func _handles_type(type: StringName) -> bool: return type == &"Resource"
	func _get_resource_type(path: String) -> String: return "Resource" if path.get_extension() == "garagecleanupfixture" else ""
	func _load(_path: String,_original: String,_sub_threads: bool,_cache_mode: int) -> Variant:
		entered.post()
		release.wait()
		if fail: return ERR_CANT_OPEN
		var result := Resource.new()
		result.resource_name = "worker finished"
		return result

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func _wait_entered(format: BlockingFormat) -> bool:
	var deadline: int = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec() < deadline:
		if format.entered.try_wait(): return true
		await process_frame
	return false

func run() -> void:
	var folder: String = "user://garage-read-cleanup-"+str(Time.get_ticks_usec())
	check(DirAccess.make_dir_recursive_absolute(folder) == OK,"private fixture directory")
	var script: GDScript = load("res://ui/garage_preloader.gd")
	var format := BlockingFormat.new()
	ResourceLoader.add_resource_format_loader(format,true)
	for fail: bool in [false,true]:
		format.fail = fail
		for retiring: bool in [false,true]:
			var path: String = folder.path_join("case-%s-%s.garagecleanupfixture" % [str(fail),str(retiring)])
			var file := FileAccess.open(path,FileAccess.WRITE)
			check(file != null,"owned fixture opens")
			if file != null: file.store_string("owned fixture")
			file = null
			var preloader: Node = script.new()
			preloader._tree_ref = weakref(self)
			preloader._wanted.append(path)
			check(ResourceLoader.load_threaded_request(path) == OK,"Garage fixture request starts")
			preloader._pending.append(path)
			check(await _wait_entered(format),"Garage fixture reaches worker gate")
			if retiring:
				preloader.free()
				check(not is_instance_valid(preloader),"Garage retirement does not join unfinished worker")
			else:
				preloader._poll_loads()
				check(preloader._pending.size() == 1,"Garage poll preserves unfinished worker")
			check(ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS,"worker remains blocked until explicitly released")
			if fail: print("EXPECTED_FAILURE_BEGIN: Garage worker")
			format.release.post()
			var deadline: int = Time.get_ticks_msec()+5000
			while ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and Time.get_ticks_msec() < deadline:
				if not retiring: preloader._poll_loads()
				await process_frame
			if fail: print("EXPECTED_FAILURE_END: Garage worker")
			check(ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,"Garage terminal request relinquishes engine token")
			if not retiring:
				check(preloader._pending.is_empty(),"completed request leaves pending queue")
				if fail: check(preloader._failed.has(path) and not preloader._resources.has(path),"Garage failure never installs a null resource")
				else: check(not preloader._failed.has(path) and preloader._resources.get(path).resource_name == "worker finished","Garage success retains requested asset")
				preloader.free()
	ResourceLoader.remove_resource_format_loader(format)
	for frame: int in range(4): await process_frame
	print("Garage threaded read cleanup: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
