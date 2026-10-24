extends SceneTree
const Budget = preload("res://track/night_light_budget.gd")
var checks: int = 0
var failures: int = 0
var settled: bool = false
class SlicedVisual extends NativeTrackVisual:
	func _yield_build() -> bool:
		if not _build_is_current(): return false
		await get_tree().process_frame
		return _build_is_current()
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func partition(visual: NativeTrackVisual) -> void:
	await visual._partition_bank_meshes(); settled = true
func cancellation(destroy: bool) -> void:
	var visual := SlicedVisual.new(); visual.theme_id = "winter"; visual.colors = TrackTheme.palette("winter"); root.add_child(visual)
	var objects: Array = []
	for index: int in range(3): objects.append({"kind":"snow_castle","position":[index*40,0],"rotation":0,"scale":1})
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects}}; await visual._build_placed_objects(track)
	var source: WeakRef = weakref(visual.get_node("WinterCraft")); var current: Array[bool] = [true]
	visual.build_current = func() -> bool: return current[0]
	visual._menu_slices = true; settled = false; partition(visual)
	var lease: Node
	for frame: int in range(100):
		await process_frame
		for child: Node in visual.get_children():
			if child.get_script()==preload("res://race/install_staging.gd"): lease = child; break
		if lease!=null: break
	check(lease!=null,"rigid-family source is owned while splitting yields")
	if destroy: visual.free()
	else: current[0] = false
	for frame: int in range(8): await process_frame
	check(source.get_ref()==null,"canceled family releases its unattached original")
	if not destroy:
		check(settled,"superseded family build settles without publishing")
		visual.free()
func night_race() -> void:
	var document: Dictionary = TrackDocument.create_default(); document.theme = "night_city"
	for index: int in range(92): document.objects.append({"kind":"light","position":[-44+(index%12)*8,-28+(index/12)*8],"rotation":0,"scale":1})
	for index: int in range(4): document.objects.append({"kind":"burning_barrel","position":[index*5-8,10],"rotation":0,"scale":1})
	var track: NativeTrack = TrackCompiler.compile(document); var original: Dictionary
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/gameplay-f05-f10-2026-10-23/night-runtime/"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()); DirAccess.make_dir_recursive_absolute(folder)
	for cycle: int in range(3):
		var game: Node = load("res://core/game.tscn").instantiate(); game.production_mode = true; game.initial_track = track; game.hitch_diagnostics_enabled = false; root.add_child(game); game.process_mode = Node.PROCESS_MODE_DISABLED
		var budget: Node3D = game.track_ground.get_node("NightLightBudget")
		check(budget.sources.size()==96 and budget.selected.size()==8,"cold/cached race owns all 92 lamps and four flame lights within eight active slots")
		var state: Dictionary = RewindHistory.properties(game.sim.state)
		if cycle==0: original = state
		else: check(state==original,"reloaded race starts from the identical complete simulation state")
		for frame: int in range(20):
			game._process(0.016); budget.update_camera(game.camera)
			check(budget.sources.filter(func(light: OmniLight3D) -> bool: return light.visible).size()<=8,"moving barrel synchronization cannot exceed the Night light pool")
		check(RewindHistory.properties(game.sim.state)==state and game.countdown_ticks==360,"presentation/light updates leave physics and countdown exact")
		game.restart(); check(game.sim.state.tick==0 and game.countdown_ticks==360 and budget.selected.size()==8,"restart retains the complete countdown and primes camera-local lights")
		if DisplayServer.get_name()!="headless" and cycle==0:
			for frame: int in range(60): await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder.path_join("92-lamps-four-barrels.png"))==OK,"native crowded Night view retained")
		var retained: WeakRef = weakref(budget); game.free(); await process_frame
		check(retained.get_ref()==null,"race teardown releases the light selector")
func run() -> void:
	await cancellation(false); await cancellation(true); await night_race()
	print("GAMEPLAY_RUNTIME_LIFECYCLE: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
