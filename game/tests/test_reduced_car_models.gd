extends "res://tests/test_vehicle_mesh_simplification.gd"
## ACM02-ACM03: optional stronger reduction with explicit appearance allowances.
var probe_only: bool=false

func built(id: String, parts: Dictionary, reduced: bool) -> CarVisual:
	simple_case=reduced
	var result: CarVisual=make_car(id,parts,true,true)
	while not result.model_ready:await process_frame
	return result

func projected_bounds(car: CarVisual) -> Rect2i:
	var low:=Vector2(INF,INF)
	var high:=Vector2(-INF,-INF)
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		for corner: int in range(8):
			var point: Vector2=camera.unproject_position(part.global_transform*part.mesh.get_aabb().get_endpoint(corner))
			low=low.min(point);high=high.max(point)
	return Rect2i(Vector2i(low.floor())-Vector2i(8,8),Vector2i((high-low).ceil())+Vector2i(17,17)).intersection(Rect2i(Vector2i.ZERO,viewport.size))

func compare_native(standard: CarVisual,reduced: CarVisual,label: String) -> void:
	reduced.hide();standard.show();await settle()
	var a: Image=viewport.get_texture().get_image()
	var old_count: int=viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var rect: Rect2i=projected_bounds(standard)
	standard.hide();reduced.show();await settle()
	var b: Image=viewport.get_texture().get_image()
	var new_count: int=viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var box: Rect2i=rect.merge(projected_bounds(reduced))
	var detail: Dictionary=image_difference(a.get_region(box),b.get_region(box))
	var whole: Dictionary=image_difference(a,b)
	# This optional quality tier explicitly permits more differences than standard.
	# The budget is measured on the car crop, so empty background cannot hide loss.
	if not probe_only:
		check(detail.mean_rgb_delta<8.0,"reduced car crop mean below 8/255 "+label)
		check(detail.pixels_over_8_fraction<0.15,"reduced car crop changed area below 15% "+label)
		check(new_count<old_count*0.65 if label.ends_with("overhead") else new_count<old_count*0.8,"substantial optional triangle reduction "+label)
	for item: Array in [[a,"standard"],[b,"reduced"]]:check(item[0].save_png(output.path_join(label+"-"+item[1]+".png"))==OK,"native capture "+label+" "+item[1])
	rows.append({"case":label,"standard_primitives":old_count,"reduced_primitives":new_count,"car_crop":detail,"whole_frame":whole,"crop":[box.position.x,box.position.y,box.size.x,box.size.y]})
	print("REDUCED_CAR_NATIVE ",label," ",old_count," -> ",new_count," crop=",JSON.stringify(detail))

func pictures(only: String) -> void:
	Engine.time_scale=0.0
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true
	viewport.mesh_lod_threshold=1.0;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-58,-35,0);light.shadow_enabled=true;stage.add_child(light)
	var world:=WorldEnvironment.new();environment=Environment.new();world.environment=environment
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("34434a")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0.5;stage.add_child(world)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(90,90);floor.mesh=plane;floor.position.y=-0.025
	floor.material_override=VisualGeometry.material(Color("73796c"));stage.add_child(floor)
	for id: String in VehicleCatalog.IDS:
		if not only.is_empty() and id!=only:continue
		for fitted: bool in [false,true]:
			var parts: Dictionary=VehicleCustomisation.defaults()
			if fitted:
				for category: String in VehicleCustomisation.CATEGORIES:parts[category]=VehicleCustomisation.options(category,id)[-1][0]
			var standard: CarVisual=await built(id,parts,false)
			var reduced: CarVisual=await built(id,parts,true)
			var conditions: Array=[];var glass: Array=[]
			for car: CarVisual in [standard,reduced]:
				var condition:=VehicleWeathering.new();condition.configure(car,"winter",VehicleCatalog.config(id))
				condition.restore({"dirt":0.22,"slow_dirt":0.08,"color":"b9a788","snow":0.16,"slow_snow":0.04});conditions.append(condition)
				glass.append(preload("res://race/electric_glass_lighting.gd").new())
			for night: bool in [false,true]:
				for index: int in range(2):
					var car: CarVisual=standard if index==0 else reduced
					car.set_night_headlights(night)
					conditions[index].configure(car,"night_city" if night else "winter",VehicleCatalog.config(id))
					glass[index].configure(car,"night_city" if night else "winter")
				environment.ambient_light_energy=0.18 if night else 0.5;light.light_energy=0.25 if night else 1.0
				for view: String in ["overhead","close","rear","macro"]:
					camera.size=35.0/1.15 if view=="overhead" else (3.4 if view=="macro" else 5.8)
					camera.position=Vector3(8,32,20) if view=="overhead" else Vector3(5.4,3.8,-7.1 if view=="close" else 7.1)
					camera.look_at(Vector3(0,0.65,0))
					await compare_native(standard,reduced,id+("-fitted" if fitted else "-stock")+("-night-" if night else "-day-")+view)
			for index: int in range(2):glass[index].reset();conditions[index].reset()
			standard.free();reduced.free();await process_frame
	viewport.free();await process_frame

