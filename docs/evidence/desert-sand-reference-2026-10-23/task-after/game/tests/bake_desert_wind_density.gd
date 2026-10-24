extends SceneTree
## Original offline scalar density, fine breakup and grain; no colour/reference pixels.
func _initialize() -> void:
	var fields: Array[Image] = []
	for channel: int in range(3):
		var noise := FastNoiseLite.new()
		noise.seed = [63143, 92381, 41773][channel]
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = [0.020, 0.065, 0.31][channel]
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = [4, 3, 2][channel]
		noise.fractal_gain = 0.52
		fields.append(noise.get_seamless_image(256, 256))
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y: int in range(256):
		for x: int in range(256):
			image.set_pixel(x, y, Color(fields[0].get_pixel(x, y).r, fields[1].get_pixel(x, y).r, fields[2].get_pixel(x, y).r))
	var error: Error = image.save_png("res://assets/textures/desert_wind_density_v1.png")
	print("DESERT_WIND_DENSITY: original seamless 256x256 RGB scalar field; error=", error)
	quit(0 if error == OK else 1)
