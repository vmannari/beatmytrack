extends RefCounted
## Canonical bridge unloading; heights use the same axle support as the car.
const GRAVITY: float = 22.0 # Brief game-scale arcs between the owner's two extremes.
const MAX_RISE_SPEED: float = 3.2
const RELEASE_GAP: float = 0.00001

static func support(bridge: BridgeElevation, point: Vector2, heading: float, route: int, layer: bool, wheelbase: float) -> float:
	var axle := Vector2(sin(heading),cos(heading))*wheelbase*0.5
	return (bridge.height_at(point+axle,route,int(layer))+bridge.height_at(point-axle,route,int(layer)))*0.5

static func release(state: VehicleState, previous: Vector2, heading: float, velocity: Vector2, route: int, layer: bool, bridge: BridgeElevation, wheelbase: float, seconds: float) -> void:
	if state.jump_height > 0.0 or state.jump_cooldown > 0 or state.roll_ticks > 0 or velocity.length_squared() < 1.0: return
	# A ground underpass must never borrow the deck above it. Legacy bridges
	# include their approach in the shared sampler before the layer changes.
	var before: float = support(bridge,previous,heading,route,layer,wheelbase)
	var after: float = support(bridge,state.position,state.heading,state.route_index,state.track_elevated,wheelbase)
	if before <= bridge.road_surface.lift+0.001 and after <= bridge.road_surface.lift+0.001: return
	var behind: float = support(bridge,previous-velocity*seconds,heading,route,layer,wheelbase)
	var rise_speed: float = (before-behind)/seconds
	var support_speed: float = (after-before)/seconds
	if rise_speed <= 0.0 or rise_speed-support_speed <= GRAVITY*seconds: return
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

static func advance(state: VehicleState, previous_support: float, bridge: BridgeElevation, wheelbase: float, seconds: float) -> void:
	var floor_height: float = support(bridge,state.position,state.heading,state.route_index,state.track_elevated,wheelbase)
	state.jump_velocity -= GRAVITY*seconds
	state.jump_height = maxf(0.0,previous_support+state.jump_height+state.jump_velocity*seconds-floor_height)
	if state.jump_height == 0.0:
		var relative_speed: float = state.jump_velocity-(floor_height-previous_support)/seconds
		state.velocity *= 1.0-clampf(-relative_speed*0.01,0.0,0.08)
		state.jump_velocity = 0.0
		state.bridge_airborne = false
		state.jump_cooldown = maxi(state.jump_cooldown,24)

static func pitch(state: VehicleState) -> float:
	var direction: float = -1.0 if state.velocity.dot(state.forward()) < 0.0 else 1.0
	return atan2(state.jump_velocity*direction,maxf(5.0,state.velocity.length()))