func standard_assets() -> void:
	var paths: Array[String]=[]
	for folder: String in [Base.DIRECTORY,Kits.DIRECTORY,"res://assets/garage/cars_v1","res://assets/menu/header_car_templates_v1"]:scene_paths(folder,paths)
	for path: String in paths:
		if "/simple/" in path or "_simple_" in path:continue
		var previous: String="res://../docs/evidence/aggressive-car-models-2026-11-07/before/game/"+path.trim_prefix("res://")
		if not ResourceLoader.exists(previous):continue
		var old_scene: PackedScene=load(previous);var new_scene: PackedScene=load(path)
		var old_root: Node=old_scene.instantiate();var new_root: Node=new_scene.instantiate()
		var old_parts: Array[Node]=old_root.find_children("*","MeshInstance3D",true,false)
		var new_parts: Array[Node]=new_root.find_children("*","MeshInstance3D",true,false)
		check(old_parts.size()==new_parts.size(),"standard mesh attachment count "+path)
		for index: int in range(mini(old_parts.size(),new_parts.size())):
			var a: MeshInstance3D=old_parts[index];var b: MeshInstance3D=new_parts[index]
			if a.mesh is ArrayMesh and b.mesh is ArrayMesh:
				var left: Array=a.mesh.get("_surfaces").duplicate(true);var right: Array=b.mesh.get("_surfaces").duplicate(true)
				for surface: Dictionary in left:surface.erase("material")
				for surface: Dictionary in right:surface.erase("material")
				check(left==right,"standard raw geometry/LOD exact "+path)
			else:check(a.mesh.surface_get_arrays(0)==b.mesh.surface_get_arrays(0),"standard primitive geometry exact "+path)
			for surface: int in range(a.mesh.get_surface_count()):check(material_key(a.get_active_material(surface))==material_key(b.get_active_material(surface)),"standard materials exact "+path)
			check(a.transform==b.transform and a.cast_shadow==b.cast_shadow and a.lod_bias==b.lod_bias,"standard attachment/shadow/LOD policy exact "+path)
		old_root.free();new_root.free()

func structural() -> void:
	standard_assets()
	stage=Node3D.new();root.add_child(stage)
	for id: String in VehicleCatalog.IDS:
		for fitted: bool in [false,true]:
			var parts: Dictionary=VehicleCustomisation.defaults()
			if fitted:
				for category: String in VehicleCustomisation.CATEGORIES:parts[category]=VehicleCustomisation.options(category,id)[-1][0]
			var standard: CarVisual=await built(id,parts,false)
			var hits: int=Base.hits
			var reduced: CarVisual=await built(id,parts,true)
			check(Base.hits==hits+1,"reduced stock/fitted model uses offline base "+id+str(fitted))
			check(standard.front_wheels.size()==reduced.front_wheels.size() and standard.rear_wheels.size()==reduced.rear_wheels.size() and standard.rolling_wheels.size()==reduced.rolling_wheels.size(),"moving wheel frames retained "+id)
			for part: MeshInstance3D in reduced.find_children("*","MeshInstance3D",true,false):check(part.lod_bias==0.5,"reduced two-pixel LOD policy "+id)
			if fitted:check(reduced.find_children("RaceShadowProxy","MeshInstance3D",true,false).is_empty(),"fitted reduced model retains real silhouette casters "+id)
			var condition:=VehicleWeathering.new();condition.configure(reduced,"winter",VehicleCatalog.config(id))
			check(not condition.materials.is_empty(),"weathering binds to reduced model "+id)
			var state:=VehicleState.new();state.tick=12;state.velocity=Vector2(2,12);state.steering=0.4
			var snapshot: Array=state.snapshot().duplicate(true)
			reduced.present(state.position,0.2,state,DriveFrame.sample(0,0,1));reduced.present_suspension(state,0.04)
			check(state.snapshot()==snapshot,"reduced presentation retains canonical state "+id)
			check(reduced.brake_material.albedo_color==Color("f17158"),"reduced brake lamps respond "+id)
			var ghost:=PersonalGhost.new();root.add_child(ghost);ghost.configure(reduced)
			check(ghost.mesh!=null,"reduced personal ghost builds "+id)
			ghost.free();condition.reset();standard.free();reduced.free();await process_frame
	stage.free()

func run() -> void:
	output="res://../docs/evidence/aggressive-car-models-2026-11-07/structural"
	var only: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--vehicle="):only=argument.trim_prefix("--vehicle=")
		if argument=="--probe":probe_only=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if DisplayServer.get_name()=="headless":await structural()
	else:await pictures(only)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"probe_only":probe_only,"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"\t"))
	print("REDUCED_CAR_MODELS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
