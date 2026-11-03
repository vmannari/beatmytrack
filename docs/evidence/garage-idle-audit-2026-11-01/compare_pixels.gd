extends SceneTree
func _initialize() -> void:
	var base: String = "res://../docs/evidence/garage-idle-audit-2026-11-01/diagnostic/gl_compatibility/"
	for pair: Array in [["room-retained.png","room-forced.png"],["snow-retained-compact.png","snow-compact.png"]]:
		var a: Image = Image.load_from_file(base+pair[0])
		var b: Image = Image.load_from_file(base+pair[1])
		if a == null or b == null: continue
		var changed: int = 0
		var peak: float = 0.0
		var sum: float = 0.0
		var box := Rect2i()
		for y: int in range(a.get_height()):
			for x: int in range(a.get_width()):
				var d: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
				var value: float = maxf(absf(d.r),maxf(absf(d.g),absf(d.b)))*255
				if value == 0: continue
				box = Rect2i(x,y,1,1) if changed == 0 else box.merge(Rect2i(x,y,1,1))
				changed += 1
				peak = maxf(peak,value)
				sum += absf(d.r)+absf(d.g)+absf(d.b)
		print("PIXEL_DIFF ",pair," ",{"changed":changed,"peak":peak,"mean_255":sum*255/(a.get_width()*a.get_height()*3),"bounds":box})
	quit()
