extends SceneTree
const Menu = preload("res://ui/garage_records_menu.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu := Menu.new()
	menu.records = LocalRecords.new("user://record_flip_motion/records.json")
	root.add_child(menu)
	menu._browse_to(1)
	check(menu.display_position == 0.0,"selection starts at the visible pose")
	menu.flip_motion.pause()
	menu.flip_motion.custom_step(0.2)
	check(menu.display_position > 0.0 and menu.display_position < 1.0,"flip passes through intermediate poses")
	var pose: float = menu.display_position
	menu._browse_to(0)
	check(menu.display_position == pose,"rapid reversal does not snap")
	menu.flip_motion.pause()
	menu.flip_motion.custom_step(0.2)
	check(menu.display_position > 0.0 and menu.display_position < pose,"reversal moves smoothly from current pose")
	menu.flip_motion.custom_step(1.0)
	check(menu.display_position == 0.0,"flip settles exactly")
	menu._browse_to(13)
	menu.flip_motion.pause()
	menu.flip_motion.custom_step(0.55)
	check(menu.display_position > 1.0 and menu.display_position < 12.0,"distant selection animates intervening sleeves")
	menu.finish()
	check(menu.display_position == 13.0 and menu.flip_motion == null,"closing settles and stops animation")
	menu.free()
	print("Record flip motion: 7 checks, ",failures," failures")
	quit(1 if failures else 0)
