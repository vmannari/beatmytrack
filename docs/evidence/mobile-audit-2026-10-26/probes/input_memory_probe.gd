extends SceneTree
const Evidence = preload("res://race/attempt_evidence.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var frame := DriveFrame.sample(0.1,1.0,0.0)
	for count: int in [3600,18000,216000]:
		var evidence := Evidence.new()
		var frames: Array = []
		var before: int = Performance.get_monitor(Performance.MEMORY_STATIC)
		var start: int = Time.get_ticks_usec()
		for index: int in range(count): evidence.append_input(frames,frame)
		var end: int = Time.get_ticks_usec()
		var retained: int = Performance.get_monitor(Performance.MEMORY_STATIC)-before
		var encoded: String = JSON.stringify({"frames":frames,"rewinds":[]})
		print("INPUT_MEMORY ",JSON.stringify({"frames":count,"recorded_seconds":count/120.0,"retained_bytes":retained,"allocation_ms":(end-start)/1000.0,"json_bytes":encoded.to_utf8_buffer().size(),"encoding_ms":(Time.get_ticks_usec()-end)/1000.0}))
		frames.clear()
	quit()
