extends SceneTree
func _initialize() -> void:
	var results: Dictionary = {}
	for id: String in ["compact","kart","forklift","electric","hovercraft","super_rally"]:
		var a: Image = Image.load_from_file("res://assets/garage/previews_v1/"+id+".png")
		var b: Image = Image.load_from_file("res://../docs/evidence/challenger-quality-2026-11-12/preview-repeat/"+id+".png")
		a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
		assert(a.get_size()==b.get_size())
		var aa: PackedByteArray = a.get_data(); var bb: PackedByteArray = b.get_data()
		var changed: int = 0; var maximum: int = 0; var total: int = 0
		for pixel: int in range(a.get_width()*a.get_height()):
			var different: bool = false
			for channel: int in range(4):
				var difference: int = absi(aa[pixel*4+channel]-bb[pixel*4+channel])
				different = different or difference>0; maximum = maxi(maximum,difference); total += difference
			if different: changed += 1
		results[id] = {"changed_pixels":changed,"total_pixels":a.get_width()*a.get_height(),"max_channel_difference":maximum,"sum_absolute_channel_difference":total}
		print("PREVIEW_REPEAT_PIXELS ",id," ",JSON.stringify(results[id]))
	var out := FileAccess.open("res://../docs/evidence/challenger-quality-2026-11-12/preview-repeat-pixels.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(results,"\t"));out.close();quit()
