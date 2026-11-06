extends SceneTree
func _initialize() -> void:
	var folder: String = "res://../docs/evidence/volt-night-glass-shape-2026-11-06/"
	var before := Image.load_from_file(folder+"before/game/assets/garage/previews_v1/compact.png")
	var initial := Image.load_from_file(folder+"picture-variance/compact.png")
	var current := Image.load_from_file("res://assets/garage/previews_v1/compact.png")
	var comparisons: Array[Dictionary] = []
	for image: Image in [initial,current]:
		var count: int = 0
		var maximum: float = 0.0
		var samples: Array[Dictionary] = []
		for y: int in range(before.get_height()):
			for x: int in range(before.get_width()):
				var a: Color = before.get_pixel(x,y)
				var b: Color = image.get_pixel(x,y)
				if a == b: continue
				count += 1
				maximum = maxf(maximum,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
				if samples.size() < 12: samples.append({"x":x,"y":y,"before":str(a),"after":str(b)})
		comparisons.append({"changed":count,"maximum_255":maximum*255.0,"samples":samples})
	FileAccess.open(OS.get_environment("BMT_VOLT_GLASS_OUTPUT").path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(comparisons,"\t"))
	print("COMPACT_CAPTURE_VARIANCE ",JSON.stringify(comparisons))
	quit()
