extends SceneTree
## Ensure the lamp is physically split at both fitted hatch seams.
const B = preload("res://vehicle/electric_reference_body.gd")
const C = preload("res://vehicle/electric_reference_cabin.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures+=1
		print("FAIL: ",description)

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	var M = preload("res://vehicle/electric_reference_mesh.gd")
	M.use_baked="--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for spec: Array in [["ReferenceRearLightbar",0.805,0.835],["ReferenceRearLampHousing",0.79,0.86]]:
			var base: String=spec[0]
			for part: int in range(3):
				var node_name: String=base+("Left" if part==0 else "Right" if part==2 else "")
				var node: MeshInstance3D=car.body.get_node_or_null(node_name)
				check(node!=null,"three separate sections "+node_name+" simple="+str(simple))
				if node==null: continue
				if base=="ReferenceRearLightbar": check(node.material_override==car.brake_material,"shared brake material "+node_name)
				var arrays: Array=node.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var outside:=true
				for index: int in range(vertices.size()):
					var v: float=lerpf(float(spec[1]),float(spec[2]),uv[index].y)
					var edge: float=B.hatch_rear_left_u(v)
					var left_outer: float=B.cap_point(true,edge-0.0045,v).x
					var left_inner: float=B.cap_point(true,edge+0.0045,v).x
					var x: float=vertices[index].x
					if (x>left_outer+0.00001 and x<left_inner-0.00001) or (x > -left_inner+0.00001 and x < -left_outer-0.00001): outside=false
				check(outside,"no lamp geometry across either seam "+node_name)
		car.rear_braking=true
		car._update_rear_lights()
		check(is_equal_approx(car.brake_material.emission_energy_multiplier,2.2),"all three sections brighten together under braking")
		car.rear_braking=false
		car._update_rear_lights()
		check(is_equal_approx(car.brake_material.emission_energy_multiplier,0.65),"all three sections return to running light brightness")
		for side: int in range(2):
			check(car.body.get_node_or_null("ReferenceRearLampHatchJoint"+str(side))!=null,"dark joint present "+str(side))
		# The rendered seam ribbon connects its authored samples with straight
		# segments, so test that actual centreline, not only the ideal curve.
		for i: int in range(15):
			var v: float=lerpf(0.79,0.86,float(i)/14.0)
			var a: float=13.0+4.0*(1.0-v)/0.68
			var lo: float=floorf(a)
			var p0: Vector3=C.hatch_seam_point(lo/56.0)
			var p1: Vector3=C.hatch_seam_point((lo+1.0)/56.0)
			var x: float=lerpf(p0.x,p1.x,a-lo)
			var edge: float=B.hatch_rear_left_u(v)
			var left: float=B.cap_point(true,edge-0.0045,v).x
			var right: float=B.cap_point(true,edge+0.0045,v).x
			check(x>left and x<right,"actual seam crosses the left joint at height "+str(v))
			check(-x > -right and -x < -left,"actual seam crosses the right joint at height "+str(v))
		car.free()
		await process_frame
	print("VOLT_REAR_LAMP_GAPS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
