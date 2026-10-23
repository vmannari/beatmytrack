extends SceneTree
const OUTPUT: String = "res://../docs/evidence/biome-object-kits-2026-10-18"
const DESERT: Array[String] = ["pebbles","rock","slate","cliff","chevron","braking_board","flag","gantry","egypt_pyramid","egypt_obelisk","egypt_column","egypt_wall"]
const WINTER: Array[String] = ["tree","pebbles","rock","slate","cliff","log","tyre_stack","barrier","guardrail","fence","cone","chevron","braking_board","flag","light","gantry","shed","hut","igloo","snow_castle","snowman","snow_lantern","ice_lantern","ice_compact"]
var checks: int = 0
var failures: int = 0
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func original(name: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/fixtures/biome_kits_before/"+name+".gd.txt").replace("\r\n","\n").replace("class_name CreatorCatalog\n","").replace("class_name CreatorPropVisual\n","")
	check(script.reload() == OK,"preserved "+name+" compiles")
	return script
func prop(kind: String, x: float = 0, y: float = 0) -> Dictionary: return {"kind":kind,"position":[x,y],"rotation":0.0}
func track_for(objects: Array) -> NativeTrack:
	var track := NativeTrack.new(); track.metadata = {"creator_document":{"objects":objects},"scenery_objects":[]}; track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	return track
func run() -> void:
	root.size = Vector2i(1280,720)
	var old_catalog: GDScript = original("creator_catalog")
	var no_recent: Array[String] = []
	for biome: String in TrackTheme.IDS:
		var expected: Array = DESERT if biome == "desert" else WINTER if biome == "winter" else old_catalog.filtered("All","",no_recent,biome).map(func(asset: Array) -> String: return asset[0])
		var offered: Array = CreatorCatalog.filtered("All","",[],biome).map(func(asset: Array) -> String: return asset[0])
		check(offered == expected,biome+" has the exact intended collection")
		for family: Array in CreatorCatalog.ASSETS:
			for kind: String in family[3]: check(CreatorCatalog.available(kind,biome) == (family[0] in offered),kind+" variants follow their biome family")
			var recent: Array[String] = [family[0]]
			check(CreatorCatalog.filtered("Recent","",recent,biome).is_empty() == (family[0] not in offered),"Recent cannot leak a restricted "+family[0])
			check(CreatorCatalog.filtered(family[2],family[1],[],biome).any(func(asset: Array) -> bool: return asset[0] == family[0]) == (family[0] in offered),"category search obeys availability")
	population_checks()
	var old_visual: GDScript = original("creator_prop_visual")
	for kind: String in CreatorPropVisual.WINTER_FINISH.KINDS:
		for biome: String in TrackTheme.IDS:
			var kit := NativeTrackVisual.new(); kit.theme_id = biome
			var before := SurfaceTool.new(); before.begin(Mesh.PRIMITIVE_TRIANGLES)
			var after := SurfaceTool.new(); after.begin(Mesh.PRIMITIVE_TRIANGLES)
			old_visual.append(before,kit,kind,Vector3.ZERO,1,0)
			CreatorPropVisual.append(after,kit,kind,Vector3.ZERO,1,0)
			var a: Array = before.commit_to_arrays(); var b: Array = after.commit_to_arrays()
			if biome != "winter": check(a == b,biome+"/"+kind+" retains every original vertex/channel")
			else:
				var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
				check(bv.size() > av.size() and bv.size()-av.size() <= 6144,kind+" gains bounded fitted snow geometry")
				check(bv.slice(0,av.size()) == av,kind+" retains its complete original body geometry")
				check(b[Mesh.ARRAY_COLOR] != a[Mesh.ARRAY_COLOR],kind+" has a dedicated Winter finish")
				rows.append({"kind":kind,"original_vertices":av.size(),"winter_vertices":bv.size()})
			kit.free()
	for family: Array in CreatorCatalog.filtered("All","",[],"winter"):
		for kind: String in family[3]:
			var kit := NativeTrackVisual.new(); kit.theme_id = "winter"; kit._build_placed_objects(track_for([prop(kind)]))
			check(kit.get_child_count() > 0,kind+" builds its actual Winter placement")
			if kind in ["tyre_stack","tyre_wall"]:
				check(kit.tyre_instances.multimesh.mesh.get_meta("winter_variant","") == "tyre_stack","movable tyre instances own the Winter mesh")
				var state := VehicleState.new(); state.loose_tyres = [[3.0,4.0,0.0,0.0,0.5]]
				kit.update_tyres(state,PackedVector2Array([Vector2.ZERO]))
				# The headless dummy renderer returns identity for MultiMesh reads.
				# Native runs verify the actual submitted pose as well as CPU state.
				check(kit._tyre_positions[0] == Vector2(3,4) and kit._tyre_spins[0] == 0.5 and (DisplayServer.get_name() == "headless" or kit.tyre_instances.multimesh.get_instance_transform(0).origin.distance_to(Vector3(3,0.014,-4)) < 0.00001),"snow-covered tyres retain their movable transform")
			kit.free()
	await browser_checks()
	check(CreatorPropVisual.cache_bytes <= CreatorPropVisual.CACHE_BUDGET,"Winter meshes stay in the existing bounded cache")
	if DisplayServer.get_name() != "headless": await captures()
	var folder: String = ProjectSettings.globalize_path(OUTPUT+"/"+("headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method()))
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":rows},"\t")); file.close()
	print("BIOME_OBJECT_KITS: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

func population_checks() -> void:
	for biome: String in ["pine","night_city","storm"]:
		var canvas := EditorCanvas.new(); canvas.document = TrackDocument.create_blank(); canvas.document.theme = biome; canvas.size = Vector2(1280,720); canvas.mode = "place"; canvas.stamp_kind = "tree"
		canvas._place(Vector2(640,360)); check(canvas.document.objects.size() == 1,biome+" retains its existing direct-stamp behavior")
		canvas.free()
	for biome: String in ["desert","winter"]:
		var doc: Dictionary = TrackDocument.create_default(); doc.theme = biome; doc["automatic_scenery"] = false
		var track: NativeTrack = TrackCompiler.compile(doc)
		var generator := ObjectPopulation.new(); generator.prepare(doc,track)
		for seed: int in range(12):
			var generated: Array = generator.generate(seed,0.8,24.0)
			check(not generated.is_empty() and generated.size() <= 96,biome+" Populate remains useful and bounded")
			check(generated.all(func(object: Dictionary) -> bool: return CreatorCatalog.available(object.kind,biome)),biome+" Populate follows the complete curated collection")
			check(generated == generator.generate(seed,0.8,24.0),biome+" Populate stays deterministic")
		# Loading old documents retains placed items; only new placement is curated.
		doc.objects = [prop("hay_bale",-18,16),prop("oil",-10,16),prop("container",0,16),prop("parked_car",12,16),prop("car_wreck",22,16)]
		var saved: String = JSON.stringify(doc)
		check(TrackDocument.validate(doc).is_empty() and TrackCompiler.compile(doc) != null and JSON.stringify(doc) == saved,biome+" existing saved industrial objects survive validation/compilation unchanged")
		var canvas := EditorCanvas.new(); canvas.document = doc; canvas.mode = "place"; canvas.stamp_kind = "container"
		var count: int = doc.objects.size(); canvas._place(Vector2(60,60))
		check(doc.objects.size() == count,biome+" stale unavailable stamps cannot place new objects")
		canvas.stamp_kind = "wire_fence"; check(canvas._path_run(PackedVector2Array([Vector2.ZERO,Vector2(5,0)])).is_empty(),biome+" stale runs cannot add unavailable fences")
		canvas.free()

func browser_checks() -> void:
	var browser := ObjectBrowser.new(); browser.biome = "desert"; browser.current = "container"; browser.hide(); root.add_child(browser)
	var chosen: Array[String] = []; browser.asset_chosen.connect(func(kind: String) -> void: chosen.append(kind))
	browser.show(); await process_frame
	check(CreatorCatalog.available(browser.current,"desert") and not chosen.is_empty(),"opening a retained browser replaces its unavailable old stamp")
	var current: String = browser.current; browser.choose("hay_bale")
	check(browser.current == current,"direct browser selection cannot bypass the biome collection")
	check(not browser.categories.get_node("Category_Barriers").visible and not browser.categories.get_node("Category_Props").visible,"Desert omits empty object categories")
	browser.category = "Props"; browser.refresh(); check(browser.category == "All","retained unavailable category returns to the biome collection")
	browser.queue_free(); await process_frame

func captures() -> void:
	for biome: String in ["desert","winter"]:
		var scene := Node3D.new(); root.add_child(scene)
		var kit := NativeTrackVisual.new(); kit.theme_id = biome; scene.add_child(kit)
		var objects: Array = [prop("shed",-5,-5),prop("hut",5,-5),prop("log",-5,5),prop("guardrail",0,4),prop("tyre_stack",4,4),prop("light",8,-2),prop("tree",-10,-4),prop("chevron",-2,0),prop("braking_board",1,0),prop("cone",4,1)] if biome == "winter" else [prop("egypt_pyramid",-7,-5),prop("egypt_obelisk",6,-2),prop("egypt_column",2,4),prop("egypt_column_broken",7,5),prop("egypt_wall",-5,5),prop("rock",9,-6)]
		kit._build_placed_objects(track_for(objects))
		var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(80,80); floor_mesh.mesh = plane; floor_mesh.position.y = -0.02; floor_mesh.material_override = VisualGeometry.material(Color("c8d7e2") if biome == "winter" else Color("b69565")); scene.add_child(floor_mesh)
		var env := WorldEnvironment.new(); env.environment = Environment.new(); scene.add_child(env)
		var sun := DirectionalLight3D.new(); scene.add_child(sun); TrackTheme.apply_lighting(biome,env.environment,sun)
		var camera := Camera3D.new(); scene.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 28; camera.current = true; camera.look_at_from_position(Vector3(22,22,30),Vector3(0,0,0))
		var browser := ObjectBrowser.new(); browser.biome = biome; browser.current = "rock"; browser.category = "Buildings" if biome == "desert" else "All"; root.add_child(browser); browser.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); browser.offset_left = 40; browser.offset_right = -40; browser.offset_top = -160; browser.offset_bottom = -18
		for tick: int in range(12): await process_frame; await RenderingServer.frame_post_draw
		var folder: String = ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(folder)
		check(root.get_texture().get_image().save_png(folder.path_join(biome+"-collection.png")) == OK,"actual "+biome+" world and object browser capture")
		browser.queue_free(); scene.queue_free(); await process_frame
	# Exact thumbnail builder also proves that the studio sees the same snow caps.
	for kind: String in ["shed","hut","barrier","guardrail","log","tyre_stack","cliff","gantry"]:
		var owner := Button.new(); root.add_child(owner)
		var viewport: SubViewport = ObjectThumbnail._render_preview(owner,kind,"winter")
		for tick: int in range(3): await process_frame; await RenderingServer.frame_post_draw
		var folder: String = ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
		check(viewport.get_texture().get_image().save_png(folder.path_join("winter-"+kind+".png")) == OK,"native Winter preview "+kind)
		owner.queue_free(); await process_frame
