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
	await process_frame
	var layout_before: Dictionary = _layout(browser)
	browser.matches.assign([a,b])
	var previous_title: String = (browser.hero.find_child("HeroTrackTitle",true,false) as Label).text
	var preview_started: int = Time.get_ticks_usec()
	browser._select(a)
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == previous_title,"cold choice retains complete prior section while preparing")
	browser._select(b)
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == previous_title and browser.preview_entry.name == "Second","rapid choice replaces pending target without exposing incomplete content")
	check(browser.detail.visible and not browser.pending_records.visible,"pending selection retains coherent old hero and records without loading flashes")
	print("HERO_TWO_RAPID_CHOICES_MS: ",(Time.get_ticks_usec()-preview_started)/1000.0)
	check(browser.selecting,"selection returns while work is pending")
	check(browser._hero_direction == 1.0 and is_zero_approx(browser._section_offset),"pending selection waits before beginning the slide")
	check(is_equal_approx(browser.hero.position.x,browser.records_panel.position.x),"hero and records slide together during rapid selections")
	check(is_equal_approx(browser.hero.modulate.a,1.0),"old section remains fully readable during preparation")
	check(_same_layout(_layout(browser),layout_before),"pending selection preserves section rectangles")
	var frames: int = 0
	while browser.selecting:
		await process_frame
		frames += 1
	await process_frame
	check(_same_layout(_layout(browser),layout_before),"completed selection preserves section rectangles")
	check(frames > 1,"UI continues processing frames during compilation")
	check(browser.selected_track.identity == "creator_second_track","latest rapid selection wins")
	check(browser.preview_entry.is_empty() and browser.detail.visible and not browser.pending_records.visible,"ready track restores its own records and clears preview state")
	check(browser._section_offset > 0.0 and browser.detail.visible,"slide begins with resolved records already visible")
	await create_timer(0.5).timeout
	check(browser._hero_scenery.get_child_count() == 1,"interrupted fades dispose all outgoing scenery")
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).modulate.a == 1.0,"resolved hero is fully visible without a repeated transition")
	check(browser.catalog.cached_track(a) != null,"superseded valid result is cached")
	browser._select(a)
	check(not browser.selecting and browser.selected_track.identity == "creator_"+str(first.id),"return selection uses compiled cache immediately")
	check(browser._hero_direction == -1.0 and is_equal_approx(browser._section_offset,-browser._slide_distance),"backward selection slides new scenery in from the left")
	var third: Dictionary = second.duplicate(true)
	third.id = "third_track"
	check(library.save_document(third) == OK,"third fixture saved")
	# Refresh index revision and seed the known compiled selection.
	browser.catalog.indexed_revision = library.revision
	browser.catalog.remember_track(a,browser.selected_track)
	browser._select(TrackCatalog.local_metadata(third))
	check(browser.selecting,"cold third selection begins")
	browser._select(a)
	check(not browser.selecting and browser.selected_track.identity == "creator_"+str(first.id),"cached choice is immediate during unrelated active compilation")
	check(browser.race_button.disabled,"race cannot begin with superseded menu work still active")
	while browser._resolve_thread != null: await process_frame
	check(browser.selected_track.identity == "creator_"+str(first.id),"superseded worker cannot replace cached choice")
	check(not browser.race_button.disabled,"race unlocks after superseded worker is drained")
	var retained: NativeTrack = browser.selected_track
	browser.catalog.clear_resolved()
	browser.catalog.remember_track(a,retained)
	for id: String in ["cache_b","cache_c","cache_d"]: browser.catalog.remember_track({"id":id},retained)
	check(browser.catalog.cached_track(a) == retained,"cache touch revisits first entry")
	browser.catalog.remember_track({"id":"cache_e"},retained)
	check(browser.catalog.cached_track(a) == retained and browser.catalog.cached_track({"id":"cache_b"}) == null,"least recently used entry is evicted")
	browser.catalog.remember_track(a,retained)
	check(browser.catalog._resolved.size() == 4,"updating existing cached track does not evict another entry")
	first.name = "Edited"
	check(library.save_document(first) == OK,"save changes revision")
	check(browser.catalog.cached_track(a) == null,"saved changes invalidate compiled cache")
	browser.catalog.clear_resolved()
	check(browser.catalog.cached_track(b) == null,"manual refresh clears cached tracks")
	var delayed := DelayedCloud.new()
	root.add_child(delayed)
	browser.cloud = delayed
	var cloud_entry: Dictionary = a.duplicate(true)
	cloud_entry.id = "cloud_delayed_fixture"
	cloud_entry.source = "cloud"
	cloud_entry.name = "Cloud preview"
	var retained_title: String = (browser.hero.find_child("HeroTrackTitle",true,false) as Label).text
	browser._select(cloud_entry)
	check((browser.hero.find_child("HeroTrackTitle",true,false) as Label).text == retained_title and delayed.calls == 0,"cloud download keeps prior complete section visible")
	while delayed.calls == 0: await process_frame
	check(browser.race_button.disabled,"pending download cannot race the previous selection")
	delayed.finished.emit()
	await process_frame
	check(browser.race_button.disabled and browser.pending_records.text.contains("unavailable"),"failed download keeps its own preview and never enables stale racing")
	var board := DelayedBoard.new()
	root.add_child(board)
	browser.cloud = board
	var ready_track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	ready_track.identity = str(a.id)
	ready_track.metadata.cloud_version = "fixture_ready"
	browser.catalog.indexed_revision = library.revision
	browser.catalog.remember_track(a,ready_track)
	browser._select(a)
	check(not browser.selecting and not browser.race_button.disabled,"cached cloud track is playable while optional standings wait")
	check(board.calls == 1,"cloud records request starts before the section transition")
	board.finished.emit()
	await process_frame
	check(not browser.selecting and browser.detail.visible and not browser.race_button.disabled,"failed optional standings preserve the playable cached section")
	browser.cloud = null
	board.queue_free()
	delayed.queue_free()
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

func _same_layout(a: Dictionary, b: Dictionary) -> bool:
	for key: String in a:
		if not (a[key] as Rect2).is_equal_approx(b[key]): return false
	return true

func _layout(browser: TrackBrowser) -> Dictionary:
	var result: Dictionary = {}
	for title: String in ["HeroSlot","RecordsSlot","GallerySlot","PersonalRecords","Standings","RaceComparison","PlayActions","LibraryRace"]:
		result[title] = (browser.find_child(title,true,false) as Control).get_global_rect()
		if title in ["PersonalRecords","Standings","RaceComparison"]:
			result[title].position.x -= browser._section_offset
	return result

class DelayedCloud extends Node:
	signal finished
	var client: Node = self
	var calls: int = 0
	var last_error: String = "Fixture download unavailable"
	func cancel_public_reads(_owner: int) -> void: pass
	func download(_entry: Dictionary) -> bool:
		calls += 1
		await finished
		return false


class DelayedBoard extends Node:
	signal finished
	var client: Node = self
	var calls: int = 0
	func cancel_public_reads(_owner: int) -> void: pass
	func request_public(_path: String, _owner: int) -> Dictionary:
		calls += 1
		await finished
		return {"ok":false,"error":"Fixture unavailable"}
