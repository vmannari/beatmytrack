extends Node
const EVIDENCE = preload("res://race/attempt_evidence.gd")
## Completed recordings belong to this service, independently of race/menu nodes.
signal changed
signal saved(ticket_id: String)
const MAX_FRAMES: int = 432000
const MAX_JOBS: int = 16
const MAX_BYTES: int = 160 * 1024 * 1024
# One encoder (UTF-16/UTF-8, normalized ghost and compression), plus the
# bounded wire packet retained by an in-flight upload. Inputs/proofs are separate.
const ENCODER_BYTES: int = 96 * 1024 * 1024
const ATTEMPT_BYTES: int = 40 * 1024 * 1024
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
	return jobs.size() < MAX_JOBS and frames_held() <= MAX_FRAMES-EVIDENCE.MAX_INPUTS and bytes_held()+ENCODER_BYTES+ATTEMPT_BYTES <= MAX_BYTES

func bytes_held() -> int:
	var total: int = 0
	for entry: Dictionary in jobs.values(): total += int(entry.bytes)
	return total

func enqueue(ticket: Dictionary, frames: Variant, publish: String, rewinds: Array) -> bool:
	var id: String = str(ticket.get("ticket_id",""))
	if id.is_empty() or frames.is_empty() or frames.size() > EVIDENCE.MAX_INPUTS: return false
	if jobs.has(id):
		var existing: Dictionary = jobs[id]
		return existing.frames == frames and existing.rewinds == rewinds and existing.packet.proof == ticket.get("_race_proof",{}) and existing.packet.ghost == ticket.get("_race_ghost",{}) and existing.ticket.get("_owner_id","") == ticket.get("_owner_id","") and existing.ticket.get("_origin","") == ticket.get("_origin","")
	if jobs.size() >= MAX_JOBS or frames_held()+frames.size() > MAX_FRAMES: return false
	var metadata: Dictionary = ticket.duplicate()
	var packet: RefCounted = preload("res://backend/completed_evidence.gd").capture(frames,rewinds,metadata.get("_race_proof",{}),metadata.get("_race_ghost",{}),metadata.get("_race_ghost_source"))
	metadata.erase("_race_proof"); metadata.erase("_race_ghost"); metadata.erase("_race_ghost_source")
	metadata = metadata.duplicate(true)
	var held: int = packet.bytes+JSON.stringify(metadata).length()*4+1024
	if held > ATTEMPT_BYTES or bytes_held()+held+ENCODER_BYTES > MAX_BYTES: return false
	metadata["_evidence"] = packet
	jobs[id] = {"ticket":metadata,"frames":packet.frames,"packet":packet,"bytes":held,
		"publish":publish,"rewinds":packet.rewinds,"retry_at":0,"error":""}
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
