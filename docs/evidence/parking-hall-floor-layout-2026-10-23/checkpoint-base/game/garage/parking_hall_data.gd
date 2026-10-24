extends PlaygroundData
## Local, untimed test facility. Visuals consume these exact wall/pillar bounds.
const SIZE := Vector2(120.0,72.0)
const PILLAR_RADIUS: float = 0.65
const STRAIGHT_Y: float = -18.0
const STRAIGHT_LENGTH: float = 90.0
const TURNING_CENTER := Vector2(-24.0,8.0)
const TURNING_RADIUS: float = 12.0
const PARKED_CARS: Array[Dictionary] = [
	{"position":Vector2(-31.5,-31),"vehicle":"compact","colour":"85877b","half_length":2.0},
	{"position":Vector2(22.5,31),"vehicle":"pickup","colour":"485a60","half_length":2.5},
	{"position":Vector2(37.5,-31),"vehicle":"classic","colour":"805849","half_length":2.0}]
var columns: Array[Vector3] = []

func _init() -> void:
	identity = "garage-parking-hall-v2"
	half_extent = SIZE * 0.5
	spawn = Vector2(-44.0,STRAIGHT_Y)
	spawn_heading = PI * 0.5
	islands = []
	for x: float in [-48.0,-36.0,-24.0,-12.0,0.0,12.0,24.0,36.0,48.0]:
		for y: float in [-26.0,26.0]: columns.append(Vector3(x,y,PILLAR_RADIUS))
	# A clear west-end manoeuvring area joins the two parking aisles.
	for x: float in [-48.0,0.0,12.0,24.0,36.0,48.0]:
		columns.append(Vector3(x,0.0,PILLAR_RADIUS))
	islands.assign(columns)
	# Two overlapping circles form each parked vehicle's conservative capsule.
	for parked: Dictionary in PARKED_CARS:
		for offset: float in [1.0-float(parked.half_length),float(parked.half_length)-1.0]:
			islands.append(Vector3(parked.position.x,parked.position.y+offset,1.0))
