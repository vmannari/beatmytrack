extends SceneTree
## Actual editor and shared shipping model captures. Isolated local draft only.
const OUTPUT: String = "res://../docs/evidence/track-object-refinement-2026-10-12"
var checks: int = 0
var failures: int = 0
var folder: String

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Use TestScript -Graphical for prop captures"); quit(1); return
	folder = ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1560,1080); root.content_scale_size = root.size
	var backdrop := ColorRect.new(); backdrop.color = Color("131f25"); backdrop.size = Vector2(1560,1080); root.add_child(backdrop)
	var index: int = 0
	for family: Array in CreatorCatalog.ASSETS:
		for kind: String in family[3]:
			var button: Button = ObjectThumbnail.make(kind,CreatorCatalog.label(kind),false,func() -> void: pass)
			backdrop.add_child(button); button.position = Vector2(20+(index%7)*220,20+(index/7)*174); button.scale = Vector2(2,2)
			index += 1
	await frames(8)
	await capture("all-37-icons.png")
	var pigment_metrics: Array[Dictionary] = []
	for button: ObjectThumbnail in backdrop.get_children():
		check(button._viewport == null,"one-shot thumbnail releases its 3D viewport: "+button.name)
		var pixels: Image = button._image.texture.get_image()
		var visible: int = 0; var edge: int = 0; var opaque: int = 0; var luminance: float = 0
		for y: int in range(pixels.get_height()):
			for x: int in range(pixels.get_width()):
				if pixels.get_pixel(x,y).a < 0.15: continue
				visible += 1
				var pixel: Color = pixels.get_pixel(x,y)
				if pixel.a > 0.95:
					opaque += 1; luminance += pixel.r*0.2126+pixel.g*0.7152+pixel.b*0.0722
				if x == 0 or y == 0 or x == pixels.get_width()-1 or y == pixels.get_height()-1: edge += 1
		check(visible > 90 and edge == 0,"rendered icon has visible unclipped silhouette: "+button.name)
		check(pixels.has_mipmaps(),"baked icon has minification mipmaps: "+button.name)
		var mean: float = luminance/maxi(1,opaque)
		var kind: String = button.name.trim_prefix("Asset_")
		pigment_metrics.append({"kind":kind,"opaque_pixels":opaque,"mean_luminance":mean})
		if kind in ["tree","broadleaf","bush"]: check(mean < 0.50,"foliage retains muted natural pigment on "+kind)
		if kind in ["tyre_stack","tyre_wall"]: check(mean < 0.38,"rubber remains dark on "+kind)
		if kind == "oil": check(mean < 0.24,"oil retains dark liquid pigment")
	var pigment_file := FileAccess.open(folder+"/icon-pigments.json",FileAccess.WRITE)
	pigment_file.store_string(JSON.stringify(pigment_metrics,"\t")); pigment_file.close()
	var cached: Button = ObjectThumbnail.make("crate","Crate",false,func() -> void: pass)
	check(cached._viewport == null,"repeated icon reuses a baked texture without a live viewport")
	cached.free(); backdrop.queue_free(); await process_frame
	root.size = Vector2i(1280,720); root.content_scale_size = root.size
	for category: String in CreatorCatalog.CATEGORIES: await category_stage(category)
	var folder_local: String = "user://prop_refinement_"+TrackLibrary.unique_id()
	var app: Node = load("res://core/app.gd").new()
	app.set("library",TrackLibrary.new(folder_local)); app.set("records",LocalRecords.new(folder_local+"/records.json"))
	root.add_child(app); await process_frame
	var document: Dictionary = TrackDocument.create_default()
	document.name = "Track object review"; document["automatic_scenery"] = false
	document.objects = []
	for i: int in range(12):
		document.objects.append({"kind":["tree","broadleaf","bush","rock","barrier","tyre_stack","crate","parked_car","container","shed","hut","grandstand"][i],"position":[-25+(i%6)*10,-7+(i/6)*14],"rotation":15})
	app.set("document",document); app.call("_show_screen","create"); await process_frame; app.call("_editor_category","objects")
	var browser: ObjectBrowser = app.get("object_browser")
	for width: int in [1280,960]:
		root.size = Vector2i(width,width*9/16); root.content_scale_size = root.size
		await frames(4)
		for category: String in CreatorCatalog.CATEGORIES:
			browser.category = category; browser.page = 0; browser.refresh()
			await frames(5)
			check(root.get_visible_rect().encloses(browser.get_global_rect()),"actual object menu fits "+str(width)+"/"+category)
			await capture("editor-%s-%d.png" % [category.to_lower(),width])
	app.queue_free(); await process_frame
	print("PROP_CAPTURE_TESTS: %d checks, %d failures; %s" % [checks,failures,folder])
	quit(1 if failures else 0)

func frames(count: int) -> void:
	for i: int in range(count): await RenderingServer.frame_post_draw

func capture(filename: String) -> void:
	check(root.get_texture().get_image().save_png(folder+"/"+filename) == OK,"save "+filename)

func category_stage(category: String) -> void:
	var stage := Node3D.new(); root.add_child(stage)
	var objects: Array = []
	for family: Array in CreatorCatalog.ASSETS:
		if family[2] != category: continue
		for kind: String in family[3]: objects.append({"kind":kind,"position":[-18+(objects.size()%4)*12,-10+(objects.size()/4)*10],"rotation":15})
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects}}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	var kit := NativeTrackVisual.new(); stage.add_child(kit); kit._build_placed_objects(track)
	VisualGeometry.box(stage,Vector3(70,0.1,60),Vector3(0,-0.10,0),VisualGeometry.material(Color("5c6759")))
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1b2b32")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6d6df")
	environment.environment.ambient_light_energy = 0.45; stage.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48,-38,0); light.light_color = Color("fff0d9"); light.shadow_enabled = true; stage.add_child(light)
	var car := CarVisual.new(); car.position = Vector3(22,0,10); car.rotation.y = PI*0.5; stage.add_child(car)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; stage.add_child(camera)
	var bounds: AABB = ObjectThumbnail._mesh_bounds(kit).merge(ObjectThumbnail._mesh_bounds(car))
	var target: Vector3 = bounds.get_center()
	camera.look_at_from_position(target+Vector3(18,34,-34),target)
	var low := Vector3(INF,INF,INF); var high := Vector3(-INF,-INF,-INF)
	for i: int in range(8):
		var p: Vector3 = camera.basis.transposed()*(bounds.get_endpoint(i)-target)
		low = low.min(p); high = high.max(p)
	var extent: Vector3 = high-low
	camera.size = maxf(extent.y,extent.x/(1280.0/720))*1.16; camera.current = true
	await frames(5); await capture("models-"+category.to_lower()+".png")
	stage.queue_free(); await process_frame
