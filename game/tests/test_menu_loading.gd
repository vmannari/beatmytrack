extends SceneTree

var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func run() -> void:
	var folder: String = "user://menu_loading_"+TrackLibrary.unique_id()
	var library := TrackLibrary.new(folder)
	var first: Dictionary = TrackDocument.create_default()
	first.name = "First"
	first.pieces = [RoadPieces.create("curve",Vector2(-10,-8)),RoadPieces.create("straight",Vector2(6,8),90)]
	var second: Dictionary = first.duplicate(true)
	second.id = "second_track"
	second.name = "Second"
	check(library.save_document(first) == OK and library.save_document(second) == OK,"fixture tracks saved")
	var browser := TrackBrowser.new()
	browser.library = library
	browser.records = LocalRecords.new(folder+"/records.json")
	browser.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	browser.state = {"section":"all","page":0}
	root.add_child(browser)
	while browser.loading: await process_frame
	var a: Dictionary = TrackCatalog.local_metadata(first)
	var b: Dictionary = TrackCatalog.local_metadata(second)
	browser._select(a)
	browser._select(b)
	check(browser.selecting,"selection returns while work is pending")
	var frames: int = 0
	while browser.selecting:
		await process_frame
		frames += 1
	check(frames > 1,"UI continues processing frames during compilation")
	check(browser.selected_track.identity == "creator_second_track","latest rapid selection wins")
	check(browser.catalog.cached_track(a) != null,"superseded valid result is cached")
	browser._select(a)
	check(not browser.selecting and browser.selected_track.identity == "creator_"+str(first.id),"return selection uses compiled cache immediately")
	first.name = "Edited"
	check(library.save_document(first) == OK,"save changes revision")
	check(browser.catalog.cached_track(a) == null,"saved changes invalidate compiled cache")
	browser.catalog.clear_resolved()
	check(browser.catalog.cached_track(b) == null,"manual refresh clears cached tracks")
	var track: NativeTrack = browser.selected_track
	browser.queue_free()
	await process_frame
	# The sliced builder must produce the identical scene, not a cheaper mesh.
	var sync := NativeTrackVisual.new()
	root.add_child(sync)
	sync.build(track,BridgePresentation.new(track))
	var sliced := NativeTrackVisual.new()
	root.add_child(sliced)
	await sliced.build(track,BridgePresentation.new(track),true)
	check(_geometry(sync) == _geometry(sliced),"sliced and synchronous mesh geometry match exactly")
	sync.queue_free()
	sliced.queue_free()
	if DisplayServer.get_name() != "headless":
		var preview := TrackShowroom.new()
		preview.track = track
		preview.size = Vector2(220,150)
		root.add_child(preview)
		while not preview.ready_for_display: await process_frame
		await process_frame
		check(preview.find_children("*","SubViewport",true,false).is_empty(),"completed preview releases its live 3D viewport")
		preview.queue_free()
		await process_frame
		var cached := TrackShowroom.new()
		cached.track = track
		cached.size = Vector2(220,150)
		root.add_child(cached)
		for i: int in range(4): await process_frame
		check(cached.ready_for_display,"repeat preview uses cached image")
		cached.queue_free()
		await process_frame
		var cancelled := TrackShowroom.new()
		cancelled.track = track
		cancelled.size = Vector2(241,151)
		root.add_child(cancelled)
		for i: int in range(3): await process_frame
		cancelled.queue_free()
		for i: int in range(3): await process_frame
		check(not is_instance_valid(cancelled),"preview can be closed during sliced construction")
	for filename: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(folder+"/"+filename)
	DirAccess.remove_absolute(folder)
	print("MENU_LOADING: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func _geometry(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is MeshInstance3D:
		result.append(node.transform)
		for surface: int in range(node.mesh.get_surface_count()): result.append(node.mesh.surface_get_arrays(surface))
	for child: Node in node.get_children(): result.append(_geometry(child))
	return result
