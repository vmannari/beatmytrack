extends "res://tests/audit_race_work_recheck.gd"
## Retain the original demand-work assertions; replace the old counterexamples
## with regression checks for deferred completion, ownership and event wakeups.
const Snapshots = preload("res://backend/menu_snapshot_writer.gd")
const HeaderIcons = preload("res://ui/header_car_icons.gd")
const Jobs = preload("res://editor/work_job.gd")

class ObservedPreloader extends "res://ui/garage_preloader.gd":
	var wakeups: int = 0
	func invalidate() -> void:
		wakeups += 1
		super.invalidate()

func _initialize() -> void:
	var config := ConfigFile.new()
	config.set_value("backend","url","")
	assert(config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
	output = "res://../build/race-optional-work-fixes-2026-10-27/focused.json"
	super._initialize()

func audit_extras(client: Node, folder: String) -> void:
	client.phase = "natural_race_window"
	var before: Dictionary = quiet_counters()
	await create_timer(35.0).timeout
	var after: Dictionary = quiet_counters()
	check(paths(client,client.phase).is_empty(),"35-second race sends no optional HTTP")
	check(after.tick>before.tick and not app.game.paused,"race continues advancing during the natural window")
	check(after.header_captures==before.header_captures and after.header_disk_hits==before.header_disk_hits and after.header_active_worlds==0,"natural race starts no header captures or reads")
	check(after.snapshot_writes==before.snapshot_writes and after.cloud_flush_passes==before.cloud_flush_passes,"natural race dispatches no snapshot or old-upload work")
	check(after.editor_memory_sample==before.editor_memory_sample,"natural race leaves ordinary editor inventory asleep")
	report.observations.natural_window = {"before":before,"after":after,"http":paths(client,client.phase)}
	await snapshots(folder)
	await completed_images()
	await sleeping_preloader()
	await paused_presentation()

func snapshots(folder: String) -> void:
	var writer: Node = Snapshots.shared()
	var destination: String = folder.path_join("late-snapshot.json")
	var writes: int = writer.completed_writes
	for value: int in range(4): Snapshots.queue(destination,{"scope":"private-late","value":value})
	await frames(8)
	check(not app._background_work_allowed(),"snapshot probe uses the actual closed race policy")
	check(writer.completed_writes==writes and writer.active==null and not FileAccess.file_exists(destination),"late snapshots cannot dispatch during racing")
	check(Snapshots.peek(destination,"private-late").get("value")==3 and writer.pending.size()==1,"deferred snapshots retain immediate latest RAM value and coalesce")
	check(Snapshots.peek(destination,"another-owner").is_empty(),"deferred RAM snapshots retain their scope fence")
	check(not writer.is_processing(),"blocked snapshot writer sleeps")
	# Recreate a real write admitted before the policy closed. It must finish
	# without dispatching the other queued path behind it.
	var active_path: String = folder.path_join("already-active.json")
	writer.active_value = {"path":active_path,"payload":{"scope":"private-active","value":7}}
	writer.active = Jobs.start(Snapshots._write.bind(writer.active_value),self)
	writer.set_process(true)
	var deadline: int = Time.get_ticks_msec()+5000
	while writer.active!=null and Time.get_ticks_msec()<deadline: await process_frame
	check(FileAccess.file_exists(active_path) and writer.completed_writes==writes+1,"already admitted atomic snapshot finishes while policy is closed")
	check(not FileAccess.file_exists(destination) and writer.pending.has(destination) and not writer.is_processing(),"finishing a write does not dispatch another blocked snapshot")
	# Only the writer's test policy opens; all actual App/network race gates
	# remain closed. Ordinary navigation must wake the sleeping writer.
	var policy: Callable = writer.background_allowed
	writer.background_allowed = func() -> bool: return true
	app._race_menu_visible(false)
	deadline = Time.get_ticks_msec()+5000
	while not Snapshots.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(Snapshots.idle() and FileAccess.file_exists(destination),"menu lifecycle event wakes queued snapshots")
	check(Snapshots.IO.read(destination).get("value")==3,"resumed disk snapshot contains the latest value")
	writer.background_allowed = policy
	report.observations.deferred_snapshot = {"latest":Snapshots.IO.read(destination),"completed_writes":writer.completed_writes-writes}

func ready_image(cache: Node, kind: String, key: String) -> Image:
	var pixels := Image.create(176,112,false,Image.FORMAT_RGBA8)
	pixels.fill(Color(0.1,0.2,0.3,1))
	var ready := CompletedIconIO.new()
	ready.result = {"image":pixels}
	cache._io = ready
	cache._io_job = {"vehicle":"compact","key":key,"epoch":cache._epoch}
	cache._io_kind = kind
	return pixels

func completed_images() -> void:
	var cache: Node = app.header_car_cache
	var policy: Callable = cache.allowed
	var owner: LocalRecords = cache.records
	var key: String = HeaderIcons.appearance_key("compact",owner)
	var previous: Variant = HeaderIcons.customized.get(key)
	var had_previous: bool = HeaderIcons.customized.has(key)
	var changes: Array[int] = [0]
	var changed: Callable = func(_vehicle: String) -> void: changes[0]+=1
	cache.changed.connect(changed)
	for kind: String in ["read","write"]:
		HeaderIcons.customized.erase(key)
		changes[0] = 0
		var hits: int = cache.disk_hits
		var image: Image = ready_image(cache,kind,key)
		cache._process(0.0)
		await frames(4)
		check(cache._io!=null and cache._io.done,"completed "+kind+" remains held until its consumer is allowed")
		check(not HeaderIcons.customized.has(key) and not image.has_mipmaps() and changes[0]==0 and cache.disk_hits==hits,"blocked "+kind+" performs no texture/mipmap publication or notification")
		cache.allowed = func() -> bool: return true
		cache._process(0.0)
		check(HeaderIcons.customized.has(key) and changes[0]==1 and cache._io==null,"eligible "+kind+" publishes exactly once")
		check(cache.disk_hits==hits+(1 if kind=="read" else 0),"only an eligible disk read increments the hit counter")
		cache._process(0.0)
		check(changes[0]==1,"completed "+kind+" is never published twice")
		cache.allowed = policy
	HeaderIcons.customized.erase(key)
	ready_image(cache,"read",key)
	cache._process(0.0)
	cache.bind_records(LocalRecords.new(owner.path.get_base_dir().path_join("other-owner/records.json")))
	cache.allowed = func() -> bool: return true
	cache._process(0.0)
	check(not HeaderIcons.customized.has(key) and cache._io==null,"account replacement discards a held completed image")
	cache.bind_records(owner)
	cache.allowed = policy
	ready_image(cache,"read",key)
	cache._process(0.0)
	var original: Variant = owner.settings.get("vehicle_liveries")
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "8a42cc"
	owner.settings.vehicle_liveries = {"compact":paint}
	cache.allowed = func() -> bool: return true
	cache._process(0.0)
	check(not HeaderIcons.customized.has(key) and cache._io==null,"appearance replacement discards a held completed image")
	if original==null: owner.settings.erase("vehicle_liveries")
	else: owner.settings.vehicle_liveries = original
	cache.allowed = policy
	# Race entry may occur between _process and frame_post_draw. No readback
	# or new write may start after permission closes in that interval.
	var captures: int = cache.captures
	cache.canvas = SubViewport.new()
	cache.add_child(cache.canvas)
	cache._stage = "draw"
	cache._draws = 5
	cache._current = {"vehicle":"compact","key":key,"epoch":cache._epoch,"read":false}
	cache._after_draw()
	check(cache.canvas==null and cache._io==null and cache.captures==captures,"late draw completion skips readback after race entry")
	check(cache._jobs.size()==1 and cache._jobs[0].key==key,"late draw retains one scoped recapture for menu return")
	cache._jobs.clear()
	cache.changed.disconnect(changed)
	if had_previous: HeaderIcons.customized[key] = previous
	else: HeaderIcons.customized.erase(key)

func sleeping_preloader() -> void:
	var loader: Node = app._garage_preloader
	var deadline: int = Time.get_ticks_msec()+5000
	while not loader._pending.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	await frames(3)
	check(not loader.has_work() and not loader.is_processing(),"empty preloader sleeps during active racing")
	loader.invalidate()
	check(loader.is_processing(),"appearance or navigation invalidation wakes a suspended preloader")
	loader._process(0.0)
	check(not loader.is_processing() and not loader.has_work(),"a wake during racing retires optional work and sleeps again")
	loader.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(loader.is_processing(),"foreground lifecycle wakes a suspended preloader")
	await frames(2)
	check(not loader.is_processing(),"foreground wake cannot start race-time preload")
	var resource_path: String = "res://assets/menu/icon.png"
	check(ResourceLoader.load_threaded_request(resource_path)==OK,"load-reaping control starts an actual resource request")
	loader._pending.append(resource_path)
	loader.invalidate()
	deadline = Time.get_ticks_msec()+5000
	while loader.is_processing() and Time.get_ticks_msec()<deadline: await process_frame
	check(loader._pending.is_empty() and loader._resources.is_empty() and not loader.is_processing(),"in-flight asset reads are consumed before race-time suspension")
	var observed := ObservedPreloader.new()
	observed.app = app
	app._garage_preloader = observed
	app.add_child(observed)
	loader.queue_free()
	app.cloud_starting = true
	await frames(2)
	var wakeups: int = observed.wakeups
	app.cloud_starting = false
	await frames(2)
	check(observed.wakeups>wakeups,"loading-state event wakes a suspended preloader")
	check(not observed.is_processing(),"loading completion still respects the active-game guard")

func paused_presentation() -> void:
	var current: Node = app.game
	# The inherited transport fixture intentionally has uncommitted synthetic
	# appearance recovery data. Camera persistence gets its own valid store.
	var original_preferences: LocalRecords = current.preference_records
	var preferences_path: String = original_preferences.path.get_base_dir().path_join("pause-preferences/records.json")
	check(DirAccess.make_dir_recursive_absolute(preferences_path.get_base_dir())==OK,"create isolated camera-preference directory")
	current.preference_records = LocalRecords.new(preferences_path)
	current.toggle_pause(false)
	await frames(4)
	var state: Dictionary = RewindHistory.properties(current.sim.state)
	var updates: int = current.presentation_world_updates
	await frames(8)
	check(current.presentation_world_updates==updates and not current._paused_presentation_key.is_empty(),"unchanged pause freezes world presentation with its retained key")
	check(RewindHistory.properties(current.sim.state)==state,"pause optimization leaves canonical state exact")
	check(current.set_camera_mode("follow_car" if current.camera.mode!="follow_car" else "overhead")==OK,"paused camera setting persists to its isolated valid store")
	await frames(4)
	check(current.presentation_world_updates>updates,"paused camera changes still invalidate presentation")
	updates = current.presentation_world_updates
	var size_before: Vector2i = root.size
	root.size += Vector2i(16,0)
	await frames(4)
	check(current.presentation_world_updates>updates,"paused viewport changes still invalidate presentation")
	root.size = size_before
	current.toggle_pause(false)
	await frames(4)
	check(current._paused_presentation_key.is_empty() and not current.paused,"unpaused frames retain no pause-only key")
	check(current.frame.throttle==0 and current.frame.steer==0,"resume still clears held controls")
	current.preference_records = original_preferences

# The retained-world audit needs the completed studio's three viewports. A cold
# staged opening can still own its temporary preparation viewport after _ready.
var _initial_garage_ready: bool = false

func _studio_preparing(studio: Node) -> bool:
	var value: Variant = studio.get("preparing")
	return value if value is bool else false

func frames(count: int = 8) -> void:
	await super.frames(count)
	if _initial_garage_ready or not is_instance_valid(app) or app.screen != "garage" or not is_instance_valid(app._retained_garage): return
	var studio: Node = app._retained_garage.showroom
	var deadline: int = Time.get_ticks_msec()+120000
	while is_instance_valid(studio) and _studio_preparing(studio) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(is_instance_valid(studio) and studio.showroom_ready and not _studio_preparing(studio),"Complete retained Garage before the original three-viewport audit")
	_initial_garage_ready = true
