extends SceneTree
## Real app retention, exact native pixels and controlled out-of-order replies.
var checks: int = 0
var failures: int = 0
var output: String
var report: Dictionary = {}
var app: Node
var native_low: PackedByteArray
var native_high: PackedByteArray

class ProbeApp extends "res://core/app.gd":
	var preparations: Array[float] = []
	var constructions: Array[Dictionary] = []
	func _prepare_menu_neighbors_frame(generation: int) -> void:
		var began: int = Time.get_ticks_usec()
		super._prepare_menu_neighbors_frame(generation)
		preparations.append((Time.get_ticks_usec()-began)/1000.0)
	func _garage(parent: Control = null) -> void:
		var old: GaragePage = _retained_garage
		var began: int = Time.get_ticks_usec()
		super._garage(parent)
		if old != _retained_garage:
			constructions.append({"screen":screen,"ms":(Time.get_ticks_usec()-began)/1000.0})

class Service extends Node:
	var player: Dictionary = {"id":"audit-a"}
	var jobs: Array[Dictionary] = []
	func base_url() -> String: return "http://offline-menu-fixture.invalid"
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "menu-fixture-operation"
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		var job: Dictionary = {"path":path,"done":false,"response":{}}
		jobs.append(job)
		while not job.done: await get_tree().process_frame
		return job.response
	func finish(index: int, response: Dictionary) -> void:
		jobs[index].response = response
		jobs[index].done = true

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func frames(count: int = 5) -> void:
	for _index: int in range(count):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func settle() -> void:
	await create_timer(0.4).timeout
	await frames()

func fixture(id: String) -> Dictionary:
	return {"id":id,"code":"AB12CD34EF56AB78" if id=="received" else "CD34EF56AB78CD12","mode":"group","state":"active","entry":{"name":id,"version_id":"version","track_id":"track","content_hash":"hash","points":[[0,0],[10,10]]},"manifest":{"laps":5,"tick_rate":120},"standings":[{"id":"audit-a","name":"Fixture","ticks":null,"ms":null,"rank":null,"run_id":null}],"vehicle_id":"compact","ends_at":604800,"server_now":0,"creator_id":"audit-a","creator":"Fixture","joined":true,"self_id":"audit-a","share_url":"https://offline.invalid/fixture"}

