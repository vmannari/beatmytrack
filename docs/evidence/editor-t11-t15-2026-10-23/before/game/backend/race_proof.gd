extends RefCounted
## Small movement evidence for the owner-approved lightweight server check.
const STRIDE: int = 6
var samples: Array = []
var _laps: int = 0

func capture(state: VehicleState, session: TrackSession, force: bool = false) -> void:
	var boundary: bool = session.completed_laps > _laps
	_laps = session.completed_laps
	if not force and not boundary and not session.finished and state.tick % STRIDE != 0: return
	if not samples.is_empty() and int(samples[-1][0]) == state.tick: return
	samples.append([state.tick,state.position.x,state.position.y,state.heading,
		state.velocity.x,state.velocity.y,int(state.track_elevated),state.jump_height])

func recording(session: TrackSession) -> Dictionary:
	if not session.finished or samples.is_empty(): return {}
	return {"schema":"bmt-race-proof-v1","samples":samples.duplicate()}

func branch(tick: int, session: TrackSession) -> void:
	while not samples.is_empty() and int(samples[-1][0]) > tick: samples.pop_back()
	_laps = session.completed_laps
