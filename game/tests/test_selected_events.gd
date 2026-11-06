extends SceneTree
const Event=preload("res://race/selected_event.gd")
const Roads=preload("res://editor/road_preparation.gd")
var app: Node
var checks: int=0
var failures: int=0
var folder: String
var document: Dictionary
var entry: Dictionary
var page: Control
var rows: Array=[]

class Daily extends Control:
	var page_preview: bool=false
	var entry: Dictionary={}
	var _busy: bool=false
	var _ends_at: int=200100
	var _server_now: int=200000
	var _sample_msec: int=0
class Rivalry extends Control:
	var section: String="detail"
	var selected: int=0
class SlowCloud extends "res://backend/cloud_tracks.gd":
	var source: Dictionary={}
	var downloads: int=0
	func _ready() -> void: pass
	func download_document(_entry: Dictionary, cancelled: Callable=Callable()) -> Dictionary:
		downloads+=1
		await get_tree().create_timer(0.1).timeout
		return {} if cancelled.is_valid() and cancelled.call() else source.duplicate(true)
class Auth extends "res://backend/backend_client.gd":
	func signed_in() -> bool: return true
class Tickets extends "res://backend/weekly_rivalry_client.gd":
	var tickets: int=0
	var mutate: bool=false
	func _ready() -> void: pass
	func ticket(_index: int) -> Dictionary:
		tickets+=1
		await get_tree().process_frame
		if mutate: model.week+=1
		return {"ticket":"fixture-authorisation"}
class FixtureApp extends "res://core/app.gd":
	var handoffs: Array=[]
	func _rivalry(_parent: VBoxContainer=null) -> void: pass
	func _rivalry_ghost(_index: int,_choice: int,_wait: bool=false) -> Dictionary: return {}
	func _start_race(track: NativeTrack,_editor: bool,_offline: bool=false,issued: Dictionary={},_loading: RaceLoading=null,_daily: Dictionary={}) -> void:
		handoffs.append({"track":track,"issued":issued})

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func setup(kind: String) -> void:
	app._cancel_selected_preparation()
	if is_instance_valid(page): page.free()
	app.screen=kind
	VehicleCatalog.selected="compact"
	page=Daily.new() if kind=="daily" else Rivalry.new()
	if kind=="daily": page.entry=entry.duplicate(true); page._sample_msec=Time.get_ticks_msec()
	else:
		app.rivalry_section="detail"; app.rivalry_track=0
		app.rivalry.cached_snapshot=false
		app.rivalry.snapshot_scope=app.rivalry.scope()
		app.rivalry.model.sample=false; app.rivalry.model.completed=false; app.rivalry.model.status="active"
		app.rivalry.model.group_id="fixture-group"; app.rivalry.model.week=2
		app.rivalry.model.tracks.assign([{"entry":entry.duplicate(true),"available":true}])
	app.add_child(page)
	app.selected_track=null

func start(kind: String, source: Dictionary={}) -> void:
	app._prepare_selected_event(kind,page,entry,source)

func wait_ready() -> void:
	var deadline: int=Time.get_ticks_msec()+45000
	while app._selected_preparation_pending and Time.get_ticks_msec()<deadline: await process_frame
	check(not app._selected_preparation_pending,"one selected worker finishes")

