extends "res://tests/review_car_reductions_2026_11_13.gd"
const Coarse = preload("res://vehicle/car_coarse_reduction.gd")
const COARSE_OUT: String="res://../docs/evidence/car-coarse-models-2026-11-14"
var pairs: Array=[]

func _initialize() -> void: capture_coarse.call_deferred()

func set_coarse_meshes(changes: Dictionary, coarse: bool) -> void:
	for part: MeshInstance3D in changes:
		part.mesh=changes[part][1 if coarse else 0]
		for surface: int in range(part.mesh.get_surface_count()): part.set_surface_override_material(surface,changes[part][2][surface])

func capture_coarse() -> void:
	Base.enabled=false
	Kits.enabled=false
	Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	var directory: String=COARSE_OUT.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in VehicleCatalog.IDS:
		Coarse.enabled=true
		var view:=CarShowroom.new()
		view.vehicle_id=id
		view.simple_model=true
		view.read_only=true
		view.livery=VehicleLivery.defaults(id)
		view.size=Vector2(1000,760)
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		var candidate_data: Dictionary=inventory(view.car,false)
		Coarse.enabled=false
		var reference:=CarVisual.new()
		reference.vehicle_id=id
		reference.livery=VehicleLivery.defaults(id)
		reference.cache_rest_pose=false
		root.add_child(reference)
		while not reference.model_ready: await process_frame
		var prior_data: Dictionary=inventory(reference,false)
		check(prior_data.triangles>0,"nonempty reference "+id)
		reference.hide()
		Cache._stable_names(reference)
		Cache._stable_names(view.car)
		var changes: Dictionary={}
		for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
			var previous: MeshInstance3D=reference.get_node_or_null(view.car.get_path_to(part))
			check(previous!=null,"same coarse attachment "+id+str(part.name))
			if previous==null: continue
			var materials: Array=[]
			for surface: int in range(part.mesh.get_surface_count()): materials.append(part.get_active_material(surface))
			changes[part]=[previous.mesh,part.mesh,materials]
			part.lod_bias=100000.0
		var observations: Array=[]
		for shot: Array in [["front",-0.70,0.31,1.15],["rear",2.45,0.31,1.15],["distant",-0.4,1.02,3.1]]:
			view.yaw=shot[1];view.elevation=shot[2];view.zoom=shot[3]
			view._orbit()
			set_coarse_meshes(changes,false)
			await wait_view(view)
			var before: Image=view.showroom_viewport.get_texture().get_image()
			var stable: bool=false
			for attempt: int in range(8):
				await wait_view(view)
				var repeat: Image=view.showroom_viewport.get_texture().get_image()
				stable=before.get_data()==repeat.get_data()
				before=repeat
				if stable: break
			check(stable,"stable coarse reference "+id+shot[0])
			set_coarse_meshes(changes,true)
			await wait_view(view)
			var after: Image=view.showroom_viewport.get_texture().get_image()
			set_coarse_meshes(changes,false)
			await wait_view(view)
			var restored: Image=view.showroom_viewport.get_texture().get_image()
			for attempt: int in range(8):
				if before.get_data()==restored.get_data(): break
				await wait_view(view)
				restored=view.showroom_viewport.get_texture().get_image()
			check(before.get_data()==restored.get_data(),"coarse restored pixels "+id+shot[0])
			var stem: String=directory.path_join(id+"-"+shot[0])
			check(before.save_png(stem+"-before.png")==OK,"coarse before capture")
			check(after.save_png(stem+"-after.png")==OK,"coarse after capture")
			observations.append({"view":shot[0],"difference":difference(before,after),"restored_exact":before.get_data()==restored.get_data()})
		pairs.append({"vehicle":id,"before":prior_data.triangles,"after":candidate_data.triangles,"views":observations})
		view.free();reference.free()
		await process_frame
		print("COARSE_NATIVE ",id," ",prior_data.triangles," -> ",candidate_data.triangles)
	FileAccess.open(directory.path_join("pairs.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":pairs},"\t"))
	print("COARSE_NATIVE_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
