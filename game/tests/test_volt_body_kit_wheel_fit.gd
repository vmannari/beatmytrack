extends "res://tests/test_electric_wheel_clearance.gd"
## Fitted body-kit bounds must stay outside moving tire bounds.

func run() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	var car:=CarVisual.new()
	car.vehicle_id="electric"
	car.editable_kits=true
	car.batch_parts=false
	car.cache_rest_pose=false
	root.add_child(car)
	while not car.model_ready: await process_frame
	var state:=VehicleState.new()
	state.tick=1
	car.last_tick=1
	for option: Array in VehicleCustomisation.options("body","electric").slice(1):
		var parts: Dictionary=VehicleCustomisation.defaults()
		parts.body=option[0]
		car.change_kit_parts(parts)
		for pose: Array in [[Vector3.ZERO,Vector4.ZERO,0.0],[Vector3(-0.07,-0.12,0.0),Vector4.ZERO,0.4],[Vector3(-0.03,-0.08,-0.08),Vector4(0.10,0.0,0.0,0.0),-0.4]]:
			car.suspension=pose[0]
			for wheel: Node3D in car.front_wheels: wheel.rotation.y=pose[2]
			car.present_suspension(state,0.0,true,0.0,pose[1])
			for rotor: Node3D in car.rolling_wheels:
				var tire: MeshInstance3D=tire_in(rotor)
				var tire_bounds: AABB=(car.body.global_transform.affine_inverse()*tire.global_transform)*tire.get_aabb()
				var clear:=true
				for frame: Node3D in car.kit_frames.body:
					for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
						var part_bounds: AABB=(car.body.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
						if tire_bounds.grow(0.002).intersects(part_bounds): clear=false
				check(clear,"body kit clears tire "+str(option[0])+" "+str(rotor.get_parent().name))
	print("VOLT_BODY_KIT_WHEEL_FIT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
