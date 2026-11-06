extends SceneTree
func _initialize() -> void:
	var path: String = "res://../docs/evidence/volt-night-roof-fix-2026-11-06/final-compatibility"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): path = argument.trim_prefix("--source=")
	var names: Array[String] = ["full-day","full-studio","simple-day","simple-studio"]
	for quality: String in ["full","simple"]:
		for heading: int in [0,90,180,270]: names.append(quality+"-heading-"+str(heading))
	for name: String in names:
		var restore: bool = "heading" in name
		var before: Image = Image.load_from_file(path.path_join(name+("-after.png" if restore else "-before.png")))
		var after: Image = Image.load_from_file(path.path_join(name+("-restored.png" if restore else "-after.png")))
		var pixels: int = 0
		var maximum: float = 0
		var total: float = 0
		var samples: Array = []
		for y: int in range(before.get_height()):
			for x: int in range(before.get_width()):
				var a: Color = before.get_pixel(x,y)
				var b: Color = after.get_pixel(x,y)
				var delta: Color = a-b
				var size: float = maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b)))
				maximum = maxf(maximum,size)
				total += absf(delta.r)+absf(delta.g)+absf(delta.b)
				if size > 0:
					pixels += 1
					if samples.size()<12: samples.append({"x":x,"y":y,"before":str(a),"after":str(b)})
		print("PIXELS ",name," ",JSON.stringify({"changed":pixels,"max_255":maximum*255.0,"mean_255":total*255.0/(before.get_width()*before.get_height()*3),"samples":samples}))
	quit()
