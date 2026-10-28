extends SceneTree
## Whole-car construction gates on actual prepared geometry; no visual rating.
const COACH = preload("res://vehicle/electric_coachwork.gd")
var output: String="res://../docs/evidence/electric-rebuild-2026-10-27/construction"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)

func section(car: CarVisual) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	for mesh: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
		if mesh.name!="Windscreen" and mesh.name!="CrownedRoof" and mesh.name!="RearScreen" and not str(mesh.name).begins_with("CanopyBorder") and not str(mesh.name).begins_with("Screen"): continue
		var faces: PackedVector3Array=mesh.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			for edge: int in range(3):
				var a: Vector3=faces[i+edge]
				var b: Vector3=faces[i+(edge+1)%3]
				if absf(a.x)<0.000001: points.append(Vector2(a.z,a.y))
				if a.x*b.x<0:
					var p: Vector3=a.lerp(b,-a.x/(b.x-a.x))
					points.append(Vector2(p.z,p.y))
	points.sort_custom(func(a: Vector2,b: Vector2)->bool:return a.x<b.x)
	return points

func height(points: Array[Vector2],z: float) -> float:
	for i: int in range(points.size()-1):
		var a: Vector2=points[i]
		var b: Vector2=points[i+1]
		if a.x<=z and b.x>=z and b.x-a.x>0.000001: return lerpf(a.y,b.y,(z-a.x)/(b.x-a.x))
	return NAN

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output=argument.trim_prefix("--evidence-root=")
	if "--before" in OS.get_cmdline_user_args():
		output+="/before"
		var coach: GDScript=COACH
		coach.source_code=FileAccess.get_file_as_string("res://../docs/evidence/electric-rebuild-2026-10-27/before/game/vehicle/electric_coachwork.gd")
		assert(coach.reload()==OK)
		var model: GDScript=load("res://vehicle/electric_car_model.gd")
		model.source_code=FileAccess.get_file_as_string("res://../docs/evidence/electric-rebuild-2026-10-27/before/game/vehicle/electric_car_model.gd")
		assert(model.reload()==OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var counts: Dictionary={}
	for simple: bool in [false,true]:
		var label: String="simple" if simple else "full"
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var total: int=0
		var instances: int=0
		var finite: bool=true
		var unit: bool=true
		var first: bool=true
		var bounds:=AABB()
		var clearance: float=INF
		for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
			if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
			instances+=1
			total+=mesh.mesh.get_faces().size()/3
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					finite=finite and point.is_finite()
					var p: Vector3=car.global_transform.affine_inverse()*mesh.global_transform*point
					if first: bounds=AABB(p,Vector3.ZERO);first=false
					else: bounds=bounds.expand(p)
					if str(mesh.name).begins_with("SculptedSide") or str(mesh.name).begins_with("RolledArch") or str(mesh.name).begins_with("WheelwellTub"):
						for axle: float in [-COACH.AXLE,COACH.AXLE]:
							if absf(point.z-axle)<0.418: clearance=minf(clearance,Vector2(point.y-0.37,point.z-axle).length()-0.37)
				for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: unit=unit and n.is_finite() and absf(n.length()-1)<0.02
		check(finite,"all prepared positions finite "+label)
		check(unit,"all prepared normals finite and unit length "+label)
		check(total<(45000 if simple else 120000),"new whole-car geometry budget "+label)
		check(instances<450,"bounded authored component count "+label)
		check(car.front_wheels.size()==2 and car.rolling_wheels.size()==4,"four articulated wheels and two steering pivots "+label)
		check(car.front_wheels[0].get_node_or_null("BrakeAssembly")!=null and car.rolling_wheels[0].get_node_or_null("BrakeAssembly")==null,"brakes steer independently of rolling wheels "+label)
		check(clearance>0.029,"actual arch and tub clearance over tyre circle "+label)
		check(absf(bounds.position.x+bounds.end.x)<0.0002,"symmetric whole-car bounds "+label)
		check(bounds.size.z>4.5 and bounds.size.z<4.9 and bounds.size.y>1.40 and bounds.size.y<1.56,"believable bounded sportback proportions "+label)
		check(car.body.get_node_or_null("EndUndertrayFront")!=null and car.body.get_node_or_null("EndUndertrayRear")!=null,"both bumper undersides closed "+label)
		check(car.body.get_node_or_null("PlatePocketBack")!=null and car.body.find_children("PlatePocketReturn*","MeshInstance3D",true,false).size()==4,"plate pocket has inset back and four physical returns "+label)
		check(car.body.get_node_or_null("OpticalHousingBack")!=null and car.body.get_node_or_null("IntakeThroatBack")!=null,"lamps and lower inlet have real inset backs "+label)
		var points: Array[Vector2]=section(car)
		var previous: float=INF
		var maximum_jump: float=0
		var convex: int=0
		var valid: bool=true
		var peak: float=0
		for i: int in range(58):
			var z: float=-0.80+i*0.04
			var a: float=height(points,z)
			var b: float=height(points,z+0.04)
			valid=valid and is_finite(a) and is_finite(b)
			peak=maxf(peak,a)
			var angle: float=rad_to_deg(atan2(b-a,0.04))
			if i>0:
				maximum_jump=maxf(maximum_jump,absf(angle-previous))
				if angle<previous+0.30: convex+=1
			previous=angle
		check(valid,"actual canopy section is continuous through screens and roof "+label)
		check(maximum_jump<8,"roofline has no abrupt screen-to-roof kink "+label)
		check(convex>=52,"main canopy bends as one convex arch "+label)
		check(peak>1.43 and peak<1.54,"controlled canopy crown and height "+label)
		metrics[label]={"visible_triangles":total,"unbatched_instances":instances,"arch_clearance_model_metres":clearance,"canopy_maximum_grade_jump_degrees":maximum_jump,"canopy_convex_runs":convex,"canopy_samples":58,"canopy_peak_model_metres":peak,"bounds_size":str(bounds.size)}
		counts[label]=total
		car.free()
	check(int(counts.simple)<int(counts.full)*0.40,"racing detail uses less than 40 percent of full geometry")
	FileAccess.open(output.path_join("construction.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"))
	print("ELECTRIC_REBUILD: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
