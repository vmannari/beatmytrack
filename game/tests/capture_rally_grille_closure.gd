extends SceneTree
const OUT: String="res://../docs/evidence/rally-grille-closure-2026-11-16"
const WORK: String="res://../build/rally-grille-closure-2026-11-16"
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
		var room:=CarShowroom.new();room.vehicle_id="compact";room.simple_model=mode!="full";room.garage_mode=true;room.read_only=true;room.size=Vector2(1000,1000)
		room.livery=VehicleLivery.defaults("compact");room.livery.pattern="checker_fade"
		root.add_child(room)
		while not room.showroom_ready or not room.car.model_ready:await process_frame
		room.set_process(false);room.yaw=0;room.turntable.rotation.y=0
		var old: Node3D=load(WORK.path_join("compact-"+mode+"-before.scn")).instantiate()
		room.car.get_parent().add_child(old);old.transform=room.car.transform;room.reflections._mark_stage(old,true)
		for shot: String in ["front","low-front","low-left","low-right"]:
			room.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;room.camera.fov=36
			var lift: Vector3=room.car.position
			var positions: Dictionary={"front":Vector3(0,1.40,-4.7),"low-front":Vector3(0,0.65,-3.45),"low-left":Vector3(1.25,0.72,-3.5),"low-right":Vector3(-1.25,0.72,-3.5)}
			room.camera.position=lift+(positions[shot] as Vector3)*HandlingConfig.BODY_SCALE
			room.camera.look_at(lift+Vector3(0,0.66,-1.80)*HandlingConfig.BODY_SCALE)
			for suffix: String in ["before","after"]:
				old.visible=suffix=="before";room.car.visible=suffix=="after"
				await settle(room)
				var pixels: Image=room.showroom_viewport.get_texture().get_image()
				assert(pixels.save_png(directory.path_join(mode+"-"+shot+"-"+suffix+".png"))==OK)
				count+=1
		old.free();room.free();await process_frame
	print("RGC_NATIVE_CAPTURES ",count," images; matched camera, paint and Garage");quit()
