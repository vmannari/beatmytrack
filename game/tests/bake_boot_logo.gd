extends SceneTree
## Godot's early boot splash accepts PNG only. Derive it from the shared SVG.

static func render() -> Image:
	var artwork := Image.new()
	var error: Error = artwork.load_svg_from_string(FileAccess.get_file_as_string("res://assets/menu/logo.svg"), 2.0)
	assert(error == OK)
	var height: int = roundi(artwork.get_height() * 640.0 / artwork.get_width())
	artwork.resize(640, height, Image.INTERPOLATE_LANCZOS)
	var splash := Image.create(640, 225, false, Image.FORMAT_RGBA8)
	splash.fill(Color.TRANSPARENT)
	splash.blit_rect(artwork, Rect2i(Vector2i.ZERO, artwork.get_size()), Vector2i(0, (225 - height) / 2))
	return splash

func _initialize() -> void:
	var splash: Image = render()
	var error: Error = splash.save_png("res://assets/menu/boot_logo.png")
	print("BOOT_LOGO_BAKE: ", JSON.stringify({"source":"res://assets/menu/logo.svg", "size":str(splash.get_size()), "bounds":str(splash.get_used_rect()), "error":error}))
	quit(0 if error == OK else 1)
