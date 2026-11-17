extends SceneTree
const Source=preload("res://tests/support/car_pass10_source.gd")
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const IDS: Array[String]=["compact","kart","forklift","electric","hovercraft"]
const WORK: String="res://../build/car-pass10-2026-11-16"
const OUT: String="res://../docs/evidence/car-pass10-2026-11-16"
var rows: Array=[]
var catalog: Dictionary={}
var mode: String=""

func _initialize() -> void: run.call_deferred()
func observe(car: CarVisual, holders: Variant) -> void:
	var allowed: Dictionary={}
	for group: Dictionary in Detail.groups(car,holders):
		for entry: Dictionary in group.entries:allowed[entry.part.get_instance_id()]=preload("res://vehicle/car_surface_reduction.gd").permitted(entry)
	var parts: Array=car.find_children("*","MeshInstance3D",true,false) if holders==null else []
	if holders!=null:
		for holder: Node in holders: parts.append_array(holder.find_children("*","MeshInstance3D",true,false))
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var key: String=car.vehicle_id+"_"+Detail.mesh_key(part.mesh)
		var shaders: Array=[]
		for surface: int in range(part.mesh.get_surface_count()):
			var material: Material=part.get_active_material(surface)
			shaders.append(material.shader.resource_path if material is ShaderMaterial and material.shader!=null else material.get_class() if material!=null else "none")
		var frame: Node3D=Detail.frame_for(car,part)
		var pose: Transform3D=Detail.relative_pose(frame,part)
		rows.append({"vehicle":car.vehicle_id,"mode":mode,"permitted":allowed.get(part.get_instance_id(),false),"key":key,"name":str(part.name),"path":str(car.get_path_to(part)),"triangles":part.mesh.get_faces().size()/3,"shaders":shaders,"authored":part.mesh.has_meta("car_authored_far"),"guide_locked":part.mesh.has_meta("car_surface_guide_locked"),"blend_shapes":part.mesh.get_blend_shape_count() if part.mesh is ArrayMesh else 0,"maximum_scale":maxf(pose.basis.get_scale().abs().x,maxf(pose.basis.get_scale().abs().y,pose.basis.get_scale().abs().z)),"resource":part.mesh.resource_path,"frame":str(car.get_path_to(frame)),"pose":[[pose.basis.x.x,pose.basis.x.y,pose.basis.x.z],[pose.basis.y.x,pose.basis.y.y,pose.basis.y.z],[pose.basis.z.x,pose.basis.z.y,pose.basis.z.z],[pose.origin.x,pose.origin.y,pose.origin.z]]})
		catalog[key]={"source":part.mesh,"vehicle":car.vehicle_id,"name":str(part.name),"resource":part.mesh.resource_path}

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe
	for id: String in IDS:
		for current: String in ["stock","fitted"]:
			mode=current
			var car=Source.new();car.vehicle_id=id;car.simple_model=true;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			root.add_child(car)
			while not car.model_ready: await process_frame
			car.free();await process_frame
	var cache:=Resource.new();cache.set_meta("catalog",catalog)
	assert(ResourceSaver.save(cache,WORK.path_join("survey.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	FileAccess.open(OUT.path_join("survey.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("CAR15_SURVEY ",rows.size()," parts; ",catalog.size()," meshes");quit()
