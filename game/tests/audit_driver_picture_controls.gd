extends SceneTree
## Compare unrelated thumbnail bytes before/after the scoped driver revision.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var output: Dictionary = {}
	var prefix: String = "res://../docs/evidence/kart-driver-fit-style-2026-11-08"
	for id: String in ["compact","forklift","electric","hovercraft"]:
		var path: String = "game/assets/garage/previews_v1/"+id+".png"
		var old: Image = Image.load_from_file(ProjectSettings.globalize_path(prefix+"/before/"+path))
		var current: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/garage/previews_v1/"+id+".png"))
		assert(old.get_size() == current.get_size())
		old.convert(Image.FORMAT_RGBA8)
		current.convert(Image.FORMAT_RGBA8)
		var a: PackedByteArray = old.get_data()
		var b: PackedByteArray = current.get_data()
		var pixels: int = 0
		var peak: int = 0
		for offset: int in range(0,a.size(),4):
			var changed: bool = false
			for channel: int in range(4):
				var difference: int = absi(a[offset+channel]-b[offset+channel])
				changed = changed or difference != 0
				peak = maxi(peak,difference)
			if changed: pixels += 1
		output[id] = {"changed_pixels":pixels,"maximum_channel_difference":peak}
	FileAccess.open(prefix+"/picture-pixel-controls.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("DRIVER_PICTURE_CONTROLS ",JSON.stringify(output))
	quit()
