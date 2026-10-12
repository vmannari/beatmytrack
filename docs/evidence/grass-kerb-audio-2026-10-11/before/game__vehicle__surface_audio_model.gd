class_name SurfaceAudioModel
extends RefCounted
## Four real wheel locations drive the material mix. Read-only presentation.
var wheelbase: float = 2.55 * HandlingConfig.BODY_SCALE
var track_width: float = 1.66 * HandlingConfig.BODY_SCALE
var pavement: float = 0.0
var grass: float = 0.0
var sand: float = 0.0
var gravel: float = 0.0
var water: float = 0.0
var drive: float = 0.0
var acceleration: float = 0.0
var last_speed: float = 0.0
var has_speed: bool = false

func configure(config: HandlingConfig) -> void:
	wheelbase = config.wheelbase
	track_width = config.track_width
	reset()

func reset() -> void:
	pavement = 0.0
	grass = 0.0
	sand = 0.0
	gravel = 0.0
	water = 0.0
	drive = 0.0
	acceleration = 0.0
	last_speed = 0.0
	has_speed = false

func sample(state: VehicleState, frame: DriveFrame, track: NativeTrack, delta: float, grounded: bool) -> void:
	pavement = 0.0
	grass = 0.0
	sand = 0.0
	gravel = 0.0
	water = 0.0
	var speed: float = state.velocity.length()
	var gain: float = 1.0 - exp(-delta * 9.0)
	var measured: float = clampf((speed-last_speed)/maxf(delta,0.0001),-15.0,15.0) if has_speed else 0.0
	acceleration = lerpf(acceleration,measured,gain)
	last_speed = speed
	has_speed = true
	var reverse: bool = state.velocity.dot(state.forward()) < -0.6
	var pedal: float = float(frame.brake if reverse else frame.throttle)/255.0
	drive = lerpf(drive,clampf(pedal*0.70+maxf(acceleration,0.0)/15.0*0.30,0.0,1.0),gain)
	if not grounded: return
	var theme: String = str(track.metadata.get("theme","pine")) if track != null else "pine"
	for axle: float in [-0.5,0.5]:
		for side: float in [-0.5,0.5]:
			var point: Vector2 = state.position+state.forward()*wheelbase*axle+state.right()*track_width*side
			var cell: int = track.cell_at(point,state.track_elevated) if track != null else 0
			if cell in [3,6]:
				water += 0.25
			elif theme == "desert" and cell in [0,1,2,5]:
				sand += 0.25
			elif cell == 1:
				grass += 0.25
			elif cell == 2:
				sand += 0.25
			elif cell == 7:
				gravel += 0.25
			elif cell in [0,5]:
				pavement += 0.25
	if state.tire_water>0.05: water = maxf(water,state.tire_water)