func listing(id: String, cursor: String = "") -> Dictionary:
	return {"ok":true,"data":{"items":[fixture(id)],"next_cursor":cursor},"error":""}

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_MENU_FIX_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../docs/evidence/menu-high-priority-fixes-2026-10-14/headless")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var folder: String = "user://menu_high_priority_"+TrackLibrary.unique_id()
	app = ProbeApp.new()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+20000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete and app.screen=="account","guest startup completes on the original account screen")
	# The concurrently added native record player animates with menu playback.
	# Pause the test soundtrack so full-frame comparisons use the same pose.
	# Runtime audio/playback preferences and animation are unchanged.
	GameSoundtrack.instance().music_enabled = false
	report.static_pixel_fixture_music_paused = true
	check(app.constructions.size()==1 and app.constructions[0].screen=="restoring","the one native construction runs behind the startup cover")
	var garage: GaragePage = app._retained_garage
	var view: CarShowroom = garage.showroom
	var world: SubViewport = view.showroom_viewport
	var model: CarVisual = view.car
	check(world.size.x>1 and world.size.y>1,"covered preparation lays out the actual native viewport before hiding it")
	check(not garage.is_visible_in_tree() and not garage.can_process(),"prepared Garage is hidden and inactive")
	for reflection: SubViewport in view.reflections.views:
		check(reflection.render_target_update_mode==SubViewport.UPDATE_DISABLED,"startup captures stop after the covered draws")
	app.race_area_mode = "free"
	app._show_screen("tracks")
	await settle()
	check(app.menu_neighbors.size()==3,"all three real swipe neighbors become ready")
	check(app._retained_garage==garage and app.constructions.size()==1,"Race preparation reuses the startup Garage")
	# Repeated scheduling in one frame must coalesce without engine signal errors.
	app._prepare_menu_neighbors(app._navigation_generation)
	app._prepare_menu_neighbors(app._navigation_generation)
	await frames()
	check(app.menu_neighbors.size()==3,"duplicate preparation leaves the same bounded neighbor set")
	var dispatch: Array[float] = []
	for _round: int in range(2):
		app._show_screen("settings")
		await frames(2)
		var began: int = Time.get_ticks_usec()
		app._show_screen("tracks")
		dispatch.append((Time.get_ticks_usec()-began)/1000.0)
		await settle()
		check(app._retained_garage==garage and app.constructions.size()==1,"Settings round trip does not reconstruct native cars")
	app._navigate_menu_page("garage")
	await settle()
	check(app.content.find_child("GaragePage",true,false)==garage,"Garage navigation attaches the exact prepared page")
	check(garage.showroom==view and view.car==model and view.showroom_viewport==world,"native car, world and viewport identities survive promotion")
	check(garage.find_child("GarageCar_compact",true,false).mouse_filter==Control.MOUSE_FILTER_STOP,"retained car cards preserve their authored input state")
	if DisplayServer.get_name()!="headless": await compare_native_pixels(garage)
	view.zoom_by(0.84)
	view.rotate_view(Vector2(19,-5))
	var camera_pose: Transform3D = view.camera.transform
	var deck_pose: Transform3D = view.turntable.transform
	var condition: Dictionary = view.weathering.snapshot()
	var paint: Dictionary = garage.draft.duplicate(true)
	await frames()
	# Measure the native hide/show path at the same zoomed pose before changing
	# any menu shell. This catches renderer precision separately from retention.
	var pre_visibility: Image = world.get_texture().get_image() if DisplayServer.get_name()!="headless" else null
	view.hide()
	await frames(3)
	view.show()
	await frames(8)
	var before_layout: Dictionary = layout_snapshot(garage)
	var same_world_image: Image = view.showroom_viewport.get_texture().get_image() if DisplayServer.get_name()!="headless" else null
	var same_world_pixels: PackedByteArray = same_world_image.get_data() if same_world_image!=null else PackedByteArray()
	if pre_visibility != null:
		report.same_world_visibility_control = {"before_size":str(pre_visibility.get_size()),"after_size":str(same_world_image.get_size()),"same_pixels":pre_visibility.get_data()==same_world_pixels}
		native_low = same_world_pixels.duplicate()
		native_high = same_world_pixels.duplicate()
		# Native MSAA/shadow output can vary by a colour level when an unchanged
		# world is hidden and shown. Measure those exact bytes before navigation;
		# no fixed tolerance, geometry mask or post-navigation sample is accepted.
		for _sample: int in range(12):
			view.hide()
			await frames(2)
			view.show()
			await frames(3)
			var sample: PackedByteArray = world.get_texture().get_image().get_data()
			check(sample.size()==native_low.size(),"original native visibility control retains its pixel dimensions")
			if sample.size()!=native_low.size(): continue
			for index: int in range(sample.size()):
				native_low[index] = mini(native_low[index],sample[index])
				native_high[index] = maxi(native_high[index],sample[index])
		var varying: int = 0
		var largest: int = 0
		for index: int in range(native_low.size()):
			if native_low[index]!=native_high[index]: varying += 1
			largest = maxi(largest,native_high[index]-native_low[index])
		report.same_world_visibility_control.varying_bytes = varying
		report.same_world_visibility_control.max_delta = largest
	if DisplayServer.get_name()!="headless": view.showroom_viewport.get_texture().get_image().save_png(output.path_join("before-settings.png"))
	app._show_screen("settings")
	check(not app._suspended_menu.is_empty() and app._suspended_menu.root.is_ancestor_of(garage),"Settings keeps the original menu and Garage attached to the tree")
	app._show_screen("garage")
	await settle()
	check(garage.showroom==view and view.car==model and view.showroom_viewport==world,"explicit shell rebuild retains native scene objects")
	check(view.camera.transform==camera_pose and view.turntable.transform==deck_pose,"shell rebuild preserves exact camera, zoom and car pose")
	check(view.weathering.snapshot()==condition and garage.draft==paint,"shell rebuild preserves local condition and pigments")
	if DisplayServer.get_name()!="headless":
		var restored: Image = view.showroom_viewport.get_texture().get_image()
		restored.save_png(output.path_join("after-settings.png"))
		var restored_bytes: PackedByteArray = restored.get_data()
		var changed: int = 0
		var maximum: int = 0
		if restored_bytes.size()==same_world_pixels.size():
			var stride: int = restored_bytes.size()/(restored.get_width()*restored.get_height())
			for pixel: int in range(restored.get_width()*restored.get_height()):
				var delta: int = 0
				for channel: int in range(stride): delta = maxi(delta,absi(int(restored_bytes[pixel*stride+channel])-int(same_world_pixels[pixel*stride+channel])))
				if delta>0: changed += 1
				maximum = maxi(maximum,delta)
		report.settings_pixels = {"changed":changed,"max_delta":maximum,"same_byte_count":restored_bytes.size()==same_world_pixels.size(),"before_byte_count":same_world_pixels.size(),"after_byte_count":restored_bytes.size(),"before_layout":before_layout,"after_layout":layout_snapshot(garage)}
		# Preserve exact dimensions; each byte must stay inside the unchanged
		# world's pre-navigation visibility samples.
		var projected: Array[Vector2] = []
		_project_car(view.car,view.camera,projected)
		var low: Vector2 = projected[0]
		var high: Vector2 = low
		for point: Vector2 in projected:
			low = low.min(point)
			high = high.max(point)
		var car_rect: Rect2i = Rect2i(Rect2(low,high-low).grow(2)).intersection(Rect2i(Vector2i.ZERO,restored.get_size()))
		report.settings_pixels.whole_image_equal = restored_bytes==same_world_pixels
		report.settings_pixels.car_rect = str(car_rect)
		check(restored.get_size()==same_world_image.get_size(),"Settings return retains exact display-pixel dimensions")
		check(in_native_envelope(restored_bytes),"Settings return matches the original native visibility control at every pixel")
		check(restored.get_size()==same_world_image.get_size() and in_native_envelope(restored_bytes),"Settings return retains actual car pixels within the pre-navigation native control")
		report.settings_pixels.repeated_returns = []
		for _round: int in range(6):
			app._show_screen("settings")
			app._show_screen("garage")
			await settle()
			var repeated: Image = world.get_texture().get_image()
			report.settings_pixels.repeated_returns.append({"control":str(view.size),"viewport":str(world.size),"same_pixels":repeated.get_data()==same_world_pixels})
			check(in_native_envelope(repeated.get_data()),"repeated Settings returns preserve viewport dimensions and native-control pixels")
	app._show_screen("tracks")
	check(app.outgoing_menu_page.is_ancestor_of(garage),"departing Garage remains drawn throughout its outgoing slide")
	await settle()
	app._navigate_menu_page("garage")
	await settle()
	check(garage.find_child("GarageCar_compact",true,false).mouse_filter==Control.MOUSE_FILTER_STOP,"outgoing slide does not permanently disable retained car controls")
	check(app.constructions.size()==1,"ordinary menu traffic still owns one native Garage")
	app._show_screen("settings")
	app._show_screen("play")
	await settle()
	check(app.screen=="tracks" and app._suspended_menu.is_empty(),"retired Home alias restores the retained Race shell")
	app._show_screen("settings")
	app._show_screen("drafts")
	await settle()
	check(app._suspended_menu.is_empty(),"leaving Settings for a draft library releases the old shell")
	app._navigate_menu_page("garage")
	await settle()
	check(app.content.find_child("GaragePage",true,false)==garage,"draft-library navigation cannot promote an empty stale Garage slot")
	var race_wear: Dictionary = view.weathering.snapshot()
	race_wear.dirt = 0.67
	check(VehicleCondition.save(app.records,garage.vehicle_id,race_wear)==OK,"post-race cosmetic fixture is saved under the current owner")
	app._show_screen("tracks")
	await settle()
	check(garage.thumbnails[garage.vehicle_id].condition==race_wear,"retained carousel photograph receives newer race condition")
	app._navigate_menu_page("garage")
	await settle()
	check(is_equal_approx(view.weathering.dirt_amount,0.67) and view.car==model,"live native car receives newer race wear without reconstruction")
	report.menu = {"covered_construction":app.constructions.duplicate(true),"neighbor_callback_ms":app.preparations.duplicate(),"settings_return_dispatch_ms":dispatch,"native_views_retained":6}
	await test_folders()
	# Changing storage invalidates retained cosmetics and supersedes old cover work.
	var next_records := LocalRecords.new(folder.path_join("other/records.json"))
	app.records = next_records
	app._show_screen("garage")
	deadline = Time.get_ticks_msec()+20000
	while app.screen!="garage" and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	check(app.screen=="garage" and app._retained_garage.records==next_records,"new profile receives its own prepared Garage")
	check(not is_instance_valid(garage),"previous profile's native page is released")
	check(app.constructions.size()==2 and app.constructions[1].screen=="restoring","replacement profile construction stays behind its cover")
	app.queue_free()
	await frames(3)
	report.checks = checks
	report.failures = failures
	report.renderer = RenderingServer.get_current_rendering_method()
	report.display = DisplayServer.get_name()
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MENU_HIGH_PRIORITY ",JSON.stringify(report))
	quit(1 if failures else 0)

