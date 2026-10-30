extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rear: GDScript=load("res://vehicle/compact_rear_design.gd")
	var rear_source: String=rear.source_code
	var start: int=rear_source.find("static func build(")
	var end: int=rear_source.find("\nstatic func _lamps",start)
	var section: String=rear_source.substr(start,end-start)
	for call: String in ["_lamps(car,trim)","_tailgate(car,paint,trim)","_bumper_bevel(car)","_plate(car,trim,metal)","_window(car,trim)","_exhaust(car,trim,metal)"]:
		section=section.replace("\t"+call,"\tvar stamp_"+call.get_slice("(",0)+": int=Time.get_ticks_usec()\n\t"+call+"\n\tprint(\"REAR_PART "+call.get_slice("(",0)+" us=\",Time.get_ticks_usec()-stamp_"+call.get_slice("(",0)+")")
	rear.source_code=rear_source.substr(0,start)+section+rear_source.substr(end)
	assert(rear.reload(true)==OK)
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
