extends SceneTree
## Prepare isolated copies; live mode only reads the explicitly selected library.
const IDS: Array[String] = ["storm_freight","storm_switchyard","storm_timber","storm_quarry","storm_floodgate"]
const OUTPUT: String = "res://../build/storm-ville-drafts-2026-10-26"
var checks: int = 0
var failures: int = 0
var output_directory: String = OUTPUT

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output_directory = argument.trim_prefix("--output-dir=")
	var live: bool = "--verify-live" in OS.get_cmdline_user_args()
	var directory: String = ProjectSettings.globalize_path(output_directory+"/prepared")
	if live:
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output_directory+"/plan.json"))
		check(plan.owner=="Ville" and (str(plan.origin)+"/"+str(plan.player_id)).sha256_text()==str(plan.profile),"plan uses Ville's observed account scope")
		directory = str(plan.destination)
		check(directory.replace("\\","/").ends_with("/Circuit01Lab/players/"+str(plan.profile)+"/tracks"),"live verification stays within the selected profile library")
	var library := TrackLibrary.new(directory)
	var rows: Array[Dictionary] = []
	for id: String in IDS:
		var source_path: String = "res://resources/storm_tracks/"+id+".json"
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
		var expected: Dictionary = source.duplicate(true)
		expected.creator = "Ville"
		check(TrackDocument.validate(expected).is_empty(),id+" remains a valid current creator document")
		check(expected.layout.is_empty() and expected.pieces.size()>=20,id+" uses supported editor road parts")
		check(RoadPieces.route_from_pieces(expected).ok and expected.has("start_line"),id+" passes the real editor connected-road and start-line requirements")
		if not live:
			library.owner_name = "Ville"
			check(library.save_document(expected)==OK,id+" saves through the actual local draft writer")
		var saved: Dictionary = library.load_document(id)
		check(saved==expected,id+" reloads with only the requested creator attribution changed")
		check(not library.is_published(id),id+" has no publication binding")
		if not live:
			var original: NativeTrack = TrackCompiler.compile(source)
			var draft: NativeTrack = TrackCompiler.compile(saved)
			check(original!=null and draft!=null,id+" compiles")
			if original!=null and draft!=null:
				check(original.route==draft.route and original.cells==draft.cells and original.deck_cells==draft.deck_cells,id+" actual road and collision geometry are unchanged")
		rows.append({"id":id,"name":str(expected.name),"creator":str(expected.creator),"source_sha256":FileAccess.get_sha256(source_path),"draft_sha256":FileAccess.get_sha256(directory.path_join(id+".json"))})
	var entries: Array[Dictionary] = library.editable_entries()
	var found: Array[String] = []
	for item: Dictionary in entries:
		if str(item.id) in IDS:
			found.append(str(item.id))
			check(item.source in ["saved","wip"] and item.document.creator=="Ville" and library.load_document(str(item.id))==item.document,str(item.id)+" visible draft or autosave exactly matches its saved Ville original")
	check(found.size()==5,"all five tracks are visible to the real draft scan")
	if live:
		root.size = Vector2i(1280,720)
		var browser: VBoxContainer = preload("res://ui/draft_browser.gd").new()
		browser.library = library
		browser.query = "storm"
		browser.size = Vector2(1280,720)
		root.add_child(browser)
		for i: int in range(120):
			await process_frame
			if not browser.scanning and browser.scan==null: break
		check(browser.entries.filter(func(item: Dictionary) -> bool: return str(item.id) in IDS).size()==5,"actual Load track browser sees the five drafts")
		if DisplayServer.get_name()!="headless":
			await create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output_directory+"/ville-load-track.png")==OK,"native Load track screenshot")
			browser.page = 1
			browser._refresh()
			await create_timer(.2).timeout
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output_directory+"/ville-load-track-2.png")==OK,"native second draft page screenshot")
		browser.free()
		await process_frame
	var report := FileAccess.open(output_directory+("/live-result.json" if live else "/stage-result.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"mode":"read-only verification" if live else "isolated preparation","tracks":rows,"drafts_in_library":entries.size()},"\t")); report.close()
	print("VILLE_STORM_DRAFTS: %d checks, %d failures; %s" % [checks,failures,"read-only live verification" if live else "isolated preparation"])
	quit(1 if failures else 0)