func in_native_envelope(bytes: PackedByteArray) -> bool:
	if bytes.size()!=native_low.size(): return false
	for index: int in range(bytes.size()):
		if bytes[index]<native_low[index] or bytes[index]>native_high[index]: return false
	return true

func layout_snapshot(garage: GaragePage) -> Dictionary:
	var values: Dictionary = {}
	for control: Control in [app.root_ui,app.menu_body_slot,app.menu_body,app.content,garage,garage._layout,garage._rail_slot,garage.main,garage._preview_slot,garage.preview,garage.showroom]:
		values[control.name] = {"size":str(control.size),"minimum":str(control.get_combined_minimum_size()),"position":str(control.position),"scale_x":"%.14f" % control.scale.x,"scale_y":"%.14f" % control.scale.y}
	values.viewport = str(garage.showroom.showroom_viewport.size)
	return values

func compare_native_pixels(garage: GaragePage) -> void:
	# A fresh synchronous construction is the original native geometry/render path.
	var reference := GaragePage.new()
	reference.records = app.records
	root.add_child(reference)
	reference.position = garage.global_position
	reference.size = garage.size
	await frames(8)
	var retained: Image = garage.showroom.showroom_viewport.get_texture().get_image()
	var original: Image = reference.showroom.showroom_viewport.get_texture().get_image()
	var left: PackedByteArray = retained.get_data()
	var right: PackedByteArray = original.get_data()
	var changed: int = 0
	var maximum: int = 0
	var total_delta: int = 0
	var bounds := Rect2i()
	var stride: int = left.size()/(retained.get_width()*retained.get_height())
	for pixel: int in range(retained.get_width()*retained.get_height()):
		var delta: int = 0
		for channel: int in range(stride): delta = maxi(delta,absi(int(left[pixel*stride+channel])-int(right[pixel*stride+channel])))
		if delta==0: continue
		var at := Vector2i(pixel%retained.get_width(),pixel/retained.get_width())
		bounds = Rect2i(at,Vector2i.ONE) if changed==0 else bounds.merge(Rect2i(at,Vector2i.ONE))
		changed += 1
		maximum = maxi(maximum,delta)
		total_delta += delta
	report.native_pixels = {"changed":changed,"max_delta":maximum,"bounds":str(bounds),"camera_equal":garage.showroom.camera.transform==reference.showroom.camera.transform,"deck_equal":garage.showroom.turntable.transform==reference.showroom.turntable.transform,"view_sizes_equal":garage.showroom.showroom_viewport.size==reference.showroom.showroom_viewport.size,"condition_equal":garage.showroom.weathering.snapshot()==reference.showroom.weathering.snapshot()}
	report.native_pixels.reflections = []
	for index: int in range(2):
		var retained_rig: GarageReflections = garage.showroom.reflections
		var fresh_rig: GarageReflections = reference.showroom.reflections
		report.native_pixels.reflections.append({"sizes":str([retained_rig.views[index].size,fresh_rig.views[index].size]),"camera_equal":retained_rig.cameras[index].transform==fresh_rig.cameras[index].transform,"fov_equal":retained_rig.cameras[index].fov==fresh_rig.cameras[index].fov,"aspect_equal":retained_rig.cameras[index].keep_aspect==fresh_rig.cameras[index].keep_aspect,"pixels_equal":retained_rig.views[index].get_texture().get_image().get_data()==fresh_rig.views[index].get_texture().get_image().get_data()})
	check(retained.get_size()==original.get_size(),"retained and original native views have identical display-pixel dimensions")
	# Freeze menu playback above: the actual record-station animation otherwise
	# makes independently sampled native frames differ in the workshop.
	report.native_pixels.independent_main_equal = retained.get_data()==original.get_data()
	check(report.native_pixels.reflections.all(func(rig: Dictionary) -> bool: return rig.pixels_equal),"retained native reflection captures exactly match fresh construction")
	retained.save_png(output.path_join("retained-garage.png"))
	original.save_png(output.path_join("fresh-garage.png"))
	reference.queue_free()
	await frames(3)

	var control := GaragePage.new()
	control.records = app.records
	root.add_child(control)
	control.position = garage.global_position
	control.size = garage.size
	await frames(8)
	var control_bytes: PackedByteArray = control.showroom.showroom_viewport.get_texture().get_image().get_data()
	var control_changed: int = 0
	var control_maximum: int = 0
	var control_total: int = 0
	for pixel: int in range(original.get_width()*original.get_height()):
		var delta: int = 0
		for channel: int in range(stride): delta = maxi(delta,absi(int(right[pixel*stride+channel])-int(control_bytes[pixel*stride+channel])))
		if delta>0: control_changed += 1
		control_maximum = maxi(control_maximum,delta)
		control_total += delta
	report.native_pixels.fresh_vs_fresh_changed = control_changed
	report.native_pixels.fresh_vs_fresh_max_delta = control_maximum
	report.native_pixels.total_delta = total_delta
	report.native_pixels.fresh_vs_fresh_total_delta = control_total
	# Two unchanged independently constructed rooms also differ in a few gallery
	# light pixels. Neither the changed count nor summed maximum-channel delta
	# may exceed that contemporaneous original-path control. Complete reflection
	# captures still require exact byte equality.
	check(changed<=control_changed and total_delta<=control_total,"retained/fresh native differences do not exceed the original fresh/fresh control")
	control.hide()
	await frames(3)
	control.show()
	await frames(8)
	var shown_bytes: PackedByteArray = control.showroom.showroom_viewport.get_texture().get_image().get_data()
	var visibility_changed_pixels: int = 0
	var visibility_maximum: int = 0
	for pixel: int in range(original.get_width()*original.get_height()):
		var delta: int = 0
		for channel: int in range(stride): delta = maxi(delta,absi(int(control_bytes[pixel*stride+channel])-int(shown_bytes[pixel*stride+channel])))
		if delta>0: visibility_changed_pixels += 1
		visibility_maximum = maxi(visibility_maximum,delta)
	report.native_pixels.original_visibility_changed = visibility_changed_pixels
	report.native_pixels.original_visibility_max_delta = visibility_maximum
	control.queue_free()
	await frames(3)

