extends RefCounted
## Original Garage glyphs: one 64-unit optical grid and rounded 3-unit strokes.
static var cache: Dictionary = {}

static func texture(mode: String) -> Texture2D:
	if cache.has(mode): return cache[mode]
	var art: String = ""
	match mode:
		"news":
			# Open newspaper with a folded outer sheet and two clear article columns.
			art = "<path d='M46 22h9v26a5 5 0 0 1-5 5H15a5 5 0 0 1-5-5V11h36v37a5 5 0 0 0 5 5'/><path d='M19 20h18M34 29h4M34 35h4M19 42h19'/><rect x='19' y='28' width='8' height='8' rx='1' fill='white' stroke='none'/>"
		"cars":
			# Low bonnet, swept cabin and independent wheels read as a car at rail size.
			art = "<path d='M12 42H8V33q0-3 3-4l10-3 7-10q1.5-2 4-2h9q3 0 5 3l8 13 2 2q2 1 2 4v6h-7M39 42H25'/><path d='M21 26h31M36 15v11M9 34h5M53 34h4'/><circle cx='18.5' cy='42' r='6'/><circle cx='45' cy='42' r='6'/>"
		"customise":
			art = "<path d='M44 10a5 5 0 0 1 7 7L31 39l-9-9Z' fill='white' fill-opacity='.12'/><path d='m38 17 9 9M22 30l9 9'/><path d='M27 40c0 9-8 15-18 13 4-3 1-9 6-14 3-3 9-3 12 1Z' fill='white'/>"
		"care":
			art = "<path d='M28 9c-5 8-17 20-17 29a17 17 0 0 0 34 0c0-9-12-21-17-29Z' fill='white' fill-opacity='.12'/><path d='M19 38a9 9 0 0 0 9 9M48 8v14M41 15h14'/><circle cx='51' cy='34' r='3' fill='white' stroke='none'/>"
		"tuning":
			art = "<path d='M39 9a14 14 0 0 0-13 18L10 43a7 7 0 0 0 10 10l17-17a14 14 0 0 0 18-16L44 30l-10-3-3-10 9-8Z' fill='white' fill-opacity='.12'/><circle cx='16' cy='47' r='2' fill='white' stroke='none'/>"
		"trophies":
			art = "<path d='M19 11h26v13c0 11-6 17-13 17s-13-6-13-17Z' fill='white' fill-opacity='.12'/><path d='M19 17H9v6c0 8 5 13 14 14M45 17h10v6c0 8-5 13-14 14M32 41v12M22 54h20'/><path d='m32 19 2.2 4.4 4.8.7-3.5 3.4.8 4.8-4.3-2.2-4.3 2.2.8-4.8-3.5-3.4 4.8-.7Z' fill='white' stroke='none'/>"
		"records":
			# Beamed musical notes distinguish music from race records or a target.
			art = "<path d='M27 44V16l25-6v28M27 23l25-6'/><path d='M27 16l25-6v7l-25 6Z' fill='white' stroke='none'/><ellipse cx='19' cy='45' rx='8' ry='6' transform='rotate(-18 19 45)' fill='white' stroke='none'/><ellipse cx='44' cy='39' rx='8' ry='6' transform='rotate(-18 44 39)' fill='white' stroke='none'/>"
		_: return null
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><g fill='none' stroke='white' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % art
	var raster := Image.new()
	if raster.load_svg_from_string(svg,4.0) != OK: return null
	raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[mode] = result
	return result
