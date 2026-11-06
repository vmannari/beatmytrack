extends SceneTree
## Exact decoded-pixel comparison of independently rendered control/candidate views.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var folder: String = ProjectSettings.globalize_path("res://../docs/evidence/startup-shell-2026-11-04")
	var rows: Array = []
	var different: int = 0
	for view: String in ["account","tracks","race","editor","garage"]:
		var first: Image = Image.load_from_file(folder.path_join(args[0]+"-views/"+view+".png"))
		var second: Image = Image.load_from_file(folder.path_join(args[1]+"-views/"+view+".png"))
		if first == null or second == null or first.get_size() != second.get_size(): quit(1); return
		first.convert(Image.FORMAT_RGBA8)
		second.convert(Image.FORMAT_RGBA8)
		var a: PackedByteArray = first.get_data()
		var b: PackedByteArray = second.get_data()
		var changed_pixels: int = 0
		var maximum: int = 0
		if a != b:
			for pixel: int in range(first.get_width()*first.get_height()):
				var changed: bool = false
				for channel: int in range(4):
					var delta: int = absi(int(a[pixel*4+channel])-int(b[pixel*4+channel]))
					maximum = maxi(maximum,delta)
					changed = changed or delta != 0
				if changed: changed_pixels += 1
		if changed_pixels: different += 1
		rows.append({"view":view,"changed_pixels":changed_pixels,"max_channel_delta":maximum,"pixel_exact":changed_pixels == 0})
	var result: Dictionary = {"before":args[0],"after":args[1],"rows":rows,"different_views":different}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SHELL_PIXEL_COMPARISON ",JSON.stringify(result))
	quit(1 if different else 0)
