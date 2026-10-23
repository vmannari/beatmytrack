extends SceneTree
## Shipping geometry, saved placement, retained edits and independent effect clocks.
const OUTPUT: String="res://../docs/evidence/barrel-fire-2026-10-16/night-regression"
var checks: int=0
var failures: int=0
var metrics: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func object(kind: String, x: float=0.0, y: float=0.0) -> Dictionary:
	return {"kind":kind,"position":[x,y],"rotation":0}
func document() -> Dictionary:
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="night_city"; doc["automatic_scenery"]=false
	doc.objects=[object("firefly_bush",-5,0),object("burning_barrel",-2,0),object("lantern_post",2,0),object("neon_arrow",5,0),object("burning_car",0,-5)]
	return doc

func run() -> void:
	for biome: String in TrackTheme.IDS:
		var count: int=0
		for family: Array in CreatorCatalog.filtered("All","",[],biome):
			if family[0] in PropNight.KINDS: count+=1
		check(count==(6 if biome=="night_city" else 0),biome+" filters Night's six families")
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"
	for kind: String in PropNight.KINDS:
		var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		check(CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1,0),kind+" uses shipping geometry")
		var mesh: ArrayMesh=tool.commit(); var arrays: Array=mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var valid: bool=vertices.size()>0 and normals.size()==vertices.size(); var collapsed: int=0
		for i: int in range(vertices.size()): valid=valid and vertices[i].is_finite() and normals[i].length()>0.9
		for i: int in range(0,vertices.size(),3):
			if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()<1e-16: collapsed+=1
		check(valid and collapsed==0,kind+" has finite normals and no degenerate geometry")
		check(vertices.size()/3<10000,kind+" has bounded triangle count")
		var bounds: AABB=mesh.get_aabb(); var size: Vector2=CreatorObjects.dimensions(kind)
		check(bounds.position.x>=-size.x*0.5 and bounds.end.x<=size.x*0.5 and bounds.position.z>=-size.y*0.5 and bounds.end.z<=size.y*0.5,kind+" fits its selection footprint")
		if kind=="firefly_bush":
			var opaque: bool=true
			for color: Color in arrays[Mesh.ARRAY_COLOR]: opaque=opaque and color.a==0
			check(opaque,"foliage carries no accidental emissive tag")
		if kind=="burning_barrel":
			var closed: bool=false
			for i: int in range(0,vertices.size(),3):
				var p: Vector3=(vertices[i]+vertices[i+1]+vertices[i+2])/3
				closed=closed or (p.y>1.01 and Vector2(p.x,p.z).length()<0.42)
			check(not closed,"barrel has an actual open top above the recessed fuel")
		metrics.append({"kind":kind,"triangles":vertices.size()/3,"bounds":str(bounds)})
		var doc: Dictionary=document(); doc.objects=[object(kind)]
		doc.paint=[{"surface":0,"width":20.0,"shape":"square","points":[[0,0]]}]
		check(TrackDocument.validate(doc).is_empty(),kind+" validates for saving")
		var track: NativeTrack=TrackCompiler.compile(doc)
		check(track!=null,kind+" compiles")
		if track!=null:
			check(track.cell_at(Vector2.ZERO)==(0 if kind in ["firefly_bush","burning_barrel","abandoned_warehouse"] else 4),kind+" has its intended ground behavior")
			check(TrackCompiler.compile(JSON.parse_string(JSON.stringify(doc))).content_hash==track.content_hash,kind+" saved JSON keeps compiled identity")
	kit.free()
	check(not CreatorObjects.solid_contains(object("burning_barrel"),Vector2(0.55,0.55)),"round barrel has no invisible square corner collision")
	check(not CreatorObjects.solid_contains(object("lantern_post"),Vector2(0.60,0)),"post collides at its foot, not beneath the hanging lantern")
	await burning_car_checks()
	await effects_and_cache()
	await retained_editor()
	await race_lifecycle()
	if DisplayServer.get_name()!="headless": await captures()
	print("NIGHT_PROP_METRICS: ",JSON.stringify(metrics))
	print("NIGHT_PROPS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func effects_and_cache() -> void:
	var track: NativeTrack=TrackCompiler.compile(document())
	var original: Dictionary=track.metadata.duplicate(true); var cells: PackedInt32Array=track.cells.duplicate()
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"; root.add_child(kit); kit._build_placed_objects(track)
	var fx: NightPropEffects=kit.get_node("NightPropEffects")
	check(fx.get_node("Fireflies").multimesh.instance_count==12,"one bush has twelve fireflies")
	check(fx.get_node("Flames").multimesh.instance_count==3 and fx.get_node("Embers").multimesh.instance_count==21 and fx.get_node("Smoke").multimesh.instance_count==9,"barrel and two car openings share bounded flame, ember and smoke instances")
	check(fx.warm_lights.size()==3,"burning barrel and lantern illuminate their surroundings")
	fx.advance(0.08,false); var t: float=fx.elapsed
	fx.advance(0.1,true); check(fx.elapsed==t,"pause freezes the actual effect clock")
	kit.hide(); fx.advance(0.1,false); check(fx.elapsed==t,"hidden world stops animation writes"); kit.show()
	fx.advance(0.1,false); check(fx.elapsed>t,"visible unpaused world resumes")
	check(track.metadata==original and track.cells==cells,"effects leave track/collision data exact")
	var dense: Array=[]
	for i: int in range(96): dense.append(object("firefly_bush" if i<48 else "burning_barrel",i*2))
	var busy: NightPropEffects=NightPropEffects.build(kit,dense)
	check(busy.get_node("Fireflies").multimesh.instance_count==384,"dense population caps fireflies at384")
	check(busy.get_node("Flames").multimesh.instance_count==32 and busy.get_node("Embers").multimesh.instance_count==224 and busy.get_node("Smoke").multimesh.instance_count==96,"dense population caps fires at32")
	check(busy.warm_lights.size()==4,"dense population caps extra shadowless lights at four")
	for light: OmniLight3D in busy.warm_lights: check(not light.shadow_enabled and light.light_cull_mask==1,"new warm lights preserve existing scene layers")
	for child: Node in busy.get_children():
		if child is MultiMeshInstance3D: check(child.multimesh.custom_aabb.size.y>=7.0,"animated culling bounds include the entire motion envelope")
	NightPropEffects.build(kit,original.creator_document.objects)
	var cache=preload("res://track/prepared_world_cache.gd")
	cache.remember(["night-prop-test"],kit,track)
	var restored:=NativeTrackVisual.new(); root.add_child(restored)
	check(cache.restore(["night-prop-test"],restored),"prepared world restores the effect controller")
	var copy: NightPropEffects=restored.get_node("NightPropEffects"); fx=kit.get_node("NightPropEffects")
	check(copy!=fx and copy.surfaces.size()==4,"cached world owns a fresh active controller")
	check(copy.surfaces[0]!=fx.surfaces[0],"restored world owns independent animation uniforms")
	for name: String in ["Fireflies","Flames","Embers","Smoke"]:
		check(copy.get_node(name).multimesh.custom_aabb==fx.get_node(name).multimesh.custom_aabb,"prepared world retains full shader motion bounds for "+name)
	var before: float=fx.elapsed; copy.advance(0.1,false)
	check(fx.elapsed==before,"another world's clock cannot change the original")
	var prep=preload("res://track/night_render_preparation.gd")
	var camera:=Camera3D.new(); restored.add_child(camera)
	var cover: Dictionary=prep.begin(restored,camera)
	for context: int in range(4): prep.set_context(cover,context)
	prep.end(cover)
	check(copy.warm_lights.all(func(light: OmniLight3D) -> bool: return light.visible),"covered shader preparation restores warm lights")
	kit.queue_free(); restored.queue_free(); await process_frame

func burning_car_checks() -> void:
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"; root.add_child(kit)
	var car: Dictionary=object("burning_car",12,-7); car.rotation=90; car["scale"]=1.5
	var original: Dictionary=car.duplicate(true)
	var fx: NightPropEffects=NightPropEffects.build(kit,[car])
	check(fx.get_node("Flames").multimesh.instance_count==2 and fx.get_node("Embers").multimesh.instance_count==14 and fx.get_node("Smoke").multimesh.instance_count==6,"one burning car has fire and smoke at both openings")
	check(fx.warm_lights.size()==1,"one car consumes only one warm light")
	check(car==original,"effect construction preserves saved car position/rotation/scale")
	if DisplayServer.get_name()!="headless":
		var mm: MultiMesh=fx.get_node("Flames").multimesh
		var pose:=Transform3D(Basis(Vector3.UP,PI*0.5).scaled(Vector3.ONE*1.5),Vector3(12,0.014,7))
		check(mm.get_instance_transform(0).origin.is_equal_approx(pose*Vector3(1.43,0.94+0.68*1.35,0.04)),"engine flame follows actual moved/rotated/scaled car")
		check(mm.get_instance_transform(1).origin.is_equal_approx(pose*Vector3(-0.38,1.03+0.68*1.05,0)),"cabin flame follows the second actual opening")
	var dense: Array=[]
	for i: int in range(96): dense.append(object("burning_car" if i%2==0 else "burning_barrel",i*5))
	fx=NightPropEffects.build(kit,dense)
	check(fx.get_node("Flames").multimesh.instance_count==32 and fx.get_node("Embers").multimesh.instance_count==224 and fx.get_node("Smoke").multimesh.instance_count==96,"mixed cars/barrels retain the exact existing32-source caps")
	check(fx.warm_lights.size()==4,"mixed cars/barrels retain four additional lights")
	for child: Node in fx.get_children():
		if child is MultiMeshInstance3D: check(child.multimesh.custom_aabb.size.y>=9.45,"larger car fire motion stays inside its culling envelope")
	kit.queue_free(); await process_frame

func retained_editor() -> void:
	var doc: Dictionary=document(); var track: NativeTrack=TrackCompiler.compile(doc)
	var kit:=NativeTrackVisual.new(); kit.editor_preview=true; kit.theme_id="night_city"; kit.colors=TrackTheme.palette("night_city"); root.add_child(kit)
	var batches=preload("res://editor/placed_object_batches.gd").new()
	check(await batches.refresh(kit,track,false,func() -> bool: return true),"editor builds all saved props")
	var fx: NightPropEffects=kit.get_node("NightPropEffects"); fx.externally_ticked=true
	check(not await batches.refresh(kit,track,false,func() -> bool: return true),"unchanged editor refresh does no reconstruction")
	check(kit.get_node("NightPropEffects")==fx,"unchanged refresh retains animated state")
	doc.objects[0].position=[-7,2]; doc.objects[0].scale=1.5; doc.objects[0].rotation=90
	track=TrackCompiler.compile(doc)
	check(await batches.refresh(kit,track,false,func() -> bool: return true),"move/rotate/scale updates the effect sources")
	check(kit.get_node("NightPropEffects")!=fx,"edited scene replaces stale source positions")
	doc.objects=[]; track=TrackCompiler.compile(doc)
	await batches.refresh(kit,track,false,func() -> bool: return true)
	check(kit.get_node_or_null("NightPropEffects")==null,"deleting all props clears effects and lights immediately")
	kit.queue_free(); await process_frame

func frames(count: int) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> void:
	var path: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path+"/"+name+".png")==OK,name+" capture saved")

