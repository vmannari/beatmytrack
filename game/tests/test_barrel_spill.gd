extends SceneTree
const OUTPUT: String="res://../docs/evidence/barrel-slowdown-2026-10-17/spill"
var checks: int=0
var failures: int=0
var config: HandlingConfig=load("res://resources/balanced.tres")
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; print("FAIL: ",label)
func object() -> Dictionary: return {"kind":"burning_barrel","position":[0.0,0.0],"rotation":37.0,"scale":1.0}
func clear(_point: Vector2,_radius: float,_layer: bool) -> Vector3: return Vector3.ZERO
func step(state: VehicleState) -> void:
	LightProps.step(state,[object()],clear,state.position,VehicleSimulation.STEP,config.mass,config.collision_radius); state.tick+=1
func hit(state: VehicleState,speed: float=12.0) -> void:
	state.position=Vector2(-0.2,0); state.velocity=Vector2(speed,0); step(state)
func run() -> void:
	var old:=GDScript.new(); old.source_code=FileAccess.get_file_as_string("res://tests/fixtures/barrel_spill_before/burning_barrel.gd.txt").replace("\r\n","\n").replace("class_name BurningBarrel\n","")
	check(old.reload()==OK,"pre-change barrel motion loads for measured weight comparison")
	var previous:=VehicleState.new(); previous.position=Vector2(-0.2,0); previous.velocity=Vector2(12,0)
	var row: Array=old.initial(object()); old.step(previous,object(),row,clear,previous.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
	var state:=VehicleState.new(); hit(state)
	check(state.light_props[0][2]<float(row[2])*0.8,"same impact gives a substantially slower barrel")
	check(12-state.velocity.x>(12-previous.velocity.x)*2.0,"same impact transfers greater momentum from the car")
	var old_peak: float=float(row[2]); var new_peak: float=float(state.light_props[0][2])
	state.position=Vector2(100,100); previous.position=Vector2(100,100)
	for i: int in range(720):
		step(state); old.step(previous,object(),row,clear,previous.position,VehicleSimulation.STEP,config.mass,config.collision_radius)
	check(float(state.light_props[0][0])<float(row[0])*0.5,"ground drag more than halves the single-hit travel")
	check(state.light_props[0][2]==0 and state.light_props[0][4]>1.4,"heavy barrel still topples and settles")
	print("BARREL_WEIGHT: ",JSON.stringify({"old_mass":35,"new_mass":BurningBarrel.MASS,"old_launch_mps":old_peak,"new_launch_mps":new_peak,"old_travel_m":row[0],"new_travel_m":state.light_props[0][0]}))
	state=VehicleState.new(); hit(state)
	check(state.light_props[0][10]>=0 and state.light_props[0][10]<0.02,"first meaningful impact starts the burn clock immediately")
	state.position=Vector2(100,100)
	for i: int in range(240): step(state)
	var saved: Dictionary=RewindHistory.properties(state); var exact: Array=state.snapshot()
	var pose:=Transform3D(Basis.IDENTITY,Vector3(2,0.564,0))
	var profile: Dictionary=BurningBarrelVisual.fire_profile(pose,state.light_props[0],1,0)
	check(profile.spread==1.0 and profile.size.x>4 and profile.size.y<1.0,"spilled flame becomes a wide low ground fire")
	check(profile.fuel.y<0.1 and profile.fuel.x<1,"spill remains at the impact ground instead of following the moving drum")
	var middle_energy: float=profile.energy
	for i: int in range(600): step(state)
	profile=BurningBarrelVisual.fire_profile(pose,state.light_props[0],1,0)
	check(profile.energy<middle_energy and profile.energy>0,"fire fades gradually through its finite burn")
	var later: Array=state.snapshot(); RewindHistory.restore(state,saved)
	check(state.snapshot()==exact,"rewind restores exact spill origin, age and remaining fuel")
	for i: int in range(600): step(state)
	check(state.snapshot()==later,"rewound spill burns identically on replay")
	for i: int in range(500): step(state)
	profile=BurningBarrelVisual.fire_profile(pose,state.light_props[0],1,0)
	check(profile.energy==0 and profile.smoke==0 and state.light_props[0][10]==BurningBarrel.SMOKE_SECONDS,"fire, embers, smoke and clock reach their terminal state")
	state.light_props[0][0]=0; state.light_props[0][1]=0; hit(state)
	check(state.light_props[0][10]==BurningBarrel.SMOKE_SECONDS,"another collision cannot replenish burned fuel")
	var gentle:=VehicleState.new(); hit(gentle,0.5)
	check(gentle.light_props[0][10]<0,"gentle contact leaves the barrel's fire intact")
	for airborne: bool in [false,true]:
		var other:=VehicleState.new(); other.track_elevated=not airborne; other.jump_height=1 if airborne else 0; hit(other)
		check(other.light_props[0][10]<0,"elevated/airborne pass cannot spill fuel")
	await native_spill()
	print("BARREL_SPILL: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
func native_spill() -> void:
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var doc: Dictionary=TrackDocument.create_default(); doc.theme="night_city"; doc["automatic_scenery"]=false; doc.objects=[object()]
	doc.paint=[{"surface":0,"width":40.0,"shape":"square","points":[[0,0]]}]
	var track: NativeTrack=TrackCompiler.compile(doc); var stage:=Node3D.new(); root.add_child(stage)
	var kit:=NativeTrackVisual.new(); kit.theme_id="night_city"; stage.add_child(kit); kit._build_placed_objects(track)
	var fx: NightPropEffects=kit.get_node("NightPropEffects")
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("080d18"); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; stage.add_child(env)
	var moon:=DirectionalLight3D.new(); TrackTheme.apply_lighting("night_city",env.environment,moon); stage.add_child(moon)
	var floor_mesh:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(40,40); floor_mesh.mesh=plane; floor_mesh.material_override=VisualGeometry.material(Color("343943")); stage.add_child(floor_mesh)
	var camera:=Camera3D.new(); stage.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4.7; camera.current=true; camera.look_at_from_position(Vector3(5,4,-8),Vector3(0.6,0.5,0))
	var state:=VehicleState.new(); hit(state); state.position=Vector2(100,100)
	var saved: Dictionary; var mm: MultiMesh=fx.get_node("Flames").multimesh
	var phases: Array[int]=[0,30,90,240,480,720,960,1200]
	for tick: int in range(1201):
		if tick>0: step(state)
		if tick==240: saved=RewindHistory.properties(state)
		kit.update_light_props(state); fx.advance(VehicleSimulation.STEP,false)
		if tick in phases:
			var before: Array=state.snapshot(); kit.update_light_props(state); check(state.snapshot()==before,"spill presentation never writes canonical state")
			if DisplayServer.get_name()!="headless":
				await frames(); await save("spill-"+str(tick))
	check(not fx.warm_lights[0].visible and fx.warm_lights[0].light_energy==0,"burned-out spill turns off its actual warm light")
	if DisplayServer.get_name()!="headless":
		check(mm.get_instance_custom_data(0).b==0,"burned-out fire volume is fully transparent")
		check(fx.get_node("Embers").multimesh.get_instance_custom_data(0).a==0 and fx.get_node("Smoke").multimesh.get_instance_custom_data(0).a==0,"all original spark/smoke slots fade to zero")
	RewindHistory.restore(state,saved); kit.update_light_props(state)
	check(fx.warm_lights[0].visible and fx.warm_lights[0].light_energy>0,"rewind restores light and remaining fuel after complete burnout")
	if DisplayServer.get_name()!="headless":
		var before: PackedByteArray; await frames(12); before=root.get_texture().get_image().get_data(); fx.advance(0.1,true); await frames()
		check(before==root.get_texture().get_image().get_data(),"paused spilled-fire frame stays exact")
	kit.update_light_props(VehicleState.new())
	check(fx.warm_lights[0].visible and fx.barrel_sources[0].fuel.is_equal_approx(Vector3(0,0.844,0)),"restart restores intact barrel fire and source position")
	if DisplayServer.get_name()!="headless":
		check(mm.get_instance_custom_data(0).g==0 and mm.get_instance_custom_data(0).b==1,"restart resets source extent and full flame energy")
		await frames(); await save("restart")
	stage.queue_free(); await process_frame
func frames(n: int=4) -> void:
	for i: int in range(n): await process_frame
	await RenderingServer.frame_post_draw
func save(name: String) -> void:
	var path: String=ProjectSettings.globalize_path(OUTPUT+"/"+RenderingServer.get_current_rendering_method()); DirAccess.make_dir_recursive_absolute(path)
	check(root.get_texture().get_image().save_png(path+"/"+name+".png")==OK,name+" native capture saved")
