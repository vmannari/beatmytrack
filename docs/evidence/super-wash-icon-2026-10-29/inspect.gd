extends SceneTree

func _initialize() -> void:
	var report: Dictionary = {}
	var checks: int = 0
	for tool: String in ["mitt","hose","super"]:
		var tile: Button = preload("res://ui/garage_wash_tool.gd").make(tool,func() -> void: pass)
		root.add_child(tile)
		var texture: Texture2D = tile.photo.texture
		var picture: Image = texture.get_image()
		var original: Image = Image.load_from_file("res://assets/menu/garage/"+tool+"-v1.png")
		assert(texture is CompressedTexture2D)
		assert(maxi(picture.get_width(),picture.get_height()) <= 512)
		assert(picture.has_mipmaps())
		assert(original.detect_alpha() != Image.ALPHA_NONE)
		assert(tile.photo.modulate == Color.WHITE)
		checks += 5
		if tool == "super":
			assert(original.get_pixel(0,0).a <= 0.01)
			checks += 1
		report[tool] = {"source_size":[original.get_width(),original.get_height()],"imported_size":[picture.get_width(),picture.get_height()],"mipmaps":picture.has_mipmaps(),"alpha":original.detect_alpha(),"corner_alpha":original.get_pixel(0,0).a,"content_bounds":str(original.get_used_rect()),"tint":str(tile.photo.modulate)}
		tile.queue_free()
	var file := FileAccess.open("res://../docs/evidence/super-wash-icon-2026-10-29/images.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("SUPER_WASH_IMAGES: %d checks, 0 failures" % checks)
	quit(0)
