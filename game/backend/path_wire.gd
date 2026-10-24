extends RefCounted
## Exact position transport. Server decodes before hashing or verification.
const STRIDE: int = 21
const MAX_SAMPLES: int = 36012

static func encode(proof: Dictionary) -> Dictionary:
	if proof.get("schema") != "bmt-race-path-v1" or not proof.get("samples") is Array: return proof
	var samples: Array = proof.samples
	if samples.size() < 2 or samples.size() > MAX_SAMPLES: return proof
	var body := PackedByteArray()
	body.resize(samples.size()*STRIDE)
	for index: int in range(samples.size()):
		var row: Array = samples[index]
		if row.size() != 4: return proof
		var integers: int = 0
		for component: int in [1,2]:
			if row[component] is int:
				if int(row[component]) < -9007199254740992 or int(row[component]) > 9007199254740992: return proof
				integers |= 1 << (component-1)
		var offset: int = index*STRIDE
		body.encode_u32(offset,int(row[0]))
		body.encode_double(offset+4,float(row[1]))
		body.encode_double(offset+12,float(row[2]))
		body[offset+20] = int(row[3]) | (integers << 1)
	var result: Dictionary = {"schema":"bmt-packed-path-v1","count":samples.size(),"data":Marshalls.raw_to_base64(body)}
	if proof.has("incidents"): result.incidents = proof.incidents
	return result
