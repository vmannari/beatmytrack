extends "res://tests/test_electric_wheel_clearance.gd"
## Broad bounds reject distant parts; actual tire hulls test curved arch joins.

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
	car.set_process(false)
	car.set_physics_process(false)
	# Prove that the 3D query is active in this fixture before relying on a
	# negative narrow-phase result at a fitted curved opening.
	var probe:=StaticBody3D.new()
	var probe_collision:=CollisionShape3D.new()
	var probe_shape:=BoxShape3D.new()
	probe_shape.size=Vector3.ONE*0.08
	probe_collision.shape=probe_shape
	probe.add_child(probe_collision)
	root.add_child(probe)
	var probe_tire: MeshInstance3D=tire_in(car.rolling_wheels[0])
	probe.global_transform=probe_tire.global_transform
	await physics_frame
	await process_frame
	var positive:=PhysicsShapeQueryParameters3D.new()
	positive.shape=probe_tire.mesh.create_convex_shape()
	positive.shape.margin=0.0
	positive.margin=0.002
	positive.transform=probe_tire.global_transform
	check(not car.get_world_3d().direct_space_state.intersect_shape(positive,1).is_empty(),"tire query detects an intentional solid intrusion")
	probe.free()
	var state:=VehicleState.new()
	state.tick=1
	car.last_tick=1
	for option: Array in VehicleCustomisation.options("body","electric").slice(1):
		var parts: Dictionary=VehicleCustomisation.defaults()
		parts.body=option[0]
		car.change_kit_parts(parts)
		var faces:=PackedVector3Array()
		for frame: Node3D in car.kit_frames.body:
			for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
				var transform: Transform3D=car.body.global_transform.affine_inverse()*mesh.global_transform
				for point: Vector3 in mesh.mesh.get_faces(): faces.append(transform*point)
		var collider:=StaticBody3D.new()
		var shape:=ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision=true
		var collision:=CollisionShape3D.new()
		collision.shape=shape
		collider.add_child(collision)
		root.add_child(collider)
		for pose: Array in [[Vector3.ZERO,Vector4.ZERO,0.0],[Vector3(-0.07,-0.12,0.0),Vector4.ZERO,0.4],[Vector3(-0.03,-0.08,-0.08),Vector4(0.10,0.0,0.0,0.0),-0.4]]:
			car.suspension=pose[0]
			for wheel: Node3D in car.front_wheels: wheel.rotation.y=pose[2]
			car.present_suspension(state,0.0,true,0.0,pose[1])
			collider.global_transform=car.body.global_transform
			await physics_frame
			await process_frame
			for rotor: Node3D in car.rolling_wheels:
				var tire: MeshInstance3D=tire_in(rotor)
				var tire_bounds: AABB=(car.body.global_transform.affine_inverse()*tire.global_transform)*tire.get_aabb()
				var clear:=true
				for frame: Node3D in car.kit_frames.body:
					for mesh: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
						var part_bounds: AABB=(car.body.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
						if tire_bounds.grow(0.002).intersects(part_bounds): clear=false
				if not clear:
					var query:=PhysicsShapeQueryParameters3D.new()
					query.shape=tire.mesh.create_convex_shape()
					query.shape.margin=0.0
					query.margin=0.002
					query.transform=tire.global_transform
					query.collision_mask=collider.collision_layer
					clear=car.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
				check(clear,"body kit clears actual tire by 2mm "+str(option[0])+" "+str(rotor.get_parent().name))
		collider.free()
	print("VOLT_BODY_KIT_WHEEL_FIT: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
