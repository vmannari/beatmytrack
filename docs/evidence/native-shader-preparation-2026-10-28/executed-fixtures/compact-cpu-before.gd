extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var task_config:=ConfigFile.new();task_config.set_value("backend","url","");assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	var source: GDScript=load("res://vehicle/compact_detail.gd")
	var rows: PackedStringArray=source.source_code.split("\n")
	var build: bool=false
	var annotated: PackedStringArray=[]
	for index: int in range(rows.size()):
		if rows[index].begins_with("static func build("): build=true
		elif rows[index].begins_with("static func "): build=false
		if build and "cooperate.call()" in rows[index]:
			var indent: String=rows[index].substr(0,rows[index].length()-rows[index].strip_edges(true,false).length())
			annotated.append(indent+"car._model_stage=\"details:L"+str(index+1)+"\"")
		annotated.append(rows[index])
	source.source_code="\n".join(annotated)
	assert(source.reload(true)==OK)
	var model: GDScript=load("res://vehicle/car_visual.gd")
	model.source_code=model.source_code.replace("var elapsed: int = Time.get_ticks_usec()-_model_slice_started","var elapsed: int = Time.get_ticks_usec()-_model_slice_started\n\tif elapsed>10000: print(\"COMPACT_SLICE \",_model_stage,\" us=\",elapsed)")
	assert(model.reload(true)==OK)
	for simple: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="compact";car.simple_model=simple;car.cooperative_build=true
		var began: int=Time.get_ticks_usec()
		root.add_child(car)
		while not car.model_ready: await process_frame
		print("COMPACT_PROFILE ",JSON.stringify({"simple":simple,"total_us":Time.get_ticks_usec()-began,"max_slice_us":car.model_max_slice_us,"stage":car.model_slice_at,"yields":car.model_yields}))
		car.queue_free()
		for index: int in range(8): await process_frame
	quit()
