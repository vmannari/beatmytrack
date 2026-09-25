class_name DrivingMusicProgress
extends RefCounted
## Presentation-only streak, independent of lap count and canonical physics.
var average_speed: float = 0.0
var qualifying_seconds: float = 0.0
var intensity: float = 0.0
var recovery_seconds: float = 0.0
var melancholy: bool = false
var fast: bool = false
var last_collisions: int = 0

func reset() -> void:
	average_speed = 0.0
	qualifying_seconds = 0.0
	intensity = 0.0
	recovery_seconds = 0.0
	melancholy = false
	fast = false
	last_collisions = 0

func advance(speed_mps: float, collisions: int, delta: float, paused: bool, profile: MusicProfile) -> void:
	if paused: return
	var dt: float = maxf(delta,0.0)
	if collisions < last_collisions: reset()
	if collisions > last_collisions:
		intensity = 0.0
		qualifying_seconds = 0.0
		average_speed = 0.0
		fast = false
		recovery_seconds = profile.collision_recovery_seconds
		melancholy = true
		last_collisions = collisions
		return
	last_collisions = collisions
	average_speed = lerpf(average_speed,maxf(speed_mps,0.0),1.0-exp(-dt/profile.speed_average_seconds))
	if recovery_seconds > 0.0:
		recovery_seconds = maxf(0.0,recovery_seconds-dt)
		return
	if average_speed >= profile.clean_speed_mps: fast = true
	elif average_speed < profile.clean_speed_mps-profile.speed_hysteresis_mps: fast = false
	if fast:
		var before: float = qualifying_seconds
		qualifying_seconds += dt
		var earned: float = maxf(0.0,qualifying_seconds-profile.speed_qualification_seconds)-maxf(0.0,before-profile.speed_qualification_seconds)
		intensity = minf(1.0,intensity+earned/profile.clean_build_seconds)
	else:
		qualifying_seconds = 0.0
		intensity = maxf(0.0,intensity-dt/profile.slow_decay_seconds)
	if intensity >= 0.3: melancholy = false
