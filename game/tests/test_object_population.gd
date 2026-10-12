extends SceneTree
## Independent geometry, persistence and real-editor transaction checks.
var checks: int = 0
var failures: int = 0
var captures: bool = false
var app: Node
var evidence: String = "res://../build/procedural-placement-2026-10-11"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)

func run() -> void:
	captures = "--capture" in OS.get_cmdline_user_args() or "capture" in OS.get_cmdline_user_args()
	_distance_transform()
	for biome: String in TrackDocument.THEMES: _geometry(biome)
	_special_geometry()
	await _editor()
	print("OBJECT_POPULATION checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func _distance_transform() -> void:
	var mask := PackedInt32Array([1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,0])
	var field: PackedFloat32Array = ObjectPopulation._distance_field(mask,Vector2i(5,4))
	for y: int in range(4):
		for x: int in range(5):
			var expected: float = minf(Vector2(x,y).distance_to(Vector2(1,1)),Vector2(x,y).distance_to(Vector2(4,3)))*ObjectPopulation.CELL
			check(absf(field[y*5+x]-expected) < 0.0001,"distance transform matches independent nearest-road calculation")

func _geometry(biome: String) -> void:
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = biome
	doc.objects = [{"kind":"hut","position":[0,0],"rotation":0}]
	var track: NativeTrack = TrackCompiler.compile(doc)
	var before: String = JSON.stringify(doc)
	var population := ObjectPopulation.new()
	population.prepare(doc,track)
	var objects: Array = population.generate(27,0.65,22.0)
	var first_sample_usec: int = population.sample_usec
	check(not objects.is_empty() and objects.size() <= 95,biome+" has a bounded usable population")
	check(JSON.stringify(doc) == before,"generation cannot mutate authoring data")
	check(objects == population.generate(27,0.65,22.0),"same seed reproduces fixed placements")
	check(objects != population.generate(28,0.65,22.0),"shuffle changes the arrangement")
	var dense: Array = population.generate(27,1.0,22.0)
	var sparse: Array = population.generate(27,0.0,22.0)
	check(dense.size() > sparse.size(),"density changes actual object population")
	var roadside: int = 0
	var woodland: int = 0
	var layout: Dictionary = TrackDocument.route_data(doc.layout)
	for object: Dictionary in objects:
		var point := Vector2(object.position[0],object.position[1])
		var radius: float = ObjectPopulation.radius(object)
		var road_distance: float = _road_distance(point,layout.points,layout.widths,true)
		check(road_distance-radius >= ObjectPopulation.CLEARANCE,"whole footprint stays clear of the actual variable-width road")
		if object.kind in ObjectPopulation.ROADSIDE:
			roadside += 1
			check(road_distance+radius <= 22.0,"roadside objects stay entirely inside the roadside zone")
		else:
			woodland += 1
			check(object.kind in ObjectPopulation.NATURE,"outer population contains only trees and rocks")
			check(CreatorCatalog.NATURE_BIOMES.get(object.kind,[biome]).has(biome),"nature respects biome availability")
		for other: Dictionary in population.occupied+objects:
			if other == object: continue
			var other_point := Vector2(other.position[0],other.position[1])
			check(point.distance_to(other_point)+0.001 >= radius+ObjectPopulation.radius(other)+1.5,"generated footprints are separated from authored/automatic/generated objects")
	check(roadside > 0 and woodland > 0,"both roadside and woodland zones are populated")
	var candidate: Dictionary = doc.duplicate(true)
	candidate.objects.append_array(objects)
	candidate["automatic_scenery"] = false
	check(TrackDocument.validate(candidate).is_empty(),"generated data obeys the shipping authoring contract")
	if not TrackDocument.validate(candidate).is_empty(): print("VALIDATION_ERRORS ",TrackDocument.validate(candidate))
	var compiled: NativeTrack = TrackCompiler.compile(candidate)
	check(compiled != null and compiled.route == track.route and compiled.metadata.finish == track.metadata.finish,"population preserves the timed route and finish")
	if compiled == null: return
	check(compiled.metadata.scenery_objects.is_empty(),"explicit population cannot gain extra implicit objects")
	for point: Vector2 in track.route:
		check(compiled.cell_at(point) == track.cell_at(point),"population preserves existing road surfaces")
	for object: Dictionary in objects:
		if object.kind == "car_wreck":
			check(compiled.cell_at(Vector2(object.position[0],object.position[1])) == 4,"wreck is a static solid obstacle")
	print("POPULATION_MEASURE biome=",biome," objects=",objects.size()," prepare_us=",population.prepare_usec," sample_us=",first_sample_usec," grid=",population.grid)
	var nearly_full: Dictionary = doc.duplicate(true)
	nearly_full.objects.resize(95)
	for i: int in range(95): nearly_full.objects[i] = {"kind":"rock","position":[0.0,0.0],"rotation":0.0}
	var capped := ObjectPopulation.new()
	capped.prepare(nearly_full,track)
	check(capped.generate(27,1.0,22.0).size() <= 1,"generation respects remaining capacity")
	var blank := ObjectPopulation.new()
	blank.prepare(TrackDocument.create_blank(),null)
	check(not blank.error.is_empty() and blank.generate(27,1.0,22.0).is_empty(),"empty maps give an actionable state without creating roads")

func _road_distance(point: Vector2, points: PackedVector2Array, widths: PackedFloat32Array, closed: bool) -> float:
	var best: float = INF
	for index: int in range(points.size() if closed else points.size()-1):
		var next: int = (index+1)%points.size()
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(point,points[index],points[next])
		var along: float = clampf((nearest-points[index]).dot(points[next]-points[index])/maxf(0.00001,points[index].distance_squared_to(points[next])),0.0,1.0)
		best = minf(best,point.distance_to(nearest)-lerpf(widths[index],widths[next],along)*0.5)
	return best

func _special_geometry() -> void:
	var doc: Dictionary = TrackDocument.create_blank()
	var spline: Dictionary = RoadPieces.create("spline",Vector2(-40,-28))
	spline.point_widths = [6.0,8.0,20.0,10.0,6.0]
	spline.width = 20.0
	doc.pieces = [spline,RoadPieces.create("bridge",Vector2(-24,15)),RoadPieces.create("hairpin",Vector2(28,-12))]
	doc.paint = [{"surface":0,"width":8.0,"shape":"round","points":[[-25,-2],[28,-2]]},{"surface":3,"width":16.0,"shape":"square","points":[[-45,30]]}]
	var track: NativeTrack = TrackCompiler.compile(doc)
	check(track != null,"mixed spline/bridge/hairpin/free-painted-road fixture compiles")
	if track == null:
		print("MIXED_VALIDATION_ERRORS ",TrackDocument.validate(doc))
		return
	var population := ObjectPopulation.new()
	population.prepare(doc,track)
	var geometry: Array[Dictionary] = []
	var topology: Dictionary = RoadPieces.prepare_endpoints(doc.pieces)
	for i: int in range(doc.pieces.size()): geometry.append(RoadPieces.section_geometry(doc.pieces,i,topology))
	for seed_value: int in [5,27,99]:
		var objects: Array = population.generate(seed_value,1.0,24.0)
		check(not objects.is_empty(),"mixed road geometry can be populated")
		for object: Dictionary in objects:
			var point := Vector2(object.position[0],object.position[1])
			var radius: float = ObjectPopulation.radius(object)
			var actual: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(-25,-2),Vector2(28,-2)))-4.0
			for section: Dictionary in geometry: actual = minf(actual,_road_distance(point,section.points,section.widths,false))
			check(actual-radius >= ObjectPopulation.CLEARANCE,"spline widths, bridge ramps, hairpins and painted roads stay clear")
			if object.kind in ObjectPopulation.ROADSIDE: check(actual+radius <= 24.0,"roadside placement follows the nearest of all road sections")
			var water_local: Vector2 = point-Vector2(-45,30)
			check(water_local.distance_to(water_local.clamp(Vector2.ONE*-8.0,Vector2.ONE*8.0)) >= radius,"population avoids the entire water footprint")
	var invalid: Dictionary = doc.duplicate(true)
	invalid["automatic_scenery"] = "false"
	check(not TrackDocument.validate(invalid,false).is_empty(),"automatic scenery flag is strictly boolean")

