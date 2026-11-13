extends SceneTree
func _initialize() -> void:
	var folder: String = "res://../docs/evidence/challenger-hellcat-2026-11-09/opaque/mobile/"
	for view: String in ["front","rear","side"]:
		var a: Image = Image.load_from_file(folder+"simple-"+view+".png")
		var b: Image = Image.load_from_file(folder+"simple-"+view+"-probe.png")
		var low := Vector2i(9999,9999); var high := Vector2i.ZERO; var count: int = 0
		for y: int in range(a.get_height()):
			for x: int in range(a.get_width()):
				if a.get_pixel(x,y) != b.get_pixel(x,y):
					count += 1
					if count < 8: print("PIXEL ",view," ",Vector2i(x,y)," ",a.get_pixel(x,y)," -> ",b.get_pixel(x,y))
					low = low.min(Vector2i(x,y)); high = high.max(Vector2i(x,y))
		print("DIFF ",view," ",count," ",low," ",high)
	quit()
