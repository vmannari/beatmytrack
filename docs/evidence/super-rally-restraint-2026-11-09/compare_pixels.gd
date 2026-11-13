extends SceneTree
## Read-only comparison of identical native review views.
func _initialize() -> void:
	var folder: String = "res://../docs/evidence/super-rally-restraint-2026-11-09"
	var result: Dictionary = {}
	for view: String in ["front","rear","side","overhead"]:
		var a: Image = Image.load_from_file(folder.path_join("before/gl_compatibility/"+view+".png"))
		var b: Image = Image.load_from_file(folder.path_join("final/gl_compatibility/"+view+".png"))
		var area := Rect2i(0,40,530,440)
		var exact: bool = a.get_region(area).get_data() == b.get_region(area).get_data()
		result[view] = {"normal_rally_pixels_exact":exact}
		assert(exact,"Normal Rally pixels changed in "+view)
	var file := FileAccess.open(folder.path_join("normal-rally-pixels.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("NORMAL_RALLY_PIXELS: all four native views exact")
	quit()
