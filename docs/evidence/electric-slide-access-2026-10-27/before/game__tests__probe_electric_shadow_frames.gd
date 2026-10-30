extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var car := CarVisual.new()
	car.vehicle_id = "electric"
	car.simple_model = true
	root.add_child(car)
	while not car.model_ready: await process_frame
	var casters: Array = []
	for mesh: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casters.append({"path":str(car.get_path_to(mesh)),"mode":mesh.cast_shadow,"triangles":mesh.mesh.get_faces().size()/3})
	var state := VehicleState.new()
	state.tick = 1
	state.steering = 0.4
	car.present(Vector2.ZERO,0,state,DriveFrame.sample(0,0,1))
	print("EV_FRAME_PROBE ",JSON.stringify({"casters":casters,"rear_braking_at_rest":car.rear_braking,"brake_colour":car.brake_material.albedo_color.to_html(false)}))
	state.velocity = Vector2(0,10)
	state.tick += 1
	car.present(Vector2.ZERO,0,state,DriveFrame.sample(0,0,1))
	print("EV_MOVING_BRAKE ",car.rear_braking," ",car.brake_material.albedo_color.to_html(false))
	quit()
