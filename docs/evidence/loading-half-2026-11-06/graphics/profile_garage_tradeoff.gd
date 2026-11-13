extends "res://tests/profile_podium_loading_half.gd"
## Evidence only. Same production path; control disables only podium image reuse.
var live_podium: bool = false

func run() -> void:
	live_podium = "--live-podium" in OS.get_cmdline_user_args()
	load("res://ui/rivalry_podium_pictures.gd").enabled = not live_podium
	await super.run()

func context() -> Dictionary:
	var result: Dictionary = {"live_podium":live_podium,"engine_ms":Time.get_ticks_usec()/1000.0}
	for path: String in ["res://vehicle/car_visual.gd","res://track/native_track_visual.gd","res://editor/editor_memory.gd","res://ui/garage_page.gd","res://ui/garage_environment.gd","res://ui/showroom_studio.gd"]:
		result[path.get_file()] = ResourceLoader.has_cached(path)
	# Never load a dependency merely to inspect its state.
	if ResourceLoader.has_cached("res://ui/showroom_studio.gd"):
		var studio: Script = load("res://ui/showroom_studio.gd")
		result.sky_exists = studio.cached_sky != null
		result.sky_id = studio.cached_sky.get_instance_id() if studio.cached_sky != null else 0
	if ResourceLoader.has_cached("res://rendering/graphics_preparation.gd"):
		var graphics: Script = load("res://rendering/graphics_preparation.gd")
		result.receipts = graphics.warmed.size()
		result.receipt_hits = graphics.hits
		result.receipt_submissions = graphics.submissions
		result.receipt_generation = graphics.generation
	result.memory_policy_active = app.editor_memory._policy != null
	if is_instance_valid(app._garage_preloader):
		var loader: Node = app._garage_preloader
		result.preloader = {"process":loader.is_processing(),"evicted":loader.evicted,"foreground":loader.foreground,"has_studio":is_instance_valid(loader.studio),"resources":loader._resources.size(),"pending":loader._pending.size(),"picture_renderer":is_instance_valid(loader.picture_service) and is_instance_valid(loader.picture_service.renderer)}
		if is_instance_valid(loader.studio):
			result.preloader.merge({"studio_ready":loader.studio.showroom_ready,"prepared":loader.studio.prepared,"warming":loader.studio.warming,"warm_draws":loader.studio.warm_draws})
	return result

func entry(page: String, cycle: int) -> void:
	var before: Dictionary = context() if page in ["rivalry","garage"] else {}
	if not before.is_empty(): print("GARAGE_TRADEOFF_CONTEXT ",JSON.stringify({"page":page,"cycle":cycle,"boundary":"before","state":before}))
	await super.entry(page,cycle)
	if before.is_empty(): return
	var after: Dictionary = context()
	rows[-1].tradeoff_before = before
	rows[-1].tradeoff_after = after
	print("GARAGE_TRADEOFF_CONTEXT ",JSON.stringify({"page":page,"cycle":cycle,"boundary":"after","state":after}))
