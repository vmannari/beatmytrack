class_name DriveFrame
extends RefCounted
## Signed 8-bit steering, unsigned 8-bit pedals. One frame per fixed tick.

var steer: int = 0
var throttle: int = 0
var brake: int = 0
var handbrake: int = 0
var launch_start: int = 0 # Tick-zero marker: 1 clean countdown, 2 early pedal.


static func sample(turn: float, gas: float, stop: float, hand: float = 0.0) -> DriveFrame:
	var frame := DriveFrame.new()
	frame.steer = clampi(roundi(turn * 127.0), -127, 127)
	frame.throttle = clampi(roundi(gas * 255.0), 0, 255)
	frame.brake = clampi(roundi(stop * 255.0), 0, 255)
	frame.handbrake = clampi(roundi(hand * 255.0), 0, 255)
	return frame


func packed() -> Array[int]:
	if launch_start > 0: return [steer, throttle, brake, handbrake, launch_start]
	return [steer, throttle, brake, handbrake] if handbrake > 0 else [steer, throttle, brake]
