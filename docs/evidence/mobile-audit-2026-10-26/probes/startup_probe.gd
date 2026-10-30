extends SceneTree
class AuditApp extends "res://core/app.gd":
	func _prepare_garage_covered() -> void:
		var begin: int = Time.get_ticks_usec()
		await super._prepare_garage_covered()
		print("STARTUP_GARAGE ",JSON.stringify({"milliseconds":(Time.get_ticks_usec()-begin)/1000.0,"retained":is_instance_valid(_retained_garage),"viewports":_retained_garage.find_children("*","SubViewport",true,false).size() if is_instance_valid(_retained_garage) else 0}))

func _initialize() -> void: run.call_deferred()
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var started: int = Time.get_ticks_usec()
	var app: Node = AuditApp.new()
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+90000
	while not app.startup_complete and Time.get_ticks_msec()<deadline: await process_frame
	print("STARTUP_TOTAL ",JSON.stringify({"milliseconds":(Time.get_ticks_usec()-started)/1000.0,"ready":app.startup_complete,"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}))
	app.queue_free()
	await process_frame
	await process_frame
	quit()
