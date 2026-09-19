class_name MenuIcon
extends RefCounted
## Original, consistent vector navigation glyphs, rasterized once by Godot.

static var cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var paths: Dictionary = {
		"home":"<path d='M3 12 12 4l9 8M6 10v11h5v-7h3v7h4V10'/>",
		"tracks":"<path d='M5 21c-5-7 11-8 7-13C7 2 20 1 20 7c0 5-13 9-9 14Z'/>",
		"garage":"<path d='m5 9 2-5h10l2 5M3 16V9h18v7ZM5 16v4h3v-4m8 0v4h3v-4M6 12h2m8 0h2'/>",
		"create":"<path d='M12 3v18M3 12h18'/>",
		"settings":"<path d='M4 6h16M4 12h16M4 18h16'/><path d='M8 3v6m8 0v6M10 15v6' stroke-width='4'/>",
		"arrow":"<path d='M4 12h16m-7-7 7 7-7 7'/>",
		"surprise":"<path d='M5 19 19 5M7 5h12v12'/>",
		"star":"<path d='m12 2 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z'/>",
		"star_filled":"<path fill='white' d='m12 2 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z'/>",
		"heart":"<path d='M12 21 3 12C-2 4 8 1 12 7c4-6 14-3 9 5Z'/>",
		"flag":"<path d='M5 22V3m0 1c5-5 9 4 15-1v11c-6 5-10-4-15 1'/>",
		"clock":"<circle cx='12' cy='12' r='9'/><path d='M12 6v6l4 2'/>",
	}
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 24 24'><g fill='none' stroke='white' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % paths.get(kind,paths.home)
	var raster := Image.new()
	if raster.load_svg_from_string(svg) != OK: return null
	var result := ImageTexture.create_from_image(raster)
	cache[kind] = result
	return result
