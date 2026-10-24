class_name TerrainUniformRegions
extends RefCounted
## Exact five-by-five homogeneous regions of the final presentation masks.

static func build(kinds: PackedByteArray, width: int, height: int, slots: Vector4i = Vector4i(-1,-1,-1,-1)) -> Dictionary:
	assert(width > 0 and height > 0 and kinds.size() == width*height)
	var horizontal := PackedByteArray()
	horizontal.resize(kinds.size())
	# A run needs two equal neighbours on either side. Clamp-to-edge runs
	# extend beyond the map, matching the original bilinear texture sampler.
	for y: int in range(height):
		var x: int = 0
		while x < width:
			var end: int = x+1
			while end < width and kinds[y*width+end] == kinds[y*width+x]: end += 1
			for column: int in range(x+2 if x > 0 else 0,end-2 if end < width else width): horizontal[y*width+column] = 1
			x = end
	var codes := PackedByteArray()
	codes.resize(kinds.size())
	var packed: bool = slots.x >= 0
	var eligible: int = 0
	for x: int in range(width):
		var y: int = 0
		while y < height:
			if horizontal[y*width+x] == 0:
				y += 1
				continue
			var end: int = y+1
			var kind: int = kinds[y*width+x]
			while end < height and horizontal[end*width+x] != 0 and kinds[end*width+x] == kind: end += 1
			var code: int = kind+1
			if packed:
				for channel: int in range(4):
					if slots[channel] == kind: code = channel+1; break
			for row: int in range(y+2 if y > 0 else 0,end-2 if end < height else height):
				codes[row*width+x] = code
				eligible += 1
			y = end
	return {"image":Image.create_from_data(width,height,false,Image.FORMAT_R8,codes),"eligible":eligible,"cells":kinds.size()}

static func bind(material: ShaderMaterial, high: Image, regions: Dictionary, high_present: bool) -> void:
	# Reuse an entirely absent weight channel. Every active weight byte and
	# its sampler coordinates/filtering remain untouched, including boundaries.
	var low: Image = (material.get_shader_parameter("surface_low") as Texture2D).get_image()
	var chosen: Image
	var channel: int = -1
	var in_low: bool = false
	for candidate: Image in [high,low]:
		var bytes: PackedByteArray = candidate.get_data()
		var used: Array[bool] = [false,false,false,false]
		for index: int in range(0,bytes.size(),4):
			for component: int in range(4):
				if bytes[index+component] != 0: used[component] = true
		for component: int in range(3,-1,-1):
			if not used[component]: channel = component; break
		if channel >= 0:
			chosen = candidate
			break
		in_low = true
	if chosen != null:
		var bytes: PackedByteArray = chosen.get_data()
		var codes: PackedByteArray = regions.image.get_data()
		for index: int in range(codes.size()): bytes[index*4+channel] = 255 if codes[index] != 0 else 0
		var image := Image.create_from_data(chosen.get_width(),chosen.get_height(),false,Image.FORMAT_RGBA8,bytes)
		material.set_shader_parameter("surface_low" if in_low else "surface_high",ImageTexture.create_from_image(image))
	material.set_shader_parameter("terrain_uniform_enabled",channel >= 0)
	material.set_shader_parameter("terrain_region_channel",channel)
	material.set_shader_parameter("terrain_region_low",in_low)
	material.set_meta("terrain_uniform_cells",regions.eligible if channel >= 0 else 0)
	material.set_meta("terrain_total_cells",regions.cells)
