extends SceneTree
const Layout = preload("res://ui/keyboard_dialog.gd")
var failures: int = 0
var checks: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	for scale: float in [1.0, 1.5, 2.0, 3.0]:
		for keyboard: float in [240.0, 360.0, 440.0]:
			var transform := Transform2D(Vector2(scale,0),Vector2(0,scale),Vector2.ZERO)
			var rect: Rect2 = Layout.available_rect(Rect2(0,0,1280,720),transform,720*scale,keyboard*scale)
			check(is_equal_approx(rect.end.y,720-keyboard-8),"keyboard pixels map to viewport at scale "+str(scale))
	var dialog := ConfirmationDialog.new()
	dialog.title = "Save this draft?"
	dialog.ok_button_text = "Save"
	dialog.add_button("Discard",true,"discard")
	var field := LineEdit.new()
	field.text = "My phone circuit"
	field.custom_minimum_size = Vector2(440,52)
	dialog.add_child(field)
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(520,180))
	await process_frame
	for height: float in [0.0,320.0,440.0]:
		Layout.layout(dialog,root,height)
		await process_frame
		check(dialog.position.y >= 8,"dialog stays below screen top")
		check(dialog.position.y+dialog.size.y <= 720-height-8,"whole dialog clears keyboard")
		check(field.get_global_rect().size.y >= 52,"touch field retains height")
	if "--capture" in OS.get_cmdline_user_args():
		var keyboard := ColorRect.new()
		keyboard.color = Color("27313f")
		keyboard.position = Vector2(0,280)
		keyboard.size = Vector2(1280,440)
		root.add_child(keyboard)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/phone-keyboard-2026-10-12/save-keyboard.png"))
	print("Keyboard dialog: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
