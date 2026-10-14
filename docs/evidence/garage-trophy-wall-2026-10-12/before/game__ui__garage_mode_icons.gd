extends RefCounted
## Original 64-unit Garage navigation glyphs, matching the Race rail's weight.
static var cache: Dictionary = {}

static func texture(mode: String) -> Texture2D:
	if cache.has(mode): return cache[mode]
	var art: String = ""
	match mode:
		"cars":
			art = "<path d='m15 28 5-14h24l5 14M11 28h42v21H11Z' fill='white' fill-opacity='.12'/><path d='M17 49v7h7v-7m16 0v7h7v-7M21 14h22M17 30h30'/><path d='M18 37h8m12 0h8' stroke-width='4'/><path d='M27 43h10' stroke-width='2'/><path d='m11 30-5-2m47 2 5-2'/>"
		"customise":
			art = "<path d='m29 32 21-21c3-3 8 2 5 5L34 37Z' fill='white' fill-opacity='.14'/><path d='M29 32c-7-1-12 3-13 9-1 5-5 8-9 8 5 7 18 10 25 3 5-5 6-10 2-15Z' fill='white' fill-opacity='.14'/><path d='m28 33 7 7M16 41l8 8m-4-12 9 9M8 49c5 3 14 4 19 0'/><path d='m47 14 5 5'/><path d='m15 11 1.6 4.8L21 17l-4.4 1.3L15 23l-1.6-4.7L9 17l4.4-1.2Z' fill='white' stroke='none'/>"
		"care":
			art = "<path d='M31 10c-4 8-15 20-15 30a15 15 0 0 0 30 0c0-10-11-22-15-30Z' fill='white' fill-opacity='.13'/><path d='M23 39c-1 6 2 10 7 10'/><circle cx='49' cy='15' r='5'/><circle cx='53' cy='30' r='3'/><circle cx='12' cy='19' r='3.5'/>"
		"tuning":
			art = "<path d='M44 8a13 13 0 0 0-16 15L10 41a7 7 0 0 0 10 10l18-18A13 13 0 0 0 53 17l-9 9-7-2-2-7Z' fill='white' fill-opacity='.14'/><circle cx='16' cy='45' r='2.6'/><path d='m26 30 8 8M47 43h10m-5-5v10'/>"
		_: return null
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><g fill='none' stroke='white' stroke-width='2.7' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % art
	var raster := Image.new()
	if raster.load_svg_from_string(svg, 3.0) != OK: return null
	raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[mode] = result
	return result
