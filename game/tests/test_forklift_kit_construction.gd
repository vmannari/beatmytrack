extends "res://tests/review_forklift_model.gd"
## Construction gates cover every custom assembly; appearance is reviewed separately.
var checks: int = 0
var failures: int = 0
var certificates: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)

func run() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="forklift"
		car.simple_model=simple
		car.editable_kits=true
		car.batch_parts=false
		car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for category: String in VehicleCustomisation.CATEGORIES:
			for option: Array in VehicleCustomisation.options(category,"forklift").slice(1):
				var parts: Dictionary=VehicleCustomisation.defaults()
				parts[category]=option[0]
				car.graphics.restore_originals()
				car.change_kit_parts(parts)
				var label: String=category+"/"+str(option[0])+"/"+str(simple)
				var bounds:=AABB()
				var first: bool=true
				var total: int=0
				for frame: Node3D in car.kit_frames[category]:
					var wheel_outer: float=-INF
					var wheel_radial: float=0.0
					var rotor_index: int=car.rolling_wheels.find(frame.get_parent())
					var side: float=signf((frame.get_parent().get_parent() as Node3D).position.x) if category=="rims" else 0.0
					for node: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
						var data: Dictionary=topology(node)
						var mesh_label: String=label+"/"+str(node.name)
						check(data.boundary_edges==0 and data.inconsistent_edges==0,mesh_label+" closed consistent volume "+JSON.stringify(data))
						check(data.normal_disagreements==0 and absf(data.signed_volume)>0.0000000001,mesh_label+" outward exterior normals "+JSON.stringify(data))
						total+=data.triangles
						var local: Transform3D=car.body.global_transform.affine_inverse()*node.global_transform
						var box: AABB=local*node.mesh.get_aabb()
						bounds=box if first else bounds.merge(box)
						first=false
						var finite: bool=true
						for vertex: Vector3 in node.mesh.get_faces():
							if not vertex.is_finite(): finite=false
							if category=="rims":
								var p: Vector3=frame.global_transform.affine_inverse()*node.global_transform*vertex
								wheel_outer=maxf(wheel_outer,p.x*side)
								wheel_radial=maxf(wheel_radial,Vector2(p.y,p.z).length())
						check(finite,mesh_label+" finite vertices")
					if category=="rims":
						var width: float=0.32 if frame.get_parent().get_parent().position.z<0 else 0.25
						var radius: float=car.wheel_radii[rotor_index]/HandlingConfig.BODY_SCALE
						check(wheel_outer<=width*0.48+0.060,label+" centre remains within factory stud projection "+str(wheel_outer))
						check(wheel_radial<=radius*0.64,label+" centre fits inside tyre bead "+str(wheel_radial))
				if category=="hood":
					check(bounds.position.y>=1.40 and bounds.end.y<=1.56,label+" lid remains within formed-cover envelope")
					check(car.body.find_children("EngineLid","MeshInstance3D",true,false).is_empty(),label+" replaces the factory lid")
					check(bounds.position.x>=-0.73 and bounds.end.x<=0.73 and bounds.position.z>=0.61 and bounds.end.z<=1.47,label+" fits the lid aperture")
				if category=="aero":
					check(bounds.position.y>=0.44 and bounds.end.y<=0.78 and bounds.position.x>=-0.84 and bounds.end.x<=0.84 and bounds.end.z<=1.79,label+" stays below lights and within bumper envelope")
					check(car.body.find_children("RearBumper","MeshInstance3D",true,false).is_empty(),label+" replaces factory bumper")
				if category=="body":
					check(car.body.find_children("RearCabinBrace*","MeshInstance3D",true,false).is_empty(),label+" no decorative cross across operator sightline")
					check(bounds.position.y>=1.01 and bounds.end.y<=2.75 and bounds.position.x>=-0.81 and bounds.end.x<=0.81,label+" bounded cabin and fitted feet")
				check(total<14000,label+" bounded kit triangle count "+str(total))
				certificates[label]={"triangles":total,"bounds":str(bounds)}
		car.free()
	var path: String="res://../docs/evidence/forklift-kit-refinement-2026-11-02/construction.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path=argument.trim_prefix("--output=")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"assemblies":certificates},"\t"))
	file.close()
	print("FORKLIFT_KIT_CONSTRUCTION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
