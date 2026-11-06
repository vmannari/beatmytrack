extends SceneTree
## Compare every changed pixel in the retained Mobile mask controls.
func _initialize() -> void:
	var path: String = "res://../docs/evidence/volt-night-windows-2026-11-06/"
	var comparisons: Array[Dictionary] = []
	var failures: int = 0
	for quality: String in ["full", "simple"]:
		for heading: int in [0,90,180,270]:
			for part: String in ["windows", "roof"]:
				var name: String = quality+"-heading-"+str(heading)
				var differences: Array[Dictionary] = []
				for version: String in ["mobile-before-control", "final-mobile"]:
					var a := Image.load_from_file(path+version+"/"+name+"-after.png")
					var b := Image.load_from_file(path+version+"/"+name+"-"+part+"-restored.png")
					assert(a != null and b != null and a.get_size() == b.get_size())
					var changed: Dictionary = {}
					for y: int in range(a.get_height()):
						for x: int in range(a.get_width()):
							var left: Color = a.get_pixel(x,y)
							var right: Color = b.get_pixel(x,y)
							if left != right: changed[Vector2i(x,y)] = [left, right]
					differences.append(changed)
				var equal: bool = differences[0] == differences[1]
				if not equal: failures += 1
				comparisons.append({"view":name, "part":part, "before_changed":differences[0].size(), "final_changed":differences[1].size(), "all_coordinates_and_colours_equal":equal})
	FileAccess.open(OS.get_environment("BMT_VOLT_GLASS_OUTPUT").path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":comparisons.size(),"failures":failures,"comparisons":comparisons},"\t"))
	print("MOBILE_WINDOW_CONTROLS: %d comparisons, %d failures" % [comparisons.size(), failures])
	quit(1 if failures else 0)
