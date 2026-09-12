class_name RaceDebrief
extends RefCounted
## Feedback uses the same integer-millisecond comparison as local records.

static func feedback(total: float, previous: float, clean: bool, saved: bool, editor: bool) -> Dictionary:
	if editor: return {"title":"TEST DRIVE COMPLETE","detail":"Return to your circuit to refine it, or drive it again."}
	if not clean: return {"title":"PRACTICE COMPLETE","detail":"This run was paused. Your personal best is unchanged."}
	if not saved: return {"title":"TIME NOT SAVED","detail":"Check storage space. Your previous personal best is unchanged."}
	if previous <= 0.0: return {"title":"FIRST TIME SET","detail":"Your benchmark is set. The next run is yours to improve."}
	var delta: int = roundi(total*1000.0)-roundi(previous*1000.0)
	if delta < 0: return {"title":"PERSONAL BEST","detail":"%.3f s faster than your previous best." % (-delta/1000.0)}
	if delta == 0: return {"title":"MATCHED YOUR BEST","detail":"The same time to the millisecond. Go for the improvement."}
	return {"title":"RACE COMPLETE","detail":"+%.3f s off your personal best." % (delta/1000.0)}
