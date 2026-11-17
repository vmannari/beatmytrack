extends SceneTree
const OUT: String="res://../docs/evidence/volt-hood-outline-2026-11-16"
const WORK: String="res://../build/volt-hood-outline-2026-11-16"
func _initialize() -> void:run.call_deferred()
func settle(room: CarShowroom) -> void:
	room.invalidate_render()
	for frame: int in range(8):await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	Engine.time_scale=0
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false;preload("res://ui/garage_car_cache.gd").enabled=false
	var directory: String=OUT.path_join("views-"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.size=Vector2i(1000,1000)
	var count: int=0
	for mode: String in ["stock","full"]:
		var room:=CarShowroom.new();room.vehicle_id="electric";room.simple_model=mode!="full";room.garage_mode=true;room.read_only=true;room.size=Vector2(1000,1000)
		room.livery=VehicleLivery.defaults("electric");room.livery.pattern="apex_twin";room.livery.colors.body="708ae8";room.livery.colors.accent="7222dd";room.livery.colors.detail="f06484"
		root.add_child(room)
		while not room.showroom_ready or not room.car.model_ready:await process_frame
		room.set_process(false);room.yaw=0;room.turntable.rotation.y=0
		var old: Node3D=load(WORK.path_join("electric-"+mode+"-before.scn")).instantiate()
		room.car.get_parent().add_child(old);old.transform=room.car.transform;room.reflections._mark_stage(old,true)
		for shot: String in ["top","hood-top","quarter","front"]:
			room.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if "top" in shot else Camera3D.PROJECTION_PERSPECTIVE
			var lift: Vector3=room.car.position
			if "top" in shot:
				var target: Vector3=lift+Vector3(0,0.65,-1.60 if shot=="hood-top" else 0)*HandlingConfig.BODY_SCALE
				room.camera.size=1.80 if shot=="hood-top" else 4.55
				room.camera.position=target+Vector3.UP*3;room.camera.look_at(target,Vector3.BACK)
			else:
				room.camera.fov=36
				room.camera.position=lift+(Vector3(2.8,2.1,-3.8) if shot=="quarter" else Vector3(0,2.3,-4.6))*HandlingConfig.BODY_SCALE
				room.camera.look_at(lift+Vector3(0,0.7,-0.65)*HandlingConfig.BODY_SCALE)
			for suffix: String in ["before","after"]:
				old.visible=suffix=="before";room.car.visible=suffix=="after"
				await settle(room)
				var pixels: Image=room.showroom_viewport.get_texture().get_image()
				assert(pixels.save_png(directory.path_join(mode+"-"+shot+"-"+suffix+".png"))==OK)
				count+=1
		old.free();room.free();await process_frame
	print("VHO_NATIVE_CAPTURES ",count," images; matched camera, paint and Garage");quit()
