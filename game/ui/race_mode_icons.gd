extends RefCounted
## Original 64-unit navigation artwork; optical weight tuned for 38px display.
static var cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var art: String = ""
	match kind:
		"trophy":
			art = "<path d='M19 10h26v15c0 10-6 16-13 16s-13-6-13-16Z' fill='white' fill-opacity='.13'/><path d='M19 15H9v7c0 8 5 13 13 14m23-21h10v7c0 8-5 13-13 14M32 41v11M22 55h20M25 51h14M17 10h30'/><path d='m32 17 2.5 5 5.5.8-4 3.9 1 5.5-5-2.6-5 2.6 1-5.5-4-3.9 5.5-.8Z' fill='white' stroke='none'/>"
		"flag":
			art = "<path d='m12 56 7-47M18 14c12-9 23 9 37 0l-4 27c-14 9-25-9-37 0' stroke-width='3'/><path d='M18 14c3-2 6-3 9-2l-1.3 9c-3-1-6 0-9 2ZM35 15c3 1 6 3 9 3l-1.3 9c-3 0-6-2-9-3ZM53.7 23l-1.3 9c-3 2-6 3-9 2l1.3-9c3 1 6 0 9-2ZM25.7 21c3 0 6 2 9 3l-1.3 9c-3-1-6-3-9-3ZM15.4 32c3-2 6-3 9-2l-1.3 9c-3-1-6 0-9 2ZM33.4 33c3 1 6 3 9 3l-1.3 9c-3 0-6-2-9-3Z' fill='white' stroke='none'/>"
		"target":
			art = "<path d='M47 29a21 21 0 1 1-13-15' stroke-width='3'/><path d='M38 31a12 12 0 1 1-11-8' stroke-width='3'/><circle cx='27' cy='35' r='3.5' fill='white' stroke='none'/><path d='m28 34 22-22M42 12l9-5-1 9 8 1-8 8-8-1Z' fill='white' fill-opacity='.2'/><path d='m42 24 8-8'/><path d='m11 51-3 5m31-1 3 3'/>"
		"friends":
			art = "<circle cx='26' cy='20' r='9' fill='white' fill-opacity='.13'/><path d='M43 13a8 8 0 0 1 0 16M9 51v-5c0-9 7-14 17-14s17 5 17 14v5Z' fill='white' fill-opacity='.1'/><path d='M46 35c7 1 11 5 11 12v4h-8M18 51v-7m16 7v-7'/><path d='M23 19h6' stroke-width='2'/>"
	var source: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><g fill='none' stroke='white' stroke-width='2.7' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % art
	var raster := Image.new()
	if raster.load_svg_from_string(source,3.0) != OK: return null
	raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[kind] = result
	return result
