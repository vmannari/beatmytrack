class_name SurfaceAudioModel
extends RefCounted
## Four real wheel locations drive the material mix. Read-only presentation.
var wheelbase: float = 2.55 * HandlingConfig.BODY_SCALE
var track_width: float = 1.66 * HandlingConfig.BODY_SCALE
var bumper_length: float = 0.0
var pavement: float = 0.0
var grass: float = 0.0
var sand: float = 0.0
var sand_depth: float = 0.0
var gravel: float = 0.0
var water: float = 0.0
var kerb: float = 0.0
var snow: float = 0.0
var snow_bank: float = 0.0
var snow_body: float = 0.0
var drive: float = 0.0
var acceleration: float = 0.0
var last_speed: float = 0.0
var has_speed: bool = false
var contacts_grounded: bool = false

func configure(config: HandlingConfig) -> void:
	wheelbase = config.wheelbase
	track_width = config.track_width
	bumper_length = maxf(config.collision_radius,config.wheelbase*0.5+0.80*HandlingConfig.BODY_SCALE)
	reset()

func reset() -> void:
	pavement = 0.0
	grass = 0.0
	sand = 0.0
	sand_depth = 0.0
	gravel = 0.0
	water = 0.0
	kerb = 0.0
	snow = 0.0
	snow_bank = 0.0
	snow_body = 0.0
	drive = 0.0
	acceleration = 0.0
	last_speed = 0.0
	has_speed = false
	contacts_grounded = false

func sample(state: VehicleState, frame: DriveFrame, track: NativeTrack, delta: float, grounded: bool, shared_contacts: SurfaceAudioModel = null) -> void:
	# An explicit result from the same synchronous presentation callback only.
	# Never retain/reuse it across physics, frames or mutable track edits.
	if shared_contacts == null or shared_contacts.contacts_grounded != grounded or shared_contacts.wheelbase != wheelbase or shared_contacts.track_width != track_width or shared_contacts.bumper_length != bumper_length:
		sample_contacts(state,track,grounded)
	else:
		pavement = shared_contacts.pavement
		grass = shared_contacts.grass
		sand = shared_contacts.sand
		sand_depth = shared_contacts.sand_depth
		gravel = shared_contacts.gravel
		water = shared_contacts.water
		kerb = shared_contacts.kerb
		snow = shared_contacts.snow
		snow_bank = shared_contacts.snow_bank
		snow_body = shared_contacts.snow_body
		contacts_grounded = grounded
	var speed: float = state.velocity.length()
	var gain: float = 1.0 - exp(-delta * 9.0)
	var measured: float = clampf((speed-last_speed)/maxf(delta,0.0001),-15.0,15.0) if has_speed else 0.0
	acceleration = lerpf(acceleration,measured,gain)
	last_speed = speed
	has_speed = true
	var reverse: bool = state.velocity.dot(state.forward()) < -0.6
	var pedal: float = float(frame.brake if reverse else frame.throttle)/255.0
	drive = lerpf(drive,clampf(pedal*0.70+maxf(acceleration,0.0)/15.0*0.30,0.0,1.0),gain)

func sample_contacts(state: VehicleState, track: NativeTrack, grounded: bool) -> void:
	contacts_grounded = grounded
	pavement = 0.0
	grass = 0.0
	sand = 0.0
	sand_depth = 0.0
	gravel = 0.0
	water = 0.0
	kerb = 0.0
	snow = 0.0
	snow_bank = 0.0
	snow_body = 0.0
	if not grounded: return
	var theme: String = str(track.metadata.get("theme","pine")) if track != null else "pine"
	var document: Dictionary = track.metadata.get("creator_document",{}) if track!=null else {}
	var grass_shoulder: bool = not state.track_elevated and theme in ["pine","storm"] and not document.get("pieces",[]).is_empty() and str(document.get("base_track",""))==""
	var winter_ground: bool = track!=null and theme=="winter" and not state.track_elevated
	for axle: float in [-0.5,0.5]:
		for side: float in [-0.5,0.5]:
			var point: Vector2 = state.position+state.forward()*wheelbase*axle+state.right()*track_width*side
			var cell: int = track.cell_at(point,state.track_elevated) if track != null else 0
			var bank_height: float = track.snow_banks.height_at(point) if winter_ground else 0.0
			snow_bank = maxf(snow_bank,bank_height/SnowBanks.BANK_HEIGHT)
			var raised: bool = track!=null and not state.track_elevated and not track.kerbs.triangles.is_empty() and track.kerbs.height_at(point)>.004
			if raised: kerb += .25
			if winter_ground and (bank_height>.004 or cell in [1,2,5]):
				snow += .25
			elif raised and theme!="desert":
				pavement += .25
			elif cell in [3,6]:
				water += 0.25
			elif theme == "desert" and cell in [0,1,2,5]:
				sand += 0.25
				# The same four contacts distinguish compacted road from soft
				# shoulders/banks and loose sand; no extra terrain queries.
				sand_depth += 0.25 if raised or cell in [1,2] else (0.125 if cell==5 else 0.0)
			elif cell == 1:
				grass += 0.25
			elif cell == 2:
				sand += 0.25
			elif cell == 7:
				gravel += 0.25
			elif cell == 5 and grass_shoulder:
				# Creator raster shoulder is a full metre wide, while the rendered
				# soil/grass fringe starts within it. It is not all raised concrete.
				grass += .125
				pavement += .125
			elif cell in [0,5]:
				pavement += 0.25
	if winter_ground:
		# Match the existing physical bank's four wheel, centre and bumper
		# contacts. A nose/rear push is audible before the tyres reach the ridge.
		for offset: float in [-bumper_length,0.0,bumper_length]:
			snow_bank = maxf(snow_bank,track.snow_banks.height_at(state.position+state.forward()*offset)/SnowBanks.BANK_HEIGHT)
		snow_bank = clampf(snow_bank,0.0,1.0)
		# Use the same bounded ellipse as the visible snow spray. Its front
		# corners/side panels can touch before the seven physical sample points.
		# These current contacts only drive sound; no future contact is predicted.
		var direction: float = state.velocity.angle()
		var half_width: float = track_width*.5+.12*HandlingConfig.BODY_SCALE
		for index: int in range(12):
			var offset: int = (index+1)/2*(1 if index%2==1 else -1)
			var ray: Vector2 = Vector2.from_angle(direction+float(offset)*TAU/12.0)
			var along: float = ray.dot(state.forward())/maxf(bumper_length,.01)
			var across: float = ray.dot(state.right())/half_width
			var height: float = track.snow_banks.height_at(state.position+ray/sqrt(along*along+across*across))
			if height>.035: snow_body = maxf(snow_body,height/SnowBanks.BANK_HEIGHT)
	if state.tire_water>0.05: water = maxf(water,state.tire_water)

func kerb_at(position: Vector2, heading: float, track: NativeTrack) -> float:
	if track==null or track.kerbs.triangles.is_empty(): return 0.0
	var forward := Vector2(sin(heading),cos(heading))
	var right := Vector2(cos(heading),-sin(heading))
	var amount: float = 0.0
	for axle: float in [-.5,.5]:
		for side: float in [-.5,.5]:
			if track.kerbs.height_at(position+forward*wheelbase*axle+right*track_width*side)>.004: amount += .25
	return amount
