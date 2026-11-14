extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	if "--draft" in OS.get_cmdline_user_args():
		var manifest: Dictionary=(load(SuperRallyModel.ROOT+"manifest.json") as JSON).data
		for item: Dictionary in manifest.tiers.simple:
			if str(item.group).begins_with("wheel_"):continue
			var original: Mesh=load(SuperRallyModel.ROOT+str(item.mesh))
			var mesh:=ArrayMesh.new()
			for surface: int in range(original.get_surface_count()):
				var data: Array=original.surface_get_arrays(surface)
				var positions: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
				for i: int in range(positions.size()):
					var scale: float=1;var derivative: float=0
					for band: Vector3 in [Vector3(1.53,1.73,.040),Vector3(1.65,2.22,.035)]:
						var t: float=clampf((-positions[i].z-band.x)/(band.y-band.x),0,1)
						scale-=band.z*t*t*t*(10+t*(-15+6*t))
						derivative+=band.z*30*t*t*(1-t)*(1-t)/(band.y-band.x)
					normals[i].x/=scale
					normals[i].z-=derivative*(positions[i].x-.005052088637516661)*normals[i].x
					normals[i]=normals[i].normalized()
					positions[i].x=SuperRallyModel._nose_plan_x(positions[i].x,positions[i].z)
				data[Mesh.ARRAY_VERTEX]=positions;data[Mesh.ARRAY_NORMAL]=normals
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
			SuperRallyModel.assets[SuperRallyModel.ROOT+str(item.mesh)]=mesh
	var stage: String = "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
	root.size=Vector2i(1000,600)
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("353c40")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.75;world.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-65,-30,0);light.light_energy=1.3;world.add_child(light)
	var car:=CarVisual.new();car.vehicle_id="super_rally";car.simple_model=true;car.batch_parts=prepared
	car.livery=VehicleLivery.defaults("super_rally");car.livery.colors.body="ffffff"
	world.add_child(car)
	while not car.model_ready:await process_frame
	if prepared:assert(preload("res://vehicle/modular_car_base.gd").hits>0,"Final plan view must consume the prepared base")
	car.rotation.y=PI/2
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=2.8;camera.position=Vector3(0,6,0);world.add_child(camera)
	camera.look_at(Vector3(0,.65,0),Vector3.BACK);camera.current=true
	for frame: int in range(16):await process_frame;await RenderingServer.frame_post_draw
	var folder: String="res://../docs/evidence/challenger-corner-roll-2026-11-13/plan-"+stage
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	assert(root.get_texture().get_image().save_png(folder.path_join(RenderingServer.get_current_rendering_method()+".png"))==OK)
	world.queue_free();await process_frame;await process_frame
	print("CHALLENGER_PLAN: ",stage);quit()
