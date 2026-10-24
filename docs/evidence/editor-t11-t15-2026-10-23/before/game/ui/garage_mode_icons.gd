extends RefCounted
## Original Garage emblems. A 64-unit master, substantial silhouettes and open
## cutouts keep the same visual language legible on both gold and navy buttons.
## White artwork inherits Button tint; the holes remain genuinely transparent.
static var cache: Dictionary = {}

static func texture(mode: String) -> Texture2D:
	if cache.has(mode): return cache[mode]
	var art: String = ""
	match mode:
		"cars":
			# A planted, head-on Compact: chamfered shoulders, wide glass and lamps.
			art = """
			<path fill-rule='evenodd' d='M9 46V35q0-4 4-6l4-12q1.5-5 7-5h16q5.5 0 7 5l4 12q4 2 4 6v11q0 3-3 3H12q-3 0-3-3Zm13-28-4 12h28l-4-12Zm-7 19v5h10v-5Zm24 0v5h10v-5Zm-10 0v3h6v-3Z'/>
			<path d='M11 47h8v5q0 2-2 2h-4q-2 0-2-2Zm34 0h8v5q0 2-2 2h-4q-2 0-2-2Z'/>
			"""
		"customise":
			# A tapered studio brush, with a separate metal ferrule and swept bristles.
			art = """
			<path d='m26 29 19-19a6 6 0 0 1 9 8L35 37Z'/>
			<path d='m24 32 9 9-5 5-9-9Z' fill-opacity='.58'/>
			<path d='M18 40q-7 1-7 9 0 4-4 6 20 4 21-10l-5-5Z'/>
			"""
		"care":
			# Broad water silhouette, an open reflection and a four-point clean glint.
			art = """
			<path fill-rule='evenodd' d='M28 9c-4 8-18 21-18 31a18 18 0 0 0 36 0C46 30 32 17 28 9Zm-9 27a1.8 1.8 0 0 0-3.5.5A13 13 0 0 0 27 50a1.8 1.8 0 0 0 .5-3.5A9.5 9.5 0 0 1 19 36Z'/>
			<path d='m48 8 2.5 7.5L58 18l-7.5 2.5L48 28l-2.5-7.5L38 18l7.5-2.5Z'/>
			"""
		"tuning":
			# Forged open-end spanner. A real open jaw and punched socket, no outline.
			art = """
			<path fill-rule='evenodd' d='M39 9q-14 0-14 14 0 3 1 5L10 44a7 7 0 0 0 10 10l17-17q3 1 5 1 14 0 14-14l-1-5-10 10-9-2-2-9 9-9Zm-26 38a3 3 0 1 0 6 0 3 3 0 0 0-6 0Z'/>
			"""
		"records":
			# One continuous musical silhouette, with a broad raked beam and full heads.
			art = """
			<path d='m25 15 27-6v31c0 5-5 9-11 9-5 0-8-2-8-6 0-5 5-8 11-8h3V22l-16 4v20c0 5-5 9-11 9-5 0-8-2-8-6 0-5 5-8 11-8h2Z'/>
			"""
		"trophies":
			# Championship cup with a punched star, flared handles and a stepped foot.
			art = """
			<path fill-rule='evenodd' d='M18 10h28v13c0 11-5 17-12 19v6h10l4 6H16l4-6h10v-6c-7-2-12-8-12-19Zm14 8-2.4 5-5.6.8 4 4-.9 5.5 4.9-2.6 4.9 2.6-.9-5.5 4-4-5.6-.8Z'/>
			<path d='M18 17H9v7c0 8 5 13 14 14M46 17h9v7c0 8-5 13-14 14' fill='none' stroke='white' stroke-width='3.5' stroke-linejoin='round'/>
			"""
		"news":
			# Printed front page, photo block and folded trailing sheet; ample column gaps.
			art = """
			<path fill-rule='evenodd' d='M10 10h37v11h9v27q0 6-6 6H16q-6 0-6-6Zm4 4v34q0 2 2 2h28a6 6 0 0 1-1-3V14Zm33 11v22a3 3 0 0 0 6 0V25Z'/>
			<path d='M19 19h19v5H19Zm0 10h9v11h-9Zm13 0h6v3h-6Zm0 7h6v3h-6ZM19 44h19v3H19Z'/>
			"""
		_: return null
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'><g fill='white'>%s</g></svg>" % art
	var raster := Image.new()
	if raster.load_svg_from_string(svg,4.0) != OK: return null
	raster.generate_mipmaps()
	var result := ImageTexture.create_from_image(raster)
	cache[mode] = result
	return result
