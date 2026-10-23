extends SceneTree
const OUTPUT: String = "res://../docs/evidence/catalog-road-review-2026-10-16/"
var maps: Array[Image] = []
var saved: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i: int in range(16): await process_frame
	await RenderingServer.frame_post_draw

func write_sheet(folder: String, pictures: Array[Image]) -> void:
	if pictures.is_empty(): return
	var columns: int = mini(4,pictures.size())
	var sheet := Image.create(columns*320,ceili(float(pictures.size())/columns)*225,false,Image.FORMAT_RGB8)
	sheet.fill(Color("20272b"))
	for i: int in range(pictures.size()):
		var thumbnail: Image = pictures[i].duplicate()
		thumbnail.convert(Image.FORMAT_RGB8)
		thumbnail.resize(320,225,Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(thumbnail,Rect2i(0,0,320,225),Vector2i((i%columns)*320,(i/columns)*225))
	assert(sheet.save_png(folder+"/contact-sheet.png") == OK)

func run() -> void:
	if "--sheets-only" in OS.get_cmdline_user_args():
		for method: String in ["gl_compatibility","mobile"]:
			for phase: String in ["before","current"]:
				var folder: String = OUTPUT+method+"/"+phase
				if not FileAccess.file_exists(folder+"/captures.json"): continue
				var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(folder+"/captures.json"))
				var pictures: Array[Image] = []
				for entry: Dictionary in entries: pictures.append(Image.load_from_file(folder+"/"+entry.map))
				write_sheet(folder,pictures)
				print("CATALOG_SHEET ",method," ",phase," ",pictures.size())
		quit(); return
	root.size = Vector2i(1280,900)
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var drafts: bool = "--drafts" in OS.get_cmdline_user_args()
	var selected: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): selected = arg.trim_prefix("--only=")
	if baseline and selected.is_empty(): selected = "Saw"
	var folder: String = OUTPUT+RenderingServer.get_current_rendering_method()+("/before" if baseline else ("/current-drafts" if drafts else "/current"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/catalog-road-review-2026-10-16/"+("supplemental-manifest.json" if drafts else "manifest.json")))
	var layer := CanvasLayer.new(); root.add_child(layer)
	var title := Label.new(); title.position = Vector2(14,10); title.add_theme_font_size_override("font_size",24); title.add_theme_color_override("font_outline_color",Color.BLACK); title.add_theme_constant_override("outline_size",6); layer.add_child(title)
	for entry: Dictionary in manifest.entries:
		if not selected.is_empty() and entry.name != selected: continue
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.path))
		var track: NativeTrack = TrackCompiler.compile(document)
		var game: Node = preload("res://core/game.tscn").instantiate()
		game.initial_track = track; game.production_mode = true
		root.add_child(game)
		game.set_physics_process(false); game.set_process(false); game.paused = true; game.race_cues.hide(); game.hud.hide()
		if baseline:
			var source: String = FileAccess.get_file_as_string(OUTPUT+"before-source/native_track_visual.gd").replace("\r\n","\n")
			var method: String = "func _build_creator_roads"+source.get_slice("func _build_creator_roads",1).get_slice("\nfunc ",0)
			method = method.replace('preload("res://track/desert_road_union.gd").new()','preload("res://../docs/evidence/catalog-road-review-2026-10-16/baseline/desert_road_union.gd").new()')
			method = method.replace('ShoulderMesh.new()','preload("res://../docs/evidence/catalog-road-review-2026-10-16/baseline/shoulder_mesh.gd").new()')
			var script := GDScript.new(); script.source_code = "extends NativeTrackVisual\n"+method
			assert(script.reload() == OK)
			var old: NativeTrackVisual = script.new()
			old.cache_road_meshes = false; old.persist_road_meshes = false; old.cache_race_world = false
			var parent: Node = game.track_ground.get_parent(); game.track_ground.free(); parent.add_child(old)
			await old.build(track,BridgePresentation.new(track)); game.track_ground = old
		var bounds := Rect2(track.route[0],Vector2.ZERO)
		for point: Vector2 in track.route: bounds = bounds.expand(point)
		bounds = bounds.grow(16.0)
		var camera: Camera3D = game.camera
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(bounds.size.y,bounds.size.x*900.0/1280.0)
		camera.position = VisualGeometry.world(bounds.get_center())+Vector3.UP*100
		camera.rotation_degrees = Vector3(-90,0,0)
		assert(camera.far > camera.position.y+1.0)
		title.text = entry.name+" - "+entry.theme
		await settle()
		var picture: Image = root.get_texture().get_image()
		var name: String = str(entry.name).to_lower().replace(" ","-")
		assert(picture.save_png(folder+"/"+name+"-map.png") == OK)
		var thumbnail: Image = picture.duplicate(); thumbnail.resize(320,225,Image.INTERPOLATE_LANCZOS); maps.append(thumbnail)
		saved.append({"name":entry.name,"map":name+"-map.png","theme":entry.theme})
		if entry.name in ["Saw","Ajorata"]:
			var point := Vector2(-14,-41) if entry.name == "Ajorata" else Vector2(0,0)
			if entry.name == "Saw":
				var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"prepared.json"))
				for row: Dictionary in review.results:
					if row.name == "Saw": point = Vector2(row.before.widest_gaps[0].point[0],row.before.widest_gaps[0].point[1])
			game.sim.state.position = point; game.previous_position = point
			game._process(0.0); camera.follow(point,Vector2.ZERO,game.sim.state.heading,0,true)
			await settle()
			assert(root.get_texture().get_image().save_png(folder+"/"+name+"-detail.png") == OK)
		game.free(); await process_frame
		print("CATALOG_CAPTURE ",entry.name," ",RenderingServer.get_current_rendering_method()," baseline=",baseline)
		var file := FileAccess.open(folder+"/captures.json",FileAccess.WRITE); file.store_string(JSON.stringify(saved,"\t")); file.close()
	write_sheet(folder,maps)
	layer.free()
	print("CATALOG_CAPTURE_COMPLETE ",saved.size()," tracks")
	quit()
