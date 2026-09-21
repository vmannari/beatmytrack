class_name RaceResultData
extends RefCounted
## Completed result read model. UI has no car/controller dependency.
var route := PackedVector2Array()
var laps: Array[Dictionary] = []
var fastest: int = -1
var sector_boundaries := PackedFloat32Array([0.0, 1.0/3.0, 2.0/3.0, 1.0])

static func build(track: NativeTrack, times: Array[float], telemetry: LapTelemetry, practice: bool) -> RaceResultData:
	var result := RaceResultData.new()
	var start: float = float(track.project_race_route(track.finish_center).progress)
	# Equal-distance geometry shared by all modes; cached once per completed race.
	for i: int in range(361): result.route.append(track._race_route_point(start + track.route_length * i / 360.0))
	for i: int in range(times.size()):
		var lap: Dictionary = telemetry.completed[i].duplicate(true) if i < telemetry.completed.size() else {"index":i,"time":times[i],"duration":times[i],"valid":not practice,"samples":[]}
		if practice: lap.valid = false
		result.laps.append(lap)
		if lap.valid and (result.fastest < 0 or times[i] < times[result.fastest]): result.fastest = i
	return result

static func speed_stats(lap: Dictionary) -> Vector2:
	var points: Array = lap.get("samples", [])
	var integral: float = 0.0
	var top: float = 0.0
	for i: int in range(points.size()):
		top = maxf(top,float(points[i].speed))
		if i > 0: integral += (float(points[i].speed)+float(points[i-1].speed))*0.5*(float(points[i].elapsed)-float(points[i-1].elapsed))
	return Vector2(integral/maxf(float(lap.get("duration",0)),0.001),top)*3.6