func _wait_editor() -> void:
	var deadline: int = Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline and (app.editor_preview_thread != null or app.canvas.native_preview == null or app.editor_world._building): await process_frame
	check(app.editor_preview_thread == null and app.canvas.native_preview != null and not app.editor_world._building,"real editor preparation finishes")

func _wait_population(panel: ObjectPopulationPanel) -> void:
	var deadline: int = Time.get_ticks_msec()+20000
	while is_instance_valid(panel) and Time.get_ticks_msec() < deadline and (panel.worker != null or panel.pending or not panel.ready_to_apply): await process_frame
	check(is_instance_valid(panel) and panel.ready_to_apply and panel.worker == null and not panel.pending,"latest background placement preview finishes")
	await _wait_editor()

func _editor() -> void:
	root.size = Vector2i(1280,720)
	app = (load("res://core/app.tscn") as PackedScene).instantiate()
	var directory: String = "user://object_population_tests_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory))
	app.set("records",LocalRecords.new(directory.path_join("records.json")))
	root.add_child(app)
	await process_frame
	var doc: Dictionary = TrackDocument.create_default()
	doc.id = "population_fixture"; doc.name = "Woodland circuit"
	app.set("document",doc)
	app.call("_show_screen","create")
	await _wait_editor()
	app.call("_editor_category","objects")
	await process_frame
	var populate: Button = app.object_browser.find_child("PopulateObjects",true,false)
	check(populate != null and populate.visible,"Objects exposes Populate")
	check(root.get_visible_rect().encloses(populate.get_global_rect()),"Populate action fits the viewport")
	var original: Dictionary = app.document.duplicate(true)
	var original_hash: String = app.canvas.native_preview.content_hash
	populate.pressed.emit()
	var panel: ObjectPopulationPanel = app.object_population_panel
	await _wait_population(panel)
	check(app.document == original and app.history.is_empty(),"preview leaves the document and undo history untouched")
	var first: Array = panel.generated.duplicate(true)
	(panel.find_child("PopulationShuffle",true,false) as Button).pressed.emit()
	await _wait_population(panel)
	check(panel.generated != first,"real Shuffle button changes the preview")
	(panel.find_child("PopulationDensity",true,false) as HSlider).value = 0.1
	(panel.find_child("PopulationDensity",true,false) as HSlider).value = 0.9
	(panel.find_child("PopulationReach",true,false) as HSlider).value = 26
	await _wait_population(panel)
	check(panel.density == 0.9 and panel.roadside_reach == 26 and panel.ready_to_apply,"rapid settings changes settle on the newest preview")
	var canvas_before: Dictionary = app.document.duplicate(true)
	var pan_before: Vector2 = app.canvas.pan
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = Vector2(500,240)
	panel._gui_input(down)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(530,255)
	panel._input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = Vector2(530,255)
	panel._input(up)
	check(app.canvas.pan != pan_before and app.document == canvas_before and app.canvas.active_pointer == -99,"preview supports navigation without authoring or stuck gestures")
	app.canvas.pan = pan_before
	app.canvas.zoom_by(0.65)
	await _capture("preview-desktop")
	root.size = Vector2i(960,540)
	await process_frame; await process_frame
	check(root.get_visible_rect().encloses(panel.panel.get_global_rect()),"population controls fit compact landscape")
	await _capture("preview-compact")
	(panel.find_child("PopulationCancel",true,false) as Button).pressed.emit()
	await process_frame
	await _wait_editor()
	check(app.document == original and app.history.is_empty(),"Cancel removes preview without saving or creating undo")
	check(app.editor_world.track.content_hash == original_hash,"Cancel restores the actual original scenery")
	app.call("_open_object_population")
	panel = app.object_population_panel
	await _wait_population(panel)
	var generated: Array = panel.generated.duplicate(true)
	(panel.find_child("PopulationApply",true,false) as Button).pressed.emit()
	await process_frame
	await _wait_editor()
	check(app.document.objects == original.objects+generated and app.history.size() == 1,"Apply commits exactly one undoable group")
	check(app.library.save_document(app.document) == OK,"populated track saves")
	var restored: Dictionary = app.library.load_document(doc.id)
	check(restored.objects == app.document.objects,"save/reload retains exact placements including wrecks")
	check(not restored.automatic_scenery and TrackCompiler.compile(restored).content_hash == app.canvas.native_preview.content_hash,"reload retains the same collision/content contract without implicit scenery")
	var populated: Dictionary = app.document.duplicate(true)
	app.call("_undo")
	await _wait_editor()
	check(app.document == original,"Undo restores the original document")
	app.call("_redo")
	await _wait_editor()
	check(app.document == populated,"Redo restores exact generated placements")
	var canvas: EditorCanvas = app.canvas
	canvas.mode = "objects"
	canvas.selected_object = 0
	app.call("_delete_selection")
	await _wait_editor()
	check(app.document.objects.size() == populated.objects.size()-1,"generated objects remain individually deletable")
	root.size = Vector2i(1280,720)
	await process_frame; await process_frame
	canvas.fit()
	await _capture("applied-editor")
	# Close during preparation: join the owned worker and discard its result.
	app.call("_open_object_population")
	panel = app.object_population_panel
	await process_frame
	app.call("_close_object_population",false)
	await process_frame
	check(not is_instance_valid(panel),"closing during generation cleans up its worker")
	app.queue_free()
	await process_frame

func _capture(label: String) -> void:
	if not captures: return
	var deadline: int = Time.get_ticks_msec()+20000
	while app.editor_world._building and Time.get_ticks_msec() < deadline: await process_frame
	for tick: int in range(5): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(evidence.path_join(label+".png"))) == OK,"actual editor capture "+label)
