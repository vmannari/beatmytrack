extends SceneTree
## Explicit unscored source-discovery benchmark; no player records or services.
func _initialize() -> void: run.call_deferred()

func quantiles(samples: Array[float]) -> Dictionary:
	samples.sort()
	return {"median_us":samples[samples.size()/2],"p95_us":samples[int(samples.size()*0.95)],"max_us":samples.back()}

func run() -> void:
	var document: Dictionary = TrackLibrary.new().load_document("track_3e26605a8a90165e")
	assert(not document.is_empty())
	var track: NativeTrack = TrackCompiler.compile(document)
	var fx := DesertSandWind.new()
	root.add_child(fx)
	fx.configure(track)
	var samples: Array[float] = []
	var queries: int = 0
	for lap: int in range(3):
		for index: int in range(240):
			var focus: Vector2 = track.route[index*track.route.size()/240]
			var started: int = Time.get_ticks_usec()
			fx._prepare_crests(focus)
			samples.append(float(Time.get_ticks_usec()-started))
			queries += fx.source_samples
	var result: Dictionary = quantiles(samples)
	result.calls = samples.size()
	result.logical_source_samples = queries
	print("DESERT_WIND_LOOKUP ", JSON.stringify(result))
	var folder: String = "res://../docs/evidence/desert-phone-performance-2026-10-25/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var out := FileAccess.open(folder+"lookup-current.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(result,"\t")); out.close()
	fx.free()
	quit()
