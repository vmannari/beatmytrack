extends SceneTree
## Read-only design study; parameter variants are reloaded in isolated memory.
const COACH = preload("res://vehicle/electric_coachwork.gd")
func _initialize() -> void: run.call_deferred()

func curvature(points: Array[Vector2]) -> Dictionary:
	var sampled: Array[Vector2] = [points[0]]
	var remaining: float = 0.02
	for index: int in range(points.size()-1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index+1]
		var length_value: float = a.distance_to(b)
		while length_value>=remaining:
			a = a.lerp(b,remaining/length_value)
			sampled.append(a)
			length_value = a.distance_to(b)
			remaining = 0.02
		remaining -= length_value
	var previous: float = -INF
	var reverse: float = 0
	var rising: float = 0
	for index: int in range(sampled.size()-1):
		var delta: Vector2 = sampled[index+1]-sampled[index]
		var angle: float = rad_to_deg(atan2(-delta.y,-delta.x))
		if is_finite(previous): reverse = maxf(reverse,previous-angle)
		rising = maxf(rising,delta.y)
		previous = angle
	return {"reverse_degrees":reverse,"upward_step":rising}

func run() -> void:
	var author: GDScript = COACH
	var original: String = author.source_code
	for power: float in [0.5,0.65,0.75,0.85,1.0,1.25]:
		author.source_code = original.replace("(front.y-upper(front.z))*(1-across*across)","(front.y-upper(front.z))*pow(1-across*across,"+str(power)+")")
		assert(author.reload() == OK)
		var result: Dictionary = {"power":power}
		for x: float in [0.0,0.4,0.65,0.78]:
			var points: Array[Vector2] = []
			for step: int in range(241):
				var v: float = 1-step/240.0
				var low: float = 0.5
				var high: float = 1
				for iteration: int in range(20):
					var u: float = (low+high)*0.5
					if COACH.hood_point(u,v).x<x: low = u
					else: high = u
				var point: Vector3 = COACH.hood_point((low+high)*0.5,v)
				points.append(Vector2(point.z,point.y))
			result[str(x)] = curvature(points)
		print("HOOD_FORM_STUDY ",JSON.stringify(result))
	quit()
