class_name ResultsIcons
extends RefCounted
## Original vector UI artwork, rasterized once per requested icon size.
static func texture(kind: String, color: Color = Color("a5c8df")) -> Texture2D:
	var drawing: String = ""
	match kind:
		"friends":
			drawing = '<circle cx="12" cy="9" r="4"/><circle cx="24" cy="11" r="3"/><path d="M3 28v-5c0-8 18-8 18 0v5zM24 18c5 0 6 4 6 9h-5"/>'
		"back":
			drawing = '<path d="M27 16H5m9-9-9 9 9 9"/>'
		"home":
			drawing = '<path d="M3 15L16 4l13 11M7 13v15h7v-9h5v9h6V13"/>'
		"track":
			drawing = '<path d="M9 27C1 26 2 17 9 15c4-1 3-6 8-9 5-3 12-2 12 3s-7 6-8 10c-1 4 5 6 1 9-3 2-9 0-13-1z"/>'

		"coin":
			drawing = '<circle cx="16" cy="16" r="12"/><circle cx="16" cy="16" r="6" fill="currentColor"/>'
		"timer":
			drawing = '<circle cx="16" cy="18" r="11"/><path d="M12 2h8M16 2v5M16 11v7l3 2M24 7l3-3"/>'
		"flag":
			drawing = '<path d="M6 29l5-25h18l-3 15H8"/>'
			for y: int in range(3):
				for x: int in range(4):
					if (x+y)%2 == 0: drawing += '<path d="M%s %sh4l-1 5h-4z" fill="currentColor" stroke="none"/>' % [11+x*4-y,4+y*5]

		"podium":
			# Original awards podium: connected plinth, matte facets and gold winner.
			# The winner numeral is cut from the face, so panel colour shows through.
			drawing = '''<g stroke="none">
				<path fill-rule="evenodd" d="M2 16h8v11H2Zm2 3v1.5h2.5v1H4V25h4v-1.5H5.5v-1H8V19Z" fill="currentColor" opacity=".82"/>
				<path d="m2 16 3-3h5v3Z" fill="currentColor"/>
				<path fill-rule="evenodd" d="M20 18h7v9h-7Zm2 2v1.5h2v1H22v1h2v1H22V26h3.5v-6Z" fill="currentColor" opacity=".70"/>
				<path d="m20 18 3-3h7l-3 3Z" fill="currentColor"/>
				<path d="m27 18 3-3v9l-3 3Z" fill="currentColor" opacity=".42"/>
				<path d="m20 9 3-3v9l-3 3Z" fill="#b88d3c"/>
				<path fill-rule="evenodd" d="M10 9h10v18H10Zm2.5 6H14v6h-1.5v2H18v-2h-1.5v-9h-2l-2 1Z" fill="#ebcb79"/>
				<path d="m10 9 3-3h10l-3 3Z" fill="#fff0b9"/>
				<path d="M1 27h26l3-3v2l-3 3H1Z" fill="currentColor" opacity=".62"/>
				<path d="M1 27h26v1H1Z" fill="currentColor"/>
			</g>'''
		"Sectors", "bars":
			drawing = '<path d="M5 27V18h4v9zm9 0V11h4v16zm9 0V4h4v23z" fill="currentColor" stroke="none"/>'
		"Time diff":
			drawing = '<path d="M4 25l7-13 7 6 9-12"/><circle cx="4" cy="25" r="1.5"/><circle cx="11" cy="12" r="1.5"/><circle cx="18" cy="18" r="1.5"/><circle cx="27" cy="6" r="1.5"/>'
		"Speed":
			drawing = '<path d="M6 26a13 13 0 1 1 20 0M16 16l7-7M6 16h2M10 7l1 2M24 16h2"/><circle cx="16" cy="16" r="2" fill="currentColor"/>'
		"trophy":
			drawing = '<path d="M9 4h14v9c0 6-3 9-7 9s-7-3-7-9z" fill="currentColor"/><path d="M9 7H3c0 8 3 10 8 10M23 7h6c0 8-3 10-8 10M16 22v6M10 29h12"/>'
		"laurel":
			drawing = '<path d="M24 30C5 23 5 10 17 2" stroke-width="1"/>'
			for i: int in range(7):
				var t: float = 0.12+i*0.115
				# Each leaf starts and ends on the exact cubic stem, not an estimated arc.
				var base: Vector2 = Vector2(24,30).bezier_interpolate(Vector2(5,23),Vector2(5,10),Vector2(17,2),t)
				var tangent: Vector2 = Vector2(24,30).bezier_derivative(Vector2(5,23),Vector2(5,10),Vector2(17,2),t).normalized()
				var normal := Vector2(-tangent.y,tangent.x)
				for side: float in [-1.0,1.0]:
					var tip: Vector2 = base+tangent*3.9+normal*side*3.8
					var c1: Vector2 = base+normal*side*3.6
					var c2: Vector2 = base+tangent*3.8
					drawing += '<path d="M%s %sQ%s %s %s %sQ%s %s %s %sZ" fill="currentColor" stroke="none"/>' % [base.x,base.y,c1.x,c1.y,tip.x,tip.y,c2.x,c2.y,base.x,base.y]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32"><g fill="none" stroke="#%s" color="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [color.to_html(false),color.to_html(false),drawing]
	if kind == "laurel": svg = svg.replace('width="64" height="64" viewBox="0 0 32 32"','width="44" height="64" viewBox="4 0 22 32"')
	var image := Image.new()
	image.load_svg_from_string(svg,4.0 if kind == "podium" else 1.0)
	if kind == "podium": image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func view(kind: String, width: float, color: Color = Color("a5c8df")) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(kind,color)
	icon.custom_minimum_size = Vector2(width,46 if kind == "laurel" else width)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
