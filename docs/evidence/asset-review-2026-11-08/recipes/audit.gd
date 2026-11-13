extends SceneTree
## AOR01-AOR03: read-only current cars, all placed objects and complete worlds.
const Metrics=preload("res://../build/asset-review-2026-11-08/metrics.gd")
const Base=preload("res://vehicle/modular_car_base.gd")
const Kits=preload("res://vehicle/modular_car_kits.gd")
var checks: int=0
var failures: int=0
var rows: Array=[]
var output: String="res://../docs/evidence/asset-review-2026-11-08"
var mode: String="catalogue"
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures+=1;printerr("ASSET_REVIEW_FAIL ",label)
func write(name: String,value: Variant)->void:
	FileAccess.open(output.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(value,"\t")+"\n")
func cars()->void:
	for id: String in VehicleCatalog.IDS:
		for editable: bool in [false,true]:
			for fitted: bool in [false,true]:
				var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=true;car.editable_kits=editable
				car.garage_template=editable;car.cache_rest_pose=false;car.customisation=VehicleCustomisation.defaults()
				if fitted:
					for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=str(VehicleCustomisation.options(category,id)[-1][0])
				var base_hits: int=Base.hits;var kit_hits: int=Kits.hits
				root.add_child(car)
				while not car.model_ready:await process_frame
				check(car.simple_model and car.model_ready,"actual reduced model ready "+id)
				var row: Dictionary=Metrics.inventory(car,true)
				row.merge({"vehicle":id,"chassis":VehicleCatalog.model_id(id),"editable":editable,"fitted":fitted,"prepared_base_hits":Base.hits-base_hits,"prepared_kit_hits":Kits.hits-kit_hits})
				check(row.base_triangles>1000,"nonempty model "+id)
				rows.append(row);print("AUDIT_CAR ",id," ",editable," ",fitted," triangles=",row.base_triangles," vertices=",row.base_vertices," lod=",row.lod_surfaces," passes=",row.estimated_material_draws)
				car.free();await process_frame
		var file: String="res://assets/vehicles/modular_car_bases_v1/"+VehicleCatalog.model_id(id)+"_simple_fixed.scn"
		if ResourceLoader.exists(file):
			var scene: PackedScene=load(file);var holder: Node=scene.instantiate();root.add_child(holder)
			var stored: Dictionary=Metrics.inventory(holder)
			stored.merge({"vehicle":id,"context":"stored_prepared_resource_not_assumed_active","path":file,"sha256":FileAccess.get_sha256(file)})
			rows.append(stored);holder.free()

func prop(theme: String,kind: String)->NativeTrackVisual:
	var track:=NativeTrack.new();track.metadata={"creator_document":{"objects":[{"kind":kind,"position":[0.0,0.0],"rotation":0.0}]},"scenery_objects":[]}
	track.tyre_origins=LooseTyres.positions(track.metadata.creator_document)
	var original: Dictionary=track.metadata.duplicate(true)
	var visual:=NativeTrackVisual.new();visual.theme_id=theme;visual.colors=TrackTheme.palette(theme);visual._suppress_night_fx=true
	await visual._build_placed_objects(track)
	check(track.metadata==original,"immutable object "+theme+"/"+kind)
	return visual
func catalogue()->void:
	for theme: String in TrackTheme.IDS:
		for kind: String in CreatorObjects.KINDS:
			var visual: NativeTrackVisual=await prop(theme,kind)
			var row: Dictionary=Metrics.inventory(visual,true);row.merge({"theme":theme,"kind":kind})
			check(row.base_triangles>0 or kind in ["dirt","water"],"catalogue coverage "+theme+"/"+kind)
			rows.append(row);visual.free()
		print("AUDIT_CATALOGUE ",theme," done");await process_frame

func worlds()->void:
	root.size=Vector2i(1280,720)
	var viewport:=SubViewport.new();viewport.size=root.size;viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;viewport.mesh_lod_threshold=1.0
	root.add_child(viewport)
	var stage:=Node3D.new();viewport.add_child(stage)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;stage.add_child(camera)
	var light:=DirectionalLight3D.new();light.shadow_enabled=true;stage.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();stage.add_child(environment)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	for theme: String in TrackTheme.IDS:
		var document: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/to_the_trees.json"))
		document.theme=theme
		var original: Dictionary=document.duplicate(true)
		var track: NativeTrack=TrackCompiler.compile(document)
		check(track!=null,"compile representative track "+theme)
		if track==null:continue
		var canonical: Array=[track.cells.duplicate(),track.route.duplicate(),track.kerbs.triangles.duplicate(true)]
		var visual:=NativeTrackVisual.new();visual.cache_race_world=false;visual.cache_road_meshes=false;visual.profile_build=true
		stage.add_child(visual)
		var started: int=Time.get_ticks_usec()
		await visual.build(track,BridgePresentation.new(track))
		check(visual.world_built,"actual complete world "+theme)
		var row: Dictionary=Metrics.inventory(visual,true)
		row.merge({"theme":theme,"fixture":"to_the_trees","build_ms":(Time.get_ticks_usec()-started)/1000.0,"build_costs":visual.build_costs.duplicate(true),"route_points":track.route.size(),"kerb_triangles":track.kerbs.triangles.size(),"road_piece_count":document.pieces.size(),"views":[]})
		check(document==original and canonical==[track.cells,track.route,track.kerbs.triangles],"world review leaves canonical road/kerb data exact "+theme)
		TrackTheme.apply_lighting(theme,environment.environment,light)
		if DisplayServer.get_name()!="headless":
			for view: String in ["overhead","follow","speed_zoom"]:
				var at: Vector3=VisualGeometry.world(track.route[0])
				var pitch: float=deg_to_rad(48.0 if view=="follow" else 56.0)
				camera.size=35.0/1.15*(1.3 if view=="speed_zoom" else 1.0)
				camera.look_at_from_position(at+Vector3(sin(0.314)*cos(pitch),sin(pitch),cos(0.314)*cos(pitch))*65.0,at)
				for frame: int in range(20):await RenderingServer.frame_post_draw
				var gpu: Array[float]=[];var cpu: Array[float]=[]
				for frame: int in range(31):
					await RenderingServer.frame_post_draw
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
				gpu.sort();cpu.sort()
				var primitives: int=viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
				check(primitives>100,"nonempty native world "+theme+"/"+view)
				var image: Image=viewport.get_texture().get_image();image.save_png(output.path_join(theme+"-"+view+".png"))
				row.views.append({"view":view,"primitives":primitives,"draws":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"render_cpu_median_ms":cpu[15],"gpu_median_ms":gpu[15]})
		rows.append(row);print("AUDIT_WORLD ",theme," triangles=",row.base_triangles," vertices=",row.base_vertices," passes=",row.estimated_material_draws)
		visual.free();await process_frame
	viewport.free()
func run()->void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):mode=argument.trim_prefix("--mode=")
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if mode=="cars":await cars()
	elif mode=="catalogue":await catalogue()
	elif mode=="worlds":await worlds()
	else:check(false,"known review mode")
	write(mode+".json",{"requirements":["AOR01","AOR02","AOR03"],"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows,"scope":"Current source checkout, private offline review only. Surface/pass counts exclude GPU culling; raw buffers are unique resource payloads, not process RAM. Index probe is a prospective packing metric, not an approved geometry change or FPS gain."})
	print("ASSET_REVIEW ",mode," ",checks," checks, ",failures," failures, ",rows.size()," cases")
	quit(1 if failures else 0)
