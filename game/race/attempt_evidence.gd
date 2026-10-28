extends RefCounted
## Input offsets are monotonic across rewinds. Local driving has no time limit.
const MAX_INPUTS: int = 216000
const MAX_PROOF_SAMPLES: int = MAX_INPUTS / 6 + 32
const MAX_INCIDENTS: int = 8192
var overflow: bool = false

func append_input(frames: Variant, frame: DriveFrame) -> void:
	if overflow: return
	if frames.size() >= MAX_INPUTS:
		overflow = true
		return
	frames.append(preload("res://race/input_record.gd").pack(frame))

func eligible(proof: RefCounted) -> bool:
	return not overflow and not proof.overflow

func can_resume(frames: Variant, proof: RefCounted) -> bool:
	return eligible(proof) and frames.size() < MAX_INPUTS
