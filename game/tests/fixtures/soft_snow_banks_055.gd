extends SnowBanks
## Frozen original wheel-only drag; shared unchanged contact geometry.

func slow_car(state: VehicleState, previous: Vector2, config: HandlingConfig, seconds: float) -> void:
	if triangles.is_empty() or state.track_elevated or state.jump_height > 0.0: return
	var axle: Vector2 = state.forward()*config.wheelbase*0.5
	var side: Vector2 = state.right()*config.track_width*0.5
	var contact: float = 0.0
	var steps: int = maxi(1,ceili(previous.distance_to(state.position)/0.25))
	for i: int in range(steps+1):
		var point: Vector2 = previous.lerp(state.position,float(i)/steps)
		var height: float = maxf(maxf(height_at(point+axle-side),height_at(point+axle+side)),maxf(height_at(point-axle-side),height_at(point-axle+side)))
		contact += clampf(height/BANK_HEIGHT,0.0,1.0)/(steps+1)
	# Resist all travel directions, including a sideways slide, without bounce.
	state.velocity = state.velocity.move_toward(Vector2.ZERO,(8.0+state.velocity.length()*1.8)*contact*seconds)
