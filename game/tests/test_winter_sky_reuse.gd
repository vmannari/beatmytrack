extends SceneTree
## Cache ownership, coexistence and regeneration; no canonical state involved.
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func run() -> void:
	TrackTheme.trim_winter_sky()
	var editor:=Environment.new(); var race:=Environment.new()
	var editor_sun:=DirectionalLight3D.new(); var race_sun:=DirectionalLight3D.new()
	TrackTheme.apply_lighting("winter",editor,editor_sun)
	var initial: Sky=editor.sky
	check(initial!=null and TrackTheme.winter_reflection_sky==initial,"Winter populates exactly one sky cache")
	TrackTheme.apply_lighting("winter",race,race_sun)
	check(race.sky==initial and editor.sky==initial,"editor and race share unchanged static radiance")
	check(initial.sky_material.shader==preload("res://track/winter_reflection_sky.gdshader") and initial.radiance_size==Sky.RADIANCE_SIZE_128 and initial.process_mode==Sky.PROCESS_MODE_QUALITY,"shared sky retains original shader and settings")
	TrackTheme.apply_lighting("pine",race,race_sun)
	check(race.sky==null and editor.sky==initial,"changing one biome does not change the other environment")
	TrackTheme.trim_winter_sky()
	check(TrackTheme.winter_reflection_sky==null and editor.sky==initial,"pressure drops cache without disturbing active environment")
	TrackTheme.apply_lighting("winter",race,race_sun)
	check(race.sky!=null and race.sky!=initial and TrackTheme.winter_reflection_sky==race.sky,"Winter recreates cache after trim")
	check(race.sky.sky_material.shader==initial.sky_material.shader and race.sky.radiance_size==initial.radiance_size and race.sky.process_mode==initial.process_mode,"recreated sky uses exact original resource and settings")
	var old_ref: WeakRef=weakref(initial)
	editor.sky=null; initial=null
	check(old_ref.get_ref()==null,"old sky releases after its last environment")
	var current_ref: WeakRef=weakref(race.sky)
	race.sky=null; TrackTheme.trim_winter_sky()
	check(current_ref.get_ref()==null,"cached sky releases after trimming and environment teardown")
		# Exercise real App retention and its ordinary and forced pressure paths.
	var app: Node=load("res://core/app.tscn").instantiate()
	var folder: String="user://winter-sky-cache-test-"+TrackLibrary.unique_id()
	app.records=LocalRecords.new(folder.path_join("records.json"))
	app.library=TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	TrackTheme.apply_lighting("winter",editor,editor_sun)
	var active: Sky=editor.sky
	var memory = app.editor_memory
	var snapshot: Dictionary=memory.retained(app)
	check(int(snapshot.other.winter_sky_bytes)==TrackTheme.WINTER_SKY_ESTIMATED_BYTES,"optional sky is included in retained-budget accounting")
	app.editor_compiled_cache.append({"bytes":memory.RETAINED_BUDGET+1})
	memory.next_sample=0; memory.tick(app)
	check(TrackTheme.winter_reflection_sky==null and editor.sky==active,"ordinary retained-budget trim releases cache and preserves active sky")
	check(int(memory.retained(app).other.winter_sky_bytes)==0,"trimmed cache leaves retained accounting")
	TrackTheme.apply_lighting("winter",race,race_sun)
	memory.pressure_requested=true; memory.next_sample=0; memory.tick(app)
	check(TrackTheme.winter_reflection_sky==null and race.sky!=null,"forced pressure trims cache without clearing an active environment")
	editor.sky=null; race.sky=null; active=null
	app.queue_free(); await process_frame
	editor_sun.free(); race_sun.free()
	print("WINTER_SKY_REUSE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)



