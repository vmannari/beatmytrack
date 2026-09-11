class_name DriveFrame
extends RefCounted
## Signed 8-bit steering, unsigned 8-bit pedals. One frame per fixed tick.

var steer: int = 0
var throttle: int = 0
var brake: int = 0


static func sample(turn: float, gas: float, stop: float) -> DriveFrame:
	var frame := DriveFrame.new()
	frame.steer = clampi(roundi(turn * 127.0), -127, 127)
	frame.throttle = clampi(roundi(gas * 255.0), 0, 255)
	frame.brake = clampi(roundi(stop * 255.0), 0, 255)
	return frame


func packed() -> Array[int]:
	return [steer, throttle, brake]
