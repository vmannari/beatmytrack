extends SceneTree
var checks: int = 0
var failures: int = 0

class Preview extends Control:
	var presentation_ready: bool = false

class InitialMenu extends "res://core/app.gd":
	var speculative_requests: int = 0
	func _ready() -> void:
		content = VBoxContainer.new(); add_child(content)
		screen = "restoring"
		_initial_menu_drawn.call_deferred()
	func _prefetch_discovery() -> void:
		speculative_requests += 1
	func _exit_tree() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func frames() -> void:
	for index: int in range(4): await process_frame
func run() -> void:
	var app := InitialMenu.new(); root.add_child(app)
	await frames()
	check(not app._initial_menu_presented and app.speculative_requests==0,"restoring shell does not release optional work")
	app.screen = "rivalry"
	var car := Preview.new(); car.name = "RivalryPodiumCar_1"; app.content.add_child(car)
	await frames()
	check(not app._initial_menu_presented and app.speculative_requests==0,"actual podium preparation holds speculative work")
	car.presentation_ready = true
	await frames()
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	await frames()
	check(app._initial_menu_presented and app.speculative_requests==1,"presented content releases the deferred discovery once")
	app.free()
	var closing := InitialMenu.new(); root.add_child(closing)
	await frames(); closing.queue_free(); await frames()
	check(not is_instance_valid(closing),"closing during restoration releases the waiter safely")
	print("INITIAL_MENU_READINESS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
