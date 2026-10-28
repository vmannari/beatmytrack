extends RefCounted
## A finished attempt has one sealed evidence owner and one compact input snapshot;
## restarting Game cannot mutate that snapshot. Tickets contain metadata only.
var frames: Variant
var rewinds: Array
var proof: Dictionary
var ghost: Dictionary
var ghost_source: RefCounted
var bytes: int = 0

static func capture(inputs: Variant, branches: Array, trajectory: Dictionary = {}, poses: Dictionary = {}, source: RefCounted = null) -> RefCounted:
	var packet = load("res://backend/completed_evidence.gd").new()
	packet.frames = inputs.duplicate() if inputs is PackedInt64Array else inputs.duplicate(true)
	packet.rewinds = branches.duplicate(true)
	packet.proof = trajectory
	packet.ghost = poses
	packet.ghost_source = source
	# Fixed-channel recording domains permit constant-time conservative accounting.
	# Do not walk tens of thousands of sample rows in the finish UI callback.
	packet.bytes = 1024+(inputs.size()*8 if inputs is PackedInt64Array else inputs.size()*512)
	packet.bytes += trajectory.get("samples",[]).size()*512+poses.get("poses",[]).size()*512
	if source != null: packet.bytes += source.poses.size()*512+1024
	packet.bytes += JSON.stringify(branches).length()*4+JSON.stringify(trajectory.get("incidents",{})).length()*4
	packet.rewinds.make_read_only()
	for value: Dictionary in [packet.proof,packet.ghost]:
		for key: String in ["samples","poses"]:
			if value.get(key) is Array: value[key].make_read_only()
		value.make_read_only()
	return packet

func seal_rows() -> void:
	# Existing sample rows never change after capture. Seal their shared scalar
	# rows on the owned save worker, before encoding; Game only appends/branches
	# its separate outer arrays and clears them on restart.
	_seal_and_measure(proof)
	_seal_and_measure(ghost)
	if ghost_source != null: _seal_and_measure(ghost_source.poses)

static func _seal_and_measure(value: Variant) -> int:
	if value is PackedInt64Array: return 64+value.size()*8
	if value is Array:
		var bytes: int = 128+value.size()*32
		for item: Variant in value: bytes += _seal_and_measure(item)
		value.make_read_only()
		return bytes
	if value is Dictionary:
		var bytes: int = 128+value.size()*128
		for key: Variant in value:
			bytes += _seal_and_measure(key)+_seal_and_measure(value[key])
		value.make_read_only()
		return bytes
	if value is String: return 32+value.length()*4
	return 16
