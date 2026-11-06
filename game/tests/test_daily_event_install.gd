extends SceneTree
const Fixture=preload("res://tests/test_daily_metadata_catalog.gd")
const Events=preload("res://tests/test_selected_events.gd")
var checks: int=0
var failures: int=0
class DailyApp extends Fixture.DailyApp:
	var limits_requests: int=0
	func _load_daily_limits(track: NativeTrack,vehicle: String,request: Dictionary) -> RefCounted:
		limits_requests+=1
		return super._load_daily_limits(track,vehicle,request)
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var folder: String=ProjectSettings.globalize_path("res://../build/selected-events-retention-20261104/daily-install-"+TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	NativeTrackVisual.ROAD_DISK_CACHE.directory=folder.path_join("roads")
	var app:=DailyApp.new()
	app.records=LocalRecords.new(folder.path_join("records.json")); app.records.settings.music_enabled=false
	app.library=TrackLibrary.new(folder.path_join("library")); app.cloud_root_override=folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.set_process(false)
	app.screen="daily"
	var source: Dictionary=TrackDocument.create_default()
	var body: String=JSON.stringify(source)
	var path: String=folder.path_join("track.json"); FileAccess.open(path,FileAccess.WRITE).store_string(body)
	var entry: Dictionary={"id":"cloud_daily_selected","track_id":"daily_selected","version_id":"00000000-0000-4000-8000-000000000001","content_hash":body.sha256_text(),"cache_path":path,"name":"Selected Daily","creator":"Fixture","theme":"pine","points":source.points}
	var page:=Events.Daily.new(); page.entry=entry; page._sample_msec=Time.get_ticks_msec(); app.add_child(page)
	app._prepare_selected_event("daily",page,entry)
	app._selected_preparation_event.due=0
	var deadline: int=Time.get_ticks_msec()+45000
	while app._selected_preparation_pending and Time.get_ticks_msec()<deadline: await process_frame
	var prepared: NativeTrack=app.selected_track
	check(not app._selected_preparation_pending and prepared!=null and not prepared.metadata.get("metadata_only",false),"Daily prepares before its race tap")
	check(app._selected_event_track(entry)==prepared,"Daily handler selects the hydrated exact object")
	await app._start_race(prepared,false,false,{},null,{"day":page._server_now/86400,"version_id":entry.version_id})
	check(app.game!=null and app.game.preparation_complete,"selected Daily reaches the actual native Game")
	if app.game!=null:
		app.game.set_physics_process(false)
		check(app.game.native_track==prepared,"actual Daily install consumes the prepared object")
		check(app.game.daily_elimination!=null and app.game.track_session.target_laps==10,"fresh Daily limits install the original ten-lap event")
		check(app.game.sim.state.tick==0 and app.game.countdown_ticks==360,"early preparation advances no race clock")
		check(app.limits_requests==1,"early geometry never substitutes for fresh Daily limits")
		app._leave_race()
	app.queue_free()
	for i: int in range(12): await process_frame
	print("DAILY_EVENT_INSTALL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
