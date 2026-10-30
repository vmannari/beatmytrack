extends SceneTree
## Real compiler/simulation/editor coverage; isolated files, no owner account.
const OUT: String = "res://../docs/evidence/jump-palette-objects-2026-10-28"
var checks: int = 0
var failures: int = 0
var captures: bool = false
var measurements: Array = []
var geometry: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func document(theme: String = "pine") -> Dictionary:
	var doc: Dictionary = TrackDocument.create_blank()
	doc.theme = theme
	doc["automatic_scenery"] = false
	var road: Dictionary = RoadPieces.create("straight",Vector2(-55,0),0,12)
	road.length = 110.0
	doc.pieces = [road]
	return doc

func object(profile: String, scale_value: float = 1.0, angle: float = 0.0) -> Dictionary:
	return {"kind":"jump","jump_profile":profile,"position":[0,0],"rotation":angle,"scale":scale_value}

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	print("TEST_USER_DATA=",OS.get_user_data_dir())
	captures = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var before_catalog := GDScript.new()
	before_catalog.source_code=FileAccess.get_file_as_string("res://tests/fixtures/jump_palette_before/creator_catalog.gd.txt").replace("\r\n","\n").replace("class_name CreatorCatalog\n","")
	check(before_catalog.reload() == OK,"task-start palette catalogue loads independently")
	var no_recent: Array[String] = []
	var prior: Array = before_catalog.filtered("Props","",no_recent,"desert")
	check(prior.size() == 1 and prior[0][0] == "jump","reported navigation reproduces as one aggregate card on task-start sources")
	for biome: String in ["desert","pine","storm","night_city"]:
		var entries: Array = CreatorCatalog.filtered("Props","",[],biome)
		var separate: int = 0
		for entry: Array in entries:
			if CreatorCatalog.JUMP_ASSETS.has(entry[0]): separate+=1
		check(separate == 5 and not entries.any(func(entry: Array) -> bool: return entry[0] == "jump"),biome+" exposes all five jump objects without an aggregate card")
	var legacy_doc: Dictionary = document()
	legacy_doc.objects = [{"kind":"jump","position":[0,0],"rotation":0}]
	var legacy_track: NativeTrack = TrackCompiler.compile(legacy_doc)
	var baseline_script := GDScript.new()
	baseline_script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/jump_styles_before/track_hazards.gd.txt").replace("\r\n","\n").replace("class_name TrackHazards\n","")
	check(baseline_script.reload() == OK,"original hazard source loads independently")
	var legacy_hash: String = TrackCompiler.document_hash(legacy_doc,"")
	check(legacy_hash == (TrackCompiler.VERSION+"\n\n"+JSON.stringify(JSON.parse_string(JSON.stringify(legacy_doc)),"",true)).sha256_text(),"unchanged documents retain the exact original compiler hash")
	for i: int in range(121):
		var p := Vector2(-3.0+float(i)*0.05,0)
		check(TrackHazards.ramp_height(p,legacy_doc.objects) == baseline_script.ramp_height(p,legacy_doc.objects),"original ramp support remains exact")
		check(TrackHazards.ramp_pitch(p,Vector2.RIGHT,legacy_doc.objects) == baseline_script.ramp_pitch(p,Vector2.RIGHT,legacy_doc.objects),"original ramp angle remains exact")
	for speed: float in [4.0,5.0,14.0,30.0,52.0]:
		var a := VehicleState.new(); a.position=Vector2(3.1,0); a.velocity=Vector2(speed,0)
		var b := VehicleState.new(); b.position=a.position; b.velocity=a.velocity
		TrackHazards.launch(a,Vector2(2.9,0),legacy_doc.objects)
		baseline_script.launch(b,Vector2(2.9,0),legacy_doc.objects)
		check(a.snapshot() == b.snapshot(),"historical launch state remains exact")
	check(CreatorCatalog.available("jump","desert"),"desert exposes jumps and sand bumps")
	check(JumpProfiles.default_for("desert") == "dune_v1" and JumpProfiles.default_for("pine") == "low_ramp_v1","sensible biome defaults")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	for profile: String in JumpProfiles.IDS:
		var doc: Dictionary = document("desert" if profile == "dune_v1" else "pine")
		doc.objects = [object(profile)]
		var errors: Array[String] = TrackDocument.validate(doc)
		check(errors.is_empty(),profile+" validates: "+str(errors))
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null and track.content_hash != legacy_track.content_hash,profile+" has its own content identity")
		if track == null: continue
		var verification: NativeTrack = preload("res://backend/verification_track.gd").frozen(track)
		var half: Vector2 = CreatorObjects.size_of(doc.objects[0])*0.5
		check(half == JumpProfiles.dimensions(profile)*0.5,profile+" uses the same selection and support footprint")
		check(JumpProfiles.peak(profile) <= 0.48,profile+" is below half the old standard height")
		if JumpProfiles.rounded(profile):
			check(absf(track.ramp_height(Vector2(-half.x,0))) < 0.000001 and absf(track.ramp_height(Vector2(half.x,0))) < 0.000001,profile+" meets the road at both ends")
			check(absf(track.ramp_height(Vector2(0,half.y))) < 0.000001,profile+" has seated rounded shoulders")
			check(absf(track.ramp_pitch(Vector2(-half.x+0.01,0),Vector2.RIGHT)) < 0.006,profile+" has no sharp entry")
			check(track.ramp_height(Vector2.ZERO)>0.1,profile+" has a visible crown")
		for speed: float in [8.0,14.0,30.0,52.0]:
			var sim := VehicleSimulation.new(config)
			sim.reset(Vector2(-half.x-1.0,0),PI*0.5); sim.state.velocity=Vector2(speed,0)
			var replay := VehicleSimulation.new(config)
			replay.reset(sim.state.position,sim.state.heading); replay.state.velocity=sim.state.velocity
			var frames: Array = []
			var worker := VehicleSimulation.new(config)
			worker.reset(sim.state.position,sim.state.heading); worker.state.velocity=sim.state.velocity
			var saved: Dictionary = {}
			var max_height: float = 0.0
			var exact: bool = true
			var air_ticks: int = 0
			for tick: int in range(360):
				var frame := DriveFrame.new(); frame.throttle = 255
				var encoded: Array = JSON.parse_string(JSON.stringify(frame.packed()))
				var decoded := DriveFrame.new(); decoded.steer=encoded[0]; decoded.throttle=encoded[1]; decoded.brake=encoded[2]
				frames.append(decoded)
				sim.step(frame,track); replay.step(decoded,track)
				worker.step(decoded,verification)
				exact = exact and sim.state.snapshot() == replay.state.snapshot()
				exact = exact and sim.state.snapshot() == worker.state.snapshot()
				max_height = maxf(max_height,sim.state.jump_height)
				if sim.state.jump_height>0.0: air_ticks += 1
				if tick == 59: saved = RewindHistory.properties(sim.state)
			check(exact,profile+" replays JSON inputs at "+str(speed))
			var resumed := VehicleSimulation.new(config)
			for key: String in saved: resumed.state.set(key,saved[key])
			for tick: int in range(60,360): resumed.step(frames[tick],track)
			check(resumed.state.snapshot() == sim.state.snapshot(),profile+" rewinds exactly")
			check(max_height <= (0.73 if profile == "kicker_v1" else 0.45),profile+" retains a restrained flight bound")
			check(air_ticks == 0 if JumpProfiles.rounded(profile) else air_ticks>0 and air_ticks<100,profile+" has its stated grounded/hop response")
			measurements.append({"profile":profile,"entry_m_s":speed,"airborne_ticks":air_ticks,"peak_m":max_height})
		for angle: float in [0.0,22.5,90.0,217.0]:
			var placed: Dictionary = object(profile,0.75,angle)
			var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle))
			var half_length: float = CreatorObjects.size_of(placed).x*0.5
			var state := VehicleState.new(); state.position=direction*(half_length+0.1); state.velocity=direction*14.0
			TrackHazards.launch(state,direction*(half_length-0.1),[placed])
			check(state.jump_height == 0.0 if JumpProfiles.rounded(profile) else state.jump_height>0.0,profile+" rotates/scales its response")
			var reverse := VehicleState.new(); reverse.position=direction*(half_length-0.1); reverse.velocity=-direction*14.0
			TrackHazards.launch(reverse,direction*(half_length+0.1),[placed])
			check(reverse.jump_height == 0.0,profile+" rejects reverse launch")
		var mesh_parent := Node3D.new()
		HazardVisual.build(mesh_parent,doc.objects[0])
		var mesh: ArrayMesh = mesh_parent.get_child(0).mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var bytes: int = var_to_bytes(arrays).size()
		geometry.append({"profile":profile,"array_bytes":bytes,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"triangles":arrays[Mesh.ARRAY_INDEX].size()/3})
		check(bytes < 384000,profile+" mesh stays within authoring memory bound")
		var bounds: AABB = mesh.get_aabb()
		check(absf(bounds.size.x-half.x*2.0)<0.001 and bounds.end.y <= JumpProfiles.peak(profile)+0.05,profile+" rendered dimensions match support")
		var correct_normals: bool = true
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for index: int in range(vertices.size()):
			if absf(vertices[index].z) >= half.y-0.05 or absf(vertices[index].x) >= half.x-0.05: continue
			correct_normals = correct_normals and normals[index].y > 0.85
		check(correct_normals,profile+" deck normals face upward without backface striping")
		if JumpProfiles.rounded(profile):
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var clear_edge: bool = true
			for index: int in range(vertices.size()):
				if vertices[index].y <= 0.04001: clear_edge = clear_edge and colors[index].a < 0.001
			check(clear_edge,profile+" zero-height edges blend into the receiving road")
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if vertex.y < 0.041: continue
			check(absf(vertex.y-0.04-JumpProfiles.height(doc.objects[0],Vector2(vertex.x,vertex.z)))<0.0041,profile+" all deck details sit on its actual surface")
		mesh_parent.free()
		var invalid: Dictionary = doc.duplicate(true); invalid.objects[0].jump_profile="unknown"
		check(not TrackDocument.validate(invalid).is_empty(),"reject unknown jump profile")
		invalid.objects[0].jump_profile=7
		check(not TrackDocument.validate(invalid).is_empty(),"reject non-string jump profile")
		invalid.objects[0].jump_profile=profile; invalid.objects[0].kind="rock"
		check(not TrackDocument.validate(invalid).is_empty(),"reject jump data on other objects")
	await editor_flow()
	if captures: await gallery()
	var report := FileAccess.open(OUT+"/results-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()+".json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements,"geometry":geometry},"\t")); report.close()
	print("EDITOR_JUMP_STYLES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func wait_editor(app: Node) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	for tick: int in range(3): await process_frame
	while (app.editor_preview_thread != null or app.canvas.preparing or app.editor_world._building) and Time.get_ticks_msec()<deadline: await process_frame
	check(app.editor_preview_thread == null and not app.canvas.preparing and not app.editor_world._building,"actual editor finishes preparing")
	await process_frame

func capture(name_value: String) -> void:
	if not captures: return
	for tick: int in range(4): await RenderingServer.frame_post_draw
	var path: String = OUT+"/"+RenderingServer.get_current_rendering_method()+"-"+name_value+".png"
	check(root.get_texture().get_image().save_png(path) == OK,"native screenshot "+name_value)

func tap(button: Button) -> void:
	var down := InputEventScreenTouch.new(); down.index=0; down.pressed=true; down.position=button.get_global_rect().get_center()
	root.push_input(down,true); await process_frame
	var up := InputEventScreenTouch.new(); up.index=0; up.pressed=false; up.position=down.position
	root.push_input(up,true); await process_frame

func open_palette(app: Node, category: String = "Props") -> void:
	app._editor_category("objects")
	app.object_browser.category=category; app.object_browser.page=0; app.object_browser.refresh()
	await process_frame; await process_frame

func ready_icons(browser: ObjectBrowser) -> void:
	if not captures: return
	var deadline: int = Time.get_ticks_msec()+15000
	var ready: bool = false
	while not ready and Time.get_ticks_msec()<deadline:
		ready=true
		for tile: Node in browser.tiles.get_children():
			if tile is ObjectThumbnail: ready = ready and tile._image.texture != null and tile._viewport == null
		await process_frame
	check(ready,"all five object cards publish their native previews")

func editor_flow() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var folder: String = ProjectSettings.globalize_path("res://../tmp/jump_palette_"+TrackLibrary.unique_id())
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library=TrackLibrary.new(folder); app.records=LocalRecords.new(folder+"/records.json"); app.cloud_root_override=folder+"/cloud"
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+15000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	check(app.startup_complete,"isolated actual app starts")
	var doc: Dictionary = document("desert")
	app.document=doc; app._show_screen("create")
	await process_frame; await wait_editor(app); await open_palette(app)
	check(app.object_browser.tiles.get_child_count() == 5,"Desert Props shows five separate jump and bump objects together")
	check(app.object_browser.tiles.find_child("Asset_jump",true,false) == null,"aggregate Jumps and bumps tile is removed")
	check(app.object_browser.details.find_child("JumpStyle",true,false) == null,"palette has no jump-style dropdown")
	await ready_icons(app.object_browser)
	await capture("desert-palette-1280")
	var keys: Dictionary = {}
	var pictures: Dictionary = {}
	for profile: String in JumpProfiles.IDS:
		await open_palette(app)
		var asset: String = CreatorCatalog.jump_asset(profile,"desert")
		var tile: ObjectThumbnail = app.object_browser.tiles.get_node("Asset_"+asset)
		check(tile != null and tile._kind == asset,profile+" has its own visible object card")
		keys[tile._cache_key]=true
		if captures:
			await ready_icons(app.object_browser)
			pictures[tile._image.texture.get_image().get_data().hex_encode().sha256_text()]=true
		await tap(tile)
		check(app.canvas.stamp_kind == "jump" and app.canvas.stamp_jump_profile == profile,"one native touch chooses "+profile)
		check(app.editor_status.text.begins_with(JumpProfiles.label(profile)),"placement guidance names the selected object")
		tile=app.object_browser.tiles.get_node("Asset_"+asset)
		check(app.object_browser.current == asset and tile.button_pressed,"matching card remains selected")
		var selected_count: int=0
		for other: Button in app.object_browser.tiles.get_children():
			if other.button_pressed: selected_count+=1
		check(selected_count == 1,"only the exact jump card is highlighted")
		await tap(tile)
		check(not app.object_browser.options.visible and app.canvas.mode == "place","reselecting "+profile+" keeps direct placement without a popup")
		app.canvas._place(app.canvas.to_screen(Vector2(-32+doc.objects.size()*16,0)))
		await wait_editor(app)
		check(JumpProfiles.id(doc.objects[-1]) == profile,"actual canvas places chosen "+profile)
		check(app.editor_context.find_child("JumpStyle",true,false) == null,"placed jump has normal object controls without a style menu")
	check(keys.size() == 5,"all five object previews have distinct cache identities")
	if captures: check(pictures.size() == 5,"all five cards show different rendered object previews")
	check(app.library.save_document(doc) == OK,"profiled document saves locally")
	check(app.library.load_document(doc.id).objects == doc.objects,"all separate objects survive file reload exactly")
	var before_copy: Array = doc.objects.duplicate(true)
	app._duplicate_object(); await wait_editor(app)
	check(JumpProfiles.id(app.document.objects[-1]) == "dune_v1","copy retains the exact selected object")
	app._undo(); await wait_editor(app)
	check(app.document.objects == before_copy,"undo restores exact objects after copying")
	var original_legacy: Dictionary = {"kind":"jump","position":[0,22],"rotation":0}
	app.document.objects.append(original_legacy.duplicate(true))
	app.canvas.selected_object=app.document.objects.size()-1; app.canvas.mode="objects"; app._build_editor_tools()
	check(app.editor_context.find_child("JumpStyle",true,false) == null,"legacy objects do not restore the rejected style navigation")
	await open_palette(app)
	var low: Button = app.object_browser.tiles.get_node("Asset_jump_low_ramp")
	await tap(low)
	check(app.document.objects[-1] == original_legacy,"choosing another object never changes an existing saved ramp")
	check(app.canvas.stamp_jump_profile == "low_ramp_v1","new selection changes only the placement object")
	await open_palette(app,"Recent")
	check(app.object_browser.tiles.get_child_count() == 5,"Recent keeps all five distinct object cards")
	await tap(app.object_browser.tiles.get_node("Asset_jump_kicker"))
	var saved_hash: String = TrackCompiler.document_hash(app.document,"")
	app._show_screen("tracks"); await process_frame; await process_frame
	app._show_screen("create"); await process_frame; await wait_editor(app)
	check(app.canvas.stamp_jump_profile == "kicker_v1" and app.object_browser.current == "jump_kicker","reopening the editor restores the exact selected jump card")
	check(TrackCompiler.document_hash(app.document,"") == saved_hash,"editor navigation does not alter saved object identities")
	for width: int in [1280,960]:
		root.size=Vector2i(width,720 if width==1280 else 540); root.content_scale_size=root.size
		for tick: int in range(4): await process_frame
		await open_palette(app)
		check(app.object_browser.tiles.get_child_count() == 5,"all five Desert cards fit at width "+str(width))
		await ready_icons(app.object_browser)
		for profile: String in JumpProfiles.IDS:
			var tile: Button = app.object_browser.tiles.get_node("Asset_"+CreatorCatalog.jump_asset(profile,"desert"))
			check(root.get_visible_rect().encloses(tile.get_global_rect()),profile+" is visible without paging at "+str(width))
		await tap(app.object_browser.tiles.get_node("Asset_jump_sand_rise"))
		check(app.canvas.stamp_jump_profile == "dune_v1" and not app.object_browser.options.visible,"Sand rise is one tap at "+str(width))
		await capture("desert-palette-"+str(width)+"-selected")
	app.queue_free(); await process_frame; await process_frame

func gallery() -> void:
	root.size = Vector2i(1536,920)
	root.content_scale_size = root.size
	var layout := GridContainer.new(); layout.columns=3; root.add_child(layout)
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://tests/fixtures/jump_styles_before/hazard_visual.gd.txt").replace("\r\n","\n").replace("class_name HazardVisual\n","")
	check(before.reload() == OK,"task-start jump builder loads for matched comparison")
	for profile: String in ["before"]+JumpProfiles.IDS:
		var column := VBoxContainer.new(); layout.add_child(column)
		var label := Label.new(); label.text="Original jump" if profile=="before" else JumpProfiles.label(profile)
		label.add_theme_font_size_override("font_size",24); column.add_child(label)
		var container := SubViewportContainer.new(); container.custom_minimum_size=Vector2(502,390); column.add_child(container)
		var viewport := SubViewport.new(); viewport.size=Vector2i(502,390); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
		var world := Node3D.new(); viewport.add_child(world)
		if profile == "before": before.build(world,{"kind":"jump","position":[0,0],"rotation":0})
		else: HazardVisual.build(world,object(profile))
		var ground := MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(24,24); ground.mesh=plane
		ground.position.y=-0.01; ground.material_override=VisualGeometry.material(Color("ad8957") if profile=="dune_v1" else Color("515657")); world.add_child(ground)
		var environment := WorldEnvironment.new(); var settings := Environment.new(); settings.background_mode=Environment.BG_COLOR; settings.background_color=Color("20272c"); settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_energy=0.55; settings.ambient_light_color=Color("d2d7d8"); environment.environment=settings; world.add_child(environment)
		var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-40,0); light.light_energy=1.15; world.add_child(light)
		var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=15; camera.position=Vector3(10,9,13); world.add_child(camera); camera.look_at(Vector3.ZERO)
	await capture("profile-comparison")
	layout.queue_free(); await process_frame
