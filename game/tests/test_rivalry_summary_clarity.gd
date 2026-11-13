extends "res://tests/test_rivalry_awards.gd"
## Offline rendering of final facts, partial participation and translated layout.
const Sheet = preload("res://ui/rivalry_summary_dialog.gd")

func run() -> void:
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-summary-clarity-2026-11-09/ui")
	DirAccess.make_dir_recursive_absolute(evidence)
	var before: bool = "--clarity-before" in OS.get_cmdline_user_args()
	if before:
		for source: String in ["rivalry_summary_banner.gd","rivalry_summary_dialog.gd"]:
			var original: GDScript = load("res://ui/"+source)
			original.source_code = FileAccess.get_file_as_string("res://../docs/evidence/rivalry-summary-clarity-2026-11-09/before/"+source)
			check(original.reload() == OK,"before source loads only in this test process")
	for locale: String in ["en","fi","de","fr","es","it","pt_BR","nl","sv","nb","ja","ko"]:
		TranslationServer.set_locale(locale)
		for kind: String in ["partial","perfect","champion","podium","middle","unranked","tied","solo"]:
			if before and (locale != "en" or kind != "partial"): continue
			var model := WeeklyRivalry.new()
			model.apply_snapshot(awarded_snapshot("perfect" if kind == "solo" else "middle" if kind == "partial" else kind))
			var facts: Dictionary = model.finale_summary()
			facts.personal_bests = model.personal_best_slots.size()
			var opponent: Dictionary = {}
			for driver: Dictionary in model.standing():
				if driver.id != WeeklyRivalry.SELF:
					opponent = driver
					break
			facts.opponent_points = opponent.get("points")
			facts.lead = int(facts.points)-int(opponent.get("points",0))
			if kind == "partial":
				# The owner's screenshot: final place and only one of five tracks raced.
				facts.merge({"rank":14,"drivers":14,"points":30,"opponent_points":126,"lead":-96,"completed":1,"wins":1,"personal_bests":1},true)
			if kind == "solo": facts.opponent_points = null
			for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
				root.size = dimensions
				var dialog: AcceptDialog = Sheet.new()
				dialog.summary = facts
				dialog.week = 45
				dialog.player_name = "VILLE"
				root.add_child(dialog)
				dialog.present()
				await settle()
				if not before:
					check(dialog.rank_label.text == ("—" if facts.rank == null else str(int(facts.rank))),"actual final rank")
					check(dialog.metric_labels[0].text == "%d / 5" % int(facts.completed),"participation stays separate from final placing")
					check(dialog.metric_labels[1].text == str(int(facts.wins)),"victories are a count")
					check(dialog.metric_labels[2].text == str(int(facts.personal_bests)),"personal bests are a count")
					check(dialog.lead_label.text.is_empty() if facts.rank == null or facts.opponent_points == null else true,"missing rank or opponent has no misleading gap")
					if kind == "partial": check(dialog.lead_label.text == GameText.message("%d PTS BEHIND") % 96,"final gap uses completed-week language")
					for label: Label in dialog.surface.find_children("*","Label",true,false):
						if not label.is_visible_in_tree(): continue
						var font: Font = label.get_theme_font("font")
						var font_size: int = label.get_theme_font_size("font_size")
						check(Rect2(Vector2.ZERO,Vector2(dialog.size)).grow(1).encloses(label.get_global_rect()),locale+" "+kind+" label inside popup: "+label.text)
						if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
							check(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= label.size.x+1,locale+" "+kind+" text fits: "+label.text)
				if DisplayServer.get_name() != "headless" and dimensions.x == 1280 and ((locale == "en" and kind in ["partial","perfect","unranked","tied"]) or (locale in ["fi","de","ja"] and kind == "partial")):
					await RenderingServer.frame_post_draw
					var shot: Image = dialog.get_texture().get_image()
					shot.save_png(evidence.path_join(("before-" if before else "after-")+locale+"-"+kind+"-"+RenderingServer.get_current_rendering_method()+".png"))
				dialog.hide()
				dialog.queue_free()
				await process_frame
	TranslationServer.set_locale("en")
	print("RIVALRY_SUMMARY_CLARITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
