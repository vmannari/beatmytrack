extends SceneTree
## Opening the car page must not compile optional Garage tool controllers.
func _initialize() -> void:
	var failures: int=0
	var page: Script=load("res://ui/garage_page.gd")
	if page==null or not page.can_instantiate(): failures+=1
	for path: String in ["res://ui/garage_livery_menu.gd","res://ui/sticker_placement.gd","res://ui/garage_news_menu.gd","res://ui/garage_records_menu.gd","res://ui/achievements_menu.gd","res://ui/world_ranking_summary.gd","res://ui/cosmetic_purchase_dialog.gd","res://ui/garage_part_option.gd"]:
		if ResourceLoader.has_cached(path):
			failures+=1
			printerr("GARAGE_LAZY_FAIL optional controller imported ",path)
	print("GARAGE_LAZY_SECTIONS 9 checks, ",failures," failures")
	quit(1 if failures else 0)
