extends RefCounted
## Original 64-unit navigation artwork; optical weight tuned for 38px display.
static var cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var art: String = ""
	match kind:
		"sun":
			# Keep the established rail key; a calendar and race flag identify the daily track.
			art = "<rect x='8' y='12' width='48' height='46' rx='5' fill='white' fill-opacity='.08'/><path d='M20 6v12M44 6v12M8 24h48M22 51V31h22v14H22'/><path d='M22 31h5.5v7H22ZM33 31h5.5v7H33ZM27.5 38H33v7h-5.5ZM38.5 38H44v7h-5.5Z' fill='white' stroke='none'/>"
		"trophy":
			# Ranked competitors communicate the Rivalry standings, rather than a generic award.
			art = "<path d='M7 57V39h17V27h16v18h17v12Z' fill='white' fill-opacity='.08'/><path d='M24 39v18M40 45v12'/><circle cx='15.5' cy='27' r='4.5'/><circle cx='32' cy='12' r='5'/><circle cx='48.5' cy='33' r='4.5'/><path d='M8.5 38v-2c0-6 14-6 14 0v2M25 26v-4c0-6 14-6 14 0v4M41.5 44v-2c0-6 14-6 14 0v2'/>"
		"flag":
			art = "<path d='m12 56 7-47M18 14c12-9 23 9 37 0l-4 27c-14 9-25-9-37 0' stroke-width='3'/><path d='M18 14c3-2 6-3 9-2l-1.3 9c-3-1-6 0-9 2ZM35 15c3 1 6 3 9 3l-1.3 9c-3 0-6-2-9-3ZM53.7 23l-1.3 9c-3 2-6 3-9 2l1.3-9c3 1 6 0 9-2ZM25.7 21c3 0 6 2 9 3l-1.3 9c-3-1-6-3-9-3ZM15.4 32c3-2 6-3 9-2l-1.3 9c-3-1-6 0-9 2ZM33.4 33c3 1 6 3 9 3l-1.3 9c-3 0-6-2-9-3Z' fill='white' stroke='none'/>"
		"target":
			art = "<g transform='scale(2.6666666667)' stroke-width='1.05'>%s</g>" % MenuIcon.CHALLENGES_ART
		"friends":
			art = "<circle cx='26' cy='20' r='9' fill='white' fill-opacity='.13'/><path d='M43 13a8 8 0 0 1 0 16M9 51v-5c0-9 7-14 17-14s17 5 17 14v5Z' fill='white' fill-opacity='.1'/><path d='M46 35c7 1 11 5 11 12v4h-8M18 51v-7m16 7v-7'/><path d='M23 19h6' stroke-width='2'/>"
	var source: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><g fill='none' stroke='white' stroke-width='2.7' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % art
	var raster := Image.new()
	if raster.load_svg_from_string(source,3.0) != OK: return null
	raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[kind] = result
	return result
