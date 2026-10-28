extends SceneTree
## Actual menu, isolated saves and no backend; report cold and warm stalls.
var output: String = "res://../build/menu-responsiveness"
var samples: Array[float] = []
var last: int = 0
var report: Dictionary = {"transitions":[]}

class ProbeApp extends "res://core/app.gd":
	var stages: Array[Dictionary] = []
	func _prepare_menu_neighbors_frame(generation: int) -> void:
		var began: int = Time.get_ticks_usec()
		super._prepare_menu_neighbors_frame(generation)
		stages.append({"stage":"neighbors","screen":screen,"ms":(Time.get_ticks_usec()-began)/1000.0})
	func _garage(parent: Control = null) -> void:
		var began: int = Time.get_ticks_usec()
		super._garage(parent)
		stages.append({"stage":"garage","ms":(Time.get_ticks_usec()-began)/1000.0})

func _initialize() -> void: run.call_deferred()
func tick() -> void:
	var now: int = Time.get_ticks_usec()
	if last: samples.append((now-last)/1000.0)
	last = now
func collect(count: int) -> Dictionary:
	samples.clear()
	last = Time.get_ticks_usec()
	for _i: int in range(count): await process_frame
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	return {"max_ms":ordered[-1],"p95_ms":ordered[int((ordered.size()-1)*0.95)],"over_50ms":ordered.filter(func(v: float) -> bool: return v>50).size(),"frames":ordered}
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	output=ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	process_frame.connect(tick)
	var baseline: bool="--baseline" in OS.get_cmdline_user_args()
	var app: Node
	if baseline:
		for filename: String in ["ui/garage_preview_cache.gd","ui/car_showroom.gd","ui/garage_environment.gd","core/app.gd"]:
			var script: GDScript=load("res://"+filename)
			script.source_code=FileAccess.get_file_as_string("res://../docs/evidence/menu-responsiveness-2026-10-26/before/game/"+filename)
			assert(script.reload()==OK)
		# Recompile the thumbnail subclass after restoring its parent's layout.
		var thumbnail: GDScript=load("res://ui/garage_cached_thumbnail.gd")
		assert(thumbnail.reload()==OK)
		app=load("res://core/app.gd").new()
	else: app=ProbeApp.new()
	var folder: String = "user://menu-responsive-"+TrackLibrary.unique_id()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled=false
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false
	music.menu_player.stop()
	music.menu_player.stream=null
	# Exercise the saved-appearance path as well as stock catalogue pictures.
	app.records.settings.vehicle_liveries={}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary=VehicleLivery.for_car({},id)
		paint.colors.body="c72d34"
		app.records.settings.vehicle_liveries[id]=paint
	app.race_area_mode="free"
	for destination: String in ["tracks","biome","garage","tracks","store","biome","garage","settings","tracks","garage"]:
		var began: int=Time.get_ticks_usec()
		app._navigate_menu_page(destination)
		var call_ms: float=(Time.get_ticks_usec()-began)/1000.0
		var metrics: Dictionary=await collect(80)
		metrics.destination=destination
		metrics.call_ms=call_ms
		report.transitions.append(metrics)
		print("MENU_TRANSITION ",destination," call_ms=",call_ms," frame_max_ms=",metrics.max_ms," p95_ms=",metrics.p95_ms," over50=",metrics.over_50ms)
		if DisplayServer.get_name()!="headless" and destination=="garage":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("garage.png"))
	report.stages=[] if baseline else app.stages
	report.baseline=baseline
	app.queue_free()
	for _i: int in range(5): await process_frame
	var file:=FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	quit()
