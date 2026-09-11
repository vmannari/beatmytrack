class_name DriverInput
extends RefCounted
## Touch ownership is per finger; releasing one cannot release another finger.

var touches: Dictionary = {}


func set_touch(index: int, action: StringName) -> void:
	touches[index] = action


func release_touch(index: int) -> void:
	touches.erase(index)


func clear() -> void:
	touches.clear()
	for action: StringName in [&"steer_left", &"steer_right", &"accelerate", &"brake"]:
		Input.action_release(action)


func sample() -> DriveFrame:
	return DriveFrame.sample(_strength(&"steer_right") - _strength(&"steer_left"),
		_strength(&"accelerate"), _strength(&"brake"))


func _strength(action: StringName) -> float:
	return maxf(Input.get_action_strength(action), 1.0 if touches.values().has(action) else 0.0)
