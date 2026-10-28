extends "res://tests/test_editor_incremental_objects.gd"
## Real fitted runs, topology, finite geometry and race/editor parity.
const RAIL = preload("res://track/guardrail_visual.gd")

func run() -> void:
	root.size = Vector2i(1280,720)
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/guardrail-ends-2026-10-27/"+RenderingServer.get_current_rendering_method())
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): evidence = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(evidence)
	baseline_geometry()
	topology_cases()
	for theme: String in ["pine","winter"]: await parity(theme)
	await editor_flow()
	print("GUARDRAIL_ENDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func baseline_geometry() -> void:
	var old := GDScript.new()
	old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/guardrail-ends-2026-10-27/before/game/track/prop_equipment.gd").replace("\r\n","\n").replace("class_name PropEquipment\n","")
	check(old.reload() == OK,"exact original equipment source compiles in isolated memory")
	var legacy: SurfaceTool = PropGeometry.model()
	old._fence(legacy,"guardrail",6.0,true)
	var revised: SurfaceTool = PropGeometry.model()
	RAIL.append(revised,6.0)
	var before: PackedVector3Array = PropGeometry.finish(legacy).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var after: PackedVector3Array = PropGeometry.finish(revised).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var old_end_height: float = 0.0; var new_end_height: float = 0.0
	for p: Vector3 in before:
		if absf(absf(p.x)-3.0) < 0.00001: old_end_height = maxf(old_end_height,p.y)
	for p: Vector3 in after:
		if absf(absf(p.x)-3.0) < 0.00001: new_end_height = maxf(new_end_height,p.y)
	check(old_end_height > 1.0,"original geometry reproduces the abrupt full-height rail ends")
	check(new_end_height == 0.0,"actual revised terminal vertices meet ground at both ends")
	for kind: String in ["fence","wire_fence"]:
		var a: SurfaceTool = PropGeometry.model(); var b: SurfaceTool = PropGeometry.model()
		old._fence(a,kind,6.0,true); PropEquipment._fence(b,kind,6.0,true)
		check(PropGeometry.finish(a).surface_get_arrays(0) == PropGeometry.finish(b).surface_get_arrays(0),kind+" retains exact original mesh arrays")
	print("GUARDRAIL_TERMINAL_HEIGHT original=",old_end_height," revised=",new_end_height)

func stations(objects: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for object: Dictionary in RAIL.prepare(objects):
		var point := Vector2(object.position[0],object.position[1])
		for x: float in object._guardrail.posts:
			result.append(point+Vector2(x*float(object.get("scale",1.0)),0).rotated(deg_to_rad(float(object.rotation))))
	result.sort()
	return result

func audit(objects: Array, label: String) -> void:
	var before: Array = objects.duplicate(true)
	var prepared: Array = RAIL.prepare(objects)
	check(objects == before,label+" leaves canonical authored objects exact")
	var count: int = 0
	var valid: bool = true
	for object: Dictionary in prepared:
		var profile: Dictionary = object._guardrail
		var span: float = CreatorObjects.size_of(object).x/float(object.get("scale",1.0))
		count += profile.posts.size()
		var tool: SurfaceTool = PropGeometry.model()
		RAIL.append(tool,span,profile)
		var arrays: Array = PropGeometry.finish(tool).surface_get_arrays(0)
		for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: valid = valid and p.is_finite() and p.y >= -0.00001
		for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: valid = valid and n.is_finite() and n.length() > 0.9
	check(valid,label+" produces finite above-ground vertices and unit normals")
	print("GUARDRAIL_FIXTURE ",label," sections=",objects.size()," posts=",count)

func topology_cases() -> void:
	var path := PackedVector2Array([Vector2(-12,0),Vector2(12,0)])
	var straight: Array = ObjectRuns.build(path,"guardrail",1.0,96)
	check(straight.size() == 4,"straight fixture has four original six-metre sections")
	audit(straight,"straight")
	var prepared: Array = RAIL.prepare(straight)
	check(stations(straight).size() == 8,"24m run uses eight posts instead of twelve overlapping section posts")
	for object: Dictionary in prepared:
		var p: Dictionary = object._guardrail
		var span: float = CreatorObjects.size_of(object).x
		check(is_zero_approx(RAIL.height(-span*0.5,span,p)) if is_zero_approx(p.start) else RAIL.height(-span*0.5,span,p) == 1.0,"only the exposed start lowers to ground")
		check(is_zero_approx(RAIL.height(span*0.5,span,p)) if is_equal_approx(p.end,p.total) else RAIL.height(span*0.5,span,p) == 1.0,"only the exposed finish lowers to ground")
	var short_sections: Array = []
	for i: int in range(48): short_sections.append({"kind":"guardrail","position":[-11.75+i*0.5,0.0],"rotation":0.0,"length":0.5})
	check(stations(short_sections) == stations(straight),"half-metre curve chords cannot multiply posts or reset spacing")
	var reversed: Array = straight.duplicate(true); reversed.reverse()
	for object: Dictionary in reversed: object.rotation = 180.0
	var a: PackedVector2Array = stations(straight); var b: PackedVector2Array = stations(reversed)
	var equal: bool = a.size() == b.size()
	for i: int in range(mini(a.size(),b.size())): equal = equal and a[i].distance_to(b[i]) < 0.00001
	check(equal,"saved ordering and reversed sections preserve physical post positions")
	for scale: float in [0.5,0.75,1.5,2.0]: audit(ObjectRuns.build(path,"guardrail",scale,96),"scale "+str(scale))
	for length: float in [0.01,0.2,1.0,3.0,6.0,18.0]:
		audit([{"kind":"guardrail","position":[0.0,0.0],"rotation":0.0,"length":length}],"isolated length "+str(length))
		var p: Dictionary = RAIL.standalone(length)
		check(RAIL.height(-length*0.5,length,p) == 0.0 and RAIL.height(length*0.5,length,p) == 0.0,"both isolated ends start at ground")
		check(is_equal_approx(RAIL.height(0,length,p),1.0),"short isolated rail retains a readable middle")
	var loop: Array = ObjectRuns.build(PackedVector2Array([Vector2(0,0),Vector2(12,0),Vector2(12,12),Vector2(0,12),Vector2(0,0)]),"guardrail",1.0,96)
	for object: Dictionary in RAIL.prepare(loop): check(object._guardrail.closed,"closed loop has no invented lowered terminals")
	audit(loop,"closed loop")
	var gap: Array = straight.duplicate(true); gap.remove_at(1)
	var pieces: Array = RAIL.prepare(gap)
	check(pieces[0]._guardrail.total == 6.0 and pieces[1]._guardrail.total == 12.0,"deletion creates two independently terminated runs")
	var branch: Array = straight.duplicate(true); branch.append({"kind":"guardrail","position":[0.0,3.0],"rotation":90.0,"length":6.0})
	audit(branch,"branch")
	for object: Dictionary in RAIL.prepare(branch):
		var center := Vector2(object.position[0],object.position[1])
		var span: float = CreatorObjects.size_of(object).x
		for x: float in [-span*0.5,span*0.5]:
			if (center+Vector2(x,0).rotated(deg_to_rad(float(object.rotation)))).length() < 0.001:
				check(RAIL.height(x,span,object._guardrail) == 1.0,"shared branch junction stays full height")
	var mixed: Array = straight.duplicate(true); mixed.append({"kind":"fence","position":[15.0,0.0],"rotation":0.0})
	check(not RAIL.prepare(mixed)[-1].has("_guardrail"),"wooden and wire fences keep their own model")
	# The actual road-edge fitter creates many small sections around this turn.
	var road: Dictionary = RoadPieces.create("curve",Vector2(-20,0),0.0,10.0); road.radius = 20.0
	var doc: Dictionary = TrackDocument.create_blank(); doc.pieces = [road]
	var run: Array = RoadPieces.barrier_run(doc,Vector2(-20,-7),Vector2(7,20),"guardrail")
	check(not run.is_empty(),"actual road-edge action creates a curved run")
	audit(run,"road-edge curve")
	var posts: PackedVector2Array = stations(run)
	var minimum: float = INF
	for i: int in range(posts.size()):
		for j: int in range(i+1,posts.size()): minimum = minf(minimum,posts[i].distance_to(posts[j]))
	check(minimum > 2.7,"curved road-edge posts stay separated across fitted seams")
	print("GUARDRAIL_ROAD_EDGE sections=",run.size()," posts=",posts.size()," minimum_post_distance_m=",minimum)

func fixture(objects: Array, theme: String) -> NativeTrack:
	var track := NativeTrack.new()
	track.metadata = {"creator_document":{"objects":objects},"scenery_objects":[],"theme":theme}
	return track

func parity(theme: String) -> void:
	var path := PackedVector2Array([Vector2(-12,0),Vector2(-6,0),Vector2(-2,1),Vector2(2,3),Vector2(6,5),Vector2(12,5)])
	var objects: Array = ObjectRuns.build(path,"guardrail",1.0,96)
	var track: NativeTrack = fixture(objects,theme)
	var original: Dictionary = track.metadata.duplicate(true)
	var race := NativeTrackVisual.new(); race.theme_id = theme; race.colors = TrackTheme.palette(theme)
	var editor := NativeTrackVisual.new(); editor.theme_id = theme; editor.colors = race.colors
	root.add_child(race); root.add_child(editor)
	await race._build_placed_objects(track)
	await editor.refresh_editor_objects(track,false)
	check(same_triangles(triangles(race),triangles(editor)),theme+" connected run has exact editor/race triangles and normals")
	check(track.metadata == original,theme+" render context never reaches track data")
	await render_closeup(race,objects,theme)
	var changed: Array = objects.duplicate(true); changed.remove_at(changed.size()/2)
	var revised: NativeTrack = fixture(changed,theme)
	await editor.refresh_editor_objects(revised,false)
	var independent := NativeTrackVisual.new(); independent.theme_id = theme; independent.colors = race.colors
	await independent._build_placed_objects(revised)
	check(same_triangles(triangles(independent),triangles(editor)),theme+" deletion updates neighbouring terminal meshes")
	await editor.refresh_editor_objects(track,false)
	check(same_triangles(triangles(race),triangles(editor)),theme+" restoring sections restores original complete run")
	independent.free(); race.queue_free(); editor.queue_free(); await process_frame

func render_closeup(race: NativeTrackVisual, objects: Array, theme: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	race.reparent(viewport)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 20.0
	viewport.add_child(camera); camera.look_at_from_position(Vector3(7,17,22),Vector3(0,0,-2)); camera.current = true
	var sunlight := DirectionalLight3D.new(); sunlight.rotation_degrees = Vector3(-55,-30,0); sunlight.shadow_enabled = true; viewport.add_child(sunlight)
	var ambient := WorldEnvironment.new(); ambient.environment = Environment.new()
	ambient.environment.background_mode = Environment.BG_COLOR; ambient.environment.background_color = Color("45535a")
	ambient.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; ambient.environment.ambient_light_energy = 0.55; viewport.add_child(ambient)
	var ground := Node3D.new(); viewport.add_child(ground)
	VisualGeometry.box(ground,Vector3(200,0.12,200),Vector3(0,-0.06,0),VisualGeometry.material(Color("becbd1") if theme == "winter" else Color("718263")))
	for frame: int in range(5): await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(evidence.path_join(theme+"-run-closeup.png")) == OK,theme+" native closeup shows true ground terminals")
	if theme == "pine":
		var old := GDScript.new()
		old.source_code = FileAccess.get_file_as_string("res://../docs/evidence/guardrail-ends-2026-10-27/before/game/track/prop_equipment.gd").replace("\r\n","\n").replace("class_name PropEquipment\n","")
		check(old.reload() == OK,"original renderer loads for matched visual comparison")
		var tool: SurfaceTool = PropGeometry.model()
		for object: Dictionary in objects:
			var local: SurfaceTool = PropGeometry.model()
			old._fence(local,"guardrail",CreatorObjects.size_of(object).x,true)
			PropGeometry.append_transformed(tool,local,Vector3(object.position[0],0.014,-object.position[1]),1.0,deg_to_rad(float(object.rotation)))
		var mesh := MeshInstance3D.new(); mesh.mesh = PropGeometry.finish(tool)
		var material := VisualGeometry.material(Color.WHITE); material.vertex_color_use_as_albedo = true; material.vertex_color_is_srgb = true; material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material; viewport.add_child(mesh); race.hide()
		for frame: int in range(5): await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(evidence.path_join("pine-original-closeup.png")) == OK,"matched original view records abrupt ends and crowded seam posts")
	race.reparent(root); race.show(); viewport.queue_free(); await process_frame

func editor_flow() -> void:
	var storage: String = evidence.path_join("storage")
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(storage); app.records = LocalRecords.new(storage.path_join("records.json")); app.cloud_root_override = storage.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var doc: Dictionary = TrackDocument.create_blank(); doc.id = "guardrail_review"; doc.name = "Guardrail review"
	var piece: Dictionary = RoadPieces.create("spline",Vector2(-27,-10),0.0,10.0)
	piece.spline_points = [[0.0,0.0],[18.0,0.0],[32.0,9.0],[38.0,25.0],[57.0,28.0]]
	doc.pieces = [piece]
	app.document = doc; app.canvas = null; app.editor_view.clear(); app.call("_show_screen","create")
	await settle()
	app.call("_editor_category","objects"); app.call("_choose_object","guardrail"); app.call("_object_placement","road edge")
	app.object_browser.current = "guardrail"; app.object_browser.category = "Barriers"; app.object_browser.refresh()
	app.canvas._place(app.canvas.to_screen(Vector2(-27,-17)))
	app.canvas._place(app.canvas.to_screen(Vector2(30,25)))
	await settle()
	check(not app.document.objects.is_empty(),"real editor gestures place the curved guardrail")
	var placed: Dictionary = app.document.duplicate(true)
	check(app.history.size() == 1,"complete guardrail run is one undo operation")
	check(app.library.load_wip(doc.id) == JSON.parse_string(JSON.stringify(placed)),"autosave retains exact original objects without render metadata")
	app.canvas.fit()
	await screenshot("editor-curved-run")
	app.call("_undo"); await settle()
	check(app.document.objects.is_empty(),"undo removes the whole run")
	app.call("_redo"); await settle()
	check(app.document == placed,"redo restores exact authored run")
	app.canvas.zoom_by(2.0,app.canvas.to_screen(Vector2(-20,-17)))
	await screenshot("editor-ground-terminal")
	app.queue_free(); await process_frame

func screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(4): await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png")) == OK,"capture "+label)
