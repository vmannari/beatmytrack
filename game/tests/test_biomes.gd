extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	var folder: String = "user://biomes_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("library",TrackLibrary.new(folder))
	app.set("records",LocalRecords.new(folder+"/records.json"))
	root.add_child(app)
	await process_frame
	for biome: String in TrackDocument.THEMES:
		app.call("_show_screen","play")
		var create: Button = app.get("root_ui").find_child("Tab_create",true,false)
		create.pressed.emit()
		await process_frame
		check(app.get("screen")=="biome" and app.get("canvas")==null,"Create requires biome before editing")
		var doc: Dictionary = app.get("document")
		check(doc.pieces.is_empty() and doc.objects.is_empty() and doc.paint.is_empty() and doc.layout.is_empty() and doc.base_track.is_empty(),"new track has no authored geometry")
		var choice: Button = app.get("root_ui").find_child("Biome_"+biome,true,false)
		check(choice != null and choice.icon != null and choice.size.y>=260,"large scenic biome choice")
		if biome=="pine" and "--capture" in OS.get_cmdline_user_args():
			for i: int in range(3): await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/biomes"))
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/biomes/picker.png"))
		choice.pressed.emit()
		await process_frame
		check(app.get("screen")=="create" and doc.theme==biome,"choice opens selected empty biome")
		check(app.get("root_ui").find_child("EditorBiome",true,false)==null,"editor has no biome menu")
		app.call("_set_document_value","theme","desert" if biome!="desert" else "pine")
		app.call("_select_creation_biome","coast")
		check(doc.theme==biome and app.get("history").is_empty(),"biome is immutable and cannot be undone")
		var trees: Array = CreatorCatalog.filtered("Nature","Pine tree",[],biome)
		check(trees.is_empty()==(biome not in ["pine","winter","storm"]),"pine trees restricted to forest")
		check(not CreatorCatalog.filtered("Barriers","Tyres",[],biome).is_empty(),"race equipment shared")
		if biome=="desert" and "--capture" in OS.get_cmdline_user_args():
			app.call("_editor_category","objects")
			for i: int in range(5): await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/biomes/desert-editor.png"))
		app.call("_new_document")
		check(app.get("screen")=="biome" and app.get("document").id!=doc.id,"New repeats required selection with fresh identity")
	app.queue_free()
	await process_frame
	check(TrackTheme.IDS == ["pine","desert","night_city","winter","storm"],"exact owner biome catalog")
	for biome: String in ["night_city","winter","storm"]:
		var sample: Dictionary = TrackDocument.create_default()
		sample.theme = biome
		for x: float in [-46.0,-29.0,-12.0]:
			sample.objects.append({"kind":"light","position":[x,-6.0],"rotation":0.0,"scale":1.0})
		sample.objects.append({"kind":"tree","position":[-25.0,-20.0],"rotation":0.0,"scale":1.0})
		var compiled: NativeTrack = TrackCompiler.compile(sample)
		check(compiled != null,"new biome compiles")
		var race: Node = load("res://core/game.tscn").instantiate()
		race.initial_track = compiled
		race.production_mode = true
		root.add_child(race)
		await process_frame
		var lamps: Array[Node] = race.find_children("*","OmniLight3D",true,false)
		check(lamps.size() == (3 if biome == "night_city" else 0),"lamps illuminate night only")
		if "--capture" in OS.get_cmdline_user_args():
			for i: int in range(5): await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/biomes/"+biome+"-race.png"))
		race.queue_free()
		await process_frame
	# Audio playback cleanup runs on the mixer thread even in headless tests.
	await create_timer(0.15).timeout
	print("BIOMES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

