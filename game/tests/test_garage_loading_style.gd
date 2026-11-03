extends "res://tests/test_garage_deferred_views.gd"
## Rendered loading-state review plus the retained real-App lifecycle checks.
var reviewed: bool = false

func caption_fits(placeholder: Control, label: String) -> void:
	var caption: Label = placeholder.get_node("LoadingCaption")
	var font: Font = caption.get_theme_font("font")
	var width: float = font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
	check(width <= caption.size.x,"localized loading text fits "+label)
	check(caption.position.x >= 0 and caption.get_rect().end.x <= placeholder.size.x,"loading text stays inside its preview "+label)
	if placeholder.compact:
		check(caption.get_rect().end.y <= placeholder.size.y-36,"loading message clears the car-name footer "+label)

func pixels_changed(a: Image, b: Image) -> int:
	var changed: int = 0
	for y: int in range(0,a.get_height(),3):
		for x: int in range(0,a.get_width(),3):
			var delta: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(delta.r)+absf(delta.g)+absf(delta.b) > 0.012: changed += 1
	return changed

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if label == "loading-1280x720" and not reviewed:
		reviewed = true
		var page: GaragePage = app._retained_garage
		var cover: Control = page.showroom.get_node("GarageOpeningPicture")
		for locale: String in ["en","fi","de","fr","es","pt_BR","ja","ko","nl","it","sv","nb"]:
			GameFonts.configure(locale)
			TranslationServer.set_locale(locale)
			GameText.refresh(self)
			await frames(3)
			caption_fits(cover,"main/"+locale)
			for id: String in page.thumbnails: caption_fits(page.thumbnails[id]._placeholder,id+"/"+locale)
			if locale in ["fi","de","ja"]: await super.capture("loading-"+locale)
		GameFonts.configure("en")
		TranslationServer.set_locale("en")
		GameText.refresh(self)
		await frames(4)
		await RenderingServer.frame_post_draw
		var region := Rect2i(cover.get_node("LoadingCarMask").get_global_rect())
		var first: Image = root.get_texture().get_image().get_region(region)
		await create_timer(0.55).timeout
		await RenderingServer.frame_post_draw
		var second: Image = root.get_texture().get_image().get_region(region)
		await create_timer(0.55).timeout
		await RenderingServer.frame_post_draw
		var third: Image = root.get_texture().get_image().get_region(region)
		var motion: int = maxi(pixels_changed(first,second),pixels_changed(second,third))
		check(motion > 100,"rendered ghost and light actually animate")
		print("GARAGE_LOADING_STYLE_MOTION changed_samples=",motion)
	await super.capture(label)
