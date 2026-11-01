extends SceneTree
## Reports RGB changes and alpha values; does not assert cross-renderer identity.
func _initialize() -> void:
	var folder := "res://../docs/evidence/renderer-comparison-2026-10-31/"
	var pairs: Array = [["compatibility repeat","gl_compatibility/star-0.png","gl_compatibility/star-1.png"],["mobile repeat","mobile/star-0.png","mobile/star-1.png"],["cross renderer first","gl_compatibility/star-0.png","mobile/star-0.png"],["cross renderer repeat","gl_compatibility/star-1.png","mobile/star-1.png"]]
	var reports: Array = []
	for pair: Array in pairs:
		var a := Image.load_from_file(ProjectSettings.globalize_path(folder+pair[1]))
		var b := Image.load_from_file(ProjectSettings.globalize_path(folder+pair[2]))
		if a == null or b == null or a.get_size() != b.get_size(): push_error("Missing or mismatched images"); quit(1); return
		a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
		var aa: PackedByteArray = a.get_data(); var bb: PackedByteArray = b.get_data()
		var sum: int = 0; var changed: int = 0; var changed_over_two: int = 0
		var alpha_a: Dictionary = {}; var alpha_b: Dictionary = {}
		var top_left_sum: int = 0; var bottom_right_sum: int = 0
		for y: int in range(a.get_height()):
			for x: int in range(a.get_width()):
				var offset: int = (y*a.get_width()+x)*4
				var delta: int = 0; var max_delta: int = 0
				for channel: int in range(3):
					var d: int = absi(int(aa[offset+channel])-int(bb[offset+channel]))
					delta += d; max_delta = maxi(max_delta,d)
				sum += delta
				if max_delta > 0: changed += 1
				if max_delta > 2: changed_over_two += 1
				alpha_a[aa[offset+3]] = true; alpha_b[bb[offset+3]] = true
				if x < 320 and y < 180: top_left_sum += delta
				if x >= 960 and y >= 540: bottom_right_sum += delta
		var pixels: int = a.get_width()*a.get_height()
		var report: Dictionary = {"label":pair[0],"pixels":pixels,"changed_rgb_pixels":changed,"pixels_over_2_rgb":changed_over_two,"mean_abs_rgb":float(sum)/(pixels*3),"mean_abs_rgb_top_left_320x180":float(top_left_sum)/(320*180*3),"mean_abs_rgb_bottom_right_320x180":float(bottom_right_sum)/(320*180*3),"alpha_values_a":alpha_a.keys(),"alpha_values_b":alpha_b.keys()}
		reports.append(report); print("CAPTURE_DIFF ",JSON.stringify(report))
	var file := FileAccess.open(folder+"capture-differences.json",FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify(reports,"  ")); file.close()
	quit()
