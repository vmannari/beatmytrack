extends SceneTree
func _initialize() -> void:
	var base: String = "res://../docs/evidence/challenger-panels-2026-11-12/"
	var controls: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base+"pictures-immediately-before-refresh.json"))
	var results: Dictionary = {}; var exact: int = 0
	for path: String in controls:
		var a: Image = Image.load_from_file(base+"pictures-immediately-before-refresh/"+path)
		var b: Image = Image.load_from_file("res://../"+path)
		assert(a != null and b != null and a.get_size()==b.get_size())
		a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
		var aa: PackedByteArray = a.get_data();var bb: PackedByteArray = b.get_data()
		var pixels: int = 0;var largest: int = 0
		if aa != bb:
			for i: int in range(0,aa.size(),4):
				var changed: bool = false
				for channel: int in range(4):
					var delta: int = absi(aa[i+channel]-bb[i+channel]);largest = maxi(largest,delta);changed = changed or delta>0
				if changed:pixels += 1
		var same: bool = FileAccess.get_sha256("res://../"+path)==controls[path]
		if same:exact += 1
		results[path] = {"byte_exact":same,"changed_pixels":pixels,"max_channel_delta":largest,"size":str(a.get_size())}
	var file := FileAccess.open(base+"picture-control-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"exact":exact,"total":controls.size(),"pictures":results},"\t"));file.close()
	print("CHALLENGER_PICTURE_CONTROLS: ",exact,"/",controls.size()," byte exact; measured native differences retained")
	quit()
