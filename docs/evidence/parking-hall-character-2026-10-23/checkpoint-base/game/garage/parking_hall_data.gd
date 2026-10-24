extends PlaygroundData
## Local, untimed test facility. Visuals consume these exact wall/pillar bounds.
const SIZE := Vector2(240.0,160.0)
const PILLAR_RADIUS: float = 0.8
const STRAIGHT_Y: float = -48.0
const TURNING_CENTER := Vector2(-56.0,23.0)
const TURNING_RADIUS: float = 28.0

func _init() -> void:
	identity = "garage-parking-hall-v1"
	half_extent = SIZE * 0.5
	spawn = Vector2(-100.0,STRAIGHT_Y)
	spawn_heading = PI * 0.5
	islands = []
	for x: float in [-108.0,-84.0,-60.0,-36.0,-12.0,12.0,36.0,60.0,84.0,108.0]:
		for y: float in [-66.0,66.0]: islands.append(Vector3(x,y,PILLAR_RADIUS))
	# Leave a broad turning area and an uninterrupted 200 m straight.
	for x: float in [-108.0,0.0,24.0,48.0,72.0,108.0]:
		islands.append(Vector3(x,0.0,PILLAR_RADIUS))
