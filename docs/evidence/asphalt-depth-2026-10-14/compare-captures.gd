extends SceneTree
func _initialize() -> void:
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/asphalt-depth-2026-10-14/")
	var metrics: Array = []
	for renderer: String in ["gl_compatibility","mobile"]:
		for theme: String in ["pine","storm","winter","desert"]:
			for view: String in ["overhead","seam"]:
				var name: String = theme+"-"+view+".png"
				var a := Image.load_from_file(folder+"before/"+renderer+"/"+name)
				var b := Image.load_from_file(folder+"final/"+renderer+"/"+name)
				a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
				var first: PackedByteArray = a.get_data(); var last: PackedByteArray = b.get_data()
				var count: int = 0; var maximum: int = 0
				for i: int in range(0,first.size(),4):
					if first[i] != last[i] or first[i+1] != last[i+1] or first[i+2] != last[i+2]: count += 1
					for channel: int in range(3): maximum = maxi(maximum,absi(int(first[i+channel])-int(last[i+channel])))
				metrics.append({"renderer":renderer,"theme":theme,"view":view,"changed_pixels":count,"max_rgb_code_difference":maximum})
				print(renderer," ",theme," ",view,": ",count," pixels, max ",maximum)
	var file := FileAccess.open(folder+"capture-comparison.json",FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t")); file.close()
	quit()
