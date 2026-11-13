extends RefCounted
## Optional ordered dense solver. No nodes, clocks, IO or quality-dependent rules.
const MIN_BODIES: int = 48

static func step(state: VehicleState, contact: Callable, previous: Vector2, config: HandlingConfig, seconds: float) -> bool:
	if state.loose_tyres.size() < MIN_BODIES:
		if state.has_meta(&"native_tyre_contacts"): state.remove_meta(&"native_tyre_contacts")
		return false
	if not ClassDB.class_exists("BmtTyreContacts"): return false
	var solver: RefCounted = state.get_meta(&"native_tyre_contacts") if state.has_meta(&"native_tyre_contacts") else null
	if solver == null:
		solver = ClassDB.instantiate("BmtTyreContacts")
		if solver == null or solver.call("algorithm_version") != 2: return false
		state.set_meta(&"native_tyre_contacts",solver)
	if not solver.has_method("step_grid"): return false
	var car: Array = [state.position,state.velocity,state.collision_impulse,state.forward(),state.track_elevated,config.mass,config.collision_radius,seconds,state.collision_count]
	var world: Dictionary = {}
	var owner_track: Object = contact.get_object()
	# Only the exact base implementation has this immutable grid-only contact
	# contract. Custom callbacks/subclasses keep every original world query.
	if owner_track != null and contact.get_method() == &"_contact" and contact.get_bound_arguments_count() == 0 and contact.get_unbound_arguments_count() == 0 and owner_track.has_method("_tyre_contact_grid"):
		world = owner_track.call("_tyre_contact_grid")
	if not solver.call("step_grid",state.loose_tyres,car,contact,previous,Geometry2D,world): return false
	state.position = car[0]; state.velocity = car[1]; state.collision_impulse = car[2]; state.collision_count = car[8]
	return true
