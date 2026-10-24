class_name LightProps
extends RefCounted
## Deterministic, forgiving movable props; previous attempts cannot change a run.
static func step(state: VehicleState, objects: Array, contact: Callable, previous: Vector2, dt: float, car_mass: float, car_radius: float) -> void:
	# Derived scratch data is not canonical state or rewind payload. Compare the
	# immutable source by value so editor/test mutations also invalidate it.
	var work: Dictionary = state.get_meta(&"light_prop_work",{})
	if work.is_empty() or objects != work.source:
		var prepared: Array = []
		var radii: Array[float] = []
		var has_breakables: bool = false
		for object: Dictionary in objects:
			if object.kind in CreatorCatalog.SOFT:
				prepared.append(object)
				radii.append(CreatorObjects.size_of(object).x*0.35)
				if object.kind in BreakableProps.KINDS: has_breakables = true
		work = {"source":objects.duplicate(true),"props":prepared,"radii":radii,"breakables":has_breakables}
		state.set_meta(&"light_prop_work",work)
	var props: Array = work.props
	if state.light_props.is_empty():
		for object: Dictionary in props: state.light_props.append(BurningBarrel.initial(object) if object.kind=="burning_barrel" else [object.position[0],object.position[1],0.0,0.0,0.0])
	if work.breakables: BreakableProps.prepare(state,props)
	for index: int in range(props.size()):
		if props[index].kind=="burning_barrel":
			BurningBarrel.step(state,props[index],state.light_props[index],contact,previous,dt,car_mass,car_radius)
			continue
		if props[index].kind in BreakableProps.KINDS:
			BreakableProps.step_one(state,props,index,contact,previous,dt,car_mass,car_radius)
			continue
		var row: Array = state.light_props[index]
		var p := Vector2(row[0],row[1])
		var velocity := Vector2(row[2],row[3])
		var radius: float = work.radii[index]
		var reach: float = car_radius+radius+0.0001
		var near_car: bool = p.x >= minf(previous.x,state.position.x)-reach and p.x <= maxf(previous.x,state.position.x)+reach and p.y >= minf(previous.y,state.position.y)-reach and p.y <= maxf(previous.y,state.position.y)+reach
		if not state.track_elevated and state.jump_height<=0 and near_car:
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
		# At zero velocity both branches of the old query leave p/velocity exact.
		if velocity != Vector2.ZERO or p.x == 0.0 or p.y == 0.0:
			var collision: Vector3 = contact.call(next,radius,false)
			if collision.z<=0: p=next
			else: velocity=Vector2.ZERO
		row[0]=p.x; row[1]=p.y; row[2]=velocity.x; row[3]=velocity.y
	BreakableProps.step_fragments(state,contact,previous,dt,car_mass,car_radius)
