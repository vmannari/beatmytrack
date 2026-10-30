extends SceneTree
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func run() -> void:
	var folder: String = ProjectSettings.globalize_path("res://../build/storm-five-tracks-catalog-user/"+str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(folder)
	var library := TrackLibrary.new(folder+"/tracks")
	var catalog := TrackCatalog.new(library)
	for id: String in BuiltinTracks.ids(): catalog.add_builtin(id)
	check(catalog.query({"theme":"storm"},[]).size()==5,"all five original Storm tracks appear in the local catalogue")
	check(BuiltinTracks.ids()[0]=="ellipse","Ellipse remains the tutorial/default track")
	for id: String in IDS:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/storm_tracks/"+id+".json"))
		var entry: Dictionary = BuiltinTracks.metadata(id)
		check(entry.theme=="storm" and entry.creator_kind=="original" and entry.name==source.name,id+" searchable original metadata")
		var track: NativeTrack = NativeTrack.read(entry.path)
		check(track != null and track.identity==id,id+" prepared native file loads")
		if track == null: continue
		check(track.metadata.creator_document==source,id+" prepared resource exactly matches final editable source")
		var compiled: NativeTrack = TrackCompiler.compile(source)
		check(track.route==compiled.route and track.cells==compiled.cells and track.deck_cells==compiled.deck_cells,id+" prepared route and collision cells exactly match compilation")
		check(library.save_document(source)==OK and library.load_document(id)==source,id+" imports and reloads through the real local library")
	catalog.indexed_revision = library.revision
	var browser := TrackBrowser.new()
	browser.library = library
	browser.catalog = catalog
	browser.records = LocalRecords.new(folder+"/records.json")
	browser.state = {"section":"all","theme":"storm","feed":"recommended"}
	browser.selected_track = NativeTrack.read("res://resources/tracks/ellipse.json")
	root.size = Vector2i(1280,720)
	browser.size = Vector2(1280,720)
	root.add_child(browser)
	await process_frame
	await process_frame
	check(browser.matches.size()==5,"actual local browser displays the five Storm choices")
	for entry: Dictionary in browser.matches:
		browser._select(entry)
		while browser.selecting: await process_frame
		check(browser.selected_track!=null and browser.selected_track.identity==entry.id and not browser.race_button.disabled,str(entry.id)+" actual browser selection enables Race")
	if DisplayServer.get_name()!="headless":
		browser._close_track_view()
		await create_timer(.6).timeout
		for i: int in range(12): await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://../docs/evidence/storm-five-tracks-2026-10-25/"+RenderingServer.get_current_rendering_method()+"/local-catalog.png"
		check(root.get_texture().get_image().save_png(path)==OK,"native local browser screenshot")
	browser.free()
	await process_frame
	print("STORM_TRACK_CATALOG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
