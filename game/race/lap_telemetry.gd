class_name LapTelemetry
extends RefCounted
## Presentation-only observations; never read by simulation or record validation.
## Sample dictionaries are extensible with input/event channels in a later schema.
const MAX_SAMPLES: int = 2048
var completed: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var stride: int = 6
var lap_shortcuts: int = 0
var lap_start: float = 0.0

func begin(position: Vector2) -> void:
	samples = [_point(0, 0.0, 0.0, position, 0.0, 0.0, true)]

func observe(session: TrackSession, track: NativeTrack, position: Vector2, speed: float, practice: bool) -> void:
	var index: int = completed.size()
	var ended: bool = session.completed_laps > index
	var timestamp: float = session.elapsed_ticks / float(session.tick_rate)
	var valid: bool = not practice and session.shortcut_count == lap_shortcuts
	if ended:
		var duration: float = session.lap_start_time - lap_start
		samples.append(_point(index, session.lap_start_time, duration, track.finish_center, 1.0, speed, valid))
		completed.append({"index":index,"time":session.lap_times[index],"duration":duration,"valid":valid,"samples":samples})
		lap_start = session.lap_start_time
		lap_shortcuts = session.shortcut_count
		samples = [_point(index + 1, lap_start, 0.0, track.finish_center, 0.0, speed, not practice)]
		stride = 6
	elif session.elapsed_ticks % stride == 0:
		# Running maximum gives a monotonic distance domain for interpolation,
		# including stops and reversing. Time continues while distance stalls.
		var progress: float = clampf(session.route_distance / track.route_length, 0.0, 0.99999)
		if not samples.is_empty(): progress = maxf(progress, float(samples[-1].progress))
		samples.append(_point(index, timestamp, timestamp - lap_start, position, progress, speed, valid))
		if samples.size() >= MAX_SAMPLES:
			var reduced: Array[Dictionary] = []
			for i: int in range(0, samples.size(), 2): reduced.append(samples[i])
			samples = reduced
			stride *= 2

static func _point(index: int, timestamp: float, elapsed: float, position: Vector2, progress: float, speed: float, valid: bool) -> Dictionary:
	return {"lap_index":index,"timestamp":timestamp,"elapsed":elapsed,"world_position":Vector3(position.x,0,-position.y),"position":position,"progress":progress,"speed":speed,"valid":valid}

static func at(lap: Dictionary, progress: float, channel: String = "elapsed") -> float:
	var points: Array = lap.get("samples", [])
	if points.is_empty(): return 0.0
	var low: int = 0
	var high: int = points.size() - 1
	while low < high:
		var mid: int = (low + high) / 2
		if float(points[mid].progress) < progress: low = mid + 1
		else: high = mid
	if low == 0: return float(points[0][channel])
	var a: Dictionary = points[low - 1]
	var b: Dictionary = points[low]
	var weight: float = clampf((progress - float(a.progress)) / maxf(float(b.progress) - float(a.progress), 0.000001), 0.0, 1.0)
	return lerpf(float(a[channel]), float(b[channel]), weight)

static func sectors(lap: Dictionary, boundaries: PackedFloat32Array = PackedFloat32Array([0.0, 0.333333, 0.666667, 1.0])) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(boundaries.size() - 1):
		result.append({"start":boundaries[i],"end":boundaries[i+1],"time":at(lap,boundaries[i+1])-at(lap,boundaries[i])})
	return result
