class_name PersonalGhostRun
extends RefCounted
## Presentation samples only; never inputs to canonical driving or race rules.
const STRIDE: int = 6 # 20 Hz, interpolated at display rate.
const MAX_TICKS: int = 216000
const MODES: Array[String] = ["off", "lap", "race"]
const TITLES: Array[String] = ["Off", "Personal best lap", "Personal best race"]
const DESCRIPTIONS: Array[String] = [
	"Drive without a ghost.",
	"Your best flying lap starts again with each of your laps.",
	"Your best complete race starts when the race begins.",
]
var poses: Array = [] # tick, x, y, world height, heading, pitch, roll
var lap_ends: Array[float] = []
var overflow: bool = false

func capture(state: VehicleState, session: TrackSession, track: NativeTrack, bridge: BridgeElevation, handling: HandlingConfig, force: bool = false) -> void:
	if state.tick > MAX_TICKS:
		overflow = true
		return
	var boundary: bool = session.completed_laps > lap_ends.size()
	if boundary: lap_ends.append(session.lap_start_time * VehicleSimulation.TICK_RATE)
	if not force and not boundary and state.tick % STRIDE != 0: return
	if not poses.is_empty() and int(poses[-1][0]) == state.tick: return
	var point: Vector2 = state.position
	var axle: Vector2 = state.forward() * handling.wheelbase * 0.5
	var layer: int = int(state.track_elevated)
	var front: float = bridge.height_at(point + axle, state.route_index, layer)
	var rear: float = bridge.height_at(point - axle, state.route_index, layer)
	var height: float = (front + rear) * 0.5 + state.jump_height
	var pitch: float = atan2(front - rear, handling.wheelbase)
	if state.jump_height > 0.0:
		pitch = atan2(state.jump_velocity, maxf(5.0, state.velocity.length()))
	elif not state.track_elevated:
		height += TrackHazards.ramp_height(point, track.hazard_objects) - track.water_depth(point)
		pitch += TrackHazards.ramp_pitch(point, axle.normalized(), track.hazard_objects)
	if state.jump_height == 0.0:
		height += state.kerb_offset.x
		pitch += state.kerb_offset.y
	poses.append([state.tick, point.x, point.y, height, state.heading, pitch, state.kerb_offset.z])

func branch(tick: int) -> void:
	while not poses.is_empty() and int(poses[-1][0]) > tick: poses.pop_back()
	while not lap_ends.is_empty() and lap_ends[-1] > tick: lap_ends.pop_back()
	overflow = tick > MAX_TICKS

func recording(mode: String) -> Dictionary:
	if overflow or lap_ends.size() != RaceRules.LAPS or poses.is_empty(): return {}
	var start: float = 0.0
	var end: float = lap_ends[-1]
	if mode == "lap":
		# Match LocalRecords: the standing first lap is excluded from flying PBs.
		var best: float = MAX_TICKS + 1.0
		for index: int in range(1, lap_ends.size()):
			var duration: float = lap_ends[index] - lap_ends[index - 1]
			if duration < best:
				best = duration
				start = lap_ends[index - 1]
				end = lap_ends[index]
	var source: Dictionary = {"ticks": poses[-1][0], "poses": poses}
	var first: Array = sample(source,start)
	first[0] = 0.0
	var samples: Array = [first]
	for pose: Array in poses:
		if float(pose[0]) <= start: continue
		if float(pose[0]) >= end: break
		var sample: Array = pose.duplicate()
		sample[0] = float(sample[0]) - start
		samples.append(sample)
	var last: Array = sample(source,end)
	last[0] = end - start
	samples.append(last)
	return {"ticks": end - start, "poses": samples}

static func sample(recording: Dictionary, tick: float) -> Array:
	if recording.is_empty() or tick < 0.0 or tick > float(recording.ticks): return []
	var samples: Array = recording.poses
	var low: int = 0
	var high: int = samples.size() - 1
	while low < high:
		var middle: int = (low + high + 1) / 2
		if float(samples[middle][0]) <= tick: low = middle
		else: high = middle - 1
	var a: Array = samples[low]
	var b: Array = samples[mini(low + 1, samples.size() - 1)]
	var weight: float = clampf((tick - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0])), 0.0, 1.0)
	return [tick, lerpf(a[1], b[1], weight), lerpf(a[2], b[2], weight), lerpf(a[3], b[3], weight), lerp_angle(a[4], b[4], weight), lerp_angle(a[5], b[5], weight), lerp_angle(a[6], b[6], weight)]