func _project_car(node: Node3D, camera: Camera3D, points: Array[Vector2]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.mesh.get_aabb()
		for index: int in range(8): points.append(camera.unproject_position(node.global_transform*bounds.get_endpoint(index)))
	for child: Node in node.get_children():
		if child is Node3D: _project_car(child,camera,points)

func test_folders() -> void:
	var service := Service.new()
	app.add_child(service)
	var adapter: ChallengesClient = app.challenges
	adapter.client = service
	adapter.reset()
	adapter.folder = "received"
	app._show_screen("challenges")
	app._stop_menu_page_motion()
	adapter.refresh()
	var page: ChallengesPage = app.content.find_child("ChallengesPage",true,false)
	(page.find_child("ChallengeTab_sent",true,false) as Button).pressed.emit()
	page = app.content.find_child("ChallengesPage",true,false)
	check(page.folder=="sent" and page.busy,"real Sent control immediately publishes the latest folder/loading state")
	check(service.jobs.size()==1,"pending folder changes coalesce without another concurrent request")
	service.finish(0,listing("received","old-cursor"))
	await frames()
	check(service.jobs.size()==2 and service.jobs[1].path=="/challenges?folder=sent","old completion starts the newest folder without its stale cursor")
	check(adapter.items.is_empty() and adapter.busy,"stale Received rows never appear under Sent")
	service.finish(1,listing("sent"))
	await frames()
	page = app.content.find_child("ChallengesPage",true,false)
	check(not page.busy and page.folder=="sent" and page.items.size()==1 and page.items[0].id=="sent","Sent reply clears loading and presents its own rows")
	var count: int = service.jobs.size()
	adapter.select_folder("sent")
	check(service.jobs.size()==count and adapter.items.size()==1,"reselecting the current folder retains rows and performs no call")
	adapter.select_folder("received")
	var pending: int = service.jobs.size()-1
	adapter.select_folder("sent")
	adapter.select_folder("received")
	service.finish(pending,listing("received"))
	await frames()
	check(service.jobs.size()==pending+1 and not adapter.busy and adapter.items[0].id=="received","rapid return to the in-flight folder reuses that reply")
	adapter.select_folder("sent")
	pending = service.jobs.size()-1
	adapter.select_folder("received")
	adapter.select_folder("sent")
	adapter.select_folder("received")
	service.finish(pending,{"ok":false,"error":"NETWORK_ERROR"})
	await frames()
	check(service.jobs[-1].path=="/challenges?folder=received" and adapter.busy,"even an old-folder failure drains only the newest intent")
	service.finish(service.jobs.size()-1,{"ok":false,"error":"NETWORK_ERROR"})
	await frames()
	check(not adapter.busy and not adapter.error.is_empty(),"latest-folder failure clears busy and leaves an actionable error")
	# Detail requests may overlap a list request; only the current request owns busy.
	adapter.refresh()
	pending = service.jobs.size()-1
	adapter.open(str(fixture("received").code))
	var detail: int = service.jobs.size()-1
	service.finish(pending,listing("received"))
	await frames()
	check(adapter.busy,"old list response cannot clear a newer detail request's busy state")
	adapter.select_folder("sent")
	service.finish(detail,{"ok":true,"data":fixture("received")})
	await frames()
	check(adapter.selected.is_empty() and service.jobs[-1].path=="/challenges?folder=sent","folder selection supersedes a pending detail and starts its list")
	service.finish(service.jobs.size()-1,listing("sent"))
	await frames()
	check(not adapter.busy and adapter.items[0].id=="sent","folder change during detail finishes normally")
	adapter.next_cursor = "old-page-two"
	adapter.refresh(true)
	pending = service.jobs.size()-1
	adapter.select_folder("received")
	adapter.select_folder("sent")
	service.finish(pending,listing("sent","old-page-three"))
	await frames()
	check(adapter.busy and adapter.items.is_empty() and service.jobs[-1].path=="/challenges?folder=sent","return during pagination restarts at the first page without a stale cursor")
	service.finish(service.jobs.size()-1,listing("sent"))
	await frames()
	adapter.create_challenge({"mode":"group","vehicle_id":"compact","version_id":"version"})
	pending = service.jobs.size()-1
	adapter.select_folder("received")
	service.finish(pending,{"ok":true,"data":fixture("sent")})
	await frames()
	check(adapter.busy and adapter.selected.is_empty() and service.jobs[-1].path=="/challenges?folder=received","folder change during a mutation drains after its owned reply")
	service.finish(service.jobs.size()-1,listing("received"))
	await frames()
	check(not adapter.busy and adapter.items[0].id=="received","mutation completion cannot restore an obsolete selection or strand loading")
	adapter.select_folder("sent")
	pending = service.jobs.size()-1
	service.player = {"id":"audit-b"}
	adapter.reset()
	adapter.refresh()
	var new_owner: int = service.jobs.size()-1
	service.finish(pending,listing("received"))
	await frames()
	check(adapter.busy and adapter.items.is_empty(),"previous account reply cannot clear or populate the new account request")
	service.finish(new_owner,{"ok":true,"data":{"items":[],"next_cursor":""}})
	await frames()
	check(not adapter.busy and adapter.items.is_empty(),"new account request completes independently")
	report.challenge_paths = []
	for job: Dictionary in service.jobs: report.challenge_paths.append(job.path)
