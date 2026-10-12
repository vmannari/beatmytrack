class_name MenuIcon
extends RefCounted
## Original, consistent vector navigation glyphs, rasterized once by Godot.

static var cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var biome_svg: String = _biome_svg(kind)
	if not biome_svg.is_empty():
		var biome_image := Image.new()
		if biome_image.load_svg_from_string(biome_svg,4.0) != OK: return null
		biome_image.generate_mipmaps()
		var biome_texture := ImageTexture.create_from_image(biome_image)
		cache[kind] = biome_texture
		return biome_texture
	var paths: Dictionary = {
		"controller":"<path d='M7 7h10c3 0 5 12 3 13-2 1-4-4-5-4H9c-1 0-3 5-5 4C2 19 4 7 7 7Z'/><path d='M8 10v5m-2.5-2.5h5M16 11h.1M18 14h.1'/>",
		"phone":"<rect x='6' y='2' width='12' height='20' rx='2'/><path d='M10 5h4M11 19h2'/>",
		"check":"<path d='m4 12 5 5L20 6'/>",
		"resume":"<path d='M4 9a8 8 0 1 1 0 7M4 3v6h6'/>",
		"restart":"<path d='M16 5a8 8 0 1 0 4 8M16 1v5h-5'/>",
		"help":"<circle cx='12' cy='12' r='9'/><path d='M9 8a3 3 0 1 1 4 3c-1 1-1 1-1 3M12 17v1'/>",
		"quit":"<path d='M13 3H4v18h9M10 12h12m-5-5 5 5-5 5'/>",
		"avatar":"<circle cx='12' cy='12' r='10.5' fill='#284858' stroke='#607d8c'/><circle cx='12' cy='9' r='3' fill='#a4bac7' stroke='none'/><path d='M5.5 19c0-7 13-7 13 0' fill='#a4bac7' stroke='none'/>",
		"chevron":"<path d='m6 9 6 6 6-6'/>",
		"gear":"<path d='m10 2-.6 3-2 .9-2.7-1L2.7 8l2.2 2v3l-2.2 2 2 3.2 2.7-.9 2 .9.6 3h4l.6-3 2-.9 2.7.9 2-3.2-2.2-2v-3l2.2-2-2-3.1-2.7 1-2-.9L14 2Z'/><circle cx='12' cy='11.6' r='3.3'/>",
		"close":"<path d='m5 5 14 14M19 5 5 19'/>",
		"filter":"<path d='M3 4h18l-7 8v7l-4 2v-9Z'/>",
		"trophy":"<path d='M7 3h10v7a5 5 0 0 1-10 0ZM7 5H3v3a5 5 0 0 0 5 5m9-8h4v3a5 5 0 0 1-5 5M12 15v5m-5 1h10'/>",
		"target":"<circle cx='11' cy='13' r='8'/><circle cx='11' cy='13' r='4'/><path d='m11 13 9-10m-1 0v4h4'/>",
		"dice":"<g stroke-width='1.35'><path d='m12 2 9 5v10l-9 5-9-5V7Z' fill='white' fill-opacity='.10'/><path d='m3 7 9 5 9-5M12 12v10M3 7l9-5 9 5-9 5Z' fill='white' fill-opacity='.22'/><path d='m5 10 1.8 1v2L5 12Zm3 6 1.8 1v2L8 18Zm7-3 1.5-.85v1.8l-1.5.85Zm3-4 1.5-.85v1.8l-1.5.85Zm-3 9 1.5-.85v1.8L15 20Zm3-4 1.5-.85v1.8l-1.5.85Z' fill='white' stroke='none'/><path d='m10 6 2-1.1L14 6l-2 1.1Z' fill='white' stroke='none'/></g>",
		"compass":"<circle cx='12' cy='12' r='9'/><path d='m16 8-2 6-6 2 2-6z'/>",
		"person":"<circle cx='12' cy='7' r='4'/><path d='M5 22v-4c0-6 14-6 14 0v4'/>",
		"friends":"<circle cx='9' cy='7' r='3'/><circle cx='18' cy='9' r='2.5'/><path d='M2 21v-4c0-6 14-6 14 0v4zM18 14c4 0 5 2 5 6h-4'/>",
		"search":"<circle cx='10' cy='10' r='7'/><path d='m15 15 7 7'/>",
		"biomes":"<path d='m2 21 7-15 6 15zm10 0 5-11 6 11zM6 13l3 2 2-2'/>",
		"sort":"<path d='M7 21V3L3 7m4-4 4 4M17 3v18l-4-4m4 4 4-4'/>",
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
		"folder":"<path d='M3 6h7l2 3h9v11H3Z'/>",
		"edit":"<path d='m4 16 12-12 4 4L8 20l-5 1ZM13 7l4 4'/>",
		"play":"<path d='m6 3 15 9L6 21Z' fill='white' stroke='none'/>",
		"publish":"<path d='M6 19a4 4 0 0 1-1-8 7 7 0 0 1 13-2 5 5 0 0 1 0 10'/><path d='M12 21V11m-4 4 4-4 4 4'/>",
		"delete":"<path d='M4 6.5h16M9 6.5V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2.5M6 9l.8 10.6A1.5 1.5 0 0 0 8.3 21h7.4a1.5 1.5 0 0 0 1.5-1.4L18 9M10 10.5v7.5m4-7.5v7.5'/>",
	}
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 24 24'><g fill='none' stroke='white' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % paths.get(kind,paths.home)
	var raster := Image.new()
	if raster.load_svg_from_string(svg,4.0 if kind == "delete" else 1.0) != OK: return null
	if kind == "delete": raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[kind] = result
	return result

