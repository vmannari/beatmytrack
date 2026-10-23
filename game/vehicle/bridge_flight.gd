extends RefCounted
## Canonical bridge unloading; heights use the same axle support as the car.
const GRAVITY: float = 22.0 # Brief game-scale arcs between the owner's two extremes.
const MAX_RISE_SPEED: float = 3.2
const RELEASE_GAP: float = 0.00001
const DESCENT_CLEARANCE: float = 0.12
const DESCENT_MAX_GRAVITY: float = 512.0
const DESCENT_TICKS: Array[int] = [8,12,16,20,24,28,32,36]

static func support(bridge: BridgeElevation, point: Vector2, heading: float, route: int, layer: bool, wheelbase: float) -> float:
	var axle := Vector2(sin(heading),cos(heading))*wheelbase*0.5
	return (bridge.height_at(point+axle,route,int(layer))+bridge.height_at(point-axle,route,int(layer)))*0.5

static func release(state: VehicleState, previous: Vector2, heading: float, velocity: Vector2, route: int, layer: bool, bridge: BridgeElevation, wheelbase: float, seconds: float) -> void:
	if state.jump_height > 0.0 or state.roll_ticks > 0 or velocity.length_squared() < 1.0: return
	# A ground underpass must never borrow the deck above it. Legacy bridges
	# include their approach in the shared sampler before the layer changes.
	var before: float = support(bridge,previous,heading,route,layer,wheelbase)
	var after: float = support(bridge,state.position,state.heading,state.route_index,state.track_elevated,wheelbase)
	if before <= bridge.road_surface.lift+0.001 and after <= bridge.road_surface.lift+0.001: return
	var behind: float = support(bridge,previous-velocity*seconds,heading,route,layer,wheelbase)
	var rise_speed: float = (before-behind)/seconds
	var support_speed: float = (after-before)/seconds
	if rise_speed-support_speed <= GRAVITY*seconds: return
	if support_speed < 0.0 and rise_speed <= 0.0:
		if velocity.length_squared() < 36.0 or before < bridge.road_surface.lift+0.5: return
		# The entry landing cooldown must not hide a separate downhill crest on
		# a short span. A downhill landing still suppresses repeated releases.
		if state.jump_cooldown > 24 or (state.jump_cooldown > 0 and state.bridge_descending): return
		_release_descent(state,bridge,wheelbase,seconds,before,after,rise_speed)
		return
	if rise_speed <= 0.0 or state.jump_cooldown > 0: return
	# Bounded suspension rebound keeps a short crest readable when its slope
	# disappears within one tick. It fades out at low speed.
	var rebound: float = MAX_RISE_SPEED*smoothstep(5.0,22.0,velocity.length())
	var vertical: float = maxf(minf(MAX_RISE_SPEED,rise_speed)-GRAVITY*seconds,rebound)
	# Leave enough supported deck for the small arc. A short bridge must not
	# turn this slight crest lift into a long fall down the opposite ramp.
	for adjustment: int in range(8):
		var landing: Vector2 = state.position+state.velocity*(2.0*vertical/GRAVITY)
		if support(bridge,landing,state.heading,state.route_index,state.track_elevated,wheelbase) >= after-0.03: break
		vertical *= 0.85
	# Wait for the axle support to flatten instead of spending the rebound on
	# a tiny front-axle skip while the rear axle is still climbing.
	if support_speed > vertical*0.5: return
	var gap: float = before+vertical*seconds-after
	if gap <= RELEASE_GAP: return
	state.jump_height = gap
	state.jump_velocity = vertical
	state.bridge_airborne = true
	state.bridge_gravity = GRAVITY
	state.bridge_descending = false
	state.bridge_landing_speed = 0.0

static func _release_descent(state: VehicleState, bridge: BridgeElevation, wheelbase: float, seconds: float, before: float, after: float, vertical: float) -> void:
	# Follow a short ballistic tangent, with no upward launch impulse. Fit its
	# downward acceleration to the short game-scale ramp so it lands on the
	# actual deck instead of sailing over the entire descending bridge.
	var best_gravity: float = 0.0
	var best_error: float = INF
	# At most 37 doubles (296 bytes), shared by all eight candidates. Check
	# every canonical tick so a short early floor crossing cannot be missed.
	var floors := PackedFloat64Array()
	floors.resize(37)
	floors[0] = before; floors[1] = after
	for tick: int in range(2,37):
		var ahead: float = (tick-1)*seconds
		floors[tick] = support(bridge,state.position+state.velocity*ahead,state.heading+state.yaw_rate*ahead,state.route_index,state.track_elevated,wheelbase)
	for ticks: int in DESCENT_TICKS:
		var duration: float = ticks*seconds
		var landing: float = floors[ticks]
		var gravity: float = 2.0*(before+vertical*duration-landing)/(duration*(duration+seconds))
		if gravity < GRAVITY or gravity > DESCENT_MAX_GRAVITY: continue
		if before+(vertical-gravity*seconds)*seconds-after <= RELEASE_GAP: continue
		var peak: float = 0.0
		var clear: bool = true
		for tick: int in range(1,ticks):
			var time: float = tick*seconds
			var gap: float = before+vertical*time-gravity*time*(time+seconds)*0.5-floors[tick]
			if gap < -RELEASE_GAP: clear = false; break
			peak = maxf(peak,gap)
		# Do not spend this crest's release on an invisible front-axle skip.
		if not clear or peak < 0.025 or peak > 0.25: continue
		var error: float = absf(peak-DESCENT_CLEARANCE)
		if error < best_error:
			best_error = error
			best_gravity = gravity
	if best_gravity == 0.0: return
	state.jump_velocity = vertical-best_gravity*seconds
	state.jump_height = before+state.jump_velocity*seconds-after
	state.bridge_airborne = true
	state.bridge_gravity = best_gravity
	state.bridge_descending = true
	state.bridge_landing_speed = 0.0

static func advance(state: VehicleState, previous_support: float, bridge: BridgeElevation, wheelbase: float, seconds: float) -> void:
	var floor_height: float = support(bridge,state.position,state.heading,state.route_index,state.track_elevated,wheelbase)
	state.jump_velocity -= state.bridge_gravity*seconds
	state.jump_height = maxf(0.0,previous_support+state.jump_height+state.jump_velocity*seconds-floor_height)
	if state.jump_height == 0.0:
		var relative_speed: float = state.jump_velocity-(floor_height-previous_support)/seconds
		if state.bridge_descending: state.bridge_landing_speed = maxf(0.0,-relative_speed)
		state.velocity *= 1.0-clampf(-relative_speed*0.01,0.0,0.08)
		state.jump_velocity = 0.0
		state.bridge_airborne = false
		state.jump_cooldown = maxi(state.jump_cooldown,24)

static func pitch(state: VehicleState) -> float:
	var direction: float = -1.0 if state.velocity.dot(state.forward()) < 0.0 else 1.0
	return atan2(state.jump_velocity*direction,maxf(5.0,state.velocity.length()))

static func landing_feedback(state: VehicleState) -> float:
	# A shallow supported crest release gets a gentle contact cue. Real wall
	# collisions retain their independent impulse/audio path.
	return minf(state.bridge_landing_speed,2.5)
