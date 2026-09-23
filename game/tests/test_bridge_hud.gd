extends SceneTree
## Native and creator bridge presentation plus real HUD layout/state witnesses.
var checks: int = 0
var failures: int = 0
var capture: bool = false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)

func circuit() -> NativeTrack:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.id = "bridge_hud_review"
	doc.name = "Overpass circuit"
	var points: Array[Vector2] = [Vector2(-48,0),Vector2(-30,0),Vector2(30,0),Vector2(50,26),Vector2(0,42),Vector2(0,-42),Vector2(-50,-26)]
	for i: int in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var piece: Dictionary = RoadPieces.create("bridge" if i == 1 else "straight",a,fposmod(rad_to_deg((b-a).angle()),360),14)
		piece.length = a.distance_to(b)
		doc.pieces.append(piece)
	return TrackCompiler.compile(RoadPieces.route_from_pieces(doc).document)

func run() -> void:
	capture = "--capture-bridge-hud" in OS.get_cmdline_user_args()
	var creator: NativeTrack = circuit()
	var native := NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_1way_test.json")
	for track: NativeTrack in [creator,native]:
		var cells: PackedInt32Array = track.cells.duplicate()
		var deck: PackedInt32Array = track.deck_cells.duplicate()
		var structure := Node3D.new()
		var bridge := BridgePresentation.new(track)
		bridge.build(structure)
		check(track.cells == cells and track.deck_cells == deck,"bridge mesh construction preserves both collision layers")
		check(structure.get_child_count() >= 2,"bridge generates road and structural meshes")
		var facets: int = 0
		for child: MeshInstance3D in structure.get_children():
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var downward: int = 0
			for normal: Vector3 in normals:
				if absf(normal.y) < 0.1: facets += 1
				if normal.y <= 0.0: downward += 1
			if child.material_override is ShaderMaterial:
				check(downward == 0,"road faces point up for correct bridge lighting")
		check(facets > 24,"bridge has vertical structural faces rather than only flat strips")
		structure.free()
	var painted_document: Dictionary = creator.metadata.creator_document.duplicate(true)
	painted_document.paint.append({"surface":0,"width":12.0,"shape":"round","points":[[75.0,0.0],[90.0,0.0]]})
	var painted: NativeTrack = TrackCompiler.compile(painted_document)
	var minimap := HUDRoadMap.new()
	minimap.configure(painted,true)
	var painted_geometry: Array = minimap.outlines.duplicate(true)
	minimap.configure(creator,true)
	check(minimap.outlines == painted_geometry,"painted surfaces cannot change the placed-road minimap")
	painted_document.pieces.append(RoadPieces.create("straight",Vector2(75,0)))
	var extended: NativeTrack = TrackCompiler.compile(painted_document)
	minimap.configure(extended,true)
	check(minimap.world_bounds.end.x >= 102.0,"placed road beyond the lap route appears in minimap bounds")
	var empty_pieces: Array = extended.metadata.creator_document.pieces
	extended.metadata.creator_document.pieces = []
	minimap.configure(extended,true)
	check(minimap.outlines.is_empty(),"no placed roads means no waypoint or paint fallback")
	extended.metadata.creator_document.pieces = empty_pieces
	minimap.free()
	await review(creator,Vector2i(1280,720),false,"creator-race")
	await review(native,Vector2i(960,540),false,"native-compact")
	await review(creator,Vector2i(1920,864),true,"practice-wide")
	print("BRIDGE_HUD_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func review(track: NativeTrack, dimensions: Vector2i, practice: bool, filename: String) -> void:
	root.size = dimensions
	root.content_scale_size = dimensions
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("initial_track",track)
	game.set("production_mode",true)
	game.set("editor_test",practice)
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.set("countdown_ticks",0)
	var sim: VehicleSimulation = game.get("sim")
	var initial_position: Vector2 = sim.state.position
	var point := Vector2(-8,0)
	var route_index: int = track.nearest_route(point)
	if track.creator_bridges.is_empty():
		var bridge: BridgePresentation = game.get("bridge_presentation")
		# Choose the highest upper-route point for a real native bridge view.
		var highest: float = -1.0
		for i: int in range(track.route.size()):
			var height: float = bridge.height_at(track.route[i],i)
			if height > highest:
				highest = height
				point = track.route[i]
				route_index = i
	sim.reset(point,PI*0.5)
	sim.state.route_index = route_index
	sim.state.track_elevated = true
	game.set("previous_position",point)
	game.set("previous_heading",sim.state.heading)
	(game.get("camera") as FollowCamera).follow(point,Vector2.ZERO,sim.state.heading,0,true)
	var hud: PlaygroundHUD = game.get("hud")
	for frame: int in range(4):
		game.call("_process",0.1)
		await process_frame
	var authored: bool = not track.metadata.get("creator_document",{}).is_empty()
	check(hud.road_map.visible == authored,"minimap is restricted to new creator-format tracks")
	check((not hud.road_map.outlines.is_empty()) == authored,"legacy converted tracks do not populate minimap geometry")
	if authored:
		check(hud.road_map.player == sim.state.position,"minimap uses current player position")
		var geometry: Array = hud.road_map.outlines.duplicate(true)
		var bounds_before: Rect2 = hud.road_map.world_bounds
		var waypoints := track.route.duplicate()
		track.route = PackedVector2Array([Vector2(-999,-999),Vector2(999,999)])
		hud.road_map.configure(track,true)
		check(hud.road_map.outlines == geometry and hud.road_map.world_bounds == bounds_before,"changing waypoints cannot change minimap roads or framing")
		track.route = waypoints
	if not practice:
		var menu := hud.find_child("RaceMenu",true,false) as MenuButton
		check(menu != null and menu.get_popup().item_count == 2,"icon menu provides restart and tracks without a camera action")
		var popup: PopupMenu = menu.get_popup()
		popup.about_to_popup.emit()
		check(bool(game.get("paused")),"race menu pauses the drive")
		popup.popup_hide.emit()
		check(not bool(game.get("paused")),"dismissing race menu resumes a running drive")
	game.call("_process",0.1)
	var rebuilds: int = hud.road_map.rebuild_count
	for update: int in range(30):
		hud.road_map.player += Vector2(0.1,0)
		hud.road_map.queue_redraw()
	check(hud.road_map.rebuild_count == rebuilds,"marker updates do not rebuild static road geometry")
	hud.road_map.player = sim.state.position
	if not practice:
		var session := TrackSession.new(120,7)
		session.elapsed_ticks = 8100
		session.completed_laps = 2
		session.lap_start_time = 61.25
		hud.show_session(session)
		check(hud.lap_label.text == "3" and hud.lap_total.text == "/ 7","lap display uses actual session count and target")
		check(hud.race_timer.text == "01:07.50" and hud.lap_timer.text == "00:06.25","race and current lap clocks use distinct session times")
		session.penalty_seconds = 5.0
		session.lap_penalty_seconds = 5.0
		hud.show_session(session)
		check(hud.race_timer.text == "01:07.50" and hud.lap_timer.text == "00:06.25","checkpoint rules use elapsed time, ignoring retired shortcut penalties")
		session.lap_times.assign([20.0,21.0,26.5])
		session.finished = true
		hud.show_session(session)
		check(hud.lap_timer.text == "00:26.50","finish retains the completed final lap time")
		hud.show_session(TrackSession.new())
		check(hud.race_timer.text == "00:00.00" and hud.lap_timer.text == "00:00.00" and hud.lap_label.text == "1","restart clears both clocks and lap")
		check(hud._time_text(59.9999) == "00:59.99" and hud._time_text(60.0) == "01:00.00","clock rollover never prints sixty seconds")
		# Show distinct changing data in the visual witness, then restore the real session.
		session.finished = false
		session.penalty_seconds = 0.0
		session.lap_penalty_seconds = 0.0
		hud.show_session(session)
	if not practice:
		for timer: Label in [hud.race_timer,hud.lap_timer]:
			var font: Font = timer.get_theme_font("font")
			var font_size: int = timer.get_theme_font_size("font_size")
			var reference_width: float = font.get_string_size("00:00.00",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			for digit: int in range(10):
				var sample: String = "%d%d:%d%d.%d%d" % [digit,digit,digit,digit,digit,digit]
				check(is_equal_approx(font.get_string_size(sample,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,reference_width),"timer digit advances stay fixed: "+sample)
		var timer_rect: Rect2 = hud.race_timer.get_global_rect()
		var lap_rect: Rect2 = hud.lap_timer.get_global_rect()
		var saved_race: String = hud.race_timer.text
		var saved_lap: String = hud.lap_timer.text
		for sample: String in ["11:11.11","88:88.88","00:59.99","01:00.00"]:
			hud.race_timer.text = sample
			hud.lap_timer.text = sample
			await process_frame
			await process_frame
			check(hud.race_timer.get_global_rect() == timer_rect and hud.lap_timer.get_global_rect() == lap_rect,"changing timer digits preserves both label rectangles")
		hud.race_timer.text = saved_race
		hud.lap_timer.text = saved_lap
		var backing: Rect2 = hud.race_frame.lap_backing_rect()
		var content := Rect2(hud.race_frame.lap_status.global_position-hud.race_frame.global_position,hud.race_frame.lap_status.size)
		check(backing.encloses(content) and backing.get_center().is_equal_approx(content.get_center()),"lap backing is centred on actual label group")
	var before: Array = sim.state.snapshot()
	var bounds := Rect2(Vector2.ZERO,Vector2(dimensions))
	var buttons: Array[Control] = [hud.pause_button,hud.handling_button]
	var actions := hud.find_child("RaceActions",true,false) as Control
	for child: Control in actions.get_child(0).get_children():
		if child != hud.pause_button: buttons.append(child)
	for button: Control in buttons:
		check(bounds.encloses(button.get_global_rect()),"action stays on screen at %s: %s" % [dimensions,button.name])
		check(button.size.y >= 52,"action retains a 52-unit touch target")
	for i: int in range(buttons.size()):
		for j: int in range(i+1,buttons.size()):
			check(not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()),"action targets do not overlap")
	if not practice:
		var card := hud.find_child("RaceCard",true,false) as Control
		var timing := hud.find_child("TimingCard",true,false) as Control
		check(not card.get_global_rect().intersects(timing.get_global_rect()) and not timing.get_global_rect().intersects(actions.get_global_rect()),"lap, timer and actions occupy separate columns")
		var saved: String = hud.title.text
		hud.title.text = "A very long fictional circuit name that must never push the race timer or actions away"
		await process_frame
		await process_frame
		check(card.size.x <= 248.1 and not card.get_global_rect().intersects(timing.get_global_rect()),"long circuit name stays inside the circuit card")
		hud.title.text = saved
		var speed := hud.find_child("SpeedCard",true,false) as Control
		check(bounds.encloses(speed.get_global_rect()) and speed.size.y <= 120,"semicircular speed gauge stays within its 120-unit budget and above the bottom inset")
		for zone: Rect2 in hud.touch.zones():
			check(not zone.intersects(speed.get_global_rect()),"speed does not cover a driving touch zone")
	check(sim.state.snapshot() == before,"HUD presentation does not change simulation state")
	await save_capture(filename)
	hud.pause_button.pressed.emit()
	game.call("_process",0.1)
	check(bool(game.get("paused")) and not hud.touch.enabled,"pause action stops input")
	if practice:
		check(hud.pause_button.text == "Paused \u00b7 Resume","practice pause retains its resume label")
		check(not hud.title.visible and not hud.race_timer.visible,"practice has no race timing or lap HUD")
		await save_capture("practice-paused")
	hud.pause_button.pressed.emit()
	game.call("_process",0.1)
	check(not bool(game.get("paused")) and hud.touch.enabled,"resume restores input")
	if not practice:
		var menu := hud.find_child("RaceMenu",true,false) as MenuButton
		menu.get_popup().id_pressed.emit(0)
		check(sim.state.position == initial_position and sim.state.tick == 0,"race-menu restart returns to the actual start")
		var observed: Dictionary = {"tracks":0}
		hud.exit_requested.connect(func() -> void: observed.tracks += 1)
		menu.get_popup().id_pressed.emit(1)
		check(observed.tracks == 1,"race-menu tracks item requests exit")
	game.queue_free()
	await process_frame

func save_capture(filename: String) -> void:
	if not capture: return
	for frame: int in range(3): await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://../build/bridge-hud-"+filename+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"saved "+filename)