static func _biome_svg(kind: String) -> String:
	# Filled silhouettes on one optical grid; transparent cutouts stay clean on
	# both card artwork and panels. Render at 112 px for 30/34 px menu use.
	var artwork: String = ""
	match kind:
		"leaf":
			# A single tapered vein divides the blade without crossing its contour.
			artwork = "<path d='M12 43C7 28 18 21 34 19Q48 18 56 8Q55 23 50 28C54 43 38 54 20 47Q30 36 43 30Q22 34 12 43Z'/><path d='M8 57Q14 44 26 38' fill='none' stroke='white' stroke-width='3' stroke-linecap='round'/>"
		"cactus":
			artwork = "<path d='M27 57V39H21Q12 39 12 30V24A4.5 4.5 0 0 1 21 24V29Q21 31 23 31H27V10A5 5 0 0 1 37 10V35H41Q43 35 43 33V21A4.5 4.5 0 0 1 52 21V34Q52 43 43 43H37V57Q37 59 35 59H29Q27 59 27 57Z'/>"
		"night":
			artwork = "<path d='M38 5C24 5 17 16 17 29Q25 25 31 32Q37 31 41 39Q48 45 41 56Q53 53 59 44C37 42 27 24 38 5Z'/><path d='M11 56C1 56 0 43 9 41C8 31 23 28 27 38C35 35 42 46 35 51Q34 58 27 58Q22 59 18 55Q15 57 11 56Z'/><path d='m48 9 1.1 3.8L53 14l-3.9 1.2L48 19l-1.2-3.8L43 14l3.8-1.2ZM55 23l1.2 3.8L60 28l-3.8 1.2L55 33l-1.2-3.8L50 28l3.8-1.2ZM8 19l1 3L12 23l-3 1-1 3-1-3-3-1 3-1Z'/>"
		"snowflake":
			# One branch rotated six times: every fork joins its own radial arm.
			for angle: int in range(0,360,60):
				artwork += "<path transform='rotate(%d 32 32)' d='M32 32V5M24 11L32 17L40 11' fill='none' stroke='white' stroke-width='2.6' stroke-linecap='round' stroke-linejoin='round'/>" % angle
		"storm":
			artwork = "<path d='M16 39C3 39 3 20 16 20C16 5 39 3 42 20C56 17 61 39 47 39Z'/><path d='M29 43H40L33 50H39L25 61L29 52H23Z'/><path d='M15 44Q10 50 15 51Q20 50 15 44ZM47 44Q42 50 47 51Q52 50 47 44Z'/>"
		_: return ""
	return "<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 64 64'><g fill='white'>%s</g></svg>" % artwork
