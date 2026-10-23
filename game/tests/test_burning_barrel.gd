extends SceneTree
const OUTPUT: String="res://../docs/evidence/barrel-slowdown-2026-10-17/barrel"
var checks: int=0
var failures: int=0
var config: HandlingConfig=load("res://resources/balanced.tres")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func object(kind: String="burning_barrel", scale: float=1.0) -> Dictionary:
	return {"kind":kind,"position":[0.0,0.0],"rotation":37.0,"scale":scale}
func clear(_p: Vector2,_radius: float,_layer: bool) -> Vector3: return Vector3.ZERO
func advance(state: VehicleState, objects: Array) -> void:
	LightProps.step(state,objects,clear,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
	state.tick+=1
func hit(state: VehicleState, objects: Array, speed: float=12.0) -> void:
	state.position=Vector2(-0.2,0); state.velocity=Vector2(speed,0); advance(state,objects)
func run() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	for scale: float in [0.5,1.0,2.5]:
		var objects: Array=[object("burning_barrel",scale)]; var state:=VehicleState.new()
		hit(state,objects,46.0 if scale>2.0 else 12.0)
		check(state.light_props[0].size()==BurningBarrel.ROW_SIZE and state.light_props[0][4]>0,"impact starts physical tipping at scale "+str(scale))
		var saved: Dictionary=RewindHistory.properties(state); var snapshot: Array=state.snapshot()
		state.position=Vector2(100,100)
		for i: int in range(720): advance(state,objects)
		print("BARREL_SETTLED: ",scale," ",state.light_props[0])
		check(is_equal_approx(state.light_props[0][4],PI*0.5),"barrel falls onto its side at scale "+str(scale))
		check(Vector2(state.light_props[0][2],state.light_props[0][3]).length()==0,"fallen barrel comes to rest")
		var later: Array=state.snapshot(); RewindHistory.restore(state,saved)
		check(state.snapshot()==snapshot,"rewind restores exact upright-to-falling state")
		state.position=Vector2(100,100)
		for i: int in range(720): advance(state,objects)
		check(state.snapshot()==later,"restored falling branch is exact")
	for airborne: bool in [false,true]:
		var state:=VehicleState.new(); state.track_elevated=not airborne; state.jump_height=1.0 if airborne else 0.0
		hit(state,[object()])
		check(state.light_props[0][4]==0 and state.light_props[0][2]==0,"airborne and bridge cars cannot knock over ground barrels")
	var gentle:=VehicleState.new(); hit(gentle,[object()],0.5); gentle.position=Vector2(100,100)
	for i: int in range(300): advance(gentle,[object()])
	check(gentle.light_props[0][4]==0,"gentle nudge rocks back upright")
	await legacy_exact()
	driven_replay()
	await presentation()
	await game_lifecycle()
	if DisplayServer.get_name()!="headless": await captures()
	print("BURNING_BARREL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func legacy_exact() -> void:
	var old:=GDScript.new()
	old.source_code=FileAccess.get_file_as_string("res://tests/fixtures/barrel_fire_before/light_props.gd.txt").replace("\r\n","\n").replace("class_name LightProps\n","")
	check(old.reload()==OK,"preserved original movable implementation compiles")
	for kind: String in CreatorCatalog.SOFT:
		if kind=="burning_barrel": continue
		var a:=VehicleState.new(); var b:=VehicleState.new(); var objects: Array=[object(kind)]
		var exact: bool=true
		for i: int in range(180):
			a.position=Vector2(-0.2,0) if i%60==0 else Vector2(100,100); a.velocity=Vector2(12,0) if i%60==0 else Vector2.ZERO
			b.position=a.position; b.velocity=a.velocity
			old.step(a,objects,clear,a.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			LightProps.step(b,objects,clear,b.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
			exact=exact and a.snapshot()==b.snapshot()
		check(exact,kind+" original motion and damage stay exact over180 steps")
func document() -> Dictionary:
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="night_city"; doc["automatic_scenery"]=false
	doc.paint=[{"surface":0,"width":40.0,"shape":"square","points":[[0,0]]}]; doc.objects=[object()]
	return doc
func driven_replay() -> void:
	var track: NativeTrack=TrackCompiler.compile(document())
	check(track!=null and track.cell_at(Vector2.ZERO)==0,"barrel is movable instead of a baked solid wall")
	for car: String in VehicleCatalog.IDS:
		var a:=VehicleSimulation.new(VehicleCatalog.config(car)); var b:=VehicleSimulation.new(VehicleCatalog.config(car))
		a.reset(Vector2(-9,0),PI*0.5); b.reset(Vector2(-9,0),PI*0.5)
		var inputs: Array=[]
		for i: int in range(220):
			var frame:=DriveFrame.new(); frame.throttle=255; inputs.append(frame.packed()); a.step(frame,track)
		for values: Array in JSON.parse_string(JSON.stringify(inputs)):
			var frame:=DriveFrame.new(); frame.steer=values[0]; frame.throttle=values[1]; frame.brake=values[2]; frame.handbrake=values[3] if values.size()>3 else 0; b.step(frame,track)
		check(a.state.snapshot()==b.state.snapshot(),car+" driving collision replays exactly from JSON")
		print("BARREL_DRIVE: ",car," ",a.state.position," ",a.state.light_props)
		check(a.state.light_props[0][4]>1.4 and a.state.position.x<float(a.state.light_props[0][0])-1.0,car+" topples barrel while its body continues resisting the car")
func presentation() -> void:
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"; root.add_child(kit); kit._build_placed_objects(TrackCompiler.compile(document()))
	var fx: NightPropEffects=kit.get_node("NightPropEffects")
	check(fx.barrel_sources.size()==1 and fx.get_node("Flames").multimesh.mesh is BoxMesh,"barrel-only world owns one actual fire volume")
	check(NightFireVolume.field.get_width()==32 and NightFireVolume.field.get_depth()==32,"fire noise has one bounded32-cubed field")
	var state:=VehicleState.new(); hit(state,[object()]); state.position=Vector2(100,100)
	for i: int in range(50): advance(state,[object()])
	var before: Array=state.snapshot(); kit.update_light_props(state)
	var node: Node3D=kit.light_instances[0]; var profile: Dictionary=BurningBarrelVisual.fire_profile(node.transform,state.light_props[0],1.0,0.0); var fuel: Vector3=profile.fuel
	check(state.snapshot()==before,"presentation leaves complete canonical snapshot exact")
	if DisplayServer.get_name()!="headless":
		check(fx.get_node("Flames").multimesh.get_instance_transform(0).origin.is_equal_approx(profile.pose.origin),"fallen fire source follows canonical spilled fuel")
	check(fx.warm_lights[0].position.is_equal_approx(fuel+Vector3.UP*0.29),"warm light follows falling barrel")
	kit.update_light_props(VehicleState.new())
	check(node.position.is_equal_approx(Vector3(0,0.564,0)) and node.basis.y.is_equal_approx(Vector3.UP),"restart restores exact upright supported pose")
	kit.update_light_props(state); var pose: Transform3D=node.transform
	state.light_props[0][0]+=1; kit.update_light_props(state); state.light_props[0][0]-=1; kit.update_light_props(state)
	check(node.transform==pose,"in-place replay rows cannot accumulate centre height")
	var cache=preload("res://track/prepared_world_cache.gd"); cache.remember(["barrel-fire-test"],kit,TrackCompiler.compile(document()))
	var before_restore_fuel: Vector3=fx.barrel_sources[0].fuel
	var restored:=NativeTrackVisual.new(); root.add_child(restored); check(cache.restore(["barrel-fire-test"],restored),"prepared world restores falling barrel nodes")
	var copy: NightPropEffects=restored.get_node("NightPropEffects")
	check(copy.barrel_sources.size()==1 and copy!=fx and copy.surfaces[0]!=fx.surfaces[0],"prepared fire owns its source descriptors and material")
	restored.update_light_props(VehicleState.new()); check(restored.light_instances[0].basis.y.is_equal_approx(Vector3.UP),"cached fallen barrel resets upright")
	var original_fuel: Vector3=fx.barrel_sources[0].fuel
	check(original_fuel==before_restore_fuel,"restored world cannot mutate original fuel descriptors")
	kit.queue_free(); restored.queue_free(); await process_frame
	var doc: Dictionary=document(); doc.objects=[]
	for i: int in range(40):
		var item: Dictionary=object(); item.position=[i*2,0]; doc.objects.append(item)
	kit=NativeTrackVisual.new(); kit.theme_id="night_city"; kit.colors=TrackTheme.palette("night_city"); kit.editor_preview=true; root.add_child(kit)
	var batches=preload("res://editor/placed_object_batches.gd").new(); await batches.refresh(kit,TrackCompiler.compile(doc),false,func() -> bool: return true)
	check(kit.find_children("NightPropEffects","",true,false).size()==1,"retained editor has one shared fire controller")
	fx=kit.get_node("NightPropEffects"); check(fx.warm_lights.size()==4 and fx.barrel_sources.size()==32,"dense editor retains four-light and32-fire bounds")
	kit.queue_free(); await process_frame
func game_lifecycle() -> void:
	var game: Node=preload("res://core/game.tscn").instantiate(); game.initial_track=TrackCompiler.compile(document()); game.editor_test=true; root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.paused=true
	game.sim.reset(Vector2(-9,0),PI*0.5)
	var frame:=DriveFrame.new(); frame.throttle=255
	for i: int in range(220):
		game.previous_position=game.sim.state.position; game.previous_heading=game.sim.state.heading
		game.sim.step(frame,game.native_track)
		game._present_frame(VehicleSimulation.STEP)
		if DisplayServer.get_name()!="headless" and i in [0,85,110,150,219]:
			for j: int in range(12): game._present_frame(0.016); await process_frame
			await frames(); await save("game-impact-"+str(i))
	check(game.track_ground.light_instances[0].basis.y.dot(Vector3.UP)<0.01,"actual race presents the barrel lying on its side")
	var before: Array=game.sim.state.snapshot(); var fx: NightPropEffects=game.track_ground.get_node("NightPropEffects"); var t: float=fx.elapsed
	game._present_frame(0.1); check(game.sim.state.snapshot()==before and fx.elapsed==t,"actual paused race freezes fire and canonical state")
	game.restart(); game.paused=true; game._present_frame(0.016)
	check(game.track_ground.light_instances[0].basis.y.is_equal_approx(Vector3.UP),"actual race restart stands the barrel upright")
	game.queue_free(); await process_frame
func frames(n: int=4) -> void:
	for i: int in range(n): await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> void:
	var directory: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory+"/"+name+".png")==OK,name+" native capture saved")
func captures() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var stage:=Node3D.new(); root.add_child(stage)
	var kit:=NativeTrackVisual.new(); stage.add_child(kit); var track: NativeTrack=TrackCompiler.compile(document()); kit.build(track,BridgePresentation.new(track))
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("070c18"); stage.add_child(env)
	var moon:=DirectionalLight3D.new(); TrackTheme.apply_lighting("night_city",env.environment,moon); stage.add_child(moon)
	var camera:=Camera3D.new(); stage.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=3.7; camera.current=true
	camera.look_at_from_position(Vector3(5,3.6,-7),Vector3(0,1.05,0))
	var fx: NightPropEffects=kit.get_node("NightPropEffects"); fx.elapsed=0.8; fx._publish(); await frames(); await save("upright")
	await frames(12)
	var before: PackedByteArray=root.get_texture().get_image().get_data(); fx.advance(0.1,true); await frames()
	if before!=root.get_texture().get_image().get_data(): await save("pause-diagnostic")
	check(before==root.get_texture().get_image().get_data(),"paused volume has exact native pixels")
	fx.elapsed=1.7; fx._publish(); await frames(); check(before!=root.get_texture().get_image().get_data(),"combustion changes actual native pixels"); await save("upright-1.7")
	camera.look_at_from_position(Vector3(-6,3.0,-4),Vector3(0,1.05,0)); await frames(); await save("side-view")
	var state:=VehicleState.new(); hit(state,[object()]); state.position=Vector2(100,100)
	for tick: int in range(180):
		advance(state,[object()]); kit.update_light_props(state); fx.advance(VehicleSimulation.STEP,false)
		if tick in [5,14,29,60,179]:
			var node: Node3D=kit.light_instances[0]; camera.look_at_from_position(node.position+Vector3(5,3.3,-7),node.position+Vector3.UP*0.5); await frames(); await save("fall-"+str(tick))
	kit.update_light_props(VehicleState.new()); camera.look_at_from_position(Vector3(5,3.6,-7),Vector3(0,1.05,0)); await frames(); await save("restart")
	stage.queue_free(); await process_frame
