extends SceneTree
## Real Winter models, canonical contacts, finite effects and restored presentation.
const OUTPUT: String="res://../docs/evidence/winter-craft-2026-10-16"
var checks: int=0
var failures: int=0
var metrics: Array=[]
var config: HandlingConfig
var clear: Callable=func(_p: Vector2,_r: float,_d: bool) -> Vector3: return Vector3.ZERO

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)

func run() -> void:
	config=VehicleCatalog.config("compact")
	for biome: String in TrackTheme.IDS:
		var count: int=0
		for family: Array in CreatorCatalog.filtered("All","",[],biome):
			if family[0] in PropWinterCraft.KINDS: count+=1
		check(count==(6 if biome=="winter" else 0),biome+" offers the six Winter craft families only where appropriate")
	var kit:=NativeTrackVisual.new(); kit.theme_id="winter"
	for kind: String in PropWinterCraft.KINDS:
		var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		check(CreatorPropVisual.append(tool,kit,kind,Vector3.ZERO,1,0),kind+" uses the shipping cached model")
		var mesh: ArrayMesh=tool.commit()
		var arrays: Array=mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var valid: bool=vertices.size()>0 and normals.size()==vertices.size()
		var collapsed: int=0
		for i: int in range(vertices.size()): valid=valid and vertices[i].is_finite() and normals[i].is_finite() and normals[i].length()>0.9
		for i: int in range(0,vertices.size(),3):
			if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()<1e-16: collapsed+=1
		check(valid and collapsed==0,kind+" has finite normals and no collapsed triangles")
		check(vertices.size()/3<10000,kind+" remains below ten thousand triangles")
		var bounds: AABB=mesh.get_aabb(); var size: Vector2=CreatorObjects.dimensions(kind)
		check(bounds.position.x>=-size.x*0.5 and bounds.end.x<=size.x*0.5 and bounds.position.z>=-size.y*0.5 and bounds.end.z<=size.y*0.5,kind+" stays inside the authored selection footprint")
		metrics.append({"kind":kind,"triangles":vertices.size()/3,"bounds":str(bounds)})
		var doc: Dictionary=TrackDocument.create_default(); doc.theme="winter"; doc.objects=[object(kind)]
		doc.paint=[{"surface":0,"width":20.0,"shape":"square","points":[[0,0]]}]
		check(TrackDocument.validate(doc).is_empty(),kind+" validates as a saved authoring object")
		var track: NativeTrack=TrackCompiler.compile(doc)
		check(track!=null,"Winter model fixture compiles: "+str(TrackDocument.validate(doc)))
		if track==null: continue
		check(track!=null and track.cell_at(Vector2.ZERO)==(0 if kind in PropWinterCraft.BREAKABLE else 4),kind+" compiles the appropriate solid or breakable footprint")
		var saved: Dictionary=JSON.parse_string(JSON.stringify(doc))
		check(TrackDocument.validate(saved).is_empty() and TrackCompiler.compile(saved).content_hash==track.content_hash,kind+" JSON round trip keeps its compiled identity")
	kit.free()
	check(CreatorObjects.solid_contains(object("igloo"),Vector2(0,3.9)) and not CreatorObjects.solid_contains(object("igloo"),Vector2(3.3,3.9)),"igloo collision follows the dome and projecting entrance rather than invisible rectangular corners")
	for kind: String in PropWinterCraft.BREAKABLE: await destruction(kind)
	await legacy_exact()
	await driven_replays()
	fragment_budget()
	print("WINTER_CRAFT_METRICS: ",JSON.stringify(metrics))
	if DisplayServer.get_name()!="headless": await captures()
	print("WINTER_CRAFT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func object(kind: String) -> Dictionary: return {"kind":kind,"position":[0,0],"rotation":0}

func advance(state: VehicleState, props: Array) -> void:
	LightProps.step(state,props,clear,state.position-Vector2(0.35,0),VehicleSimulation.STEP,config.mass,config.collision_radius)
	state.tick+=1

func hit(state: VehicleState, props: Array, index: int, speed: float) -> void:
	if state.light_props.is_empty():
		state.position=Vector2(100,100); advance(state,props)
	var p:=Vector2(state.light_props[index][0],state.light_props[index][1])
	state.position=p-Vector2(0.20,0); state.velocity=Vector2(speed,0); state.heading=PI*0.5
	advance(state,props)

func destruction(kind: String) -> void:
	var props: Array=[object(kind)]
	var state:=VehicleState.new()
	hit(state,props,0,12.0)
	check(state.prop_destruction[0][0]==0.0,kind+" breaks on an actual ground contact")
	check(not state.prop_fragments.is_empty() and state.prop_fragments.size()<=13,kind+" emits a bounded material-specific burst")
	var solid: int=0; var powder: int=0
	for row: Array in state.prop_fragments:
		if int(row[0])==(BreakableProps.ICE if kind=="ice_lantern" else BreakableProps.SNOW): solid+=1
		if int(row[0])==BreakableProps.POWDER: powder+=1
	check(solid>0 and powder>0,kind+" has correct chunks or shards and powder")
	var snapshot: Array=state.snapshot()
	var properties: Dictionary=RewindHistory.properties(state)
	for i: int in range(40): advance(state,props)
	var later: Array=state.snapshot()
	RewindHistory.restore(state,properties)
	check(state.snapshot()==snapshot,kind+" rewind restores exact fragments and saved lifetime")
	for i: int in range(40): advance(state,props)
	check(state.snapshot()==later,kind+" restored branch repeats the exact later effect state")
	var count: int=state.prop_fragments.size(); hit(state,props,0,12)
	check(state.prop_fragments.size()==count,kind+" cannot spawn duplicate fragments after destruction")
	var gentle:=VehicleState.new(); hit(gentle,props,0,0.8)
	check(gentle.prop_destruction[0][0]==1.0 and gentle.prop_fragments.is_empty(),kind+" gentle nudge does not explode")
	for layer: int in [0,1]:
		var other:=VehicleState.new(); other.track_elevated=layer==0; other.jump_height=1.0 if layer==1 else 0.0
		hit(other,props,0,12)
		check(other.prop_destruction[0][0]==1.0 and other.prop_fragments.is_empty(),kind+" bridge/airborne car cannot break a ground prop")
	var track:=NativeTrack.new(); track.metadata={"creator_document":{"objects":props}}
	var visual:=NativeTrackVisual.new(); visual.theme_id="winter"; root.add_child(visual); visual._build_placed_objects(track)
	visual.update_light_props(state)
	check(not visual.light_instances[0].visible,kind+" destroyed model and candle are hidden together")
	var before: Array=state.snapshot(); visual.update_light_props(state)
	check(state.snapshot()==before,kind+" rendering never mutates canonical damage/effect data")
	visual.update_light_props(VehicleState.new())
	check(visual.light_instances[0].visible,kind+" restarting restores the intact model and its candle immediately")
	for node_name: String in ["SnowChunks","IceShards","SnowPowder"]: check(visual.get_node(node_name).multimesh.instance_count==0,kind+" restarting clears "+node_name)
	RewindHistory.restore(state,properties); visual.update_light_props(state)
	check(not visual.light_instances[0].visible and visual.get_node("SnowPowder").multimesh.instance_count>0,kind+" earlier damaged snapshot rehydrates effects after reset")
	for i: int in range(400): advance(state,props)
	check(state.prop_fragments.is_empty(),kind+" finite effects retire after settling")
	visual.queue_free(); await process_frame

func legacy_exact() -> void:
	var old:=GDScript.new()
	old.source_code=FileAccess.get_file_as_string("res://tests/fixtures/winter_craft_before/breakable_props.gd.txt").replace("class_name BreakableProps\n","").replace("\r\n","\n")
	# Normalize before removing the class declaration on Windows checkouts.
	old.source_code=old.source_code.replace("class_name BreakableProps\n","")
	check(old.reload()==OK,"preserved pre-task breakable implementation loads")
	for kind: String in ["crate","hay_bale"]:
		var props: Array=[object(kind)]; var a:=VehicleState.new(); var b:=VehicleState.new()
		a.light_props=[[0.0,0.0,0.0,0.0,0.0]]; b.light_props=a.light_props.duplicate(true)
		old.prepare(a,props); BreakableProps.prepare(b,props)
		for tick: int in range(240):
			a.position=Vector2(-0.2,0) if tick%80==0 else Vector2(50,50)
			a.velocity=Vector2(24,0) if tick%80==0 else Vector2.ZERO
			b.position=a.position; b.velocity=a.velocity
			old.step_one(a,props,0,clear,a.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			BreakableProps.step_one(b,props,0,clear,b.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			old.step_fragments(a,clear,a.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			BreakableProps.step_fragments(b,clear,b.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			check(a.snapshot()==b.snapshot(),kind+" legacy collision, fragments and full snapshot stay exact at "+str(tick))

func driven_replays() -> void:
	for car: String in VehicleCatalog.IDS:
		var doc: Dictionary=TrackDocument.create_default(); doc.theme="winter"; doc["automatic_scenery"]=false
		doc.paint=[{"surface":0,"width":30.0,"shape":"square","points":[[-20,0],[20,0]]}]
		doc.objects=[{"kind":"snowman","position":[-3,0],"rotation":0},{"kind":"snow_lantern","position":[0,0],"rotation":0},{"kind":"ice_lantern","position":[3,0],"rotation":0}]
		var track: NativeTrack=TrackCompiler.compile(doc)
		check(track!=null,"driven Winter fixture compiles: "+str(TrackDocument.validate(doc)))
		if track==null: continue
		var a:=VehicleSimulation.new(VehicleCatalog.config(car)); var b:=VehicleSimulation.new(VehicleCatalog.config(car))
		a.reset(Vector2(-14,0),PI*0.5); b.reset(Vector2(-14,0),PI*0.5)
		var inputs: Array=[]
		for tick: int in range(480):
			var frame:=DriveFrame.new(); frame.throttle=255; inputs.append(frame.packed()); a.step(frame,track)
		for values: Array in JSON.parse_string(JSON.stringify(inputs)):
			var frame:=DriveFrame.new(); frame.steer=values[0]; frame.throttle=values[1]; frame.brake=values[2]; frame.handbrake=values[3] if values.size()>3 else 0
			b.step(frame,track)
		check(a.state.snapshot()==b.state.snapshot(),car+" actual driven Winter destruction replays exactly from JSON inputs")
		var broken: int=0
		for row: Array in a.state.prop_destruction:
			if row[0]==0.0: broken+=1
		check(broken==3,car+" drives through and breaks all three Winter props")
		print("WINTER_DRIVE: ",car," position=",a.state.position," damage=",a.state.prop_destruction)

func fragment_budget() -> void:
	var state:=VehicleState.new()
	state.prop_fragments=[[BreakableProps.WOOD,0,20.0,20.0,0.0,0.0,0.0,0.0,0.8,0.1,3.0,1.0]]
	for i: int in range(96): BreakableProps._break_winter(state,i,object("snowman"),Vector2.ZERO,Vector2.ZERO,Vector2.RIGHT,1.0)
	check(state.prop_fragments.size()==BreakableProps.MAX_WINTER_FRAGMENTS+1 and state.prop_fragments[0][0]==BreakableProps.WOOD,"192-fragment Winter cap cannot discard existing physical wood")
	state.position=Vector2.ZERO; state.velocity=Vector2(8,0)
	var incoming: Vector2=state.velocity
	BreakableProps.step_fragments(state,clear,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(state.velocity==incoming,"snow, ice and powder fragments do not change grip or impart collision forces")

func frames(count: int) -> void:
	for i: int in range(count): await process_frame
	await RenderingServer.frame_post_draw

func save(name: String) -> void:
	var folder: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(folder)
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,name+" native capture saved")

func captures() -> void:
	root.size=Vector2i(1600,900); root.content_scale_size=root.size
	var icons:=Control.new(); root.add_child(icons)
	for i: int in range(PropWinterCraft.KINDS.size()):
		var kind: String=PropWinterCraft.KINDS[i]
		var button: ObjectThumbnail=ObjectThumbnail.make(kind,CreatorCatalog.label(kind),false,func() -> void: pass,"winter")
		icons.add_child(button); button.position=Vector2(30+i*312,50); button.scale=Vector2(2.8,2.8)
	await frames(20); await save("palette-models")
	for button: ObjectThumbnail in icons.get_children(): check(button._viewport==null and button._image.texture!=null,"Winter native thumbnail releases its viewport")
	icons.queue_free(); await process_frame
	for kind: String in PropWinterCraft.KINDS:
		var host:=Button.new(); root.add_child(host)
		var view: SubViewport=ObjectThumbnail._render_preview(host,kind,"winter"); view.size=Vector2i(1600,1000); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await frames(4)
		var folder: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method())
		check(view.get_texture().get_image().save_png(folder+"/"+kind+".png")==OK,kind+" full model capture saved")
		host.queue_free(); await process_frame
	await effect_captures()
	await editor_captures()

func effect_captures() -> void:
	var stage:=Node3D.new(); root.add_child(stage)
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="winter"
	doc["automatic_scenery"]=false
	doc.objects=[{"kind":"snowman","position":[-3,0],"rotation":0},{"kind":"snow_lantern","position":[0,0],"rotation":0},{"kind":"ice_lantern","position":[3,0],"rotation":0}]
	var track: NativeTrack=TrackCompiler.compile(doc); var props: Array=track.hazard_objects
	var visual:=NativeTrackVisual.new(); visual.theme_id="winter"; stage.add_child(visual); visual._build_placed_objects(track)
	VisualGeometry.box(stage,Vector3(50,0.1,40),Vector3(0,-0.09,0),VisualGeometry.material(Color("b9cedb")))
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("1d303e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color("9db9cf"); environment.environment.ambient_light_energy=0.45; stage.add_child(environment)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-46,-35,0); sun.shadow_enabled=true; stage.add_child(sun)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=8.5; stage.add_child(camera); camera.look_at_from_position(Vector3(6,8,-13),Vector3(0,0.8,0)); camera.current=true
	var state:=VehicleState.new(); state.position=Vector2(100,100); advance(state,props)
	visual.update_light_props(state); await frames(4); await save("intact-breakable-models")
	for i: int in range(3): hit(state,props,i,12)
	var original: Dictionary=RewindHistory.properties(state)
	for tick: int in range(80):
		state.position=Vector2(100,100); state.velocity=Vector2.ZERO; advance(state,props); visual.update_light_props(state)
		if tick in [0,8,20,40,79]: await frames(2); await save("breakup-"+str(tick).pad_zeros(3))
	RewindHistory.restore(state,original); visual.update_light_props(state); await frames(3); await save("restored-breakup")
	visual.update_light_props(VehicleState.new()); await frames(3); await save("restart-restored-lanterns")
	stage.queue_free(); await frames(3)

func editor_captures() -> void:
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="winter"
	doc.objects=[{"kind":"igloo","position":[-16,0],"rotation":0},{"kind":"snow_castle","position":[-3,7],"rotation":0},{"kind":"snowman","position":[-22,13],"rotation":0},{"kind":"snow_lantern","position":[-18,14],"rotation":0},{"kind":"ice_lantern","position":[-15,14],"rotation":0}]
	var app: Node=load("res://core/app.gd").new()
	var directory: String="user://winter_craft_"+TrackLibrary.unique_id()
	app.set("library",TrackLibrary.new(directory)); app.set("records",LocalRecords.new(directory+"/records.json")); root.add_child(app)
	var deadline: int=Time.get_ticks_msec()+25000
	while not app.get("startup_complete") and Time.get_ticks_msec()<deadline: await process_frame
	check(app.get("startup_complete"),"actual Winter editor fixture completes covered startup")
	app.set("document",doc); app.call("_show_screen","create")
	deadline=Time.get_ticks_msec()+25000
	while Time.get_ticks_msec()<deadline:
		var canvas: EditorCanvas=app.get("canvas")
		if canvas!=null and canvas.native_preview!=null and not app.get("editor_world")._building and app.get("editor_preview_thread")==null: break
		await process_frame
	check(app.get("canvas")!=null and app.get("canvas").native_preview!=null,"actual Winter editor prepares all five saved models")
	app.call("_editor_category","objects")
	var browser: ObjectBrowser=app.get("object_browser")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=size; root.content_scale_size=size
		for category: String in ["Buildings","Props"]:
			browser.category=category
			# Show the final page where the new Winter entries are grouped.
			browser.page=999; browser.refresh()
			await frames(22); await save("editor-"+category.to_lower()+"-"+str(size.x))
	app.queue_free(); await frames(3)
