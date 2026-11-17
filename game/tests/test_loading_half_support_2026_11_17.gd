extends SceneTree
## Exact numeric round trips and rejection controls for the private prototype.
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	assert(ok,label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cache: Script = load("res://track/road_support_cache.gd")
	var key: String = "support/1/review-round-trip"
	var value: Dictionary = {"floors":[PackedVector2Array([Vector2(-2,3),Vector2(0,5),Vector2(2,3)])],"bins":{Vector2i(0,0):[0]}}
	var encoded: PackedByteArray = var_to_bytes(value)
	cache.write(key,value,cache.generation)
	check(cache.bytes_used() <= cache.MAX_BYTES,"existing resident memory bound")
	cache.trim()
	var hits: int = cache.review_disk_hits
	var restored: Dictionary = cache.read(key)
	check(restored.value is Dictionary,"numeric support restored")
	check(var_to_bytes(restored.value) == encoded,"ordered encoded contours and bins exact")
	check(cache.review_disk_hits == hits+1,"restore is an actual disk hit")
	var path: String = "user://cache/support-prototype/"+key.sha256_text()+".support"
	var file := FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	var original: Dictionary = file.get_var(false)
	file.close()
	for field: String in ["source","sha","key"]:
		var packet: Dictionary = original.duplicate(true)
		packet[field] = "rejected-control"
		file = FileAccess.open_compressed(path,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
		file.store_var(packet,false); file.close()
		cache.trim()
		check(cache.read(key).value == null,"reject mismatched "+field)
	file = FileAccess.open_compressed(path,FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	file.store_var(original,false); file.close()
	cache.trim()
	check(var_to_bytes(cache.read(key).value) == encoded,"valid packet restores after rejected controls")
	var before: int = cache.bytes_used()
	cache.write("stale-worker",value,cache.generation-1)
	check(cache.bytes_used() == before,"stale generation cannot repopulate resident cache")
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":0}))
	print("SUPPORT_PROTOTYPE ",checks," checks, 0 failures")
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	for frame: int in range(12): await process_frame
	quit()
