extends RefCounted
## Original solid navigation symbols. One optical grid, no decorative micro-details.
static var cache: Dictionary = {}

static func texture(mode: String) -> Texture2D:
	if cache.has(mode): return cache[mode]
	var art: String = ""
	match mode:
		"cars":
			art = "<path fill-rule='evenodd' d='M19 12h26l6 16h3v24h-7v5h-8v-5H25v5h-8v-5h-7V28h3Zm4 6-4 12h26l-4-12ZM16 36v6h10v-6Zm22 0v6h10v-6ZM27 45v3h10v-3Z'/>"
		"customise":
			art = "<path fill-rule='evenodd' d='M32 8C18 8 7 18 7 32s10 24 24 24h4c6 0 9-6 5-10-3-3-1-7 3-7h4c8 0 10-6 10-12C57 16 45 8 32 8ZM17 31a4 4 0 1 0 8 0 4 4 0 1 0-8 0Zm8-13a4 4 0 1 0 8 0 4 4 0 1 0-8 0Zm14 0a4 4 0 1 0 8 0 4 4 0 1 0-8 0Zm8 11a4 4 0 1 0 8 0 4 4 0 1 0-8 0Z'/>"
		"care":
			art = "<path d='M32 5c-3 5-9 10-9 16a9 9 0 0 0 18 0c0-6-6-11-9-16Z'/><path fill-rule='evenodd' d='M20 32h24l5 12h4v14h-8v-3H19v3h-8V44h4Zm4 4-3 8h22l-3-8ZM16 48v4h9v-4Zm23 0v4h9v-4Z'/>"
		"tuning":
			art = "<path fill-rule='evenodd' d='M45 7a14 14 0 0 0-17 16L10 41a8 8 0 0 0 13 10l16-17A14 14 0 0 0 57 16l-10 9-8-3-2-8ZM17 43a3 3 0 1 0 0 6 3 3 0 1 0 0-6Z'/>"
		"trophies":
			art = "<path fill-rule='evenodd' d='M19 9h26v6h11v9c0 9-6 15-15 16-2 3-4 5-6 6v6h11v6H18v-6h11v-6c-3-1-5-3-7-6C13 39 8 33 8 24v-9h11Zm-5 12v3c0 5 2 8 7 10-1-4-2-8-2-13Zm31 0c0 5-1 9-2 13 5-2 7-5 7-10v-3Z'/>"
		_: return null
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><g fill='white'>%s</g></svg>" % art
	var raster := Image.new()
	if raster.load_svg_from_string(svg,4.0) != OK: return null
	raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[mode] = result
	return result