func race_lifecycle() -> void:
	var game: Node=preload("res://core/game.tscn").instantiate()
	game.initial_track=TrackCompiler.compile(document()); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	var fx: NightPropEffects=game.track_ground.get_node_or_null("NightPropEffects")
	check(fx!=null,"normal race startup includes the saved Night prop effects")
	if fx!=null:
		var t: float=fx.elapsed; game.paused=true; game._present_frame(0.1)
		check(fx.elapsed==t,"actual race pause freezes its prop clock")
		game.paused=false; game._present_frame(0.1)
		check(fx.elapsed>t,"actual race presentation advances its prop clock")
		var state: Array=game.sim.state.snapshot(); game._present_frame(0.1)
		check(game.sim.state.snapshot()==state,"Night presentation leaves the canonical vehicle snapshot byte exact")
		game.restart()
		check(game.track_ground.get_node_or_null("NightPropEffects")!=null,"race restart retains the intact world effects")
	game.queue_free(); await process_frame

func captures() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var doc: Dictionary=document(); var track: NativeTrack=TrackCompiler.compile(doc)
	var stage:=Node3D.new(); root.add_child(stage)
	var kit:=NativeTrackVisual.new(); stage.add_child(kit); kit.build(track,BridgePresentation.new(track))
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); var e: Environment=env.environment
	e.background_mode=Environment.BG_COLOR; e.background_color=Color("060c19")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	stage.add_child(env)
	var moon:=DirectionalLight3D.new(); TrackTheme.apply_lighting("night_city",e,moon); stage.add_child(moon)
	var camera:=Camera3D.new(); stage.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=8.8; camera.current=true
	camera.look_at_from_position(Vector3(10,11,-19),Vector3(0,0.8,0))
	var fx: NightPropEffects=kit.get_node("NightPropEffects")
	for t: float in [0.6,1.4,2.5]:
		fx.elapsed=t; fx._publish(); await frames(4); await save("night-set-"+str(t))
	var a: PackedByteArray=root.get_texture().get_image().get_data()
	fx.advance(0.1,true); await frames(2)
	check(a==root.get_texture().get_image().get_data(),"paused actual shader uniforms keep the rendered image exact")
	fx.elapsed=4.1; fx._publish(); await frames(2)
	check(a!=root.get_texture().get_image().get_data(),"animated flame/firefly time changes actual native pixels")
	var icons:=Control.new(); root.add_child(icons)
	for i: int in range(PropNight.KINDS.size()):
		var kind: String=PropNight.KINDS[i]
		var button: ObjectThumbnail=ObjectThumbnail.make(kind,CreatorCatalog.label(kind),false,func() -> void: pass,"night_city")
		icons.add_child(button); button.position=Vector2(20+i*207,40); button.scale=Vector2(1.9,1.9)
	await frames(20); await save("palette-models")
	for button: ObjectThumbnail in icons.get_children(): check(button._viewport==null and button._image.texture!=null,"native thumbnail releases its one-shot effect viewport")
	icons.queue_free(); await process_frame
	# Native object-browser camera and materials: full-resolution model views.
	for kind: String in PropNight.KINDS:
		var button:=Button.new(); root.add_child(button)
		var view: SubViewport=ObjectThumbnail._render_preview(button,kind,"night_city")
		view.size=Vector2i(960,580)
		var model: NativeTrackVisual=view.get_child(0)
		var flame: NightPropEffects=model.get_node_or_null("NightPropEffects")
		if flame!=null: flame.elapsed=0.8; flame._publish()
		await frames(4)
		var path: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
		check(view.get_texture().get_image().save_png(path+"/"+kind+".png")==OK,kind+" native preview saved")
		button.queue_free(); await process_frame
	stage.queue_free(); await frames(2)
	await editor_capture()

func editor_capture() -> void:
	var app: Node=load("res://core/app.gd").new()
	var directory: String="user://night_props_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory)); app.set("records",LocalRecords.new(directory+"/records.json")); root.add_child(app)
	var deadline: int=Time.get_ticks_msec()+25000
	while not app.get("startup_complete") and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("startup_complete"),"Night editor completes covered startup")
	app.set("document",document()); app.call("_show_screen","create")
	deadline=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		var canvas: EditorCanvas=app.get("canvas")
		if canvas!=null and canvas.native_preview!=null and not app.get("editor_world")._building and app.get("editor_preview_thread")==null: break
		await process_frame
	check(app.get("canvas")!=null and app.get("canvas").native_preview!=null,"actual editor prepares saved Night props")
	app.call("_editor_category","objects")
	var browser: ObjectBrowser=app.get("object_browser")
	for category: String in ["Nature","Props","Trackside"]:
		browser.category=category; browser.page=0; browser.refresh()
		await frames(20); await save("editor-"+category.to_lower())
	app.queue_free(); await frames(3)
