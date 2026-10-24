extends "res://tests/test_editor_t01_t04.gd"
func summary(part: Dictionary) -> Dictionary:
	return {"key":part.mesh_key,"role":part.role,"tile":str(part.tile),"args":part.get("arguments",[]),"vertices":part.arrays[0].size()}
func run() -> void:
	var doc: Dictionary = circuit()
	var before: NativeTrack = TrackCompiler.compile(doc)
	var original: Dictionary = await packet(before)
	doc.pieces[0].width = 10.0
	var after: NativeTrack = TrackCompiler.compile(doc)
	var patch: Dictionary = await packet(after,before)
	var full: Dictionary = await packet(after)
	var merged: Array = original.parts.filter(func(part: Dictionary) -> bool: return not patch.dirty_tiles.has(part.tile))+patch.parts
	var merged_keys: Array = []; var expected_keys: Array = []
	for part: Dictionary in merged: merged_keys.append(part.mesh_key)
	for part: Dictionary in full.parts: expected_keys.append(part.mesh_key)
	var extra: Array = []; var missing: Array = []
	for part: Dictionary in merged:
		if not expected_keys.has(part.mesh_key): extra.append(summary(part))
	for part: Dictionary in full.parts:
		if not merged_keys.has(part.mesh_key): missing.append(summary(part))
	print("TILE_DIAGNOSTIC ",JSON.stringify({"dirty":str(patch.dirty_tiles),"extra":extra,"missing":missing}))
	quit()
