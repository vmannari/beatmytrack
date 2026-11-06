extends SceneTree
## Inspect roof-only variation using the retained identical-camera roof masks.
func _initialize() -> void:
	var base: String = "res://../docs/evidence/volt-night-glass-shape-2026-11-06/prototype-reflection/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): base = argument.trim_prefix("--source=")+"/"
	var masks: String = "res://../docs/evidence/volt-night-windows-2026-11-06/final-compatibility/"
	var results: Array[Dictionary] = []
	var failures: int = 0
	for quality: String in ["full","simple"]:
		for heading: int in [0,90,180,270]:
			var name: String = quality+"-heading-"+str(heading)
			var black := Image.load_from_file(masks+name+"-roof-black.png")
			var white := Image.load_from_file(masks+name+"-roof-white.png")
			var canopy_black := Image.load_from_file(base+name+"-canopy-black.png")
			var canopy_white := Image.load_from_file(base+name+"-canopy-white.png")
			var before := Image.load_from_file(base+name+"-before.png")
			var after := Image.load_from_file(base+name+"-after.png")
			var old_colours: Dictionary = {}
			var new_colours: Dictionary = {}
			var inside: int = 0
			var outside: int = 0
			for y: int in range(after.get_height()):
				for x: int in range(after.get_width()):
					if white.get_pixel(x,y).r-black.get_pixel(x,y).r < 0.95: continue
					if canopy_white.get_pixel(x,y).r-canopy_black.get_pixel(x,y).r < 0.95: outside += 1
					else: inside += 1
					old_colours[before.get_pixel(x,y).to_rgba32()] = true
					new_colours[after.get_pixel(x,y).to_rgba32()] = true
			var ok: bool = inside > 10000 and outside == 0 and new_colours.size() > old_colours.size()
			if not ok: failures += 1
			results.append({"view":name,"roof_pixels":inside,"mask_outside_canopy":outside,"before_colours":old_colours.size(),"after_colours":new_colours.size(),"pass":ok})
	FileAccess.open(OS.get_environment("BMT_VOLT_GLASS_OUTPUT").path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"\t"))
	print("ROOF_SHAPE ",JSON.stringify(results))
	quit(1 if failures else 0)
