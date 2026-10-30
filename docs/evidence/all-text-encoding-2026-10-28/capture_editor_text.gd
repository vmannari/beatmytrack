extends SceneTree
## Evidence-only text review using original menu labels/fonts and real catalogues.
const OUT: String = "res://../docs/evidence/all-text-encoding-2026-10-28"
const CODES: Array[String] = ["en", "fr", "es", "de", "pt_BR", "ja", "ko", "nl", "it", "fi", "sv", "nb"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280, 720)
	var before_source: String = FileAccess.get_file_as_string(OUT.path_join("before/game/core/app.gd"))
	var after_source: String = FileAccess.get_file_as_string("res://core/app.gd")
	var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("restored-translation-keys.json")))
	for locale: String in CODES:
		GameFonts.configure(locale)
		TranslationServer.set_locale(locale)
		var catalogue: Translation = TranslationServer.get_translation_object(locale)
		for key: Array in keys.keys:
			check(not catalogue.get_message(str(key[1])).is_empty(), locale + " has the repaired source key")
	for locale: String in ["en", "fi"]:
		GameFonts.configure(locale)
		TranslationServer.set_locale(locale)
		for version: String in ["before", "after"]:
			var source: String = before_source if version == "before" else after_source
			var surface := PanelContainer.new()
			surface.theme = MenuStyle.theme()
			surface.add_theme_stylebox_override("panel", MenuStyle.card(32))
			root.add_child(surface)
			surface.position = Vector2(64, 64)
			surface.size = Vector2(1152, 592)
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 22)
			surface.add_child(column)
			column.add_child(MenuBrand.new())
			for pattern: String in ['"(Choose a section[^"\n]+)"', '"(Drag the five numbered points[^"\n]+)"', '"(Rotate by 22.5[^"\n]+)"', '"(Width [^"\n]+)"', '"(Preparing image[^"\n]+)"', '"(Save failed [^"\n]+)"']:
				var expression := RegEx.create_from_string(pattern)
				var found: RegExMatch = expression.search(source)
				check(found != null, "caption comes directly from App source")
				var label: Label = MenuStyle.label(found.get_string(1), 22)
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				column.add_child(label)
			for frame: int in range(5): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(locale + "-" + version + "-text.png"))) == OK, "native text capture saved")
			check(surface.get_global_rect().encloses(column.get_global_rect()), "captions fit their panel")
			root.remove_child(surface)
			surface.queue_free()
			await process_frame
	print("ALL_TEXT_CAPTURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
