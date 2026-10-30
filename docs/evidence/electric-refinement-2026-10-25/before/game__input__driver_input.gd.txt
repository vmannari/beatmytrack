class_name DriverInput
extends RefCounted
## Touch ownership is per finger; releasing one cannot release another finger.

var touches: Dictionary = {}
var touch_strengths: Dictionary = {}


func set_touch(index: int, action: StringName, strength: float = 1.0) -> void:
	touches[index] = action
	touch_strengths[index] = clampf(strength,0.0,1.0)


func release_touch(index: int) -> void:
	touches.erase(index)
	touch_strengths.erase(index)


func clear() -> void:
	touches.clear()
	touch_strengths.clear()
	for action: StringName in [&"steer_left", &"steer_right", &"accelerate", &"brake", &"handbrake"]:
		Input.action_release(action)


func sample() -> DriveFrame:
	return DriveFrame.sample(_strength(&"steer_right") - _strength(&"steer_left"),
		_strength(&"accelerate"), _strength(&"brake"), _strength(&"handbrake"))


func _strength(action: StringName) -> float:
	var value: float = Input.get_action_strength(action)
	for finger: Variant in touches:
		if touches[finger] == action: value = maxf(value,float(touch_strengths.get(finger,1.0)))
	return value
