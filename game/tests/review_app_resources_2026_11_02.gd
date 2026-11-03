extends SceneTree
## Load real resources in a fresh process without preloading App in the probe.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var resources: Array[Resource] = []
	var rows: Array = []
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	if paths.is_empty(): paths.append("res://core/app.tscn")
	for path: String in paths:
		var began: int = Time.get_ticks_usec()
		var resource: Resource = load(path)
		rows.append({"path":path,"ms":(Time.get_ticks_usec()-began)/1000.0,"ok":resource != null})
		resources.append(resource)
	var output: String = OS.get_environment("BMT_LOADING_OUTPUT")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"  "))
	file.close()
	print("RESOURCE_REVIEW ",JSON.stringify(rows))
	quit(1 if resources.has(null) else 0)
