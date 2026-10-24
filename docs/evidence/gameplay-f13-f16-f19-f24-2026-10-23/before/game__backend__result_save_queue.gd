extends Node
## Completed recordings belong to this service, independently of race/menu nodes.
signal changed
signal saved(ticket_id: String)
const MAX_FRAMES: int = 432000
const MAX_JOBS: int = 16
var sink: Callable
var jobs: Dictionary = {}
var saving: bool = false
var retry_delay_msec: int = 15000

func frames_held() -> int:
	var count: int = 0
	for entry: Dictionary in jobs.values(): count += entry.frames.size()
	return count

func can_start_attempt() -> bool:
	# Reserve room for one maximum recording; ordinary offline racing is unaffected.
	return jobs.size() < MAX_JOBS and frames_held() <= MAX_FRAMES-216000

func enqueue(ticket: Dictionary, frames: Array, publish: String, rewinds: Array) -> bool:
	var id: String = str(ticket.get("ticket_id",""))
	if id.is_empty() or frames.is_empty() or frames.size() > 216000: return false
	if jobs.has(id): return jobs[id].frames == frames and jobs[id].rewinds == rewinds
	if jobs.size() >= MAX_JOBS or frames_held()+frames.size() > MAX_FRAMES: return false
	# Canonical input frames are immutable once recorded. Copy the outer list so
	# clearing/freeing the game cannot remove them; avoid deep-copying on a UI frame.
	jobs[id] = {"ticket":ticket.duplicate(true),"frames":frames.duplicate(),
		"publish":publish,"rewinds":rewinds.duplicate(true),"retry_at":0,"error":""}
	changed.emit()
	_pump.call_deferred()
	return true

func retry(id: String) -> void:
	if jobs.has(id):
		jobs[id].retry_at = 0
		_pump.call_deferred()

func _process(_delta: float) -> void:
	if not saving and not jobs.is_empty(): _pump()

func _pump() -> void:
	if saving or not sink.is_valid(): return
	for id: String in jobs.keys():
		if Time.get_ticks_msec() < int(jobs[id].retry_at): continue
		var entry: Dictionary = jobs[id]
		saving = true
		var success: bool = await sink.call(entry.ticket,entry.frames,entry.publish,entry.rewinds)
		saving = false
		if success:
			jobs.erase(id)
			saved.emit(id)
		else:
			entry.error = "Result is waiting for storage. Free space, then retry. Keep the app open."
			entry.retry_at = Time.get_ticks_msec()+retry_delay_msec
		changed.emit()
		return
