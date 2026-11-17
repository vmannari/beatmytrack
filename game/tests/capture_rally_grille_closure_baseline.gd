extends "res://tests/measure_car_simplification.gd"
## CLV01: self-contained visual models; never restore old production assets.
const DETAIL_WORK: String="res://../build/rally-grille-closure-2026-11-16"
const DETAIL_OUT: String="res://../docs/evidence/rally-grille-closure-2026-11-16"
var detail_rows: Array=[]

func _initialize() -> void: capture_detail_baseline.call_deferred()

func detach_snapshot(car: CarVisual) -> Node3D:
	var holder: Node3D=car.duplicate()
	holder.set_script(null)
	var meshes: Dictionary={}
	var materials: Dictionary={}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null: continue
		if not meshes.has(part.mesh):
			var mesh: Mesh=part.mesh.duplicate()
			if part.mesh is ImmediateMesh:
				var converted:=ArrayMesh.new()
				for surface: int in range(part.mesh.get_surface_count()):
					converted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.mesh.surface_get_arrays(surface))
					converted.surface_set_material(surface,part.mesh.surface_get_material(surface))
				mesh=converted
			for surface: int in range(mesh.get_surface_count()):
				var material: Material=mesh.surface_get_material(surface)
				if material==null: continue
				if not materials.has(material): materials[material]=material.duplicate()
				mesh.surface_set_material(surface,materials[material])
			meshes[part.mesh]=mesh
		part.mesh=meshes[part.mesh]
		var override: Material=part.material_override
		if override!=null:
			if not materials.has(override): materials[override]=override.duplicate()
			part.material_override=materials[override]
		for surface: int in range(part.mesh.get_surface_count()):
			var override_surface: Material=part.get_surface_override_material(surface)
			if override_surface==null: continue
			if not materials.has(override_surface): materials[override_surface]=override_surface.duplicate()
			part.set_surface_override_material(surface,materials[override_surface])
	for child: Node in holder.find_children("*","Node",true,false): child.owner=holder
	return holder

func capture_detail_baseline() -> void:
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DETAIL_WORK))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DETAIL_OUT))
	for id: String in ["compact"]:
		for mode: String in ["stock","fitted","full"]:
			var car:=CarVisual.new()
			car.vehicle_id=id;car.simple_model=mode!="full";car.cache_rest_pose=false
			car.customisation=VehicleCustomisation.defaults();car.livery=VehicleLivery.defaults(id)
			car.livery.pattern="checker_fade"
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			var hits: int=Base.hits
			var kit_hits: int=Kits.hits
			root.add_child(car)
			while not car.model_ready: await process_frame


			var row: Dictionary={"vehicle":id,"mode":mode,"inventory":inventory(car,false),"selection":car.customisation.duplicate()}
			var holder: Node3D=detach_snapshot(car)
			var scene:=PackedScene.new()
			check(scene.pack(holder)==OK,"baseline scene pack")
			var path: String=DETAIL_WORK.path_join(id+"-"+mode+"-before.scn")
			check(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK,"baseline detached scene save")
			holder.free()
			row["scene"]=path
			detail_rows.append(row)
			print("DETAIL_BASELINE ",id," ",mode," triangles=",row.inventory.triangles)
			car.free();await process_frame
	FileAccess.open(DETAIL_OUT.path_join("before.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":detail_rows},"\t"))
	print("DETAIL_BASELINE_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
