extends SceneTree
const Notices = preload("res://legal/third_party_notices.gd")
const Before = preload("res://../docs/evidence/challenger-hellcat-2026-11-09/before/game/legal/third_party_notices.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var panel: Control = load("res://ui/licences_panel.gd").new()
	panel.theme = MenuStyle.theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(panel)
	await process_frame
	var results: Dictionary = {}
	for entry: Dictionary in Notices.COMMON:
		if entry.id not in ["challenger_hellcat","kart_driver"]: continue
		var index: int = Notices.COMMON.find(entry)
		panel.call("_select",index)
		await process_frame
		var raw: String = Notices.text_for(entry)
		var rendered: String = panel.document.get_parsed_text()
		results[entry.id] = {"exact_render":rendered == raw,"crlf":raw.count("\r\n"),"exact_after_cr_removal":rendered == raw.replace("\r","")}
		if entry.id == "challenger_hellcat":
			assert(rendered == FileAccess.get_file_as_string(entry.files[0]))
			assert(rendered.contains("Richerworld") and rendered.contains("https://creativecommons.org/licenses/by/4.0/"))
			assert(panel.selected_id == "challenger_hellcat")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../docs/evidence/challenger-hellcat-2026-11-09/licences/challenger.png")
		else:
			for old_entry: Dictionary in Before.COMMON:
				if old_entry.id == "kart_driver": results[entry.id].task_start_text_exact = Before.text_for(old_entry) == raw
	var file := FileAccess.open("res://../docs/evidence/challenger-hellcat-2026-11-09/licence-diagnostic.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")); file.close()
	print("CHALLENGER_CREDIT: exact source and licence rendered; diagnostics ",JSON.stringify(results))
	panel.free()
	quit()
