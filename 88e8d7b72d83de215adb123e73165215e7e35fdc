extends SceneTree
const Packing=preload("res://rendering/mesh_vertex_packing.gd")
const Metrics=preload("res://../build/asset-review-2026-11-08/metrics.gd")
const Exact=preload("res://../build/asset-optimisation-2026-11-08/test_packing.gd")
var checks: int=0
var failures: int=0
var rows: Array=[]
var output: String
var mode: String="scenery"
var car_filter: String=""
var output_suffix: String=""
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures+=1;printerr("ASSET_NATIVE_FAIL ",label)
func observe()->Dictionary:
	for frame: int in range(6):await RenderingServer.frame_post_draw
	return {"image":viewport.get_texture().get_image(),"primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}
func compare(a: Node3D,b: Node3D,label: String,extent: float,center: Vector3)->void:
	camera.size=extent;camera.look_at_from_position(center+Vector3(-0.32,0.83,0.53)*65.0,center)
	a.show();b.hide();var before: Dictionary=await observe()
	a.hide();b.show();var after: Dictionary=await observe()
	a.show();b.hide();var control: Dictionary=await observe()
	check(before.image.get_data()==control.image.get_data(),"original frame restoration "+label)
	control.image.save_png(output.path_join(label+"-restored.png"))
	check(before.primitives>0 and before.draws>0,"actual visible geometry "+label)
	var metric: Dictionary=before.image.compute_image_metrics(after.image,false)
	if mode=="worlds":check(metric.max==0.0,"packed world pixels exact "+label)
	elif mode=="cars":check(metric.mean<0.15,"car batching stays within 0.15/255 full-frame mean "+label)
	elif label.ends_with("close"):
		check(before.primitives==after.primitives*int(b.get_meta("lod_counter_factor",1)),"full near geometry retained with measured instance accounting "+label)
		check(metric.mean<0.01,"near picture unchanged apart from subpixel shadow differences "+label)
	else:
		check(after.primitives*int(b.get_meta("lod_counter_factor",1))<before.primitives,"distance geometry reduces "+label)
		check(metric.mean<0.03,"distant picture mean below 0.03/255 "+label)
	before.image.save_png(output.path_join(label+"-before.png"));after.image.save_png(output.path_join(label+"-after.png"))
	var row: Dictionary={"case":label,"before_primitives":before.primitives,"after_primitives":after.primitives,"before_draws":before.draws,"after_draws":after.draws,"image_metrics":metric,"restore_metrics":before.image.compute_image_metrics(control.image,false)}
	rows.append(row);print("ASSET_NATIVE_CASE ",JSON.stringify(row))
func car(id: String,fitted: bool,batched: bool)->CarVisual:
	VisualGeometry.batch_transformed_car_parts=batched
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	var result:=CarVisual.new();result.vehicle_id=id;result.simple_model=true;result.cache_rest_pose=false;result.customisation=VehicleCustomisation.defaults()
	if fitted:
		for category: String in VehicleCustomisation.CATEGORIES:result.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
	stage.add_child(result)
	while not result.model_ready:await process_frame
	for node: Node in result.front_wheels+result.rear_wheels+result.rolling_wheels+result.brake_lights:check(is_instance_valid(node) and node.is_inside_tree(),"live moving/light handle retained "+id)
	return result
func cars()->void:
	for id: String in VehicleCatalog.IDS:
		if not car_filter.is_empty() and id!=car_filter:continue
		for fitted: bool in [false,true]:
			var a: CarVisual=await car(id,fitted,false);var b: CarVisual=await car(id,fitted,true)
			var ma: Dictionary=Metrics.inventory(a);var mb: Dictionary=Metrics.inventory(b)
			check(ma.base_triangles==mb.base_triangles,"car batching keeps every triangle "+id)
			for close: bool in [false,true]:await compare(a,b,id+("-fitted" if fitted else "-stock")+("-close" if close else "-race"),5.0 if close else 35.0/1.15,Vector3(0,0.7,0))
			var paint: Dictionary=VehicleLivery.defaults(id);paint.colors.body="a14739";a.apply_livery(paint);b.apply_livery(paint)
			a.set_night_headlights(true);b.set_night_headlights(true)
			await compare(a,b,id+("-fitted" if fitted else "-stock")+"-paint-lights",5.0,Vector3(0,0.7,0))
			pose_motion(a,b)
			await compare(a,b,id+("-fitted" if fitted else "-stock")+"-moving",5.0,Vector3(0,0.7,0))
			a.free();b.free();await process_frame
	VisualGeometry.batch_transformed_car_parts=true
func pose_motion(a: CarVisual,b: CarVisual)->void:
	var state:=VehicleState.new();state.steering=0.65;state.velocity=Vector2(0,10);state.tick=27
	var frame:=DriveFrame.new();frame.brake=255;frame.throttle=0
	a.present(Vector2(0,-0.3),0,state,frame);b.present(Vector2(0,-0.3),0,state,frame)
	state.tick=28;a.present(Vector2.ZERO,0,state,frame);b.present(Vector2.ZERO,0,state,frame)
	a.body.position.y+=0.02;b.body.position.y+=0.02;a.body.rotation.z=0.04;b.body.rotation.z=0.04
	check(a.rear_braking and b.rear_braking,"moving brake state retained "+a.vehicle_id)
	for index: int in range(a.rolling_wheels.size()):check(a.rolling_wheels[index].transform==b.rolling_wheels[index].transform,"rolling transform retained "+a.vehicle_id)
func prop(theme: String,kind: String,lods: bool)->NativeTrackVisual:
	WinterScenery.meshes.clear()
	var track:=NativeTrack.new();track.metadata={"creator_document":{"objects":[{"kind":kind,"position":[0,0],"rotation":0.0}]}}
	track.tyre_origins=LooseTyres.positions(track.metadata.creator_document)
	var result:=NativeTrackVisual.new();result.theme_id=theme;result.colors=TrackTheme.palette(theme);result.scenery_lods=lods;result._suppress_night_fx=true
	await result._build_placed_objects(track);stage.add_child(result)
	return result
func scenery()->void:
	for theme: String in ["pine","winter"]:
		for kind: String in ["tree","tyre_wall"]:
			var a: NativeTrackVisual=await prop(theme,kind,false);var b: NativeTrackVisual=await prop(theme,kind,true)
			if kind=="tyre_wall":
				var old: ArrayMesh=a.tyre_instances.multimesh.mesh;var packed: ArrayMesh=b.tyre_instances.multimesh.mesh
				var exact=Exact.new();check(exact.expanded(old)[0]==exact.expanded(packed)[0],"every near tyre encoded corner exact "+theme);exact.free()
				camera.size=6.0;camera.look_at_from_position(Vector3(-0.32,0.83,0.53)*65.0,Vector3.ZERO)
				a.show();b.hide();var normal: Dictionary=await observe()
				var packet: Dictionary=old.get("_surfaces")[0];var count: int=int(packet.index_count);var stride: int=packet.index_data.size()/count;var same:=PackedInt32Array()
				for i: int in range(count):same.append(packet.index_data.decode_u16(i*stride) if stride==2 else packet.index_data.decode_u32(i*stride))
				a.tyre_instances.multimesh.mesh=SceneryMeshLods.attach(old,{0.028:same});var control: Dictionary=await observe()
				check(normal.image.get_data()==control.image.get_data(),"identical-LOD control renders every instance exactly "+theme)
				check(normal.primitives%control.primitives==0,"instance counter ratio integral "+theme)
				b.set_meta("lod_counter_factor",normal.primitives/control.primitives)
				a.tyre_instances.multimesh.mesh=old
			await compare(a,b,theme+"-"+kind+"-race",35.0/1.15,Vector3(0,1,0))
			await compare(a,b,theme+"-"+kind+"-close",4.0 if kind=="tree" else 6.0,Vector3(0,1,0))
			a.free();b.free();await process_frame
func world(theme: String,packed: bool)->NativeTrackVisual:
	Packing.enabled=packed;WinterScenery.meshes.clear()
	var doc: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/to_the_trees.json"));doc.theme=theme
	var track: NativeTrack=TrackCompiler.compile(doc)
	var result:=NativeTrackVisual.new();result.scenery_lods=false;result.cache_road_meshes=false;result.cache_race_world=false;stage.add_child(result)
	await result.build(track,BridgePresentation.new(track));result.set_meta("review_center",VisualGeometry.world(track.route[0]))
	return result
func worlds()->void:
	for theme: String in TrackTheme.IDS:
		var a: NativeTrackVisual=await world(theme,false);var b: NativeTrackVisual=await world(theme,true)
		await compare(a,b,theme+"-world-race",35.0/1.15,a.get_meta("review_center"))
		await compare(a,b,theme+"-world-close",12.0,a.get_meta("review_center"))
		a.free();b.free();await process_frame
	Packing.enabled=true
func run()->void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):mode=argument.trim_prefix("--mode=")
		if argument.begins_with("--vehicle="):car_filter=argument.trim_prefix("--vehicle=")
		if argument.begins_with("--suffix="):output_suffix=argument.trim_prefix("--suffix=")
	output="res://../docs/evidence/asset-optimisation-2026-11-08/"+mode+"-"+RenderingServer.get_current_rendering_method()+output_suffix
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));root.size=Vector2i(1280,720);Engine.time_scale=0.0
	viewport=SubViewport.new();viewport.size=root.size;viewport.own_world_3d=true;viewport.mesh_lod_threshold=1.0;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage);camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-56,-25,0);light.shadow_enabled=true;stage.add_child(light)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("34434a");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=0.65;stage.add_child(env)
	if mode=="cars":await cars()
	elif mode=="worlds":await worlds()
	else:await scenery()
	viewport.free()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"\t"))
	print("ASSET_NATIVE ",mode," ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
