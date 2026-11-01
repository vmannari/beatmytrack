extends SceneTree
## A layout pass must not reissue theme changes when dimensions are unchanged.
var notices: int = 0
var failures: int = 0
var checks: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var shelf = preload("res://ui/garage_parts_list.gd").new()
	root.add_child(shelf)
	var row = preload("res://ui/garage_part_option.gd").new()
	row.setup(0,["stock","Original"],"Factory finish",func() -> void: pass)
	shelf.cards.add_child(row)
	for frame: int in range(8): await process_frame
	shelf._layout_cards()
	row.title.theme_changed.connect(func() -> void: notices += 1)
	for i: int in range(20): shelf._layout_cards()
	check(notices == 0,"unchanged layout does not repeatedly invalidate row themes")
	row.size.x = 300
	row._layout()
	check(row.title.get_theme_font_size("font_size") == 20,"narrow row uses compact text")
	var after_narrow: int = notices
	row._layout()
	check(notices == after_narrow,"narrow layout also settles")
	row.size.x = 500
	row._layout()
	check(row.title.get_theme_font_size("font_size") == 25,"wide row restores normal text")
	var after_wide: int = notices
	row._layout()
	check(notices == after_wide,"wide layout also settles")
	row.add_car_icon()
	row.size.x = 300
	row._layout()
	for frame: int in range(4): await process_frame
	for i: int in range(20): row._layout()
	check(row.custom_minimum_size.y == 100,"narrow paint row retains its required height")
	shelf.free()
	print("PARTS_LAYOUT_STABILITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
