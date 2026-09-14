class_name TrackHazards
extends RefCounted
## Only fixed-step state and validated object data; no scene or random state.

static func factors(state: VehicleState, objects: Array) -> Vector2:
	if state.track_elevated or state.jump_height > 0.0: return Vector2(1.0,0.0)
	var grip: float = 1.0
	var drag: float = 0.0
	for object: Dictionary in objects:
		if object.kind == "oil" and CreatorObjects.contains(object,state.position): grip = minf(grip,0.20)
		if object.kind == "puddle" and CreatorObjects.contains(object,state.position):
			grip = minf(grip,0.45)
			drag = maxf(drag,2.0+state.velocity.length()*0.65)
	return Vector2(grip,drag)

static func ramp_height(point: Vector2, objects: Array) -> float:
	for object: Dictionary in objects:
		if object.kind != "jump" or not CreatorObjects.contains(object,point): continue
		var local: Vector2 = (point-Vector2(object.position[0],object.position[1])).rotated(-deg_to_rad(float(object.rotation)))
		var length: float = CreatorObjects.size_of(object).x
		return (local.x/length+0.5)*float(object.get("scale",1.0))
	return 0.0

static func launch(state: VehicleState, previous: Vector2, objects: Array) -> void:
	if state.jump_cooldown > 0 or state.jump_height > 0.0 or state.track_elevated: return
	for object: Dictionary in objects:
		if object.kind != "jump": continue
		var turn: float = -deg_to_rad(float(object.rotation))
		var center := Vector2(object.position[0],object.position[1])
		var before: Vector2 = (previous-center).rotated(turn)
		var after: Vector2 = (state.position-center).rotated(turn)
		var half: Vector2 = CreatorObjects.size_of(object)*0.5
		if before.x < half.x and after.x >= half.x and after.x > before.x:
			var crossing: float = lerpf(before.y,after.y,(half.x-before.x)/(after.x-before.x))
			if absf(crossing) <= half.y and state.velocity.length() >= 5.0:
				state.jump_height = float(object.get("scale",1.0))
				state.jump_velocity = minf(8.0,2.0+state.velocity.length()*0.20)
				state.jump_cooldown = 120
				return


static func ramp_pitch(point: Vector2, forward: Vector2, objects: Array) -> float:
	for object: Dictionary in objects:
		if object.kind == "jump" and CreatorObjects.contains(object,point):
			var direction: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(object.rotation)))
			return atan(forward.dot(direction)/6.0)
	return 0.0
