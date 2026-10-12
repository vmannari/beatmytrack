extends SceneTree
## Original offline density/warp/grain field, not a colour image or simulation.
func _initialize() -> void:
	var fields: Array[Image] = []
	for channel: int in range(3):
		var noise := FastNoiseLite.new()
		noise.seed = [71041, 38172, 98123][channel]
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = [0.012, 0.008, 0.34][channel]
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = [2, 2, 2][channel]
		noise.fractal_gain = 0.48
		fields.append(noise.get_seamless_image(256, 256))
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y: int in range(256):
		for x: int in range(256):
			image.set_pixel(x, y, Color(fields[0].get_pixel(x, y).r, fields[1].get_pixel(x, y).r, fields[2].get_pixel(x, y).r))
	var error: Error = image.save_png("res://assets/textures/winter_wind_flow_v1.png")
	print("WINTER_FLOW_BAKE: 256x256 original seamless RGB density/warp/grain, error=", error)
	quit(0 if error == OK else 1)
