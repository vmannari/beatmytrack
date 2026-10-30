extends SceneTree
## Read native capture pixels; never modify image files.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var base: String = "res://../docs/evidence/electric-design-pass-2026-10-26"
	var report: Dictionary = {}
	for stage: String in ["before","after"]:
		var colours: Dictionary = {}
		for renderer: String in ["native","desktop-mobile"]:
			var path: String = base+"/before-glass-colour-fix/"+renderer+"-front-quarter.png" if stage=="before" else base+"/"+renderer+"/full-front-quarter.png"
			var picture: Image = Image.load_from_file(path)
			assert(picture!=null and picture.get_size()==Vector2i(1440,900))
			var colour := Vector3.ZERO
			for x: int in range(-2,3):
				for y: int in range(-2,3):
					var pixel: Color = picture.get_pixel(650+x,390+y)
					colour += Vector3(pixel.r,pixel.g,pixel.b)/25.0
			colours[renderer] = [colour.x*255,colour.y*255,colour.z*255]
		report[stage] = colours
	FileAccess.open(base+"/glass-colour-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("EV_GLASS_COLOUR ",JSON.stringify(report))
	quit()
