class_name LightProps
extends RefCounted
## Deterministic, forgiving movable props; previous attempts cannot change a run.
static func step(state: VehicleState, objects: Array, contact: Callable, previous: Vector2, dt: float, car_mass: float, car_radius: float) -> void:
	var props: Array = []
	for object: Dictionary in objects:
		if object.kind in CreatorCatalog.SOFT: props.append(object)
	if state.light_props.is_empty():
		for object: Dictionary in props: state.light_props.append([object.position[0],object.position[1],0.0,0.0,0.0])
	for index: int in range(props.size()):
		var row: Array = state.light_props[index]
		var p := Vector2(row[0],row[1])
		var velocity := Vector2(row[2],row[3])
		var radius: float = CreatorObjects.size_of(props[index]).x*0.35
		if not state.track_elevated and state.jump_height<=0:
			var delta: Vector2 = p-Geometry2D.get_closest_point_to_segment(p,previous,state.position)
			if delta.length()<car_radius+radius:
				var normal: Vector2 = delta.normalized() if delta.length_squared()>0.000001 else state.forward()
				var approach: float = (state.velocity-velocity).dot(normal)
				if approach>0:
					var mass: float = 8.0 if props[index].kind in ["cone","chevron","braking_board"] else 22.0
					var impulse: float = minf(approach/(1.0/car_mass+1.0/mass),car_mass*0.18)
					state.velocity -= normal*impulse/car_mass
					velocity += normal*impulse/mass
					row[4] = 1.0
		velocity = velocity.limit_length(16).move_toward(Vector2.ZERO,5.0*dt)
		var next: Vector2 = p+velocity*dt
		var collision: Vector3 = contact.call(next,radius,false)
		if collision.z<=0: p=next
		else: velocity=Vector2.ZERO
		row[0]=p.x; row[1]=p.y; row[2]=velocity.x; row[3]=velocity.y