func run() -> void:
	folder=ProjectSettings.globalize_path("res://../build/selected-events-retention-20261104/fixture-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	NativeTrackVisual.ROAD_DISK_CACHE.directory=folder.path_join("roads")
	document=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var body: String=JSON.stringify(document)
	FileAccess.open(folder.path_join("track.json"),FileAccess.WRITE).store_string(body)
	entry={"id":"cloud_selected_fixture","source":"cloud","track_id":"selected_fixture","version_id":"fixture-v1","content_hash":body.sha256_text(),"cache_path":folder.path_join("track.json"),"name":"Selected fixture","theme":"pine","creator":"Fixture","points":document.points}
	app=FixtureApp.new()
	app.library=TrackLibrary.new(folder.path_join("library")); app.records=LocalRecords.new(folder.path_join("records.json")); app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.set_process(false)
	app.set_process(false) # Poll explicitly to make each cancellation boundary exact.
	for kind: String in ["daily","rivalry"]:
		setup(kind)
		var stale: Dictionary=entry.duplicate(true); stale["canonical_track_hash"]="b".repeat(64)
		app._prepare_selected_event(kind,page,stale,document)
		check(not app._selected_preparation_pending and app.selected_track==null,kind+" rejects a source pin different from its current event")
		start(kind,document)
		check(app._selected_preparation_pending and app._selected_preparation_job==null,kind+" queues only the selected event after settling")
		app._poll_selected_preparation()
		check(app._selected_preparation_job==null,kind+" does not start during settle interval")
		var generation: int=app._selected_preparation_generation
		start(kind,document)
		check(app._selected_preparation_generation==generation,kind+" repeated presentation deduplicates work")
		app._selected_preparation_event.due=0
		app._poll_selected_preparation(); app._poll_selected_preparation()
		check(app._selected_preparation_job!=null,kind+" uses the existing single CPU worker")
		var began: int=Time.get_ticks_usec()
		var deadline: int=Time.get_ticks_msec()+45000
		while app._selected_preparation_pending and Time.get_ticks_msec()<deadline:
			app._poll_selected_preparation(); await process_frame
		check(not app._selected_preparation_pending and not app.selected_track.metadata.get("metadata_only",false),kind+" publishes hydrated exact event")
		check(app._selected_event_track(entry)==app.selected_track,kind+" race handoff reuses the prepared object")
		check(app.selected_track._race_gates.get("rules_key","")==RaceRules.KEY,kind+" prepares canonical gates before race")
		check(app.selected_track.metadata.cloud_version==entry.version_id,kind+" retains exact version")
		rows.append({"kind":kind,"worker_ms":(Time.get_ticks_usec()-began)/1000.0})
		for change: String in ["car","scope","navigation","hash","hidden","owner","event","preview"]:
			setup(kind); start(kind,document)
			check(app._selected_preparation_pending,kind+" cancellation begins "+change)
			match change:
				"car": VehicleCatalog.selected="kart"
				"scope": app._selected_preparation_scope+="changed"
				"navigation": app._navigation_generation+=1
				"hash": app.selected_track.metadata.cloud_entry.content_hash="changed"
				"hidden": page.hide()
				"owner": page.free()
				"event":
					if kind=="daily": page._server_now+=86400
					else: app.rivalry.model.week+=1
				"preview":
					if kind=="daily": page.page_preview=true
					else: app.rivalry.cached_snapshot=true
			app._poll_selected_preparation()
			check(not app._selected_preparation_pending and app._selected_preparation_job==null,kind+" cancels stale "+change)
	setup("daily"); start("daily",document)
	page._busy=true; page._ends_at=0
	check(not app._selected_preparation_obsolete(app._selected_preparation_generation),"Daily revalidation preserves the exact worker while refreshing")
	app._selected_preparation_event.expires=Time.get_ticks_msec()-1
	app._poll_selected_preparation()
	check(not app._selected_preparation_pending,"Daily expiry cancels even during revalidation")
	setup("daily")
	var old_cloud: Node=app.cloud
	var slow:=SlowCloud.new(); slow.client=app.online.client; slow.source=document; slow.root_override=folder.path_join("slow-cloud"); app.add_child(slow); app.cloud=slow
	start("daily"); app._selected_preparation_event.due=0; app._poll_selected_preparation()
	check(slow.downloads==1,"metadata starts one cancellable document request")
	page.hide(); app._poll_selected_preparation()
	await create_timer(0.2).timeout
	check(not app._selected_preparation_pending and app._selected_preparation_job==null,"late document cannot launch stale event preparation")
	app.cloud=old_cloud; slow.free()
	# Real Rivalry composition consumes prepared geometry, but still asks for a
	# fresh ticket and rejects an event replaced while that request is in flight.
	var auth:=Auth.new(); app.add_child(auth)
	var old_client: Node=app.online.client; app.online.client=auth
	var old_rivalry: Node=app.rivalry
	var tickets:=Tickets.new(); tickets.client=auth; app.add_child(tickets); app.rivalry=tickets
	setup("rivalry"); start("rivalry",document)
	app._selected_preparation_event.due=0
	var deadline: int=Time.get_ticks_msec()+45000
	while app._selected_preparation_pending and Time.get_ticks_msec()<deadline:
		app._poll_selected_preparation(); await process_frame
	var prepared: NativeTrack=app.selected_track
	check(not prepared.metadata.get("metadata_only",false),"Rivalry exact geometry finishes before its race tap")
	await app._start_rivalry_race(0,3)
	check(tickets.tickets==1 and app.handoffs.size()==1,"prepared Rivalry still requests a fresh ticket")
	check(app.handoffs.size()==1 and app.handoffs[0].track==prepared,"Rivalry ticket handoff uses the exact prepared track")
	tickets.mutate=true
	await app._start_rivalry_race(0,3)
	check(tickets.tickets==2 and app.handoffs.size()==1 and not app.cloud_starting,"week changed during ticket cannot install an obsolete event")
	app.rivalry=old_rivalry; app.online.client=old_client; tickets.free(); auth.free()
	app._cancel_selected_preparation()
	app.free()
	for i: int in range(8): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("SELECTED_EVENTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
