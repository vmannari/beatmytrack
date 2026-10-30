extends SceneTree

class HeldWorker extends RefCounted:
	var done: bool=false
	var result: Dictionary={}
	func cancel() -> void: pass

var failures: int=0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value:
		failures+=1
		print("FAIL: ",label)

func run() -> void:
	var cache: Node=preload("res://ui/garage_preview_cache.gd").new()
	root.add_child(cache)
	cache.set_process(false)
	cache.idle_ms=0
	cache.directory="user://garage-pipeline-test"
	cache.immediate_reads=true
	var view: CarShowroom=preload("res://ui/garage_cached_thumbnail.gd").new()
	view.vehicle_id="compact"
	view.livery=VehicleLivery.for_car({},"compact")
	view.livery.colors.body="c72d34"
	view.customisation=VehicleCustomisation.defaults()
	view.preview_service=cache
	cache.warm_views[view.vehicle_id]=view
	cache.add_child(view)
	var held:=HeldWorker.new()
	cache.worker=held
	cache.io={"read":true}
	cache._process(0.0)
	check(cache.renderer==null,"a pending read retains priority")
	cache.io={"read":false}
	cache._process(0.0)
	check(cache.renderer!=null and cache.worker==held,"a pending write overlaps the next capture")
	check(cache.renders==1,"only one native capture starts")
	cache._finish()
	cache.worker=null
	cache.queue_free()
	await process_frame
	print("GARAGE_PREVIEW_PIPELINE: ",3-failures,"/3 passed")
	quit(1 if failures else 0)
